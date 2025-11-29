//
//  SpeedTestService.swift
//  VPNClient
//
//  Created by DREAMWORLD on 25/11/25.
//

import Foundation

/// Service to measure network speed
public class SpeedTestService {
    
    /// Speed test result
    struct SpeedResult {
        let downloadSpeed: Double // in Mbps
        let uploadSpeed: Double   // in Mbps
        let latency: Int          // in ms
    }
    
    private var downloadTask: URLSessionDataTask?
    private var uploadTask: URLSessionDataTask?
    private var isRunning = false
    private var startTime: Date?
    
    /// Measure download speed using a test file
    func measureDownloadSpeed(completion: @escaping (Double?) -> Void) {
        guard !isRunning else {
            completion(nil)
            return
        }
        
        isRunning = true
        
        // Use Cloudflare's speed test endpoint (1MB download)
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=1000000") else {
            isRunning = false
            completion(nil)
            return
        }
        
        startTime = Date()
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        
        let session = URLSession(configuration: config)
        
        downloadTask = session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            self.isRunning = false
            
            guard let data = data, error == nil, let startTime = self.startTime else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let duration = Date().timeIntervalSince(startTime)
            let bytesReceived = Double(data.count)
            
            // Calculate speed in Mbps (megabits per second)
            // bytes * 8 = bits, / 1,000,000 = megabits, / seconds = Mbps
            let speedMbps = (bytesReceived * 8.0) / (duration * 1_000_000.0)
            
            DispatchQueue.main.async {
                completion(max(speedMbps, 0.1)) // Minimum 0.1 to show some activity
            }
        }
        downloadTask?.resume()
    }
    
    /// Measure upload speed by sending data to server
    func measureUploadSpeed(completion: @escaping (Double?) -> Void) {
        // Use Cloudflare's speed test upload endpoint
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else {
            completion(nil)
            return
        }
        
        // Create 500KB of random data for upload test
        let uploadSize = 500_000
        let uploadData = Data(count: uploadSize)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = uploadData
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.setValue("\(uploadSize)", forHTTPHeaderField: "Content-Length")
        request.timeoutInterval = 15
        
        let startTime = Date()
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 20
        
        let session = URLSession(configuration: config)
        
        uploadTask = session.dataTask(with: request) { [weak self] _, response, error in
            guard error == nil else {
                DispatchQueue.main.async {
                    // If upload test fails, estimate based on download (typically 1/10th)
                    completion(nil)
                }
                return
            }
            
            let duration = Date().timeIntervalSince(startTime)
            let bytesSent = Double(uploadSize)
            
            // Calculate speed in Mbps
            let speedMbps = (bytesSent * 8.0) / (duration * 1_000_000.0)
            
            DispatchQueue.main.async {
                completion(max(speedMbps, 0.1)) // Minimum 0.1 to show some activity
            }
            
            self?.uploadTask = nil
        }
        uploadTask?.resume()
    }
    
    /// Quick latency test
    func measureLatency(completion: @escaping (Int?) -> Void) {
        let startTime = Date()
        
        guard let url = URL(string: "https://www.google.com/generate_204") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5
        
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            guard error == nil, let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 204 || httpResponse.statusCode == 200 else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let latency = Int((Date().timeIntervalSince(startTime) * 1000).rounded())
            DispatchQueue.main.async {
                completion(latency)
            }
        }
        task.resume()
    }
    
    /// Cancel ongoing speed test
    func cancel() {
        downloadTask?.cancel()
        downloadTask = nil
        uploadTask?.cancel()
        uploadTask = nil
        isRunning = false
    }
}

/// Observable speed monitor for continuous monitoring
public class SpeedMonitor: ObservableObject {
    @Published var currentDownloadSpeed: Double = 0.0  // Mbps
    @Published var currentUploadSpeed: Double = 0.0    // Mbps
    @Published var latency: Int = 0                    // ms
    @Published var isTestRunning = false
    @Published var lastTestTime: Date?
    
    private let speedTestService = SpeedTestService()
    private var monitorTimer: Timer?
    
    deinit {
        stopMonitoring()
    }
    
    /// Run a single speed test (latency -> download -> upload)
    func runSpeedTest() {
        guard !isTestRunning else { return }
        
        isTestRunning = true
        
        // Step 1: Measure latency
        speedTestService.measureLatency { [weak self] latencyResult in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.latency = latencyResult ?? 0
            }
            
            // Step 2: Measure download speed
            self.speedTestService.measureDownloadSpeed { [weak self] downloadResult in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.currentDownloadSpeed = downloadResult ?? 0.0
                }
                
                // Step 3: Measure upload speed
                self.speedTestService.measureUploadSpeed { [weak self] uploadResult in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        self.currentUploadSpeed = uploadResult ?? 0.0
                        self.isTestRunning = false
                        self.lastTestTime = Date()
                    }
                }
            }
        }
    }
    
    /// Start continuous speed monitoring (every 30 seconds)
    func startMonitoring(interval: TimeInterval = 30.0) {
        stopMonitoring()
        
        // Run initial test
        runSpeedTest()
        
        // Schedule periodic tests
        monitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.runSpeedTest()
        }
    }
    
    /// Stop continuous monitoring
    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
        speedTestService.cancel()
        isTestRunning = false
    }
    
    /// Reset all values
    func reset() {
        stopMonitoring()
        currentDownloadSpeed = 0.0
        currentUploadSpeed = 0.0
        latency = 0
        lastTestTime = nil
    }
}
