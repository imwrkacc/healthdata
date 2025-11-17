# HealthKit Prometheus Exporter

Export your Apple HealthKit metrics to Prometheus format for visualization in Grafana. Access comprehensive health data from your iPhone and Apple Watch including steps, heart rate, sleep, workouts, and much more.

## 🚀 Two Ways to Export Your Data

### Option 1: Python Exporter (No macOS Required!) ⭐ **RECOMMENDED**

**Perfect if you don't have a Mac or don't want to build an iOS app.**

- ✅ Works on **Linux, Windows, or Mac**
- ✅ **No Xcode or iOS development needed**
- ✅ **No Apple Developer account required**
- ✅ Simple Python script using Apple Health's built-in export feature
- ⚠️ Manual updates (export data periodically from Health app)

**→ [Get Started with Python Exporter](PYTHON_EXPORTER.md)** (5 minutes setup)

### Option 2: Native iOS App (Real-time Data)

**Choose this if you have a Mac and want real-time continuous monitoring.**

- ✅ **Real-time data** directly from HealthKit
- ✅ Automatic updates as you move throughout the day
- ✅ Runs HTTP server on your iPhone
- ⚠️ Requires macOS + Xcode to build
- ⚠️ Requires Apple Developer account (free tier OK)

**→ Continue reading below for iOS app setup**

---

## Features

### Health Metrics Exported

#### Activity & Fitness
- **Steps** - Daily and weekly step count
- **Distance** - Walking/running distance in meters
- **Flights Climbed** - Number of floors climbed
- **Active Energy** - Calories burned through activity
- **Exercise Time** - Minutes of exercise recorded
- **Workouts** - Number of workouts completed

#### Heart Health
- **Heart Rate** - Current and average heart rate
- **Resting Heart Rate** - Your resting heart rate measurement
- **Heart Rate Variability (HRV)** - Heart rate variability in milliseconds
- **VO2 Max** - Cardiovascular fitness indicator

#### Body Measurements
- **Weight** - Body weight in kilograms
- **BMI** - Body Mass Index
- **Height** - Height in meters
- **Body Fat Percentage** - If tracked
- **Lean Body Mass** - If tracked

#### Sleep
- **Sleep Duration** - Hours of sleep from the previous night
- **Sleep Analysis** - Detailed sleep stages (deep, core, REM)

#### Other Metrics
- **Respiratory Rate** - Breaths per minute
- **Blood Oxygen** - SpO2 saturation percentage
- **Blood Pressure** - Systolic and diastolic measurements
- **Body Temperature** - Core temperature readings
- **Nutrition** - Water intake and calorie consumption

## Requirements

- iOS 16.0 or later
- iPhone with HealthKit support
- Xcode 15.0 or later (for building)
- Apple Watch (optional, for additional metrics)

## Installation

### Building from Source

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/healthdata.git
   cd healthdata
   ```

2. Open the Xcode project:
   ```bash
   open HealthKitPrometheusExporter/HealthKitPrometheusExporter.xcodeproj
   ```

3. Select your development team:
   - Click on the project in Xcode
   - Select the "HealthKitPrometheusExporter" target
   - Go to "Signing & Capabilities"
   - Select your Team from the dropdown

4. Update the Bundle Identifier (if needed):
   - In the same "Signing & Capabilities" section
   - Change `com.yourcompany.HealthKitPrometheusExporter` to your own identifier

5. Connect your iPhone and select it as the build target

6. Build and run the app (⌘R)

## Usage

### Setting Up the App

1. **Launch the app** on your iPhone

2. **Authorize HealthKit access**:
   - Tap "Authorize HealthKit" button
   - Review the health data types
   - Tap "Allow" to grant access to all requested metrics

3. **Start the Prometheus server**:
   - Tap "Start Server" button
   - The server will start on port 9090 (default)
   - Note the endpoint URL displayed: `http://localhost:9090/metrics`

4. **Verify metrics collection**:
   - Tap the refresh button (↻) to update metrics
   - View your current health data in the app

