import SwiftUI

struct InspectorReportView: View {
    let report: InspectionReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if !report.findings.isEmpty {
                    Section("Findings") {
                        ForEach(report.findings) { finding in
                            HStack(alignment: .top, spacing: SISpacing.sm) {
                                Image(systemName: finding.severity.symbolName)
                                    .foregroundStyle(color(for: finding.severity))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(finding.title).font(SIFont.headline)
                                    Text(finding.detail).font(SIFont.caption).foregroundStyle(SIColor.textSecondary)
                                }
                            }
                        }
                    }
                }

                Section("App") {
                    LabeledContent("Name", value: report.appName)
                    LabeledContent("Bundle ID", value: report.bundleIdentifier)
                    LabeledContent("Version", value: "\(report.version) (\(report.build))")
                    LabeledContent("Minimum iOS", value: report.minimumOSVersion.isEmpty ? "—" : report.minimumOSVersion)
                    LabeledContent("Uncompressed Size", value: report.displaySize)
                }

                if !report.executables.isEmpty {
                    Section("Executables") {
                        ForEach(report.executables) { executable in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(executable.path).font(SIFont.mono)
                                Text(executable.architectures.joined(separator: ", "))
                                    .font(SIFont.caption)
                                    .foregroundStyle(SIColor.textSecondary)
                                HStack(spacing: SISpacing.sm) {
                                    if executable.isSigned {
                                        StatusBadge(text: String(localized: "Signed"), color: SIColor.success)
                                    }
                                    if executable.isEncrypted {
                                        StatusBadge(text: String(localized: "Encrypted"), color: SIColor.warning)
                                    }
                                    StatusBadge(text: executable.displaySize, color: SIColor.textSecondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                if !report.frameworks.isEmpty {
                    Section("Frameworks (\(report.frameworks.count))") {
                        ForEach(report.frameworks, id: \.self) { name in
                            Text(name).font(SIFont.mono)
                        }
                    }
                }

                if !report.plugins.isEmpty {
                    Section("Extensions (\(report.plugins.count))") {
                        ForEach(report.plugins, id: \.self) { name in
                            Text(name).font(SIFont.mono)
                        }
                    }
                }

                if !report.urlSchemes.isEmpty {
                    Section("URL Schemes") {
                        ForEach(report.urlSchemes, id: \.self) { scheme in
                            Text(scheme).font(SIFont.mono)
                        }
                    }
                }

                if !report.localizations.isEmpty {
                    Section("Localizations (\(report.localizations.count))") {
                        Text(report.localizations.sorted().joined(separator: ", "))
                            .font(SIFont.caption)
                            .foregroundStyle(SIColor.textSecondary)
                    }
                }
            }
            .siScreen()
            .navigationTitle("Inspector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func color(for severity: FindingSeverity) -> Color {
        switch severity {
        case .info: return SIColor.accent
        case .warning: return SIColor.warning
        case .blocker: return SIColor.danger
        }
    }
}
