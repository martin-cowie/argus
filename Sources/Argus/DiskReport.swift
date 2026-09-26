import Foundation

/// A snapshot of a host's physical disks and mounted filesystems.
struct DiskReport: Equatable, Sendable {
    let disks: [Disk]
    let filesystems: [Filesystem]
}

/// A physical storage device.
struct Disk: Identifiable, Equatable, Sendable {
    /// The kind of storage device.
    enum Kind: Equatable, Sendable {
        case hdd
        case ssd
        case nvme

        /// The temperature, in °C, at or above which the device is considered too hot.
        var temperatureLimit: Double {
            switch self {
            case .hdd: 50
            case .ssd, .nvme: 70
            }
        }

        var label: String {
            switch self {
            case .hdd: "HDD"
            case .ssd: "SSD"
            case .nvme: "NVMe SSD"
            }
        }
    }

    /// The kernel's name for the device, such as `sda` or `nvme0n1`.
    let name: String
    let model: String?
    let serial: String?
    let sizeBytes: Int64
    let kind: Kind
    /// The temperature in °C, if the host exposes it.
    let temperature: Double?
    /// Whether the SMART overall health self-assessment passed, if `smartctl` could be run.
    let healthPassed: Bool?

    var id: String { name }

    var isTooHot: Bool { temperature.map { $0 >= kind.temperatureLimit } ?? false }
}

/// A mounted filesystem backed by a block device.
struct Filesystem: Identifiable, Equatable, Sendable {
    /// The percentage used at or above which a filesystem is considered nearly full.
    static let nearlyFullPercent = 90

    let device: String
    let mountPoint: String
    let sizeBytes: Int64
    let usedBytes: Int64
    let availableBytes: Int64
    /// The percentage of space available to ordinary users that is in use, as `df` reports it.
    let usedPercent: Int

    var id: String { mountPoint }

    var isNearlyFull: Bool { usedPercent >= Self.nearlyFullPercent }
}

/// Collecting a disk report failed.
enum DiskReportError: LocalizedError, Equatable {
    /// The host lacks `lsblk`, so is not Linux.
    case unsupportedSystem(String)
    /// The report output could not be understood.
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSystem(let system): "Disk monitoring needs Linux; this host runs \(system)."
        case .malformed(let detail): "Couldn't read the disk report: \(detail)"
        }
    }
}

extension DiskReport {
    /// A POSIX shell script that prints the report sections parsed by `parse(_:)`.
    ///
    /// Temperatures come from the kernel's hwmon sensors where present, which needs no privileges.
    /// Health, and temperatures otherwise, come from `smartctl`, run with `sudo -n` so it is
    /// skipped rather than prompting when passwordless sudo is not configured.
    static let script = """
        export LC_ALL=C
        if ! command -v lsblk >/dev/null 2>&1; then
            echo '@@unsupported'
            uname -s
            exit 0
        fi
        echo '@@lsblk'
        lsblk -J -b -d -o NAME,MODEL,SERIAL,SIZE,ROTA,TRAN,TYPE
        echo '@@df'
        df -P -k
        for dev in $(lsblk -d -n -o NAME,TYPE | awk '$2 == "disk" { print $1 }'); do
            temp=$(cat /sys/block/"$dev"/device/hwmon/hwmon*/temp1_input /sys/block/"$dev"/device/hwmon*/temp1_input 2>/dev/null | head -n 1)
            if [ -n "$temp" ]; then
                echo "@@hwmon $dev"
                echo "$temp"
            fi
            smart=$(sudo -n smartctl -H -A -j /dev/"$dev" 2>/dev/null)
            if [ -n "$smart" ]; then
                echo "@@smartctl $dev"
                echo "$smart"
            fi
        done
        """

