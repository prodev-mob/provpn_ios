//
//  PacketTunnelProvider.swift
//  Tunnel
//
//  Created by DREAMWORLD on 24/11/25.
//

import NetworkExtension
import OpenVPNAdapter

/// PacketTunnelProvider extension
class PacketTunnelProvider: NEPacketTunnelProvider {
    var startHandler: ((Error?) -> Void)?
    var stopHandler: (() -> Void)?
    var vpnReachability = OpenVPNReachability()
    private var isReasserting = false
    
    var configuration: OpenVPNConfiguration!
    var evaluation: OpenVPNConfigurationEvaluation!
    var UDPSession: NWUDPSession!
    var TCPConnection: NWTCPConnection!
    
    var profile: Profile?
    var dnsList = [String]()
    
    lazy var vpnAdapter: OpenVPNAdapter = {
        let adapter = OpenVPNAdapter()
        adapter.delegate = self
        return adapter
    }()
    
    override init() {
        _ = Settings.load()
        
        super.init()
        
        Log.append(Util.localize("application-started", Util.getAppName()), .debug, .packetTunnelProvider)
        
        profile = Settings.getSelectedProfile()
        dnsList = profile?.dnsList ?? []
    }
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard
            let protocolConfiguration = protocolConfiguration as? NETunnelProviderProtocol,
            let providerConfiguration = protocolConfiguration.providerConfiguration
        else {
            fatalError()
        }
        
        guard let ovpnFileContent: Data = providerConfiguration["ovpn"] as? Data else { return }
        
        configuration = OpenVPNConfiguration()
        configuration.fileContent = ovpnFileContent
        configuration.privateKeyPassword = profile?.privateKeyPassword
        applyConfiguration(completionHandler: completionHandler)
        
        if !evaluation.autologin {
            if let username: String = providerConfiguration["username"] as? String, let password: String = providerConfiguration["password"] as? String {
                let credentials = OpenVPNCredentials()
                credentials.username = username
                credentials.password = password
                
                do {
                    try vpnAdapter.provide(credentials: credentials)
                } catch {
                    completionHandler(error)
                    return
                }
            }
        }
        
        vpnReachability.startTracking { [weak self] status in
            guard status != .notReachable else { return }
            self?.vpnAdapter.reconnect(afterTimeInterval: 5)
        }
        
        startHandler = completionHandler
        vpnAdapter.connect(using: packetFlow)
    }
    
    func applyConfiguration(completionHandler: @escaping (Error?) -> Void) {
        do {
            evaluation = try vpnAdapter.apply(configuration: configuration)
        } catch {
            completionHandler(error)
            return
        }
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let messageString = NSString(data: messageData, encoding: String.Encoding.utf8.rawValue) else {
            completionHandler?(nil)
            return
        }
        
        Log.append(Util.localize("got-message-from-app", messageString), .info, .packetTunnelProvider)
        completionHandler?(messageData)
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    override func wake() { }
}

extension PacketTunnelProvider: OpenVPNAdapterDelegate {
    
