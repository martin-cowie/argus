import SwiftUI

/// Monitors a host's disks, refreshing periodically while shown.
struct HostDetailView: View {
    private static let refreshInterval = Duration.seconds(60)

    let host: RemoteHost
    let store: HostStore

    @State private var report: DiskReport?
    @State private var updated: Date?
    @State private var failure: String?
    @State private var isRefreshing = false

    var body: some View {
        content
            .navigationTitle(host.displayName)
            .navigationSubtitle(subtitle)
            .toolbar {
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(isRefreshing)
            }
            .task {
                while !Task.isCancelled {
                    await refresh()
                    do {
                        try await Task.sleep(for: Self.refreshInterval)
                    } catch {
                        return
                    }
                }
            }
    }

    @ViewBuilder private var content: some View {
        if let report {
            DiskReportView(report: report)
        } else if let failure {
            ContentUnavailableView("Couldn't Read Disks", systemImage: "exclamationmark.triangle", description: Text(failure))
        } else {
            ProgressView("Connecting to \(host.hostname)…")
        }
    }

    private var subtitle: String {
        if report != nil, let failure {
            return "Update failed: \(failure)"
        }
        return updated.map { "Updated \($0.formatted(date: .omitted, time: .shortened))" } ?? ""
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            let password = host.authentication == .password ? try store.password(for: host) : nil
            let output = try await SSHClient(host: host, password: password).run(DiskReport.script)
            report = try DiskReport.parse(output)
            updated = .now
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }
}

/// Lists a host's disks and filesystems, highlighting any that need attention.
struct DiskReportView: View {
    let report: DiskReport

    var body: some View {
        Form {
            Section("Disks") {
                if report.disks.isEmpty {
                    Text("No physical disks reported.").foregroundStyle(.secondary)
                }
                ForEach(report.disks) { DiskRow(disk: $0) }
            }
            Section("Filesystems") {
                if report.filesystems.isEmpty {
                    Text("No filesystems reported.").foregroundStyle(.secondary)
                }
                ForEach(report.filesystems) { FilesystemRow(filesystem: $0) }
            }
        }
        .formStyle(.grouped)
    }
}

private struct DiskRow: View {
    let disk: Disk

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(disk.model ?? disk.name)
                Text(details)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                temperature
                health
            }
        }
    }

    private var details: String {
        let parts = [
            disk.model == nil ? nil : disk.name,
            disk.kind.label,
            disk.sizeBytes.formatted(.byteCount(style: .file)),
            disk.serial.map { "Serial \($0)" },
        ]
        return parts.compactMap(\.self).joined(separator: " · ")
    }

    @ViewBuilder private var temperature: some View {
        if let celsius = disk.temperature {
            let reading = Measurement(value: celsius, unit: UnitTemperature.celsius)
                .formatted(.measurement(width: .abbreviated, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0))))
            if disk.isTooHot {
                Label(reading, systemImage: "thermometer.high")
                    .foregroundStyle(.orange)
                    .help("Hotter than the \(Int(disk.kind.temperatureLimit)) °C limit for an \(disk.kind.label)")
            } else {
                Label(reading, systemImage: "thermometer.medium")
            }
        } else {
            Label("Unavailable", systemImage: "thermometer.medium.slash")
                .foregroundStyle(.secondary)
                .help("The host exposes no temperature sensor for this disk, or smartctl needs passwordless sudo")
        }
    }

    @ViewBuilder private var health: some View {
        switch disk.healthPassed {
        case true?:
            Text("SMART passed").font(.caption).foregroundStyle(.secondary)
        case false?:
            Label("SMART failing", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        case nil:
            EmptyView()
        }
    }
}

private struct FilesystemRow: View {
    let filesystem: Filesystem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(filesystem.mountPoint)
                Spacer()
                if filesystem.isNearlyFull {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .help("More than \(Filesystem.nearlyFullPercent)% full")
                }
                Text("\(filesystem.availableBytes.formatted(.byteCount(style: .file))) free of \(filesystem.sizeBytes.formatted(.byteCount(style: .file)))")
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(min(filesystem.usedPercent, 100)), total: 100)
                .tint(filesystem.isNearlyFull ? .orange : .accentColor)
            Text("\(filesystem.device) · \(filesystem.usedPercent)% used")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
