//
//  VPNServerAPIService.swift
//  ProVPN
//
//  Created by DREAMWORLD on 24/11/25.
//

import Foundation

/// API response models
struct ServerListResponse: Codable {
    let success: Bool
    let count: Int
    let servers: [ServerAPIResponse]
}

struct ServerAPIResponse: Codable {
    let id: String
    let name: String
    let country: String
    let countryCode: String
    let fileName: String
    let flag: String
    let downloadUrl: String
    let username: String?
    let password: String?
}

/// Service to fetch VPN servers from API
public class VPNServerAPIService {
    static let shared = VPNServerAPIService()
    
    private let baseURL = "http://68.183.94.242:3500"
    private let serversEndpoint = "/api/servers"
    
    // Cache directory for downloaded .ovpn files
    private var cacheDirectory: URL {
        let urls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheURL = urls[0].appendingPathComponent("VPNConfigs", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true, attributes: nil)
        
        return cacheURL
    }
    
    private init() {}
    
    /// Fetch servers from API
    func fetchServers(completion: @escaping (Result<[VPNServer], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)\(serversEndpoint)") else {
            completion(.failure(NSError(domain: "VPNServerAPIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "VPNServerAPIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
                return
            }
            
            do {
                let response = try JSONDecoder().decode(ServerListResponse.self, from: data)
                
                // Convert API response to VPNServer models
                let servers = response.servers.map { apiServer in
                    VPNServer(
                        id: apiServer.id,
                        name: apiServer.name,
                        country: apiServer.country,
                        countryCode: apiServer.countryCode,
                        fileName: apiServer.fileName,
                        flag: apiServer.flag,
                        downloadUrl: apiServer.downloadUrl,
                        username: apiServer.username,
                        password: apiServer.password
                    )
                }
                
                DispatchQueue.main.async {
                    completion(.success(servers))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    /// Download .ovpn file from API and cache it
    func downloadConfigFile(from urlString: String, serverId: String, completion: @escaping (Result<Data, Error>) -> Void) {
        // Check cache first
        let cachedFileURL = cacheDirectory.appendingPathComponent("\(serverId).ovpn")
        if let cachedData = try? Data(contentsOf: cachedFileURL) {
            Log.append("Using cached config for server \(serverId)", .info, .mainApp)
            completion(.success(cachedData))
            return
        }
        
        // Download from API
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "VPNServerAPIService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid download URL"])))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "VPNServerAPIService", code: -4, userInfo: [NSLocalizedDescriptionKey: "No data received from download"])))
                }
                return
            }
            
            // Cache the downloaded file
            if let cacheURL = self?.cacheDirectory.appendingPathComponent("\(serverId).ovpn") {
                try? data.write(to: cacheURL)
                Log.append("Cached config file for server \(serverId)", .info, .mainApp)
            }
            
            DispatchQueue.main.async {
                completion(.success(data))
            }
        }
        
        task.resume()
    }
    
    /// Clear cached config files
    func clearCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        Log.append("Cleared VPN config cache", .info, .mainApp)
    }
    
    /// Get cached config file if exists
    func getCachedConfig(serverId: String) -> Data? {
        let cachedFileURL = cacheDirectory.appendingPathComponent("\(serverId).ovpn")
        return try? Data(contentsOf: cachedFileURL)
    }
}
