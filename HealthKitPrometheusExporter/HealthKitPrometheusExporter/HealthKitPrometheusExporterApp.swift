//
//  HealthKitPrometheusExporterApp.swift
//  HealthKitPrometheusExporter
//
//  Created for exporting HealthKit data to Prometheus
//

import SwiftUI

@main
struct HealthKitPrometheusExporterApp: App {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var prometheusServer = PrometheusServer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
                .environmentObject(prometheusServer)
        }
    }
}
