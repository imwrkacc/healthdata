# Quick Start Guide

Get your HealthKit metrics into Grafana in under 10 minutes!

## Prerequisites

- Mac with Xcode 15+
- iPhone 12 or later with iOS 16+
- USB cable to connect iPhone to Mac
- (Optional) Apple Watch SE 2 for additional metrics

## Step 1: Build the App (5 minutes)

1. **Open the project in Xcode:**
   ```bash
   cd healthdata
   open HealthKitPrometheusExporter/HealthKitPrometheusExporter.xcodeproj
   ```

2. **Connect your iPhone** via USB cable

3. **Select your iPhone** as the build target from the device dropdown

4. **Configure signing:**
   - Click on the project name in the left sidebar
   - Select "HealthKitPrometheusExporter" under TARGETS
   - Go to "Signing & Capabilities" tab
   - Select your Apple ID team from the "Team" dropdown

5. **Build and run** by pressing ⌘R (or click the Play button)

6. **Trust the developer** on your iPhone:
   - Settings → General → VPN & Device Management
   - Tap your Apple ID
   - Tap "Trust"

## Step 2: Configure the App (2 minutes)

1. **Open the app** on your iPhone

2. **Grant HealthKit permissions:**
   - Tap "Authorize HealthKit"
   - Tap "Turn On All" (or select specific categories)
   - Tap "Allow"

3. **Start the Prometheus server:**
   - Tap "Start Server"
   - You should see "Status: Running" in green

4. **Refresh metrics:**
   - Tap the refresh icon (↻) in the top right
   - View your health data in the app

## Step 3: Set Up Port Forwarding (1 minute)

To allow Prometheus (running on your Mac) to scrape metrics from your iPhone:

```bash
# Install usbmuxd (if not already installed)
brew install usbmuxd

# Forward iPhone port 9090 to Mac localhost:9090
iproxy 9090:9090
```

Keep this terminal window open while using the exporter.

**Test the connection:**
```bash
# In a new terminal window
curl http://localhost:9090/metrics
```

You should see your health metrics in Prometheus format!

## Step 4: Configure Prometheus (1 minute)

Add this to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'healthkit'
    scrape_interval: 60s  # Scrape every minute
    static_configs:
      - targets: ['localhost:9090']
        labels:
          device: 'iphone'
          source: 'healthkit'
          user: 'your_name'  # Optional: identify yourself
```

Restart Prometheus:
```bash
# If using Docker
docker restart prometheus

# If running directly
killall prometheus
prometheus --config.file=prometheus.yml
```

## Step 5: Create Grafana Dashboard (1 minute)

1. **Open Grafana** (default: http://localhost:3000)

2. **Create a new dashboard:**
   - Click "+" → "Dashboard"
   - Click "Add new panel"

3. **Add your first panel (Steps):**
   - In the query editor, enter:
     ```promql
     healthkit_steps_total{period="today"}
     ```
   - Change visualization to "Stat"
   - Set title to "Steps Today"
   - Click "Apply"

4. **Add more panels:**

   **Heart Rate:**
   ```promql
   healthkit_heart_rate_bpm{type="current"}
   ```

   **Sleep:**
   ```promql
   healthkit_sleep_hours{period="last_night"}
   ```

   **Weekly Steps Graph:**
   ```promql
   healthkit_steps_total{period="today"}
   ```
   (Change visualization to "Time series")

5. **Save the dashboard**

## Common Issues

### "Device not found" when building
- Ensure iPhone is unlocked and connected
- Trust the computer on iPhone when prompted
- Try unplugging and reconnecting

### Can't authorize HealthKit
- Check that HealthKit is available (Settings → Health)
- Ensure the app has the correct entitlements
- Try restarting the app

### Prometheus can't scrape metrics
1. Verify iproxy is running: `ps aux | grep iproxy`
2. Test locally on Mac: `curl http://localhost:9090/metrics`
3. Ensure the app shows "Status: Running"
4. Check iPhone isn't asleep (keep app in foreground)

### No data in metrics
- Ensure you've used your iPhone/Watch to generate health data
- Tap the refresh button in the app
- Some metrics (like HRV) require an Apple Watch
- Body measurements need manual entry in Health app

## Next Steps

- **Keep app running**: The app needs to be in foreground/background to serve metrics
- **Automate data collection**: Set up a cron job to scrape metrics periodically
- **Create more dashboards**: Explore all available metrics
- **Share your setup**: Export your Grafana dashboard JSON for others

## Tips for Best Results

1. **Consistent data collection**: Run the exporter at the same time each day
2. **Apple Watch syncing**: Open the Health app to trigger Watch sync
3. **Battery optimization**: The HTTP server uses minimal battery
4. **Data freshness**: Health data updates throughout the day as you move
5. **Historical data**: Grafana can show trends over weeks/months

## Example Grafana Queries

**Average daily steps (last 7 days):**
```promql
avg_over_time(healthkit_steps_total{period="today"}[7d])
```

**Heart rate range:**
```promql
max(healthkit_heart_rate_bpm) - min(healthkit_heart_rate_bpm)
```

**Total weekly distance in km:**
```promql
healthkit_distance_meters{period="weekly"} / 1000
```

**Sleep goal achievement (assuming 8h goal):**
```promql
(healthkit_sleep_hours{period="last_night"} / 8) * 100
```

## Support

Need help? Check the main [README.md](README.md) for detailed documentation or open an issue on GitHub.

Happy monitoring! 📊💪❤️