    /// Parses the output of `script`.
    ///
    /// - Parameter output: The script's standard output.
    /// - Returns: The disks and the filesystems on `/dev` block devices, excluding loop devices.
    /// - Throws: `DiskReportError` if the host is unsupported or the output is malformed.
    static func parse(_ output: String) throws -> DiskReport {
        let sections = Section.split(output)
        if let unsupported = sections.first(where: { $0.kind == "unsupported" }) {
            throw DiskReportError.unsupportedSystem(unsupported.body.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let lsblk = sections.first(where: { $0.kind == "lsblk" }) else {
            throw DiskReportError.malformed("no lsblk output")
        }
        let temperatures = try hwmonTemperatures(sections)
        let smart = try smartReports(sections)
        let disks = try BlockDevice.decode(lsblk.body)
            .filter(\.isPhysicalDisk)
            .map { device in
                Disk(
                    name: device.name,
                    model: device.model,
                    serial: device.serial,
                    sizeBytes: device.size,
                    kind: device.kind,
                    temperature: temperatures[device.name] ?? smart[device.name]?.temperature?.current,
                    healthPassed: smart[device.name]?.smartStatus?.passed
                )
            }
        let filesystems = sections.first { $0.kind == "df" }.map { parseDF($0.body) } ?? []
        return DiskReport(disks: disks, filesystems: filesystems)
    }

    private static func hwmonTemperatures(_ sections: [Section]) throws -> [String: Double] {
        var result: [String: Double] = [:]
        for section in sections where section.kind == "hwmon" {
            let text = section.body.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let device = section.argument, let millidegrees = Double(text) else {
                throw DiskReportError.malformed("bad hwmon section")
            }
            result[device] = millidegrees / 1000
        }
        return result
    }

    private static func smartReports(_ sections: [Section]) throws -> [String: SmartctlReport] {
        var result: [String: SmartctlReport] = [:]
        for section in sections where section.kind == "smartctl" {
            guard let device = section.argument else { throw DiskReportError.malformed("bad smartctl section") }
            // smartctl reports unsupported devices as JSON without these fields, so a
            // report that cannot be decoded is ignored rather than failing the whole host.
            result[device] = try? JSONDecoder().decode(SmartctlReport.self, from: Data(section.body.utf8))
        }
        return result
    }

    private static func parseDF(_ text: String) -> [Filesystem] {
        let row = /^(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)%\s+(.+)$/
        return text.split(separator: "\n").compactMap { line in
            guard let match = try? row.wholeMatch(in: line),
                  match.1.hasPrefix("/dev/"),
                  !match.1.hasPrefix("/dev/loop"),
                  let size = Int64(match.2), let used = Int64(match.3), let available = Int64(match.4),
                  let percent = Int(match.5)
            else { return nil }
            return Filesystem(
                device: String(match.1),
                mountPoint: String(match.6),
                sizeBytes: size * 1024,
                usedBytes: used * 1024,
                availableBytes: available * 1024,
                usedPercent: percent
            )
        }
    }
}

/// A `@@kind argument` delimited part of the script's output.
private struct Section {
    let kind: String
    let argument: String?
    let body: String

    static func split(_ output: String) -> [Section] {
        var result: [Section] = []
        var header: [Substring]?
        var lines: [Substring] = []
        func finish() {
            if let header, let kind = header.first {
                result.append(Section(kind: String(kind), argument: header.dropFirst().first.map(String.init), body: lines.joined(separator: "\n")))
            }
        }
        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("@@") {
                finish()
                header = line.dropFirst(2).split(separator: " ")
                lines = []
            } else {
                lines.append(line)
            }
        }
        finish()
        return result
    }
}

/// A device from `lsblk -J -b`. Older versions of lsblk emit numbers and booleans as strings.
private struct BlockDevice: Decodable {
    let name: String
    let model: String?
    let serial: String?
    let size: Int64
    let rotational: Bool
    let transport: String?
    let type: String

    private enum CodingKeys: String, CodingKey {
        case name, model, serial, size, rota, tran, type
    }

    private struct Output: Decodable {
        let blockdevices: [BlockDevice]
    }

    static func decode(_ json: String) throws -> [BlockDevice] {
        do {
            return try JSONDecoder().decode(Output.self, from: Data(json.utf8)).blockdevices
        } catch {
            throw DiskReportError.malformed("lsblk: \(error.localizedDescription)")
        }
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        model = Self.trimmed(try container.decodeIfPresent(String.self, forKey: .model))
        serial = Self.trimmed(try container.decodeIfPresent(String.self, forKey: .serial))
        transport = try container.decodeIfPresent(String.self, forKey: .tran)
        type = try container.decode(String.self, forKey: .type)
        if let number = try? container.decode(Int64.self, forKey: .size) {
            size = number
        } else if let number = Int64(try container.decode(String.self, forKey: .size)) {
            size = number
        } else {
            throw DecodingError.dataCorruptedError(forKey: .size, in: container, debugDescription: "Size is not a number")
        }
        if let flag = try? container.decode(Bool.self, forKey: .rota) {
            rotational = flag
        } else {
            rotational = try container.decode(String.self, forKey: .rota) == "1"
        }
    }

    /// Whether this is a real disk, rather than a RAM-backed one such as zram or an empty
    /// device such as an unattached nbd or a card reader with no card.
    var isPhysicalDisk: Bool {
        type == "disk" && size > 0 && !name.hasPrefix("zram") && !name.hasPrefix("ram")
    }

    var kind: Disk.Kind {
        if transport == "nvme" || name.hasPrefix("nvme") {
            return .nvme
        }
        return rotational ? .hdd : .ssd
    }

    private static func trimmed(_ text: String?) -> String? {
        let result = text?.trimmingCharacters(in: .whitespaces)
        return result?.isEmpty == true ? nil : result
    }
}

/// The parts of `smartctl -H -A -j` output that Argus uses.
private struct SmartctlReport: Decodable {
    struct Temperature: Decodable {
        let current: Double?
    }

    struct Status: Decodable {
        let passed: Bool?
    }

    let temperature: Temperature?
    let smartStatus: Status?

    private enum CodingKeys: String, CodingKey {
        case temperature
        case smartStatus = "smart_status"
    }
}