    // MARK: - REQUIRED (1/2) — Main config method with PacketFlow
    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, configureTunnelWithNetworkSettings networkSettings: NEPacketTunnelNetworkSettings, completionHandler: @escaping (OpenVPNAdapterPacketFlow?) -> Void) {
        
        // ---- DNS ----
        let dns = dnsList.isEmpty ? ["8.8.8.8"] : dnsList
        let dnsSettings = NEDNSSettings(servers: dns)
        dnsSettings.matchDomains = [""]
        networkSettings.dnsSettings = dnsSettings
        
        // ---- IPv4 Routing ----
        if let ipv4 = networkSettings.ipv4Settings {
            ipv4.includedRoutes = [NEIPv4Route.default()]
            ipv4.excludedRoutes = []
        }
        
        // ---- MTU ----
        networkSettings.mtu = NSNumber(value: 1500)
        
        // ---- Apply settings ----
        setTunnelNetworkSettings(networkSettings) { error in
            if let error = error {
                Log.append("Failed to set network settings: \(error)", .error, .packetTunnelProvider)
                completionHandler(nil)
                return
            }
            
            completionHandler(self.packetFlow)
        }
    }
    
    // MARK: - REQUIRED (2/2) — Secondary method (protocol demands this)
    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, configureTunnelWithNetworkSettings networkSettings: NEPacketTunnelNetworkSettings?, completionHandler: @escaping (Error?) -> Void) {
        
        // Apply settings without PacketFlow return
        setTunnelNetworkSettings(networkSettings) { error in
            completionHandler(error)
        }
    }
    
    // MARK: - Packet Logging (optional)
    func handler(_ packets: [NEPacket]) {
        Log.append("Packet: \(packets[0].description)", .debug, .packetTunnelProvider)
    }
    
    func handlePackets(_ packets: [Data], protocols: [NSNumber]) {
        Log.append("Packet: \(packets[0])", .debug, .packetTunnelProvider)
    }
    
    // MARK: - OpenVPNAdapter Events
    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleEvent event: OpenVPNAdapterEvent, message: String?) {
        
        switch event {
        case .connected:
            if isReasserting { isReasserting = false }
            startHandler?(nil)
            startHandler = nil
        case .disconnected:
            if vpnReachability.isTracking { vpnReachability.stopTracking() }
            stopHandler?()
            stopHandler = nil
        case .reconnecting:
            isReasserting = true
        default:
            break
        }
    }
    
    // MARK: - Error Handler
    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleError error: Error) {
        
        let nsError = error as NSError
        let isFatal = nsError.userInfo[OpenVPNAdapterErrorFatalKey] as? Bool ?? false
        
        if let msg = nsError.userInfo[OpenVPNAdapterErrorMessageKey] as? String {
            Log.append(msg, .error, .packetTunnelProvider)
        } else {
            Log.append(error.localizedDescription, .error, .packetTunnelProvider)
        }
        
        Log.append("Connection Info: \(vpnAdapter.connectionInformation.debugDescription)",
                   .info, .packetTunnelProvider)
        
        if vpnReachability.isTracking { vpnReachability.stopTracking() }
        
        if let start = startHandler {
            start(error)
            startHandler = nil
        } else {
            cancelTunnelWithError(error)
        }
    }
    
    // MARK: - Log Messages
    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleLogMessage logMessage: String) {
        
        let lower = logMessage.lowercased()
        let level: Log.LogLevel = lower.contains("error") || lower.contains("exception") ?
            .error : .info
        
        Log.append(logMessage, level, .packetTunnelProvider)
    }
}


