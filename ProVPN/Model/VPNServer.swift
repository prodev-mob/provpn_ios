//
//  VPNServer.swift
//  ProVPN
//
//  Created by DREAMWORLD on 24/11/25.
//

import Foundation

/// Represents a VPN server with display information
public struct VPNServer: Identifiable, Codable {
    public let id: String
    public let name: String
    public let country: String
    public let countryCode: String
    public let fileName: String
    public let flag: String // Emoji flag
    public let downloadUrl: String? // API download URL
    public let username: String?
    public let password: String?
    
    public init(id: String, name: String, country: String, countryCode: String, fileName: String, flag: String, downloadUrl: String? = nil, username: String? = nil, password: String? = nil) {
        self.id = id
        self.name = name
        self.country = country
        self.countryCode = countryCode
        self.fileName = fileName
        self.flag = flag
        self.downloadUrl = downloadUrl
        self.username = username
        self.password = password
    }
    
    /// Load the .ovpn file content from API or bundle (fallback)
    public func loadConfigFile(completion: @escaping (Data?) -> Void) {
        // If downloadUrl is available, download from API
        if let downloadUrl = downloadUrl {
            VPNServerAPIService.shared.downloadConfigFile(from: downloadUrl, serverId: id) { result in
                switch result {
                case .success(let data):
                    completion(data)
                case .failure(let error):
                    Log.append("Failed to download config from API: \(error.localizedDescription)", .error, .mainApp)
                    // Fallback to bundle if API download fails
                    completion(self.loadConfigFileFromBundle())
                }
            }
        } else {
            // Fallback to bundle for static servers
            completion(loadConfigFileFromBundle())
        }
    }
    
    /// Synchronous version for backward compatibility (uses cache if available)
    public func loadConfigFile() -> Data? {
        // Check cache first
        if let cachedData = VPNServerAPIService.shared.getCachedConfig(serverId: id) {
            return cachedData
        }
        
        // Fallback to bundle
        return loadConfigFileFromBundle()
    }
    
    /// Load config file from bundle (fallback method)
    private func loadConfigFileFromBundle() -> Data? {
        // Try with subdirectory first
        if let url = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".ovpn", with: ""), withExtension: "ovpn", subdirectory: "ServerFiles") {
            return try? Data(contentsOf: url)
        }
        
        // Fallback: try without subdirectory
        if let url = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".ovpn", with: ""), withExtension: "ovpn") {
            return try? Data(contentsOf: url)
        }
        
        // Last resort: try with full filename
        if let url = Bundle.main.path(forResource: fileName, ofType: nil, inDirectory: "ServerFiles") {
            return try? Data(contentsOf: URL(fileURLWithPath: url))
        }
        
        return nil
    }
}

/// Predefined list of VPN servers (fallback for offline mode)
public struct VPNServerList {
    public static let servers: [VPNServer] = [
        VPNServer(id: "jp-1", name: "Japan", country: "Japan", countryCode: "JP", fileName: "Japan.ovpn", flag: "🇯🇵"),
        VPNServer(id: "kr-1", name: "Korea", country: "Korea", countryCode: "KR", fileName: "Korea.ovpn", flag: "🇰🇷"),
        VPNServer(id: "ru-1", name: "Russia", country: "Russia", countryCode: "RU", fileName: "Russia.ovpn", flag: "🇷🇺"),
        VPNServer(id: "th-1", name: "Thailand", country: "Thailand", countryCode: "TH", fileName: "Thailand.ovpn", flag: "🇹🇭"),
        VPNServer(id: "vn-1", name: "Vietnam", country: "Vietnam", countryCode: "VN", fileName: "Vietnam.ovpn", flag: "🇻🇳"),
        VPNServer(id: "ca-1", name: "Canada", country: "Canada", countryCode: "CA", fileName: "Canada.ovpn", flag: "🇨🇦"),
        VPNServer(id: "ge-1", name: "Germany", country: "Germany", countryCode: "GE", fileName: "Germany.ovpn", flag: "🇩🇪", username: "vpnbook", password: "545ae57"),
        VPNServer(id: "fr-1", name: "France", country: "France", countryCode: "FR", fileName: "France.ovpn", flag: "🇫🇷", username: "vpnbook", password: "545ae57"),
        VPNServer(id: "Pl-1", name: "Poland", country: "Poland", countryCode: "PL", fileName: "Poland.ovpn", flag: "🇵🇱", username: "vpnbook", password: "545ae57"),
        VPNServer(id: "Uk-1", name: "United Kingdom", country: "United Kingdom", countryCode: "UK", fileName: "UnitedKingdom.ovpn", flag: "🇬🇧", username: "vpnbook", password: "545ae57"),
        VPNServer(id: "Us-1", name: "United States", country: "United States", countryCode: "US", fileName: "UnitedStates.ovpn", flag: "🇺🇸", username: "vpnbook", password: "545ae57"),
        VPNServer(id: "Au-1", name: "Australia", country: "Australia", countryCode: "AU", fileName: "Australia.ovpn", flag: "🇦🇺"),
        VPNServer(id: "Hk-1", name: "HongKong", country: "HongKong", countryCode: "HK", fileName: "HongKong.ovpn", flag: "🇭🇰"),
        VPNServer(id: "It-1", name: "Italy", country: "Italy", countryCode: "IT", fileName: "Italy.ovpn", flag: "🇮🇹"),
        VPNServer(id: "Uae-1", name: "United Arab Emirates", country: "UnitedArabEmirates", countryCode: "UAE", fileName: "UnitedArabEmirates.ovpn", flag: "🇦🇪"),
        VPNServer(id: "Tu-1", name: "Turkey", country: "Turkey", countryCode: "TU", fileName: "Turkey.ovpn", flag: "🇹🇷"),
    ]
    
    /// Get servers grouped by country
    public static func serversByCountry() -> [String: [VPNServer]] {
        Dictionary(grouping: servers) { $0.country }
    }
}

