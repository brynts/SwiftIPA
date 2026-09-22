import Foundation
import Compression

enum DebExtractorError: LocalizedError {
    case notADeb
    case unsupportedCompression(String)
    case noDylibFound
    case corruptArchive

    var errorDescription: String? {
        switch self {
        case .notADeb:
            return String(localized: "This isn't a valid .deb package.")
        case .unsupportedCompression(let name):
            return String(localized: "This .deb uses \(name) compression, which SwiftIPA can't unpack yet. Re-export it as a raw .dylib instead.")
        case .noDylibFound:
            return String(localized: "No .dylib was found inside this .deb package.")
        case .corruptArchive:
            return String(localized: "This .deb package looks corrupted.")
        }
    }
}

enum DebExtractor {
    static func extractDylibs(from debURL: URL, into destinationFolder: URL) throws -> [URL] {
        let data = try Data(contentsOf: debURL)
        guard data.count > 8, data.prefix(8).elementsEqual(Array("!<arch>\n".utf8)) else {
            throw DebExtractorError.notADeb
        }

        var cursor = 8
        var dataMember: (name: String, payload: Data)?

        while cursor + 60 <= data.count {
            let header = data.subdata(in: cursor..<(cursor + 60))
            guard let name = string(header, range: 0..<16)?.trimmingCharacters(in: .whitespaces) else {
                throw DebExtractorError.corruptArchive
            }
            guard let sizeString = string(header, range: 48..<58)?.trimmingCharacters(in: .whitespaces),
                  let size = Int(sizeString) else {
                throw DebExtractorError.corruptArchive
            }

            let payloadStart = cursor + 60
            guard payloadStart + size <= data.count else { throw DebExtractorError.corruptArchive }
            let payload = data.subdata(in: payloadStart..<(payloadStart + size))

            if name.hasPrefix("data.tar") {
                dataMember = (name, payload)
                break
            }

            var next = payloadStart + size
            if next % 2 == 1 { next += 1 }
            cursor = next
        }

        guard let member = dataMember else { throw DebExtractorError.corruptArchive }

        let tarData: Data
        if member.name.hasSuffix(".tar") {
            tarData = member.payload
        } else if member.name.hasSuffix(".tar.gz") {
            tarData = try inflateGzip(member.payload)
        } else if member.name.hasSuffix(".tar.xz") {
            throw DebExtractorError.unsupportedCompression("xz")
        } else if member.name.hasSuffix(".tar.zst") {
            throw DebExtractorError.unsupportedCompression("zstd")
        } else if member.name.hasSuffix(".tar.lzma") {
            throw DebExtractorError.unsupportedCompression("lzma")
        } else {
            throw DebExtractorError.unsupportedCompression(member.name)
        }

        let entries = readTar(tarData)
        let dylibEntries = entries.filter { $0.name.hasSuffix(".dylib") }
        guard !dylibEntries.isEmpty else { throw DebExtractorError.noDylibFound }

        try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)

        var results: [URL] = []
        for entry in dylibEntries {
            let fileName = (entry.name as NSString).lastPathComponent
            let destination = destinationFolder.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: destination)
            try entry.data.write(to: destination)
            results.append(destination)
        }
        return results
    }

    private static func string(_ data: Data, range: Range<Int>) -> String? {
        guard range.upperBound <= data.count else { return nil }
        return String(data: data.subdata(in: range), encoding: .ascii)
    }

    private static func inflateGzip(_ data: Data) throws -> Data {
        guard data.count > 18 else { throw DebExtractorError.corruptArchive }
        var offset = 10
        let flags = data[data.startIndex + 3]
        if flags & 0x04 != 0, offset + 2 <= data.count {
            let extraLength = Int(data[data.startIndex + offset]) | (Int(data[data.startIndex + offset + 1]) << 8)
            offset += 2 + extraLength
        }
        if flags & 0x08 != 0 {
            while offset < data.count, data[data.startIndex + offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x10 != 0 {
            while offset < data.count, data[data.startIndex + offset] != 0 { offset += 1 }
            offset += 1
        }
        if flags & 0x02 != 0 {
            offset += 2
        }

        guard offset < data.count - 8 else { throw DebExtractorError.corruptArchive }
        let deflateData = data.subdata(in: (data.startIndex + offset)..<(data.endIndex - 8))

        let sizeFieldStart = data.index(data.endIndex, offsetBy: -4)
        let sizeField = data.subdata(in: sizeFieldStart..<data.endIndex)
        let uncompressedSize = sizeField.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        let capacity = max(Int(uncompressedSize), deflateData.count * 4 + 1024)

        var output = Data(count: capacity)
        let decodedCount = output.withUnsafeMutableBytes { destination -> Int in
            deflateData.withUnsafeBytes { source -> Int in
                guard let sourceBase = source.bindMemory(to: UInt8.self).baseAddress,
                      let destBase = destination.bindMemory(to: UInt8.self).baseAddress else { return 0 }
                return compression_decode_buffer(destBase, capacity, sourceBase, deflateData.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard decodedCount > 0 else { throw DebExtractorError.corruptArchive }
        return output.prefix(decodedCount)
    }

    private struct TarEntry {
        var name: String
        var data: Data
    }

    private static func readTar(_ data: Data) -> [TarEntry] {
        var entries: [TarEntry] = []
        var cursor = 0

        while cursor + 512 <= data.count {
            let block = data.subdata(in: cursor..<(cursor + 512))
            if block.allSatisfy({ $0 == 0 }) { break }

            guard let rawName = string(block, range: 0..<100) else { break }
            let name = rawName.replacingOccurrences(of: "\0", with: "")
            guard !name.isEmpty else { break }

            guard let sizeOctal = string(block, range: 124..<136)?
                .trimmingCharacters(in: CharacterSet(charactersIn: " \0")), let size = Int(sizeOctal, radix: 8) else {
                break
            }

            let typeFlag = block[block.startIndex + 156]
            let fileStart = cursor + 512
            let paddedSize = ((size + 511) / 512) * 512

            if typeFlag == 0x30 || typeFlag == 0x00, fileStart + size <= data.count {
                let content = data.subdata(in: fileStart..<(fileStart + size))
                entries.append(TarEntry(name: name, data: content))
            }

            cursor = fileStart + paddedSize
        }

        return entries
    }
}
