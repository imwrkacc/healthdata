#!/usr/bin/env python3
"""
Apple Health XML to Prometheus Exporter

This script parses Apple Health export.xml and exposes metrics in Prometheus format.
No iOS app or macOS required - just export your data from the Health app!

Usage:
    1. On iPhone: Health app → Profile (top right) → Export All Health Data
    2. Extract the zip file and get export.xml
    3. Run this script: python3 health_exporter.py --file /path/to/export.xml
    4. Access metrics at http://localhost:9090/metrics
"""

import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
from collections import defaultdict
from http.server import HTTPServer, BaseHTTPRequestHandler
import argparse
import gzip
import io
import os
from typing import Dict, List, Tuple

class HealthMetrics:
    """Store and calculate health metrics from Apple Health data"""

    def __init__(self):
        self.records = []
        self.workouts = []

    def parse_export_file(self, filepath: str):
        """Parse Apple Health export.xml file"""
        print(f"Parsing {filepath}...")

        # Handle both .xml and .xml in zip
        if filepath.endswith('.zip'):
            import zipfile
            with zipfile.ZipFile(filepath, 'r') as zip_ref:
                with zip_ref.open('apple_health_export/export.xml') as xml_file:
                    tree = ET.parse(xml_file)
        else:
            tree = ET.parse(filepath)

        root = tree.getroot()

        # Parse all records
        for record in root.findall('Record'):
            self.records.append({
                'type': record.get('type'),
                'value': record.get('value'),
                'unit': record.get('unit'),
                'startDate': record.get('startDate'),
                'endDate': record.get('endDate'),
                'creationDate': record.get('creationDate'),
            })

        # Parse workouts
        for workout in root.findall('Workout'):
            self.workouts.append({
                'type': workout.get('workoutActivityType'),
                'duration': workout.get('duration'),
                'startDate': workout.get('startDate'),
                'endDate': workout.get('endDate'),
            })

        print(f"Parsed {len(self.records)} health records and {len(self.workouts)} workouts")

    def get_metrics_for_period(self, days: int = 1) -> Dict:
        """Get aggregated metrics for the last N days"""
        cutoff_date = datetime.now() - timedelta(days=days)
        metrics = defaultdict(list)

        for record in self.records:
            try:
                record_date = datetime.fromisoformat(record['startDate'].replace('Z', '+00:00'))
                if record_date < cutoff_date:
                    continue

                record_type = record['type'].replace('HKQuantityTypeIdentifier', '')
                value = float(record['value']) if record['value'] else 0

                metrics[record_type].append(value)
            except (ValueError, TypeError):
                continue

        return metrics

    def generate_prometheus_metrics(self) -> str:
        """Generate Prometheus metrics from health data"""
        output = []
        output.append("# Apple Health Metrics Exporter")
        output.append("# Data exported from Apple Health app\n")

        # Get metrics for today and last 7 days
        today_metrics = self.get_metrics_for_period(days=1)
        weekly_metrics = self.get_metrics_for_period(days=7)

        # Steps
        if 'StepCount' in today_metrics:
            steps_today = sum(today_metrics['StepCount'])
            steps_weekly = sum(weekly_metrics['StepCount'])
            output.append("# HELP healthkit_steps_total Total number of steps")
            output.append("# TYPE healthkit_steps_total counter")
            output.append(f'healthkit_steps_total{{period="today"}} {int(steps_today)}')
            output.append(f'healthkit_steps_total{{period="weekly"}} {int(steps_weekly)}\n')

        # Distance
        if 'DistanceWalkingRunning' in today_metrics:
            distance_today = sum(today_metrics['DistanceWalkingRunning'])
            distance_weekly = sum(weekly_metrics['DistanceWalkingRunning'])
            output.append("# HELP healthkit_distance_meters Distance walked/run in meters")
            output.append("# TYPE healthkit_distance_meters counter")
            output.append(f'healthkit_distance_meters{{period="today"}} {distance_today:.2f}')
            output.append(f'healthkit_distance_meters{{period="weekly"}} {distance_weekly:.2f}\n')

        # Flights Climbed
        if 'FlightsClimbed' in today_metrics:
            flights = sum(today_metrics['FlightsClimbed'])
            output.append("# HELP healthkit_flights_climbed_total Flights of stairs climbed")
            output.append("# TYPE healthkit_flights_climbed_total counter")
            output.append(f'healthkit_flights_climbed_total{{period="today"}} {int(flights)}\n')

        # Active Energy
        if 'ActiveEnergyBurned' in today_metrics:
            energy = sum(today_metrics['ActiveEnergyBurned'])
            output.append("# HELP healthkit_active_energy_kcal Active energy burned")
            output.append("# TYPE healthkit_active_energy_kcal counter")
            output.append(f'healthkit_active_energy_kcal{{period="today"}} {energy:.2f}\n')

        # Heart Rate
        if 'HeartRate' in today_metrics:
            hr_values = today_metrics['HeartRate']
            if hr_values:
                output.append("# HELP healthkit_heart_rate_bpm Heart rate in beats per minute")
                output.append("# TYPE healthkit_heart_rate_bpm gauge")
                output.append(f'healthkit_heart_rate_bpm{{type="current"}} {hr_values[-1]:.0f}')
                output.append(f'healthkit_heart_rate_bpm{{type="average_today"}} {sum(hr_values)/len(hr_values):.0f}\n')

        # Resting Heart Rate
        if 'RestingHeartRate' in today_metrics:
            rhr = today_metrics['RestingHeartRate'][-1]
            output.append("# HELP healthkit_resting_heart_rate_bpm Resting heart rate")
            output.append("# TYPE healthkit_resting_heart_rate_bpm gauge")
            output.append(f'healthkit_resting_heart_rate_bpm {rhr:.0f}\n')

        # Heart Rate Variability
        if 'HeartRateVariabilitySDNN' in today_metrics:
            hrv = today_metrics['HeartRateVariabilitySDNN'][-1]
            output.append("# HELP healthkit_heart_rate_variability_ms Heart rate variability")
            output.append("# TYPE healthkit_heart_rate_variability_ms gauge")
            output.append(f'healthkit_heart_rate_variability_ms {hrv:.2f}\n')

        # Body Mass (Weight)
        if 'BodyMass' in weekly_metrics:
            weight = weekly_metrics['BodyMass'][-1]
            output.append("# HELP healthkit_weight_kg Body weight in kilograms")
            output.append("# TYPE healthkit_weight_kg gauge")
            output.append(f'healthkit_weight_kg {weight:.2f}\n')

        # BMI
        if 'BodyMassIndex' in weekly_metrics:
            bmi = weekly_metrics['BodyMassIndex'][-1]
            output.append("# HELP healthkit_body_mass_index Body Mass Index")
            output.append("# TYPE healthkit_body_mass_index gauge")
            output.append(f'healthkit_body_mass_index {bmi:.2f}\n')

        # Height
        if 'Height' in weekly_metrics:
            height = weekly_metrics['Height'][-1]
            output.append("# HELP healthkit_height_meters Height in meters")
            output.append("# TYPE healthkit_height_meters gauge")
            output.append(f'healthkit_height_meters {height:.2f}\n')

        # Sleep Analysis
        sleep_records = [r for r in self.records
                        if r['type'] == 'HKCategoryTypeIdentifierSleepAnalysis']
        if sleep_records:
            # Calculate last night's sleep (last 24 hours)
            cutoff = datetime.now() - timedelta(hours=24)
            recent_sleep = []
            for record in sleep_records:
                try:
                    start = datetime.fromisoformat(record['startDate'].replace('Z', '+00:00'))
                    end = datetime.fromisoformat(record['endDate'].replace('Z', '+00:00'))
                    if start > cutoff and record['value'] in ['HKCategoryValueSleepAnalysisAsleep', 'InBed']:
                        duration = (end - start).total_seconds() / 3600
                        recent_sleep.append(duration)
                except:
                    continue

            if recent_sleep:
                total_sleep = sum(recent_sleep)
                output.append("# HELP healthkit_sleep_hours Sleep duration in hours")
                output.append("# TYPE healthkit_sleep_hours gauge")
                output.append(f'healthkit_sleep_hours{{period="last_night"}} {total_sleep:.2f}\n')

        # Workouts
        cutoff = datetime.now() - timedelta(days=1)
        today_workouts = [w for w in self.workouts
                         if datetime.fromisoformat(w['startDate'].replace('Z', '+00:00')) > cutoff]
        output.append("# HELP healthkit_workouts_total Number of workouts")
        output.append("# TYPE healthkit_workouts_total counter")
        output.append(f'healthkit_workouts_total{{period="today"}} {len(today_workouts)}\n')

        # Blood Oxygen
        if 'OxygenSaturation' in today_metrics:
            o2 = today_metrics['OxygenSaturation'][-1] * 100  # Convert to percentage
            output.append("# HELP healthkit_oxygen_saturation_percent Blood oxygen saturation")
            output.append("# TYPE healthkit_oxygen_saturation_percent gauge")
            output.append(f'healthkit_oxygen_saturation_percent {o2:.1f}\n')

        # VO2 Max
        if 'VO2Max' in weekly_metrics:
            vo2 = weekly_metrics['VO2Max'][-1]
            output.append("# HELP healthkit_vo2_max VO2 Max cardio fitness")
            output.append("# TYPE healthkit_vo2_max gauge")
            output.append(f'healthkit_vo2_max {vo2:.2f}\n')

        return '\n'.join(output)


