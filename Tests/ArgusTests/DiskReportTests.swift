import Foundation
import Testing
@testable import Argus

@Suite struct DiskReportTests {
    /// Output in the shape of util-linux 2.39 (Ubuntu 24.04), with hwmon and smartctl sections.
    private let modernOutput = """
        @@lsblk
        {
           "blockdevices": [
              {"name": "nbd0", "model": null, "serial": null, "size": 0, "rota": false, "tran": null, "type": "disk"},
              {"name": "sda", "model": "ST4000VN008-2DR1  ", "serial": "ZDH1ABCD", "size": 4000787030016, "rota": true, "tran": "sata", "type": "disk"},
              {"name": "nvme0n1", "model": "Samsung SSD 980 PRO 1TB", "serial": "S5GXNX0T", "size": 1000204886016, "rota": false, "tran": "nvme", "type": "disk"},
              {"name": "sr0", "model": "DVD-RW", "serial": null, "size": 1073741312, "rota": true, "tran": "sata", "type": "rom"},
              {"name": "zram0", "model": null, "serial": null, "size": 4294967296, "rota": false, "tran": null, "type": "disk"},
              {"name": "loop0", "model": null, "serial": null, "size": 67108864, "rota": false, "tran": null, "type": "loop"}
           ]
        }
        @@df
        Filesystem     1024-blocks      Used Available Capacity Mounted on
        udev              16310532         0  16310532       0% /dev
        /dev/nvme0n1p2   959786032 883003148  28000000      97% /
        /dev/nvme0n1p1     1098632      6284   1092348       1% /boot/efi
        /dev/sda1       3844640564 1922320282 1727000000     53% /srv/Media Library
        /dev/loop0           65536     65536         0     100% /snap/core/1
        @@hwmon nvme0n1
        44850
        @@smartctl sda
        {"smart_status": {"passed": true}, "temperature": {"current": 52}}
        @@smartctl nvme0n1
        {"smart_status": {"passed": false}, "temperature": {"current": 41}}
        """

    @Test func keepsOnlyNonEmptyPhysicalDisks() throws {
        let report = try DiskReport.parse(modernOutput)
        #expect(report.disks.map(\.name) == ["sda", "nvme0n1"])
    }

    @Test func describesDisks() throws {
        let disks = try DiskReport.parse(modernOutput).disks
        #expect(disks[0] == Disk(name: "sda", model: "ST4000VN008-2DR1", serial: "ZDH1ABCD", sizeBytes: 4_000_787_030_016, kind: .hdd, temperature: 52, healthPassed: true))
        #expect(disks[1].kind == .nvme)
        #expect(disks[1].healthPassed == false)
    }

    @Test func prefersHwmonTemperatureOverSmartctl() throws {
        #expect(try DiskReport.parse(modernOutput).disks[1].temperature == 44.85)
    }

    @Test func flagsHotDisksByKind() throws {
        let disks = try DiskReport.parse(modernOutput).disks
        #expect(disks[0].isTooHot)
        #expect(!disks[1].isTooHot)
    }

    @Test func keepsBlockDeviceFilesystemsWithSpacesInMountPoints() throws {
        let filesystems = try DiskReport.parse(modernOutput).filesystems
        #expect(filesystems.map(\.mountPoint) == ["/", "/boot/efi", "/srv/Media Library"])
        #expect(filesystems[0] == Filesystem(device: "/dev/nvme0n1p2", mountPoint: "/", sizeBytes: 959_786_032 * 1024, usedBytes: 883_003_148 * 1024, availableBytes: 28_000_000 * 1024, usedPercent: 97))
        #expect(filesystems[0].isNearlyFull)
        #expect(!filesystems[2].isNearlyFull)
    }

    @Test func readsStringValuesFromOlderLsblk() throws {
        // util-linux 2.31, as on Ubuntu 18.04.
        let output = """
            @@lsblk
            {
               "blockdevices": [
                  {"name": "vda", "model": null, "serial": null, "size": "494384709632", "rota": "1", "tran": null, "type": "disk"},
                  {"name": "sdb", "model": "CT500MX500SSD1  ", "serial": null, "size": "500107862016", "rota": "0", "tran": "sata", "type": "disk"}
               ]
            }
            @@df
            Filesystem     1024-blocks      Used Available Capacity Mounted on
            """
        let disks = try DiskReport.parse(output).disks
        #expect(disks.map(\.kind) == [.hdd, .ssd])
        #expect(disks[1].sizeBytes == 500_107_862_016)
        #expect(disks[1].model == "CT500MX500SSD1")
        #expect(disks[1].temperature == nil)
        #expect(disks[1].healthPassed == nil)
    }

    @Test func ignoresUndecodableSmartctlOutput() throws {
        let output = """
            @@lsblk
            {"blockdevices": [{"name": "sda", "model": null, "serial": null, "size": 1, "rota": false, "tran": "usb", "type": "disk"}]}
            @@smartctl sda
            {"smartctl": {"messages": [{"string": "Unknown USB bridge", "severity": "error"}]}}
            """
        #expect(try DiskReport.parse(output).disks[0].temperature == nil)
    }

    @Test func reportsUnsupportedSystems() {
        #expect(throws: DiskReportError.unsupportedSystem("FreeBSD")) {
            try DiskReport.parse("@@unsupported\nFreeBSD\n")
        }
    }

    @Test func rejectsOutputWithoutLsblk() {
        #expect(throws: DiskReportError.malformed("no lsblk output")) {
            try DiskReport.parse("@@df\n")
        }
    }
}