### Accessing Metrics

The Prometheus exporter runs an HTTP server on your device at:

```
http://localhost:9090/metrics
```

You can test the endpoint using Safari on your iPhone or any HTTP client:

```bash
curl http://localhost:9090/metrics
```

### Example Metrics Output

```
# HealthKit Prometheus Exporter
# Metrics collected from Apple Health

# HELP healthkit_steps_total Total number of steps
# TYPE healthkit_steps_total counter
healthkit_steps_total{period="today"} 8432
healthkit_steps_total{period="weekly"} 52891

# HELP healthkit_heart_rate_bpm Current heart rate in beats per minute
# TYPE healthkit_heart_rate_bpm gauge
healthkit_heart_rate_bpm{type="current"} 72
healthkit_heart_rate_bpm{type="average_today"} 68

# HELP healthkit_weight_kg Body weight in kilograms
# TYPE healthkit_weight_kg gauge
healthkit_weight_kg 75.2

# HELP healthkit_sleep_hours Sleep duration in hours
# TYPE healthkit_sleep_hours gauge
healthkit_sleep_hours{period="last_night"} 7.5
```

## Prometheus Configuration

To scrape metrics from your iPhone, you'll need to ensure Prometheus can reach your device. Here are several approaches:

### Option 1: USB Network (Recommended for Development)

If your iPhone is connected to your Mac via USB, you can use `iproxy` to forward the port:

```bash
# Install usbmuxd if not already installed
brew install usbmuxd

# Forward iPhone port 9090 to Mac port 9090
iproxy 9090:9090
```

Then configure Prometheus to scrape localhost:

```yaml
scrape_configs:
  - job_name: 'healthkit'
    scrape_interval: 60s
    static_configs:
      - targets: ['localhost:9090']
        labels:
          device: 'iphone'
          source: 'healthkit'
```

### Option 2: Local Network

If your iPhone and Prometheus server are on the same WiFi network:

1. Find your iPhone's IP address:
   - Go to Settings → WiFi
   - Tap the (i) icon next to your connected network
   - Note the IP Address (e.g., 192.168.1.100)

2. Configure Prometheus:

```yaml
scrape_configs:
  - job_name: 'healthkit'
    scrape_interval: 60s
    static_configs:
      - targets: ['192.168.1.100:9090']
        labels:
          device: 'iphone'
          source: 'healthkit'
```

### Option 3: Tailscale/VPN

For remote access, use a VPN solution like Tailscale:

1. Install Tailscale on your iPhone and server
2. Use the Tailscale IP address in Prometheus configuration

## Grafana Dashboard

### Sample Dashboard JSON

Create a new dashboard in Grafana with these example panels:

#### Steps Panel
```json
{
  "title": "Daily Steps",
  "targets": [
    {
      "expr": "healthkit_steps_total{period=\"today\"}",
      "legendFormat": "Steps Today"
    }
  ],
  "type": "stat"
}
```

#### Heart Rate Panel
```json
{
  "title": "Heart Rate",
  "targets": [
    {
      "expr": "healthkit_heart_rate_bpm",
      "legendFormat": "{{type}}"
    }
  ],
  "type": "graph"
}
```

#### Sleep Panel
```json
{
  "title": "Sleep Duration",
  "targets": [
    {
      "expr": "healthkit_sleep_hours",
      "legendFormat": "Sleep (hours)"
    }
  ],
  "type": "graph"
}
```

### Complete Dashboard

A complete Grafana dashboard configuration is available in the `grafana/` directory (coming soon).

## Available Metrics