//extension PacketTunnelProvider: OpenVPNAdapterDelegate {
//    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, configureTunnelWithNetworkSettings networkSettings: NEPacketTunnelNetworkSettings?, completionHandler: @escaping (Error?) -> Void) {
//
//        // Add custom settings (dns, routes, etc)
//        if let remoteIPAddress = networkSettings?.tunnelRemoteAddress ?? Util.getIPAddress(evaluation.remoteHost!) {
//            let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: remoteIPAddress)
//            let DNSSettings = NEDNSSettings(servers: dnsList)
//            let ipv4Settings = networkSettings?.ipv4Settings
//
//            DNSSettings.matchDomains = [""]
//
//            //var ipv4IncludeRoutes = [NEIPv4Route]()
//            //let dnsRoute = NEIPv4Route(destinationAddress: "", subnetMask: "255.255.255.0")
//
//            //ipv4IncludeRoutes.append(dnsRoute)
//            //ipv4Settings?.includedRoutes = ipv4IncludeRoutes
//
//            settings.ipv4Settings = ipv4Settings
//            settings.dnsSettings = DNSSettings
//
//            setTunnelNetworkSettings(settings) { (error) in
//                if error == nil {
//                    // Start handling packets
//                    //self.packetFlow.readPackets(completionHandler: self.handlePackets)
//                    //self.handlePackets()
//
//                    //self.readPackets(completionHandler: self.handlePackets)
//                    //self.packetFlow.readPackets(completionHandler: self.handlePackets)
//                    //self.packetFlow.readPacketObjects(completionHandler: self.handler)
//
//                } else {
//                    Log.append(Util.localize("error", error.debugDescription), .error, .packetTunnelProvider)
//                }
//
//                completionHandler(error)
//            }
//
//            // Custom settings successfully added
//            if networkSettings?.tunnelRemoteAddress != nil {
//                Log.append(Util.localize("remote-ip-address", networkSettings!.tunnelRemoteAddress), .info, .packetTunnelProvider)
//                Log.append(Util.localize("dns-servers-added", networkSettings!.dnsSettings?.servers.joined(separator: ", ") ?? ""), .info, .packetTunnelProvider)
//
//                if let ipv4Settings = networkSettings?.ipv4Settings {
//                    let routes = ipv4Settings.includedRoutes?.map({ return "\($0.destinationAddress) subnetmask:\($0.destinationSubnetMask)" })
//
//                    if (routes?.count ?? 0) > 0 {
//                        Log.append(Util.localize("routes", routes?.joined(separator: "\n") ?? ""), .info, .packetTunnelProvider)
//                    }
//                }
//            }
//        }
//    }
//
//    func handler(_ packets: [NEPacket]) {
//        Log.append("Packet: \(packets[0].description)", .debug, .packetTunnelProvider)
//    }
//
//    func handlePackets(_ packets: [Data], protocols: [NSNumber]) {
//        Log.append("Packet: \(packets[0])", .debug, .packetTunnelProvider)
//
//        //self.packetFlow.readPackets(completionHandler: self.handlePackets)
//
//        //readPackets(completionHandler: self.handlePackets)
//    }
//
//    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, configureTunnelWithNetworkSettings networkSettings: NEPacketTunnelNetworkSettings?, completionHandler: @escaping (OpenVPNAdapterPacketFlow?) -> Void) {
//
//        setTunnelNetworkSettings(networkSettings) { (error) in
//            completionHandler(error == nil ? self.packetFlow : nil)
//        }
//    }
//
//    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleEvent event: OpenVPNAdapterEvent, message: String?) {
//        switch event {
//        case .connected:
//            if reasserting {
//                reasserting = false
//            }
//
//            guard let startHandler = startHandler else { return }
//            startHandler(nil)
//            self.startHandler = nil
//        case .disconnected:
//            guard let stopHandler = stopHandler else { return }
//
//            if vpnReachability.isTracking {
//                vpnReachability.stopTracking()
//            }
//
//            stopHandler()
//            self.stopHandler = nil
//        case .reconnecting:
//            reasserting = true
//        default:
//            break
//        }
//    }
//
//    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleError error: Error) {
//        guard let fatal = (error as NSError).userInfo[OpenVPNAdapterErrorFatalKey] as? Bool, fatal == true else {
//            return
//        }
//
//        if let errorMessage = (error as NSError).userInfo[OpenVPNAdapterErrorMessageKey] {
//            Log.append("\(errorMessage as! String)", .error, .packetTunnelProvider)
//        } else {
//            Log.append("\(error.localizedDescription)", .error, .packetTunnelProvider)
//        }
//
//        Log.append(Util.localize("connection-info", vpnAdapter.connectionInformation.debugDescription), .info, .packetTunnelProvider)
//
//        if vpnReachability.isTracking {
//            vpnReachability.stopTracking()
//        }
//
//        if let startHandler = startHandler {
//            startHandler(error)
//            self.startHandler = nil
//        } else {
//            cancelTunnelWithError(error)
//        }
//    }
//
//    func openVPNAdapter(_ openVPNAdapter: OpenVPNAdapter, handleLogMessage logMessage: String) {
//        var logLevel: Log.LogLevel
//
//        if logMessage.lowercased().contains("exception") || logMessage.lowercased().contains("error") {
//            let lowMessage = logMessage.lowercased()
//
//            if lowMessage.contains("tun_prop_dhcp_option_error") && dnsList.contains(where: lowMessage.contains) {
//                logLevel = .debug
//            } else {
//                logLevel = .error
//            }
//        } else {
//            logLevel = .info
//        }
//
//        Log.append(logMessage, logLevel, .packetTunnelProvider)
//    }
//}

extension PacketTunnelProvider: OpenVPNAdapterPacketFlow {
    func readPackets(completionHandler: @escaping (_ packets: [Data], _ procols: [NSNumber]) -> Void) {
        packetFlow.readPackets(completionHandler: completionHandler)
    }
    
    func writePackets(_ packets: [Data], withProtocols protocols: [NSNumber]) -> Bool {
        return packetFlow.writePackets(packets, withProtocols: protocols)
    }
}

extension NEPacketTunnelFlow: @retroactive OpenVPNAdapterPacketFlow { }
