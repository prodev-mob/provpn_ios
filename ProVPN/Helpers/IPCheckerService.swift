//
//  IPCheckerService.swift
//  ProVPN
//
//  Created by DREAMWORLD on 25/11/25.
//

import Foundation
import CoreLocation

/// Service to check public IP address
public class IPCheckerService {
    
    /// IP information model with extended details
    struct IPInfo {
        let ip: String
        let country: String?
        let countryCode: String?
        let city: String?
        let region: String?      // State/Region
        let regionName: String?  // Full region name
        let isp: String?
        let org: String?         // Organization
        let timezone: String?
        let latitude: Double?
        let longitude: Double?
        let zip: String?         // Postal code
        
        /// Get coordinate for map display
        var coordinate: CLLocationCoordinate2D? {
            guard let lat = latitude, let lon = longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        
        /// Formatted location string
        var formattedLocation: String {
            var parts: [String] = []
            if let city = city { parts.append(city) }
            if let region = regionName ?? region { parts.append(region) }
            if let country = country { parts.append(country) }
            return parts.joined(separator: ", ")
        }
    }
    
    /// Fetch current public IP address with extended details
    static func fetchPublicIP(completion: @escaping (IPInfo?) -> Void) {
        // First get IP from ipify (HTTPS)
        guard let ipifyURL = URL(string: "https://api.ipify.org?format=json") else {
            completion(nil)
            return
        }
        
        let task = URLSession.shared.dataTask(with: ipifyURL) { data, response, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ip = json["ip"] as? String else {
                // Try alternative API
                fetchFromIPWhoIs(completion: completion)
                return
            }
            
            // Now get detailed info using ipwho.is (HTTPS, no API key needed)
            fetchIPDetails(ip: ip, completion: completion)
        }
        task.resume()
    }
    
    /// Fetch IP details from ipwho.is (HTTPS)
    private static func fetchIPDetails(ip: String, completion: @escaping (IPInfo?) -> Void) {
        guard let url = URL(string: "https://ipwho.is/\(ip)") else {
            let basicInfo = IPInfo(
                ip: ip, country: nil, countryCode: nil, city: nil,
                region: nil, regionName: nil, isp: nil, org: nil,
                timezone: nil, latitude: nil, longitude: nil, zip: nil
            )
            DispatchQueue.main.async {
                completion(basicInfo)
            }
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                let basicInfo = IPInfo(
                    ip: ip, country: nil, countryCode: nil, city: nil,
                    region: nil, regionName: nil, isp: nil, org: nil,
                    timezone: nil, latitude: nil, longitude: nil, zip: nil
                )
                DispatchQueue.main.async {
                    completion(basicInfo)
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success {
                    
                    // Extract timezone info
                    let timezoneDict = json["timezone"] as? [String: Any]
                    let timezoneId = timezoneDict?["id"] as? String
                    
                    // Extract connection info
                    let connectionDict = json["connection"] as? [String: Any]
                    let isp = connectionDict?["isp"] as? String
                    let org = connectionDict?["org"] as? String
                    
                    let info = IPInfo(
                        ip: json["ip"] as? String ?? ip,
                        country: json["country"] as? String,
                        countryCode: json["country_code"] as? String,
                        city: json["city"] as? String,
                        region: json["region_code"] as? String,
                        regionName: json["region"] as? String,
                        isp: isp,
                        org: org,
                        timezone: timezoneId,
                        latitude: json["latitude"] as? Double,
                        longitude: json["longitude"] as? Double,
                        zip: json["postal"] as? String
                    )
                    DispatchQueue.main.async {
                        completion(info)
                    }
                } else {
                    // Return basic info if detailed fetch fails
                    let basicInfo = IPInfo(
                        ip: ip, country: nil, countryCode: nil, city: nil,
                        region: nil, regionName: nil, isp: nil, org: nil,
                        timezone: nil, latitude: nil, longitude: nil, zip: nil
                    )
                    DispatchQueue.main.async {
                        completion(basicInfo)
                    }
                }
            } catch {
                let basicInfo = IPInfo(
                    ip: ip, country: nil, countryCode: nil, city: nil,
                    region: nil, regionName: nil, isp: nil, org: nil,
                    timezone: nil, latitude: nil, longitude: nil, zip: nil
                )
                DispatchQueue.main.async {
                    completion(basicInfo)
                }
            }
        }
        task.resume()
    }
    
    /// Alternative: Fetch from ipwho.is directly
    private static func fetchFromIPWhoIs(completion: @escaping (IPInfo?) -> Void) {
        guard let url = URL(string: "https://ipwho.is/") else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success,
                   let ip = json["ip"] as? String {
                    
                    // Extract timezone info
                    let timezoneDict = json["timezone"] as? [String: Any]
                    let timezoneId = timezoneDict?["id"] as? String
                    
                    // Extract connection info
                    let connectionDict = json["connection"] as? [String: Any]
                    let isp = connectionDict?["isp"] as? String
                    let org = connectionDict?["org"] as? String
                    
                    let info = IPInfo(
                        ip: ip,
                        country: json["country"] as? String,
                        countryCode: json["country_code"] as? String,
                        city: json["city"] as? String,
                        region: json["region_code"] as? String,
                        regionName: json["region"] as? String,
                        isp: isp,
                        org: org,
                        timezone: timezoneId,
                        latitude: json["latitude"] as? Double,
                        longitude: json["longitude"] as? Double,
                        zip: json["postal"] as? String
                    )
                    DispatchQueue.main.async {
                        completion(info)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
        task.resume()
    }
}

