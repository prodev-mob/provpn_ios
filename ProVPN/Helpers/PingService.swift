//
//  PingService.swift
//  ProVPN
//
//  Created by DREAMWORLD on 24/11/25.
//

import Foundation
import Network

/// Service to measure ping/latency to VPN servers
public class PingService {
    
    /// Extract remote host from .ovpn file content
    static func extractRemoteHost(from configData: Data) -> String? {
        guard let configString = String(data: configData, encoding: .utf8) else {
            return nil
        }
        
        let lines = configString.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("remote ") {
                let parts = trimmed.components(separatedBy: .whitespaces)
                if parts.count >= 2 {
                    return parts[1] // Return the hostname/IP
                }
            }
        }
        
        return nil
    }
    
    /// Measure ping/latency to a server using TCP connection
    static func measurePing(host: String, port: Int, timeout: TimeInterval = 3.0, completion: @escaping (Int?) -> Void) {
        let startTime = Date()
        
        // Create connection
        let hostEndpoint = NWEndpoint.Host(host)
        let portEndpoint = NWEndpoint.Port(integerLiteral: UInt16(port))
        let connection = NWConnection(host: hostEndpoint, port: portEndpoint, using: .tcp)
        
        var hasCompleted = false
        
        // Set timeout
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        timer.schedule(deadline: .now() + timeout)
        timer.setEventHandler {
            if !hasCompleted {
                hasCompleted = true
                connection.cancel()
                DispatchQueue.main.async {
                    completion(nil) // Timeout
                }
            }
        }
        timer.resume()
        
        // Handle connection state
        connection.stateUpdateHandler = { state in
            if hasCompleted { return }
            
            switch state {
            case .ready:
                if !hasCompleted {
                    hasCompleted = true
                    timer.cancel()
                    let pingTime = Int((Date().timeIntervalSince(startTime) * 1000).rounded())
                    connection.cancel()
                    DispatchQueue.main.async {
                        completion(pingTime)
                    }
                }
            case .failed(_):
                if !hasCompleted {
                    hasCompleted = true
                    timer.cancel()
                    connection.cancel()
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            default:
                break
            }
        }
        
        // Start connection
        connection.start(queue: DispatchQueue.global())
    }
}

