import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var appModel

    private let columns = [GridItem(.adaptive(minimum: 230), spacing: Theme.Spacing.medium)]

    var body: some View {
        let smartClean = appModel.smartClean

        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xLarge) {
                StorageCard(usage: appModel.diskUsage, reclaimable: smartClean.reclaimableSize)

                ReclaimCard()

                if !appModel.hasFullDiskAccess {
                    FullDiskAccessBanner()
                }

                if !smartClean.categories.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                        Text("What is using space")
                            .font(.title3.weight(.semibold))

                        LazyVGrid(columns: columns, spacing: Theme.Spacing.medium) {
                            ForEach(smartClean.categories) { category in
                                CategoryTile(
                                    category: category,
                                    size: smartClean.totalSize(in: category),
                                    count: smartClean.items(in: category).count
                                ) {
                                    appModel.navigation.open(.smartClean, routes: [.category(category)])
                                }
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.xLarge)
            .frame(maxWidth: Theme.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appModel.refreshDiskUsage()
                    Task { await smartClean.scan() }
                } label: {
                    Label("Scan Again", systemImage: "arrow.clockwise")
                }
                .disabled(smartClean.phase == .scanning)
                .help("Analyze the disk again")
            }
        }
        .task {
            if smartClean.phase == .idle {
                await smartClean.scan()
            }
        }
    }
}

private struct StorageCard: View {
    let usage: DiskUsage
    let reclaimable: Int64

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.xLarge) {
            StorageRing(fraction: usage.usedFraction)
                .frame(width: 132, height: 132)

            VStack(alignment: .leading, spacing: Theme.Spacing.medium) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(usage.volumeName)
                        .font(.title2.weight(.semibold))
                    Text("\(usage.available.formattedBytes) available of \(usage.total.formattedBytes)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                StorageBar(usage: usage, reclaimable: reclaimable)
            }
        }
        .card(padding: Theme.Spacing.xLarge)
    }
}

private struct ReclaimCard: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let smartClean = appModel.smartClean

        HStack(spacing: Theme.Spacing.large) {
            IconTile(symbol: "sparkles", tint: .accentColor, size: 44)

            switch smartClean.phase {
            case .idle, .scanning:
                VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                    Text("Analyzing your disk…")
                        .font(.headline)
                    ProgressView(value: smartClean.progress)
                        .frame(maxWidth: 280)
                    Text("Found \(smartClean.reclaimableSize.formattedBytes) so far")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()

            case .finished:
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(smartClean.safeSize.formattedBytes) can be safely reclaimed")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Text("Up to \(smartClean.reclaimableSize.formattedBytes) including items that need your review.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Review and Clean") {
                    smartClean.selectAllSafe()
                    appModel.navigation.open(.smartClean)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(smartClean.items.isEmpty)
            }
        }
        .card(padding: Theme.Spacing.large)
    }
}

private struct FullDiskAccessBanner: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.medium) {
            Image(systemName: "info.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Results may be incomplete")
                    .font(.headline)
                Text("Without Full Disk Access, the Trash, app containers and some caches cannot be measured.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Open System Settings") {
                PermissionService.openFullDiskAccessSettings()
            }
        }
        .card()
    }
}

private struct CategoryTile: View {
    let category: CleanupCategory
    let size: Int64
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.medium) {
                IconTile(symbol: category.symbol, tint: category.tint, size: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(.headline)
                    Text(Pluralize.items(count))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: Theme.Spacing.small)

                Text(size.formattedBytes)
                    .font(.callout.weight(.medium))
                    .monospacedDigit()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .card(padding: Theme.Spacing.medium)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(category.title), \(size.formattedBytes)")
        .accessibilityHint("Opens this category in Smart Clean")
    }
}
