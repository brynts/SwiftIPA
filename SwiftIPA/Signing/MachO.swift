import Foundation

enum MachOError: LocalizedError {
    case notMachO
    case truncated

    var errorDescription: String? {
        switch self {
        case .notMachO:
            return String(localized: "This file is not a Mach-O executable.")
        case .truncated:
            return String(localized: "The executable is truncated or damaged.")
        }
    }
}

enum MachO {
    static let fatMagic: UInt32 = 0xCAFE_BABE
    static let fatCigam: UInt32 = 0xBEBA_FECA
    static let fatMagic64: UInt32 = 0xCAFE_BABF
    static let fatCigam64: UInt32 = 0xBFBA_FECA
    static let magic64: UInt32 = 0xFEED_FACF
    static let cigam64: UInt32 = 0xCFFA_EDFE
    static let magic32: UInt32 = 0xFEED_FACE
    static let cigam32: UInt32 = 0xCEFA_EDFE

    static let lcLoadDylib: UInt32 = 0xC
    static let lcIdDylib: UInt32 = 0xD
    static let lcLoadWeakDylib: UInt32 = 0x8000_0018
    static let lcRpath: UInt32 = 0x8000_001C
    static let lcCodeSignature: UInt32 = 0x1D
    static let lcEncryptionInfo: UInt32 = 0x21
    static let lcEncryptionInfo64: UInt32 = 0x2C

    static func architectureName(cpuType: Int32, cpuSubtype: Int32) -> String {
        let subtype = cpuSubtype & ~Int32(bitPattern: 0x8000_0000)
        switch cpuType {
        case 0x0100_000C:
            return subtype == 2 ? "arm64e" : "arm64"
        case 0x0200_000C:
            return "arm64_32"
        case 12:
            switch subtype {
            case 9: return "armv7"
            case 11: return "armv7s"
            default: return "arm"
            }
        case 0x0100_0007:
            return "x86_64"
        case 7:
            return "i386"
        default:
            return "cpu(\(cpuType))"
        }
    }
}

struct MachOSlice {
    var offset: Int
    var is64Bit: Bool
    var isSwapped: Bool
    var cpuType: Int32
    var cpuSubtype: Int32
    var commandCount: UInt32
    var commandsSize: UInt32

    var headerSize: Int { is64Bit ? 32 : 28 }
    var architecture: String { MachO.architectureName(cpuType: cpuType, cpuSubtype: cpuSubtype) }
}

struct MachOLoadCommand {
    var kind: UInt32
    var size: UInt32
    var offset: Int
    var payload: String?
}

final class MachOImage {
    private let data: Data
    private(set) var slices: [MachOSlice] = []

    init(data: Data) throws {
        self.data = data
        try parse()
    }

    convenience init(url: URL) throws {
        try self.init(data: try Data(contentsOf: url, options: .mappedIfSafe))
    }

