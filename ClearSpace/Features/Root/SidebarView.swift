import SwiftUI

struct SidebarView: View {
    @Environment(AppModel.self) private var appModel
    @Binding var selection: SidebarSection?

    var body: some View {
        List(selection: $selection) {
            Section {
                row(.dashboard)
            }

            Section("Clean Up") {
                row(.smartClean)
                row(.largeFiles)
                row(.projects)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            storageFooter
        }
        .navigationTitle("ClearSpace")
    }

    private func row(_ section: SidebarSection) -> some View {
        Label(section.title, systemImage: section.symbol)
            .tag(section)
    }

    private var storageFooter: some View {
        let usage = appModel.diskUsage

        return VStack(alignment: .leading, spacing: 6) {
            Text(usage.volumeName)
                .font(.caption.weight(.semibold))
            ProgressView(value: usage.usedFraction)
                .tint(usage.usedFraction > 0.9 ? Color.red : Color.accentColor)
            Text("\(usage.available.formattedBytes) available")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
