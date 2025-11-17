//
//  ContentView.swift
//  HealthKitPrometheusExporter
//
//  Main UI for the app
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var prometheusServer: PrometheusServer
    @State private var isLoading = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Server Status
                    serverStatusCard

                    // Authorization Status
                    if !healthKitManager.isAuthorized {
                        authorizationCard
                    }

                    // Metrics Cards
                    if healthKitManager.isAuthorized {
                        activityMetricsCard
                        heartMetricsCard
                        bodyMetricsCard
                        sleepMetricsCard
                    }

                    // Error Message
                    if let error = healthKitManager.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            .navigationTitle("HealthKit Exporter")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshMetrics) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .onAppear {
            prometheusServer.configure(healthKitManager: healthKitManager)
            if healthKitManager.isAuthorized {
                refreshMetrics()
            }
        }
    }

    // MARK: - Server Status Card

    private var serverStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: prometheusServer.isRunning ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                    .foregroundColor(prometheusServer.isRunning ? .green : .gray)
                Text("Prometheus Server")
                    .font(.headline)
            }

            Divider()

            HStack {
                Text("Status:")
                Spacer()
                Text(prometheusServer.isRunning ? "Running" : "Stopped")
                    .foregroundColor(prometheusServer.isRunning ? .green : .red)
            }

            HStack {
                Text("Port:")
                Spacer()
                Text("\(prometheusServer.port)")
                    .monospaced()
            }

            if prometheusServer.isRunning {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Endpoint:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("http://localhost:\(prometheusServer.port)/metrics")
                        .font(.caption)
                        .monospaced()
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }
            }

            HStack {
                Text("Requests:")
                Spacer()
                Text("\(prometheusServer.requestCount)")
            }

            if let lastRequest = prometheusServer.lastRequestTime {
                HStack {
                    Text("Last Request:")
                    Spacer()
                    Text(lastRequest, style: .relative)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: toggleServer) {
                HStack {
                    Image(systemName: prometheusServer.isRunning ? "stop.fill" : "play.fill")
                    Text(prometheusServer.isRunning ? "Stop Server" : "Start Server")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(prometheusServer.isRunning ? .red : .green)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Authorization Card

    private var authorizationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square")
                    .foregroundColor(.red)
                Text("HealthKit Authorization")
                    .font(.headline)
            }

            Text("This app needs access to your HealthKit data to export metrics.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button(action: requestAuthorization) {
                Text("Authorize HealthKit")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Activity Metrics Card

    private var activityMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundColor(.blue)
                Text("Activity")
                    .font(.headline)
            }

            Divider()

            MetricRow(label: "Steps Today", value: String(Int(healthKitManager.latestMetrics.stepsToday)), unit: "steps")
            MetricRow(label: "Steps Weekly", value: String(Int(healthKitManager.latestMetrics.stepsWeekly)), unit: "steps")
            MetricRow(label: "Distance Today", value: String(format: "%.2f", healthKitManager.latestMetrics.distanceToday / 1000), unit: "km")
            MetricRow(label: "Flights Climbed", value: String(Int(healthKitManager.latestMetrics.flightsClimbedToday)), unit: "floors")
            MetricRow(label: "Active Energy", value: String(Int(healthKitManager.latestMetrics.activeEnergyToday)), unit: "kcal")
            MetricRow(label: "Exercise Time", value: String(Int(healthKitManager.latestMetrics.exerciseMinutesToday)), unit: "min")
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Heart Metrics Card

    private var heartMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("Heart")
                    .font(.headline)
            }

            Divider()

            if healthKitManager.latestMetrics.heartRateCurrent > 0 {
                MetricRow(label: "Current HR", value: String(Int(healthKitManager.latestMetrics.heartRateCurrent)), unit: "bpm")
            }
            if healthKitManager.latestMetrics.heartRateAverage > 0 {
                MetricRow(label: "Average HR Today", value: String(Int(healthKitManager.latestMetrics.heartRateAverage)), unit: "bpm")
            }
            if healthKitManager.latestMetrics.restingHeartRate > 0 {
                MetricRow(label: "Resting HR", value: String(Int(healthKitManager.latestMetrics.restingHeartRate)), unit: "bpm")
            }
            if healthKitManager.latestMetrics.heartRateVariability > 0 {
                MetricRow(label: "HRV", value: String(Int(healthKitManager.latestMetrics.heartRateVariability)), unit: "ms")
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Body Metrics Card

    private var bodyMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.arms.open")
                    .foregroundColor(.orange)
                Text("Body")
                    .font(.headline)
            }

            Divider()

            if healthKitManager.latestMetrics.weightKg > 0 {
                MetricRow(label: "Weight", value: String(format: "%.1f", healthKitManager.latestMetrics.weightKg), unit: "kg")
            }
            if healthKitManager.latestMetrics.bodyMassIndex > 0 {
                MetricRow(label: "BMI", value: String(format: "%.1f", healthKitManager.latestMetrics.bodyMassIndex), unit: "")
            }
            if healthKitManager.latestMetrics.heightMeters > 0 {
                MetricRow(label: "Height", value: String(format: "%.2f", healthKitManager.latestMetrics.heightMeters), unit: "m")
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Sleep Metrics Card

    private var sleepMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .foregroundColor(.purple)
                Text("Sleep")
                    .font(.headline)
            }

            Divider()

            if healthKitManager.latestMetrics.sleepHoursLastNight > 0 {
                MetricRow(label: "Last Night", value: String(format: "%.1f", healthKitManager.latestMetrics.sleepHoursLastNight), unit: "hours")
            } else {
                Text("No sleep data available")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }

            if healthKitManager.latestMetrics.workoutsToday > 0 {
                MetricRow(label: "Workouts Today", value: String(Int(healthKitManager.latestMetrics.workoutsToday)), unit: "")
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Actions

    private func requestAuthorization() {
        Task {
            await healthKitManager.requestAuthorization()
            if healthKitManager.isAuthorized {
                await healthKitManager.fetchAllMetrics()
            }
        }
    }

    private func refreshMetrics() {
        isLoading = true
        Task {
            await healthKitManager.fetchAllMetrics()
            isLoading = false
        }
    }

    private func toggleServer() {
        if prometheusServer.isRunning {
            prometheusServer.stop()
        } else {
            prometheusServer.start()
        }
    }
}

// MARK: - Metric Row Component

struct MetricRow: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 4) {
                Text(value)
                    .fontWeight(.semibold)
                if !unit.isEmpty {
                    Text(unit)
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitManager())
        .environmentObject(PrometheusServer())
}
