# Apple Health Exporter (No macOS Required!)

Export your Apple Health data to Prometheus without building an iOS app or needing macOS.

## How It Works

1. **Export your health data** from iPhone (built-in feature)
2. **Run a Python script** on any computer (Linux/Windows/Mac)
3. **Scrape with Prometheus** and visualize in Grafana

No Xcode, no macOS, no iOS app development needed!

## Quick Start (5 minutes)

### Step 1: Export Health Data from iPhone (2 minutes)

1. Open **Health app** on your iPhone
2. Tap your **Profile picture** (top right)
3. Scroll down and tap **Export All Health Data**
4. Tap **Export**
5. Wait for the export to complete (may take a minute)
6. **Share the zip file** to your computer via:
   - AirDrop (if you have a Mac)
   - Email to yourself
   - iCloud Drive / Dropbox / Google Drive
   - USB cable (use Files app → share to computer)

### Step 2: Set Up the Exporter (3 minutes)

```bash
# Navigate to the project
cd healthdata

# Make sure you have Python 3.6+ installed
python3 --version

# No dependencies needed! The script uses only Python stdlib

# Run the exporter (update path to your export file)
python3 health_exporter.py --file ~/Downloads/export.zip

# Or if you extracted the zip:
python3 health_exporter.py --file ~/Downloads/apple_health_export/export.xml
```

You should see:
```
✅ Apple Health Prometheus Exporter running!
📊 Metrics endpoint: http://0.0.0.0:9090/metrics
❤️  Health endpoint: http://0.0.0.0:9090/health

Parsed data from: export.zip
Total records: 45821
Total workouts: 156

🔄 Press Ctrl+C to stop
```

### Step 3: Test It

```bash
# In another terminal
curl http://localhost:9090/metrics
```

You should see your health metrics in Prometheus format!

### Step 4: Configure Prometheus

Add to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'apple_health'
    scrape_interval: 5m  # Export data manually, so scrape infrequently
    static_configs:
      - targets: ['localhost:9090']
        labels:
          source: 'apple_health'
          device: 'iphone'
```

### Step 5: View in Grafana

Import the dashboard from `grafana/dashboards/healthkit-overview.json`

## Features

### Supported Metrics

The exporter parses and exposes:

- ✅ Steps (daily & weekly)
- ✅ Distance walked/run
- ✅ Flights climbed
- ✅ Active energy burned
- ✅ Heart rate (current & average)
- ✅ Resting heart rate
- ✅ Heart rate variability (HRV)
- ✅ Weight (body mass)
- ✅ BMI (Body Mass Index)
- ✅ Height
- ✅ Sleep hours
- ✅ Workouts count
- ✅ Blood oxygen saturation
- ✅ VO2 Max

### Advantages

✅ **No macOS needed** - Run on Linux, Windows, or Mac
✅ **No iOS app** - Use Apple Health's built-in export
✅ **No Apple Developer account** - No signing required
✅ **Simple Python script** - No dependencies, just stdlib
✅ **Standard Prometheus format** - Works with any monitoring stack
✅ **Privacy-focused** - All data stays on your computer

### Limitations

⚠️ **Manual updates** - You need to re-export from Health app to get new data
⚠️ **Not real-time** - Data is a snapshot from export time
⚠️ **Export frequency** - Apple limits how often you can export (practical: daily/weekly)

## Automated Updates (Optional)

### Option 1: Shortcuts Automation (iOS 14+)

You can create an iOS Shortcut to auto-export and upload:

1. **Shortcuts app** → Create new shortcut
2. Add action: **Export Health Data** (requires iOS 14+)
3. Add action: **Save to iCloud Drive** or **Upload to Server**
4. Set automation trigger (daily, weekly)

Note: This requires some manual setup but enables automated exports.

### Option 2: Schedule Manual Exports

Simply export your data periodically:
- **Daily**: For active tracking
- **Weekly**: For general monitoring
- **Monthly**: For long-term trends

Then run:
```bash
# Update with latest export
python3 health_exporter.py --file ~/Downloads/latest_export.zip
```

## Usage Options

### Run on specific port
```bash
python3 health_exporter.py --file export.zip --port 8080
```

### Run on specific host
```bash
python3 health_exporter.py --file export.zip --host 127.0.0.1
```

### Run in background
```bash
# Linux/Mac
nohup python3 health_exporter.py --file export.zip &

# Or use systemd (see below)
```

## Systemd Service (Linux)

Create `/etc/systemd/system/health-exporter.service`:

```ini
[Unit]
Description=Apple Health Prometheus Exporter
After=network.target

[Service]
Type=simple
User=youruser
WorkingDirectory=/home/youruser/healthdata
ExecStart=/usr/bin/python3 /home/youruser/healthdata/health_exporter.py --file /home/youruser/health-data/export.zip
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl enable health-exporter
sudo systemctl start health-exporter
sudo systemctl status health-exporter
```

## Docker Support

```bash
# Build image
docker build -t health-exporter .

# Run container
docker run -d \
  --name health-exporter \
  -p 9090:9090 \
  -v /path/to/export.zip:/data/export.zip:ro \
  health-exporter --file /data/export.zip
```

## Comparison: iOS App vs Python Exporter

| Feature | iOS App | Python Exporter |
|---------|---------|-----------------|
| Real-time data | ✅ Yes | ❌ Manual export |
| Requires macOS | ✅ Yes | ❌ No |
| Requires Xcode | ✅ Yes | ❌ No |
| Apple Developer | ✅ Yes | ❌ No |
| Setup complexity | Medium | Simple |
| Data freshness | Real-time | Manual updates |
| Platform support | iOS only | Any OS |
| Background operation | ✅ Yes | ✅ Yes |

## Tips for Best Results

1. **Regular exports**: Export data weekly for consistent tracking
2. **Automation**: Use iOS Shortcuts for semi-automated exports
3. **Cloud sync**: Upload exports to Dropbox/Drive for easy access
4. **Version control**: Keep old exports for historical data
5. **Backup strategy**: Health data is valuable - keep backups!

## Troubleshooting

### "File not found"
- Make sure the path to export.zip or export.xml is correct
- Use absolute paths: `/home/user/Downloads/export.zip`

### "No data in metrics"
- Verify the export.xml contains data (open in text editor)
- Check that your iPhone has health data in the Health app
- Re-export from Health app if export is corrupted

### "Address already in use"
- Change the port: `--port 8080`
- Or kill the process using port 9090

### Old data showing
- Export fresh data from Health app
- Point the script to the new export file
- Restart the exporter

## Security Notes

- The exporter binds to `0.0.0.0` by default (accessible from network)
- For localhost only: use `--host 127.0.0.1`
- Consider running behind a reverse proxy with authentication
- Your health data contains sensitive personal information

## Next Steps

1. **Automate exports**: Set up iOS Shortcuts
2. **Create dashboards**: Build custom Grafana visualizations
3. **Add alerting**: Set up Prometheus alerts for health goals
4. **Historical analysis**: Compare exports over time

## Support

This Python exporter provides a simple, cross-platform alternative to the native iOS app. Choose the approach that works best for your setup!

- **Need real-time data?** → Use the iOS app (requires macOS)
- **Want simplicity?** → Use this Python exporter
- **No Mac?** → This is your only option! 🎉
