//
//  ConnectionDetailsView.swift
//  VPNClient
//
//  Created by DREAMWORLD on 24/11/25.
//

import SwiftUI
import MapKit

/// Speed Gauge View - Animated circular gauge showing speed
struct SpeedGaugeView: View {
    let speed: Double  // in Mbps
    let maxSpeed: Double
    let label: String
    let color: Color
    var isIPad: Bool = false
    
    private var progress: Double {
        min(speed / maxSpeed, 1.0)
    }
    
    private var gaugeSize: CGFloat { isIPad ? 140 : 100 }
    private var lineWidth: CGFloat { isIPad ? 12 : 8 }
    
    var body: some View {
        VStack(spacing: isIPad ? 12 : 8) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: lineWidth)
                
                // Progress arc
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [color.opacity(0.5), color]),
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360 * progress)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: progress)
                
                // Speed value
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", speed))
                        .font(isIPad ? .title : .title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Mbps")
                        .font(isIPad ? .caption : .caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: gaugeSize, height: gaugeSize)
            
            Text(label)
                .font(isIPad ? .subheadline : .caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

/// Map region for IP location
struct IPLocationMapView: View {
    let coordinate: CLLocationCoordinate2D?
    let city: String?
    let country: String?
    var isIPad: Bool = false
    
    @State private var region: MKCoordinateRegion
    
    init(coordinate: CLLocationCoordinate2D?, city: String?, country: String?, isIPad: Bool = false) {
        self.coordinate = coordinate
        self.city = city
        self.country = country
        self.isIPad = isIPad
        
        // Initialize region with coordinate or default
        let center = coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        _region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if let coord = coordinate {
                Map(coordinateRegion: $region, annotationItems: [MapPin(coordinate: coord)]) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        VStack(spacing: 0) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundColor(.red)
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                                .offset(y: -5)
                        }
                    }
                }
                .frame(height: isIPad ? 200 : 150)
                .cornerRadius(isIPad ? 14 : 10)
                .onAppear {
                    // Reset region when coordinate changes
                    region = MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
                    )
                }
                
                // Location label
                if let city = city, let country = country {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(city), \(country)")
                            .font(isIPad ? .subheadline : .caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            } else {
                // Placeholder when no location
                RoundedRectangle(cornerRadius: isIPad ? 14 : 10)
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(height: isIPad ? 200 : 150)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("Location unavailable")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
    }
}

/// Map pin model
struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

/// Extended IP Information Card with all details
struct ExtendedIPInfoCard: View {
    let ipInfo: IPCheckerService.IPInfo?
    let isLoading: Bool
    var isIPad: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: isIPad ? 16 : 12) {
            // Header
            HStack {
                Image(systemName: "network")
                    .font(isIPad ? .title3 : .body)
                    .foregroundColor(.blue)
                Text("IP Location Details")
                    .font(isIPad ? .headline : .subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Fetching IP information...")
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, isIPad ? 40 : 30)
            } else if let info = ipInfo {
                // Map View
                IPLocationMapView(
                    coordinate: info.coordinate,
                    city: info.city,
                    country: info.country,
                    isIPad: isIPad
                )
                
                Divider()
                
                // IP Address - Highlighted
                VStack(alignment: .leading, spacing: 4) {
                    Text("IP Address")
                        .font(isIPad ? .caption : .caption2)
                        .foregroundColor(.secondary)
                    Text(info.ip)
                        .font(isIPad ? .title2 : .title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Divider()
                
                // Location Details Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: isIPad ? 12 : 8) {
                    IPDetailItem(icon: "building.2", label: "City", value: info.city ?? "N/A", isIPad: isIPad)
                    IPDetailItem(icon: "map", label: "State/Region", value: info.regionName ?? info.region ?? "N/A", isIPad: isIPad)
                    IPDetailItem(icon: "globe", label: "Country", value: info.country ?? "N/A", isIPad: isIPad)
                    IPDetailItem(icon: "clock", label: "Timezone", value: info.timezone ?? "N/A", isIPad: isIPad)
                }
                
                Divider()
                
                // ISP Information
                VStack(alignment: .leading, spacing: 8) {
                    IPDetailRow(icon: "antenna.radiowaves.left.and.right", label: "ISP", value: info.isp ?? "N/A", isIPad: isIPad)
                    if let org = info.org, org != info.isp {
                        IPDetailRow(icon: "building", label: "Organization", value: org, isIPad: isIPad)
                    }
                    if let zip = info.zip, !zip.isEmpty {
                        IPDetailRow(icon: "number", label: "Postal Code", value: zip, isIPad: isIPad)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text("Unable to fetch IP information")
                        .font(isIPad ? .body : .subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, isIPad ? 40 : 30)
            }
        }
        .padding(isIPad ? 16 : 12)
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 14 : 10)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
}

/// IP Detail Item for grid
struct IPDetailItem: View {
    let icon: String
    let label: String
    let value: String
    var isIPad: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(isIPad ? .body : .caption)
                .foregroundColor(.blue)
                .frame(width: isIPad ? 24 : 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(isIPad ? .caption : .caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(isIPad ? .subheadline : .caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(isIPad ? 10 : 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
    }
}

/// IP Detail Row for full width items
struct IPDetailRow: View {
    let icon: String
    let label: String
    let value: String
    var isIPad: Bool = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(isIPad ? .body : .caption)
                .foregroundColor(.purple)
                .frame(width: isIPad ? 24 : 20)
            
            Text(label + ":")
                .font(isIPad ? .subheadline : .caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(isIPad ? .body : .subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            Spacer()
        }
    }
}

/// Connection Details Card - Shows when connected
struct ConnectionDetailsCard: View {
    @ObservedObject var viewModel: ServerListViewModel
    @StateObject private var speedMonitor = SpeedMonitor()
    @State private var currentIP: IPCheckerService.IPInfo?
    @State private var isLoadingIP = false
    @State private var connectionStartTime: Date?
    @State private var elapsedTime: String = "00:00:00"
    @State private var timer: Timer?
    var isIPad: Bool = false
    
    // UserDefaults key for persisting connection start time
    private static let connectionStartTimeKey = "vpn_connection_start_time"
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection Details")
                        .font(isIPad ? .title2 : .headline)
                        .fontWeight(.bold)
                    
                    if let server = viewModel.selectedServer {
                        HStack(spacing: 6) {
                            Text(server.flag)
                                .font(isIPad ? .title3 : .body)
                            Text(server.name)
                                .font(isIPad ? .body : .subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Connection duration
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Duration")
                        .font(isIPad ? .caption : .caption2)
                        .foregroundColor(.secondary)
                    Text(elapsedTime)
                        .font(isIPad ? .title3 : .subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                        .monospacedDigit()
                }
            }
            
            Divider()
            
            // Speed Gauges
            HStack(spacing: isIPad ? 40 : 24) {
                SpeedGaugeView(
                    speed: speedMonitor.currentDownloadSpeed,
                    maxSpeed: 100,
                    label: "Download",
                    color: .blue,
                    isIPad: isIPad
                )
                
                // Latency in center
                VStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .font(isIPad ? .title2 : .title3)
                        .foregroundColor(.orange)
                    Text("\(speedMonitor.latency)")
                        .font(isIPad ? .title2 : .title3)
                        .fontWeight(.bold)
                    Text("ms")
                        .font(isIPad ? .caption : .caption2)
                        .foregroundColor(.secondary)
                    Text("Ping")
                        .font(isIPad ? .subheadline : .caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: isIPad ? 80 : 60)
                
                SpeedGaugeView(
                    speed: speedMonitor.currentUploadSpeed,
                    maxSpeed: 50,
                    label: "Upload",
                    color: .green,
                    isIPad: isIPad
                )
            }
            
            // Speed Test Button
            Button(action: {
                speedMonitor.runSpeedTest()
            }) {
                HStack(spacing: 8) {
                    if speedMonitor.isTestRunning {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "speedometer")
                    }
                    Text(speedMonitor.isTestRunning ? "Testing..." : "Run Speed Test")
                }
                .font(isIPad ? .body : .subheadline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, isIPad ? 14 : 12)
                .background(speedMonitor.isTestRunning ? Color.gray : Color.blue)
                .cornerRadius(isIPad ? 12 : 10)
            }
            .disabled(speedMonitor.isTestRunning)
            
            Divider()
            
            // Extended IP Information with Map
            ExtendedIPInfoCard(
                ipInfo: currentIP,
                isLoading: isLoadingIP,
                isIPad: isIPad
            )
            
            // Server Details
            if let server = viewModel.selectedServer {
                VStack(alignment: .leading, spacing: isIPad ? 10 : 8) {
                    HStack {
                        Image(systemName: "server.rack")
                            .font(isIPad ? .title3 : .body)
                            .foregroundColor(.purple)
                        Text("Server Details")
                            .font(isIPad ? .headline : .subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        DetailRow(label: "Server", value: server.name, isIPad: isIPad)
                        DetailRow(label: "Country", value: server.country, isIPad: isIPad)
                        DetailRow(label: "Protocol", value: "OpenVPN", isIPad: isIPad)
                        DetailRow(label: "Encryption", value: "AES-256-GCM", isIPad: isIPad)
                    }
                }
                .padding(isIPad ? 16 : 12)
                .background(
                    RoundedRectangle(cornerRadius: isIPad ? 14 : 10)
                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                )
            }
        }
        .padding(isIPad ? 24 : 16)
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 20 : 16)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .onAppear {
            startTimer()
            fetchIP()
            // Auto-run speed test on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                speedMonitor.runSpeedTest()
            }
        }
        .onDisappear {
            stopTimer()
            speedMonitor.stopMonitoring()
        }
        .onChange(of: viewModel.isConnected()) { isConnected in
            if isConnected {
                // Only set new start time if we don't have a saved one
                if loadConnectionStartTime() == nil {
                    saveConnectionStartTime(Date())
                }
                startTimer()
                fetchIP()
            } else {
                // VPN disconnected (from app, Settings, or connection drop)
                // Clear timer and reset
                Self.clearConnectionStartTime()
                stopTimer()
                speedMonitor.reset()
                elapsedTime = "00:00:00"
            }
        }
    }
    
    private func startTimer() {
        // Load persisted start time or use current time
        connectionStartTime = loadConnectionStartTime() ?? Date()
        
        // If no saved time exists, save current time
        if loadConnectionStartTime() == nil {
            saveConnectionStartTime(connectionStartTime!)
        }
        
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateElapsedTime()
        }
        // Update immediately
        updateElapsedTime()
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateElapsedTime() {
        guard let startTime = connectionStartTime else { return }
        let elapsed = Date().timeIntervalSince(startTime)
        let hours = Int(elapsed) / 3600
        let minutes = (Int(elapsed) % 3600) / 60
        let seconds = Int(elapsed) % 60
        elapsedTime = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // MARK: - Persistence for Connection Start Time
    
    private func saveConnectionStartTime(_ date: Date) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: Self.connectionStartTimeKey)
    }
    
    private func loadConnectionStartTime() -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: Self.connectionStartTimeKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    /// Clear connection start time - call this only when user explicitly disconnects
    static func clearConnectionStartTime() {
        UserDefaults.standard.removeObject(forKey: connectionStartTimeKey)
    }
    
    private func fetchIP() {
        isLoadingIP = true
        IPCheckerService.fetchPublicIP { info in
            currentIP = info
            isLoadingIP = false
        }
    }
}

/// Detail row helper view
struct DetailRow: View {
    let label: String
    let value: String
    var isIPad: Bool = false
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(isIPad ? .subheadline : .caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(isIPad ? .body : .subheadline)
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

/// Mini connection status for non-connected state
struct MiniIPChecker: View {
    @State private var currentIP: IPCheckerService.IPInfo?
    @State private var isLoading = false
    var isIPad: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: isIPad ? 12 : 8) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(isIPad ? .title3 : .body)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Current IP")
                        .font(isIPad ? .caption : .caption2)
                        .foregroundColor(.secondary)
                    
                    if isLoading {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Checking...")
                                .font(isIPad ? .subheadline : .caption)
                                .foregroundColor(.secondary)
                        }
                    } else if let ip = currentIP?.ip {
                        Text(ip)
                            .font(isIPad ? .body : .subheadline)
                            .fontWeight(.semibold)
                    } else {
                        Text("Not available")
                            .font(isIPad ? .body : .subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: fetchIP) {
                    Image(systemName: "arrow.clockwise")
                        .font(isIPad ? .body : .caption)
                        .foregroundColor(.blue)
                }
                .disabled(isLoading)
            }
            
            // Show additional details if available
            if let info = currentIP, !isLoading {
                Divider()
                
                HStack(spacing: isIPad ? 16 : 12) {
                    if let city = info.city, let country = info.country {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("\(city), \(country)")
                                .font(isIPad ? .caption : .caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let isp = info.isp {
                        HStack(spacing: 4) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(isp)
                                .font(isIPad ? .caption : .caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .padding(isIPad ? 16 : 12)
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 14 : 10)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
        )
        .onAppear {
            fetchIP()
        }
    }
    
    private func fetchIP() {
        isLoading = true
        IPCheckerService.fetchPublicIP { info in
            currentIP = info
            isLoading = false
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            SpeedGaugeView(speed: 45.5, maxSpeed: 100, label: "Download", color: .blue)
            MiniIPChecker()
        }
        .padding()
    }
}
