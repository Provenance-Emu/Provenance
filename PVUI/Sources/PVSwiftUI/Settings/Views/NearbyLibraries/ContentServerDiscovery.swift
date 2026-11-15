#if os(iOS) || os(tvOS)
import Foundation
import Network
import Observation

struct DiscoveredContentServer: Identifiable, Equatable {
    let id: UUID
    let name: String
    let origin: URL

    init?(host: String, port: Int, record: Data) {
        let txt = NWTXTRecord(record)
        guard txt["v"] == "1", let id = txt["id"].flatMap(UUID.init(uuidString:)),
              let name = txt["name"], !name.isEmpty, name.utf8.count <= 63,
              let tls = txt["tls"], tls == "0" || tls == "1", (1...65535).contains(port)
        else { return nil }
        var address = URLComponents()
        address.scheme = tls == "1" ? "https" : "http"
        address.host = host.hasSuffix(".") ? String(host.dropLast()) : host
        address.port = port
        guard let origin = address.url, origin.host?.isEmpty == false else { return nil }
        self.id = id
        self.name = name
        self.origin = origin
    }
}

@MainActor
@Observable
final class ContentServerDiscovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    @ObservationIgnored private var browser: NetServiceBrowser?
    @ObservationIgnored private var services: [NetService] = []
    private var resolved: [ObjectIdentifier: DiscoveredContentServer] = [:]

    var servers: [DiscoveredContentServer] {
        var seen: Set<UUID> = []
        return resolved.values.sorted {
            ($0.name, $0.origin.absoluteString) < ($1.name, $1.origin.absoluteString)
        }.filter { seen.insert($0.id).inserted }
    }

    func start() {
        guard browser == nil else { return }
        let browser = NetServiceBrowser()
        self.browser = browser
        browser.delegate = self
        browser.searchForServices(ofType: "_pvcontent._tcp.", inDomain: "local.")
    }

    func stop() {
        browser?.stop()
        browser?.delegate = nil
        browser = nil
        for service in services { stop(service) }
        services.removeAll()
        resolved.removeAll()
    }

    private func stop(_ service: NetService) {
        service.delegate = nil
        service.stopMonitoring()
        service.stop()
    }

    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        Task { @MainActor in
            guard browser === self.browser, !services.contains(service) else { return }
            services.append(service)
            service.delegate = self
            service.resolve(withTimeout: 5)
        }
    }

    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        Task { @MainActor in
            guard browser === self.browser, let index = services.firstIndex(of: service) else { return }
            let removed = services.remove(at: index)
            stop(removed)
            resolved.removeValue(forKey: ObjectIdentifier(removed))
        }
    }

    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        Task { @MainActor in
            guard services.contains(where: { $0 === sender }) else { return }
            update(sender, record: sender.txtRecordData())
            sender.startMonitoring()
        }
    }

    nonisolated func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        Task { @MainActor in update(sender, record: data) }
    }

    private func update(_ service: NetService, record: Data?) {
        guard services.contains(where: { $0 === service }) else { return }
        resolved[ObjectIdentifier(service)] = record.flatMap { data in
            service.hostName.flatMap { DiscoveredContentServer(host: $0, port: service.port, record: data) }
        }
    }
}
#endif
