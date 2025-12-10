# ProVPN

A modern, feature-rich OpenVPN client for iOS that supports dynamic server management through API integration. Built with SwiftUI and based on the [OpenVPNAdapter](https://github.com/ss-abramchuk/OpenVPNAdapter) library.

## Features

### Core Functionality
- ✅ **Dynamic Server Management** - Fetch VPN servers from API endpoint
- ✅ **Automatic Server Discovery** - Servers are automatically loaded on app launch
- ✅ **Offline Support** - Caches server configurations and falls back to static servers when offline
- ✅ **Real-time Connection Status** - Visual indicators for connection state
- ✅ **Server Search** - Quick search functionality to find servers by name, country, or code
- ✅ **Pull-to-Refresh** - Manually refresh server list from API
- ✅ **Connection Logs** - Developer mode for debugging connection issues

### User Experience
- 🎨 **Modern UI** - Beautiful SwiftUI interface with animated backgrounds
- 📱 **iPad Support** - Optimized layouts for both iPhone and iPad
- 🔄 **Auto-reconnect** - Automatic reconnection handling
- 🌐 **Network Monitoring** - Automatic disconnection when network is lost
- ⚡ **Speed Testing** - Built-in speed test functionality
- 📍 **IP Checker** - View current IP address and location

### Security
- 🔒 **Secure Connections** - Full OpenVPN protocol support
- 🔑 **Credential Management** - Support for username/password authentication
- 🛡️ **App Transport Security** - Configured for secure API communications

## Architecture

### Project Structure
```
ProVPN/
├── Core/                    # Core VPN connection logic
│   └── Connection.swift
├── Model/                   # Data models
│   ├── VPNServer.swift     # Server model with API support
│   └── Profle.swift        # VPN profile configuration
├── View/                    # SwiftUI views
│   ├── ServerListView.swift
│   ├── ConnectionDetailsView.swift
│   └── Controls/           # Reusable UI components
├── ViewModel/              # ViewModels for state management
│   ├── ServerListViewModel.swift
│   └── ProfileViewModel.swift
├── Helpers/                # Utility services
│   ├── VPNServerAPIService.swift  # API service for dynamic servers
│   ├── IPCheckerService.swift
│   ├── NetworkMonitor.swift
│   └── SpeedTestService.swift
└── TunnelProvider/         # Network Extension for VPN tunnel
    └── Core/
        └── PacketTunnelProvider.swift
```

## API Integration

The app fetches VPN servers dynamically from a REST API endpoint. The API should return a JSON response in the following format:

### API Endpoint
```
GET http://68.183.94.242:3500/api/servers
```

### Response Format
```json
{
  "success": true,
  "count": 10,
  "servers": [
    {
      "id": "jp-1",
      "name": "Japan",
      "country": "Japan",
      "countryCode": "JP",
      "fileName": "JP_public-vpn-37.ovpn",
      "flag": "🇯🇵",
      "downloadUrl": "http://68.183.94.242:3500/api/download/jp-1",
      "username": null,
      "password": null
    }
  ]
}
```

### Server Object Fields
- `id` (string, required) - Unique server identifier
- `name` (string, required) - Display name
- `country` (string, required) - Country name
- `countryCode` (string, required) - ISO country code
- `fileName` (string, required) - OVPN file name
- `flag` (string, required) - Emoji flag
- `downloadUrl` (string, required) - URL to download .ovpn configuration file
- `username` (string, optional) - Authentication username if required
- `password` (string, optional) - Authentication password if required

### Configuration File Download
The app automatically downloads `.ovpn` configuration files from the `downloadUrl` when a server is selected. Files are cached locally for offline use.

## Setup & Installation

### Prerequisites
- Xcode 14.0 or later
- iOS 15.6 or later
- CocoaPods
- Apple Developer Account (for VPN capabilities)

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd ProVPN_iOS
   ```

2. **Install dependencies**
   ```bash
   pod install
   ```

3. **Open the workspace**
   ```bash
   open ProVPN.xcworkspace
   ```

4. **Configure Signing**
   - Select your development team in Xcode
   - Update bundle identifiers if needed
   - Ensure VPN capabilities are enabled

5. **Configure API Endpoint** (if different from default)
   - Edit `ProVPN/Helpers/VPNServerAPIService.swift`
   - Update `baseURL` constant with your API endpoint

6. **App Transport Security**
   - The app includes ATS exceptions for HTTP connections to the API server
   - For production, consider using HTTPS instead of HTTP
   - Configuration is in `ProVPN/Info.plist` under `NSAppTransportSecurity`

## Configuration

### App Transport Security (ATS)
The app includes ATS exceptions for the API server IP address (`68.183.94.242`). This allows HTTP connections to the API endpoint. The configuration is located in `Info.plist`:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>68.183.94.242</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <false/>
            <key>NSIncludesSubdomains</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### VPN Capabilities
The app requires the following capabilities:
- Personal VPN
- Network Extensions (Packet Tunnel Provider)

These are configured in the app's entitlements files.

## Usage

### Connecting to a VPN Server

1. **Launch the app** - Servers are automatically fetched from the API
2. **Select a server** - Tap on any server from the list
3. **Connect** - Tap the "Connect" button
4. **Monitor connection** - View connection status and details

### Pull-to-Refresh
Pull down on the server list to manually refresh servers from the API.

### Developer Mode
Tap the "Settings" title 5 times to enable developer mode and view connection logs.

### Offline Mode
If the API is unavailable, the app will:
- Use cached server configurations
- Fall back to static server list
- Display appropriate error messages

## Caching

The app implements intelligent caching:
- **Server List**: Cached in memory, refreshed on app launch
- **Configuration Files**: Downloaded `.ovpn` files are cached in the app's cache directory
- **Cache Location**: `Library/Caches/VPNConfigs/`

To clear the cache, you can delete the app and reinstall, or implement a cache clearing mechanism.

## Network Monitoring

The app includes automatic network monitoring:
- Detects network connectivity changes
- Automatically disconnects VPN when network is lost
- Prevents connection attempts when offline
- Shows network status in the UI

## Troubleshooting

### API Connection Issues
- Verify the API endpoint is accessible
- Check network connectivity
- Review ATS configuration in `Info.plist`
- Check console logs for detailed error messages

### VPN Connection Issues
- Enable Developer Mode to view connection logs
- Verify server configuration files are valid
- Check credentials if authentication is required
- Ensure network permissions are granted

### Build Issues
- Run `pod install` to ensure all dependencies are installed
- Clean build folder (Cmd+Shift+K)
- Verify signing and capabilities are configured correctly

## Dependencies

- [OpenVPNAdapter](https://github.com/ss-abramchuk/OpenVPNAdapter) - OpenVPN protocol implementation
- CocoaPods - Dependency management

## Requirements

- iOS 15.6+
- Xcode 14.0+
- Swift 5.0+
- Active internet connection (for API server fetching)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

For issues and questions:
- Check the troubleshooting section
- Review connection logs in Developer Mode
- Open an issue on the repository

---

**Note**: This app requires a valid VPN server API endpoint. Ensure your API server is running and accessible before using the app.