    static func isMachO(url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 4), head.count == 4 else { return false }
        let magic = head.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        return [MachO.fatMagic, MachO.fatCigam, MachO.fatMagic64, MachO.fatCigam64,
                MachO.magic64, MachO.cigam64, MachO.magic32, MachO.cigam32].contains(magic)
    }

    var architectures: [String] { slices.map(\.architecture) }

    var isEncrypted: Bool {
        slices.contains { slice in
            loadCommands(in: slice).contains { command in
                guard command.kind == MachO.lcEncryptionInfo || command.kind == MachO.lcEncryptionInfo64 else {
                    return false
                }
                return readUInt32(at: command.offset + 16, swapped: slice.isSwapped) != 0
            }
        }
    }

    var isSigned: Bool {
        slices.contains { slice in
            loadCommands(in: slice).contains { $0.kind == MachO.lcCodeSignature }
        }
    }

    var linkedDylibs: [String] {
        guard let slice = slices.first else { return [] }
        return loadCommands(in: slice)
            .filter { $0.kind == MachO.lcLoadDylib || $0.kind == MachO.lcLoadWeakDylib }
            .compactMap(\.payload)
    }

    var rpaths: [String] {
        guard let slice = slices.first else { return [] }
        return loadCommands(in: slice).filter { $0.kind == MachO.lcRpath }.compactMap(\.payload)
    }

    private func parse() throws {
        slices.removeAll()
        guard data.count >= 8 else { throw MachOError.truncated }
        let magic = readUInt32(at: 0, swapped: false)

        if magic == MachO.fatMagic || magic == MachO.fatCigam {
            let count = Int(readUInt32(at: 4, swapped: true))
            guard count > 0, count < 32 else { throw MachOError.notMachO }
            for index in 0..<count {
                let base = 8 + index * 20
                guard data.count >= base + 20 else { throw MachOError.truncated }
                let offset = Int(readUInt32(at: base + 8, swapped: true))
                let size = Int(readUInt32(at: base + 12, swapped: true))
                guard data.count >= offset + size else { throw MachOError.truncated }
                slices.append(try readSlice(at: offset))
            }
        } else {
            slices.append(try readSlice(at: 0))
        }
    }

    private func readSlice(at offset: Int) throws -> MachOSlice {
        guard data.count >= offset + 28 else { throw MachOError.truncated }
        let magic = readUInt32(at: offset, swapped: false)
        let is64Bit: Bool
        let swapped: Bool
        switch magic {
        case MachO.magic64: is64Bit = true; swapped = false
        case MachO.cigam64: is64Bit = true; swapped = true
        case MachO.magic32: is64Bit = false; swapped = false
        case MachO.cigam32: is64Bit = false; swapped = true
        default: throw MachOError.notMachO
        }

        let cpuType = Int32(bitPattern: readUInt32(at: offset + 4, swapped: swapped))
        let cpuSubtype = Int32(bitPattern: readUInt32(at: offset + 8, swapped: swapped))
        let commandCount = readUInt32(at: offset + 16, swapped: swapped)
        let commandsSize = readUInt32(at: offset + 20, swapped: swapped)

        return MachOSlice(
            offset: offset,
            is64Bit: is64Bit,
            isSwapped: swapped,
            cpuType: cpuType,
            cpuSubtype: cpuSubtype,
            commandCount: commandCount,
            commandsSize: commandsSize
        )
    }

    func loadCommands(in slice: MachOSlice) -> [MachOLoadCommand] {
        var commands: [MachOLoadCommand] = []
        var cursor = slice.offset + slice.headerSize
        let limit = slice.offset + slice.headerSize + Int(slice.commandsSize)

        for _ in 0..<slice.commandCount {
            guard cursor + 8 <= limit, cursor + 8 <= data.count else { break }
            let kind = readUInt32(at: cursor, swapped: slice.isSwapped)
            let size = readUInt32(at: cursor + 4, swapped: slice.isSwapped)
            guard size >= 8, cursor + Int(size) <= data.count else { break }

            var payload: String?
            if kind == MachO.lcLoadDylib || kind == MachO.lcLoadWeakDylib || kind == MachO.lcIdDylib || kind == MachO.lcRpath {
                let nameOffset = Int(readUInt32(at: cursor + 8, swapped: slice.isSwapped))
                payload = readString(at: cursor + nameOffset, limit: cursor + Int(size))
            }

            commands.append(MachOLoadCommand(kind: kind, size: size, offset: cursor, payload: payload))
            cursor += Int(size)
        }
        return commands
    }

    private func readUInt32(at offset: Int, swapped: Bool) -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { return 0 }
        let value = data.withUnsafeBytes { buffer -> UInt32 in
            buffer.loadUnaligned(fromByteOffset: offset, as: UInt32.self)
        }
        return swapped ? value.byteSwapped : value
    }

    private func readString(at offset: Int, limit: Int) -> String? {
        guard offset >= 0, offset < limit, limit <= data.count else { return nil }
        let bytes = data.subdata(in: offset..<limit)
        let terminated = bytes.prefix { $0 != 0 }
        return String(data: terminated, encoding: .utf8)
    }
}