| Metric Name | Type | Labels | Description |
|-------------|------|--------|-------------|
| `healthkit_steps_total` | counter | `period` | Total steps (today/weekly) |
| `healthkit_distance_meters` | counter | `period` | Distance in meters (today/weekly) |
| `healthkit_flights_climbed_total` | counter | `period` | Flights of stairs climbed |
| `healthkit_active_energy_kcal` | counter | `period` | Active energy burned (kcal) |
| `healthkit_exercise_minutes` | counter | `period` | Exercise time in minutes |
| `healthkit_heart_rate_bpm` | gauge | `type` | Heart rate (current/average) |
| `healthkit_resting_heart_rate_bpm` | gauge | - | Resting heart rate |
| `healthkit_heart_rate_variability_ms` | gauge | - | HRV in milliseconds |
| `healthkit_weight_kg` | gauge | - | Body weight in kg |
| `healthkit_body_mass_index` | gauge | - | BMI |
| `healthkit_height_meters` | gauge | - | Height in meters |
| `healthkit_sleep_hours` | gauge | `period` | Sleep duration in hours |
| `healthkit_workouts_total` | counter | `period` | Number of workouts |

## Architecture

### Components

1. **HealthKitManager** - Handles all HealthKit data access and queries
   - Requests authorization for health data types
   - Fetches metrics asynchronously
   - Caches latest values

2. **PrometheusServer** - HTTP server for metrics exposition
   - Runs on device using Network framework
   - Formats metrics in Prometheus text format
   - Serves on localhost:9090

3. **ContentView** - SwiftUI interface
   - Displays current metrics
   - Server control (start/stop)
   - Authorization management

### Data Flow

```
HealthKit → HealthKitManager → HealthMetrics Model → PrometheusServer → HTTP Response
```

## Privacy & Security

- All health data stays on your device
- The HTTP server only accepts localhost connections by default
- No data is sent to external servers
- Health data access requires explicit user authorization
- You maintain full control over which metrics to share

## Troubleshooting

### Server Won't Start
- Ensure no other app is using port 9090
- Check that the app has network permissions
- Restart the app

### No Metrics Showing
- Verify HealthKit authorization was granted
- Tap the refresh button to update data
- Check that you have health data in the Health app
- Ensure your Apple Watch is paired and syncing

### Prometheus Can't Scrape Metrics
- Verify the iPhone is reachable (ping the IP address)
- Check firewall settings on your network
- Ensure the server is running (check app status)
- Try accessing the metrics endpoint in Safari on your iPhone first

### Missing Health Data
- Some metrics require an Apple Watch (e.g., HRV, VO2 Max)
- Body measurements need to be manually entered in Health app
- Sleep data requires sleep tracking to be enabled

## Development

### Project Structure

```
HealthKitPrometheusExporter/
├── HealthKitPrometheusExporter.xcodeproj/
│   └── project.pbxproj
└── HealthKitPrometheusExporter/
    ├── HealthKitPrometheusExporterApp.swift    # App entry point
    ├── ContentView.swift                        # Main UI
    ├── HealthKitManager.swift                   # HealthKit integration
    ├── PrometheusServer.swift                   # HTTP server
    ├── Info.plist                               # App configuration
    ├── HealthKitPrometheusExporter.entitlements # Capabilities
    └── Assets.xcassets/                         # App assets
```

### Building for Release

1. Update version number in project settings
2. Select "Any iOS Device" as build target
3. Product → Archive
4. Distribute to TestFlight or App Store

### Testing

Test the app on a physical device with health data:

```bash
# Test metrics endpoint
curl http://localhost:9090/metrics

# Test health endpoint
curl http://localhost:9090/health
```

## Roadmap

- [ ] Background metric updates
- [ ] Custom port configuration
- [ ] Export configuration (select which metrics to expose)
- [ ] Historical data queries
- [ ] Grafana dashboard templates
- [ ] Remote authentication/security options
- [ ] Additional health metrics (blood glucose, etc.)
- [ ] Apple Watch companion app

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - feel free to use this project for personal or commercial purposes.

## Acknowledgments

- Apple HealthKit for comprehensive health data access
- Prometheus for the metrics exposition format
- Grafana for powerful data visualization

## Support

For issues, questions, or contributions, please open an issue on GitHub.

## Disclaimer

This app is for personal health data visualization and monitoring. It is not intended for medical diagnosis or treatment. Always consult healthcare professionals for medical advice.
