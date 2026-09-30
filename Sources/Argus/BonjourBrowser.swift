import dnssd
import Foundation
import Observation
import os

/// Finds SSH servers advertised on the local network with DNS-SD (Bonjour).
@MainActor
@Observable
final class BonjourBrowser {
    private static let logger = Logger(subsystem: "com.example.argus", category: "BonjourBrowser")
    private static let serviceType = "_ssh._tcp"

    /// The servers found and resolved so far, sorted by hostname.
    private(set) var hosts: [HostSuggestion] = []

    @ObservationIgnored private var browseRef: DNSServiceRef?
    @ObservationIgnored private var services: [ServiceKey: Service] = [:]

    /// Browses until the calling task is cancelled, keeping `hosts` up to date.
    ///
    /// Browsing fails quietly, leaving `hosts` empty, if local network access is denied.
    func browse() async {
        start()
        defer { stop() }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
        }
    }

    private func start() {
        var ref: DNSServiceRef?
        let context = Unmanaged.passUnretained(self).toOpaque()
        let error = DNSServiceBrowse(&ref, 0, 0, Self.serviceType, nil, { _, flags, interface, error, name, type, domain, context in
            guard error == kDNSServiceErr_NoError, let name, let type, let domain, let context else { return }
            let browser = Unmanaged<BonjourBrowser>.fromOpaque(context).takeUnretainedValue()
            let key = ServiceKey(name: String(cString: name), type: String(cString: type), domain: String(cString: domain))
            let isAdded = flags & DNSServiceFlags(kDNSServiceFlagsAdd) != 0
            MainActor.assumeIsolated {
                browser.serviceChanged(key, interface: interface, isAdded: isAdded)
            }
        }, context)
        guard error == kDNSServiceErr_NoError, let ref else {
            Self.logger.error("Cannot browse for \(Self.serviceType, privacy: .public): DNS-SD error \(error)")
            return
        }
        DNSServiceSetDispatchQueue(ref, .main)
        browseRef = ref
    }

    private func stop() {
        browseRef.map(DNSServiceRefDeallocate)
        browseRef = nil
        services.values.forEach { $0.cancelResolution() }
        services = [:]
        hosts = []
    }

    private func serviceChanged(_ key: ServiceKey, interface: UInt32, isAdded: Bool) {
        if isAdded {
            if let service = services[key] {
                service.interfaces.insert(interface)
            } else {
                let service = Service(key: key, interface: interface, browser: self)
                services[key] = service
                service.resolve()
            }
        } else if let service = services[key] {
            service.interfaces.remove(interface)
            if service.interfaces.isEmpty {
                service.cancelResolution()
                services[key] = nil
                publish()
            }
        }
    }

    fileprivate func publish() {
        hosts = services.values.compactMap(\.host)
            .sorted { $0.hostname.localizedStandardCompare($1.hostname) == .orderedAscending }
    }
}

/// Identifies an advertised service instance.
private struct ServiceKey: Hashable {
    let name: String
    let type: String
    let domain: String
}

/// An advertised service instance, resolved to a hostname and port.
@MainActor
private final class Service {
    let key: ServiceKey
    /// The network interfaces the service is advertised on.
    var interfaces: Set<UInt32>
    private(set) var host: HostSuggestion?
    private var resolveRef: DNSServiceRef?
    private weak var browser: BonjourBrowser?

    init(key: ServiceKey, interface: UInt32, browser: BonjourBrowser) {
        self.key = key
        self.interfaces = [interface]
        self.browser = browser
    }

    /// Looks up the hostname and port, publishing them to the browser when found.
    ///
    /// The service must stay referenced until resolution ends or is cancelled.
    func resolve() {
        var ref: DNSServiceRef?
        let context = Unmanaged.passUnretained(self).toOpaque()
        let error = DNSServiceResolve(&ref, 0, interfaces.first ?? 0, key.name, key.type, key.domain, { _, _, _, error, _, target, port, _, _, context in
            guard let context else { return }
            let service = Unmanaged<Service>.fromOpaque(context).takeUnretainedValue()
            let hostname = error == kDNSServiceErr_NoError ? target.map { String(cString: $0) } : nil
            MainActor.assumeIsolated {
                service.resolved(hostname: hostname, port: Int(UInt16(bigEndian: port)))
            }
        }, context)
        guard error == kDNSServiceErr_NoError, let ref else { return }
        DNSServiceSetDispatchQueue(ref, .main)
        resolveRef = ref
    }

    func cancelResolution() {
        resolveRef.map(DNSServiceRefDeallocate)
        resolveRef = nil
    }

    private func resolved(hostname: String?, port: Int) {
        cancelResolution()
        guard let hostname else { return }
        // DNS-SD reports fully qualified names, such as `nas.local.`.
        let name = hostname.hasSuffix(".") ? String(hostname.dropLast()) : hostname
        host = HostSuggestion(hostname: name, port: port)
        browser?.publish()
    }
}