class PrometheusHandler(BaseHTTPRequestHandler):
    """HTTP request handler for Prometheus metrics"""

    health_metrics: HealthMetrics = None

    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain; version=0.0.4; charset=utf-8')
            self.end_headers()

            metrics = self.health_metrics.generate_prometheus_metrics()
            self.wfile.write(metrics.encode('utf-8'))

        elif self.path == '/health' or self.path == '/':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()

            response = '{"status": "healthy", "service": "Apple Health Exporter"}'
            self.wfile.write(response.encode('utf-8'))

        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not Found')

    def log_message(self, format, *args):
        # Custom logging
        print(f"[{self.address_string()}] {format % args}")


def main():
    parser = argparse.ArgumentParser(
        description='Apple Health XML to Prometheus Exporter'
    )
    parser.add_argument(
        '--file', '-f',
        required=True,
        help='Path to Apple Health export.xml or export.zip file'
    )
    parser.add_argument(
        '--port', '-p',
        type=int,
        default=9090,
        help='Port to run the Prometheus exporter (default: 9090)'
    )
    parser.add_argument(
        '--host',
        default='0.0.0.0',
        help='Host to bind to (default: 0.0.0.0)'
    )

    args = parser.parse_args()

    # Validate file exists
    if not os.path.exists(args.file):
        print(f"Error: File not found: {args.file}")
        return 1

    # Parse health data
    health_metrics = HealthMetrics()
    try:
        health_metrics.parse_export_file(args.file)
    except Exception as e:
        print(f"Error parsing health data: {e}")
        return 1

    # Set up HTTP server
    PrometheusHandler.health_metrics = health_metrics
    server = HTTPServer((args.host, args.port), PrometheusHandler)

    print(f"\n✅ Apple Health Prometheus Exporter running!")
    print(f"📊 Metrics endpoint: http://{args.host}:{args.port}/metrics")
    print(f"❤️  Health endpoint: http://{args.host}:{args.port}/health")
    print(f"\nParsed data from: {args.file}")
    print(f"Total records: {len(health_metrics.records)}")
    print(f"Total workouts: {len(health_metrics.workouts)}")
    print(f"\n🔄 Press Ctrl+C to stop\n")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n\n👋 Shutting down server...")
        server.shutdown()
        return 0


if __name__ == '__main__':
    exit(main())
