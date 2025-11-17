//
//  PrometheusServer.swift
//  HealthKitPrometheusExporter
//
//  HTTP server that exposes HealthKit metrics in Prometheus format
//

import Foundation
import Network
import Combine

class PrometheusServer: ObservableObject {
    @Published var isRunning = false
    @Published var port: UInt16 = 9090
    @Published var requestCount: Int = 0
    @Published var lastRequestTime: Date?

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var healthKitManager: HealthKitManager?

    func configure(healthKitManager: HealthKitManager) {
        self.healthKitManager = healthKitManager
    }

    func start() {
        guard !isRunning else { return }

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.acceptLocalOnly = true // Only allow connections from localhost

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))

            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isRunning = true
                        print("Prometheus server started on port \(self?.port ?? 0)")
                    case .failed(let error):
                        print("Server failed: \(error)")
                        self?.isRunning = false
                    case .cancelled:
                        self?.isRunning = false
                    default:
                        break
                    }
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: .global(qos: .userInitiated))
        } catch {
            print("Failed to start server: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        isRunning = false
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)

        connection.start(queue: .global(qos: .userInitiated))

        receiveRequest(on: connection)
    }

    private func receiveRequest(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                self.handleHTTPRequest(data: data, connection: connection)
            }

            if error != nil || isComplete {
                connection.cancel()
                self.connections.removeAll { $0 === connection }
            }
        }
    }

    private func handleHTTPRequest(data: Data, connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else {
            sendResponse("HTTP/1.1 400 Bad Request\r\n\r\n", to: connection)
            return
        }

        DispatchQueue.main.async {
            self.requestCount += 1
            self.lastRequestTime = Date()
        }

        // Parse the request path
        let lines = request.split(separator: "\r\n")
        guard let requestLine = lines.first else {
            sendResponse("HTTP/1.1 400 Bad Request\r\n\r\n", to: connection)
            return
        }

        let components = requestLine.split(separator: " ")
        guard components.count >= 2 else {
            sendResponse("HTTP/1.1 400 Bad Request\r\n\r\n", to: connection)
            return
        }

        let path = String(components[1])

        switch path {
        case "/metrics":
            handleMetricsRequest(connection: connection)
        case "/health", "/":
            handleHealthRequest(connection: connection)
        default:
            sendResponse("HTTP/1.1 404 Not Found\r\n\r\nNot Found", to: connection)
        }
    }

    private func handleMetricsRequest(connection: NWConnection) {
        guard let healthKitManager = healthKitManager else {
            sendResponse("HTTP/1.1 503 Service Unavailable\r\n\r\nHealthKit not configured", to: connection)
            return
        }

        let metrics = generatePrometheusMetrics(from: healthKitManager.latestMetrics)

        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/plain; version=0.0.4; charset=utf-8\r
        Content-Length: \(metrics.utf8.count)\r
        \r
        \(metrics)
        """

        sendResponse(response, to: connection)
    }

    private func handleHealthRequest(connection: NWConnection) {
        let health = """
        {
            "status": "healthy",
            "server": "HealthKit Prometheus Exporter",
            "uptime": "\(isRunning)"
        }
        """

        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: application/json\r
        Content-Length: \(health.utf8.count)\r
        \r
        \(health)
        """

        sendResponse(response, to: connection)
    }

    private func sendResponse(_ response: String, to connection: NWConnection) {
        let data = response.data(using: .utf8)!
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
            }
            connection.cancel()
        })
    }

    private func generatePrometheusMetrics(from metrics: HealthMetrics) -> String {
        var output = ""

        // Add metadata header
        output += "# HealthKit Prometheus Exporter\n"
        output += "# Metrics collected from Apple Health\n\n"

        // Activity & Fitness Metrics
        output += """
        # HELP healthkit_steps_total Total number of steps
        # TYPE healthkit_steps_total counter
        healthkit_steps_total{period="today"} \(Int(metrics.stepsToday))
        healthkit_steps_total{period="weekly"} \(Int(metrics.stepsWeekly))

        # HELP healthkit_distance_meters Total distance walked/run in meters
        # TYPE healthkit_distance_meters counter
        healthkit_distance_meters{period="today"} \(metrics.distanceToday)
        healthkit_distance_meters{period="weekly"} \(metrics.distanceWeekly)

        # HELP healthkit_flights_climbed_total Total number of flights of stairs climbed
        # TYPE healthkit_flights_climbed_total counter
        healthkit_flights_climbed_total{period="today"} \(Int(metrics.flightsClimbedToday))

        # HELP healthkit_active_energy_kcal Active energy burned in kilocalories
        # TYPE healthkit_active_energy_kcal counter
        healthkit_active_energy_kcal{period="today"} \(metrics.activeEnergyToday)

        # HELP healthkit_exercise_minutes Total exercise minutes
        # TYPE healthkit_exercise_minutes counter
        healthkit_exercise_minutes{period="today"} \(metrics.exerciseMinutesToday)

        """

        // Heart Metrics
        if metrics.heartRateCurrent > 0 {
            output += """
            # HELP healthkit_heart_rate_bpm Current heart rate in beats per minute
            # TYPE healthkit_heart_rate_bpm gauge
            healthkit_heart_rate_bpm{type="current"} \(metrics.heartRateCurrent)

            """
        }

        if metrics.heartRateAverage > 0 {
            output += """
            healthkit_heart_rate_bpm{type="average_today"} \(metrics.heartRateAverage)

            """
        }

        if metrics.restingHeartRate > 0 {
            output += """
            # HELP healthkit_resting_heart_rate_bpm Resting heart rate in beats per minute
            # TYPE healthkit_resting_heart_rate_bpm gauge
            healthkit_resting_heart_rate_bpm \(metrics.restingHeartRate)

            """
        }

        if metrics.heartRateVariability > 0 {
            output += """
            # HELP healthkit_heart_rate_variability_ms Heart rate variability in milliseconds
            # TYPE healthkit_heart_rate_variability_ms gauge
            healthkit_heart_rate_variability_ms \(metrics.heartRateVariability)

            """
        }

        // Body Measurements
        if metrics.weightKg > 0 {
            output += """
            # HELP healthkit_weight_kg Body weight in kilograms
            # TYPE healthkit_weight_kg gauge
            healthkit_weight_kg \(metrics.weightKg)

            """
        }

        if metrics.bodyMassIndex > 0 {
            output += """
            # HELP healthkit_body_mass_index Body Mass Index
            # TYPE healthkit_body_mass_index gauge
            healthkit_body_mass_index \(metrics.bodyMassIndex)

            """
        }

        if metrics.heightMeters > 0 {
            output += """
            # HELP healthkit_height_meters Height in meters
            # TYPE healthkit_height_meters gauge
            healthkit_height_meters \(metrics.heightMeters)

            """
        }

        // Sleep
        if metrics.sleepHoursLastNight > 0 {
            output += """
            # HELP healthkit_sleep_hours Sleep duration in hours
            # TYPE healthkit_sleep_hours gauge
            healthkit_sleep_hours{period="last_night"} \(metrics.sleepHoursLastNight)

            """
        }

        // Workouts
        output += """
        # HELP healthkit_workouts_total Number of workouts completed
        # TYPE healthkit_workouts_total counter
        healthkit_workouts_total{period="today"} \(Int(metrics.workoutsToday))

        """

        // Add timestamp
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        output += "# Generated at: \(timestamp)\n"

        return output
    }
}
