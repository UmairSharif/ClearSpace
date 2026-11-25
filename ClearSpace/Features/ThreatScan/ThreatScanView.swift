import SwiftUI

/// Finds hidden malware in projects (auto-run editor tasks, scripts disguised as fonts,
/// obfuscated code) and leftovers on this Mac. Nothing is removed without the shared
/// confirmation sheet, and every finding is marked Review.
struct ThreatScanView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var viewModel = appModel.threats

        Group {
            switch viewModel.phase {
            case .idle:
                ContentUnavailableView {
                    Label("Check Projects for Hidden Malware", systemImage: "exclamationmark.shield")
                } description: {
                    Text("ClearSpace looks for the tricks used by malware that targets developers: editor tasks that run when a folder is opened, scripts disguised as fonts or images, and obfuscated code. Files are only read, never run.")
                } actions: {
                    if viewModel.root == nil {
                        Button("Choose Projects Folder…") { chooseFolder(viewModel) }
                            .buttonStyle(.borderedProminent)
                        Button("Check This Mac Only") { viewModel.scan() }
                    } else {
                        Button("Scan \(viewModel.root?.lastPathComponent ?? "")") { viewModel.scan() }
                            .buttonStyle(.borderedProminent)
                    }
                }

            case .scanning:
                ScanProgressView(
                    title: "Checking for hidden malware…",
                    message: "Reading editor settings, scripts and media files in \(viewModel.root?.lastPathComponent ?? "your home folder"). Nothing is run.",
                    onCancel: { viewModel.cancel() }
                )

            case .finished:
                if viewModel.findings.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing Suspicious Found", systemImage: "checkmark.shield")
                    } description: {
                        Text(cleanMessage(viewModel))
                    } actions: {
                        Button("Scan Again") { viewModel.scan() }
                    }
                } else {
                    findingList(viewModel)
                }
            }
        }
        .navigationTitle("Malware Check")
        .navigationSubtitle(subtitle(viewModel))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    chooseFolder(viewModel)
                } label: {
                    Label(viewModel.root?.lastPathComponent ?? "Choose Folder", systemImage: "folder")
                        .labelStyle(.titleAndIcon)
                }
                .help("Choose the folder that holds your projects")

                Toggle(isOn: $viewModel.includeThisMac) {
                    Label("Check This Mac", systemImage: "laptopcomputer")
                }
                .help("Also look in your home folder for files this malware leaves after it has run")

                Button("Select High Risk") { viewModel.selectAllHighRisk() }
                    .disabled(viewModel.removableHighCount == 0)

                Button {
                    viewModel.scan()
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
                .help("Scan again")
                .disabled(viewModel.phase == .scanning || (viewModel.root == nil && !viewModel.includeThisMac))
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SelectionBar(
                count: viewModel.selection.count,
                size: viewModel.selectedSize,
                actionTitle: "Remove…"
            ) {
                appModel.requestDeletion(
                    title: "Remove Suspicious Files",
                    entries: viewModel.selectedFindings.map(\.deletionEntry)
                ) { report in
                    viewModel.apply(report)
                }
            }
        }
    }

    private func findingList(_ viewModel: ThreatScanViewModel) -> some View {
        List {
            Section {
                ExplanationCard(hasHostFindings: !viewModel.hostFindings.isEmpty, highCount: viewModel.highCount)
                    .listRowSeparator(.hidden)
            }

            if !viewModel.hostFindings.isEmpty {
                Section("This Mac") {
                    ForEach(viewModel.hostFindings) { finding in
                        row(finding, viewModel)
                    }
                }
            }

            ForEach(viewModel.projects, id: \.self) { project in
                Section(project) {
                    ForEach(viewModel.findings(in: project)) { finding in
                        row(finding, viewModel)
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func row(_ finding: ThreatFinding, _ viewModel: ThreatScanViewModel) -> some View {
        ThreatRow(
            finding: finding,
            isSelected: Binding(
                get: { viewModel.isSelected(finding) },
                set: { viewModel.setSelected($0, for: finding) }
            )
        )
        .contextMenu {
            Button("Reveal in Finder") { SystemActions.revealInFinder([finding.url]) }
            Button("Copy Path") { SystemActions.copyToPasteboard(finding.url.path) }
        }
    }

    private func cleanMessage(_ viewModel: ThreatScanViewModel) -> String {
        var places: [String] = []
        if let root = viewModel.root { places.append(root.lastPathComponent) }
        if viewModel.includeThisMac { places.append("this Mac") }
        let scope = places.isEmpty ? "" : " in " + places.joined(separator: " or on ")
        return "No known malware patterns were found\(scope). This check looks for known tricks and cannot prove that a project is clean."
    }

    private func subtitle(_ viewModel: ThreatScanViewModel) -> String {
        guard viewModel.phase == .finished, !viewModel.findings.isEmpty else { return "" }
        let count = viewModel.findings.count
        return count == 1 ? "1 finding" : "\(count) findings"
    }

    private func chooseFolder(_ viewModel: ThreatScanViewModel) {
        guard let url = SystemActions.chooseFolder(
            startingAt: viewModel.root,
            message: "Choose the folder that holds your projects. Every project inside it is checked."
        ) else { return }
        viewModel.setRoot(url)
    }
}

private struct ExplanationCard: View {
    let hasHostFindings: Bool
    let highCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
            Label(
                highCount > 0 ? "Do not open these projects in VS Code or Cursor yet" : "Review each finding before removing it",
                systemImage: highCount > 0 ? "exclamationmark.octagon.fill" : "info.circle.fill"
            )
            .font(.headline)
            .foregroundStyle(highCount > 0 ? Color.red : Color.accentColor)

            Text("These findings come from pattern checks, so some may be harmless. Expand a finding to see why it was flagged. Removed files go to the Trash unless you choose otherwise.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if hasHostFindings {
                Text("Files under This Mac mean the malware has probably already run. After removing them, restart your Mac, then change your passwords, GitHub tokens, SSH keys and any crypto wallet seeds from a clean device.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } else if highCount > 0 {
                Text("If you opened one of these projects in an editor and trusted it, the code may already have run. Turn on Check This Mac and scan again.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }
}

private struct ThreatRow: View {
    let finding: ThreatFinding
    @Binding var isSelected: Bool
    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.medium) {
            Toggle(isOn: $isSelected) { EmptyView() }
                .toggleStyle(.checkbox)
                .labelsHidden()
                .disabled(!finding.isRemovable)
                .help(finding.isRemovable ? "Select to remove" : "Fix this one by hand. Removing the whole file would also remove your own settings.")
                .accessibilityLabel("Select \(finding.url.lastPathComponent)")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Theme.Spacing.small) {
                    Image(systemName: finding.kind.symbol)
                        .foregroundStyle(finding.level.tint)
                        .accessibilityHidden(true)
                    Text(finding.url.lastPathComponent)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    ThreatLevelBadge(level: finding.level)
                    Text(finding.kind.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(finding.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(finding.reasons.first ?? "")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                if let fix = finding.manualFix {
                    Label(fix, systemImage: "wrench.and.screwdriver.fill")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(finding.reasons.dropFirst().enumerated()), id: \.offset) { _, reason in
                            Label(reason, systemImage: "smallcircle.filled.circle")
                                .labelStyle(BulletLabelStyle())
                                .font(.callout)
                        }
                        if let evidence = finding.evidence {
                            Text(evidence)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                                .textSelection(.enabled)
                                .padding(Theme.Spacing.small)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Text("Why this was flagged")
                        .font(.caption.weight(.medium))
                }
            }

            Spacer(minLength: Theme.Spacing.medium)

            Text(finding.size.formattedBytes)
                .font(.callout)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, Theme.Spacing.xSmall)
    }
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•").foregroundStyle(.secondary)
            configuration.title
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ThreatLevelBadge: View {
    let level: ThreatLevel

    var body: some View {
        Text(level.title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(level.tint)
            .background(level.tint.opacity(0.14), in: Capsule())
            .help(level.explanation)
            .accessibilityLabel("Risk: \(level.title)")
    }
}
