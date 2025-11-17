//
//  HealthKitManager.swift
//  HealthKitPrometheusExporter
//
//  Manages HealthKit data access and querying
//

import Foundation
import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var latestMetrics: HealthMetrics = HealthMetrics()
    @Published var errorMessage: String?

    // All health data types we want to read
    private let healthDataTypes: Set<HKSampleType> = {
        var types = Set<HKSampleType>()

        // Activity & Fitness
        if let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepCount)
        }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            types.insert(distance)
        }
        if let cyclingDistance = HKObjectType.quantityType(forIdentifier: .distanceCycling) {
            types.insert(cyclingDistance)
        }
        if let flightsClimbed = HKObjectType.quantityType(forIdentifier: .flightsClimbed) {
            types.insert(flightsClimbed)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }
        if let basalEnergy = HKObjectType.quantityType(forIdentifier: .basalEnergyBurned) {
            types.insert(basalEnergy)
        }
        if let exerciseTime = HKObjectType.quantityType(forIdentifier: .appleExerciseTime) {
            types.insert(exerciseTime)
        }
        if let standTime = HKObjectType.quantityType(forIdentifier: .appleStandTime) {
            types.insert(standTime)
        }

        // Heart
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRate)
        }
        if let restingHeartRate = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHeartRate)
        }
        if let heartRateVariability = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(heartRateVariability)
        }
        if let vo2Max = HKObjectType.quantityType(forIdentifier: .vo2Max) {
            types.insert(vo2Max)
        }

        // Body Measurements
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMass)
        }
        if let bodyMassIndex = HKObjectType.quantityType(forIdentifier: .bodyMassIndex) {
            types.insert(bodyMassIndex)
        }
        if let bodyFatPercentage = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.insert(bodyFatPercentage)
        }
        if let leanBodyMass = HKObjectType.quantityType(forIdentifier: .leanBodyMass) {
            types.insert(leanBodyMass)
        }
        if let height = HKObjectType.quantityType(forIdentifier: .height) {
            types.insert(height)
        }

        // Sleep
        if let sleepAnalysis = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepAnalysis)
        }

        // Nutrition
        if let dietaryWater = HKObjectType.quantityType(forIdentifier: .dietaryWater) {
            types.insert(dietaryWater)
        }
        if let dietaryCalories = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            types.insert(dietaryCalories)
        }

        // Respiratory
        if let respiratoryRate = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            types.insert(respiratoryRate)
        }
        if let oxygenSaturation = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
            types.insert(oxygenSaturation)
        }

        // Vitals
        if let bloodPressureSystolic = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic) {
            types.insert(bloodPressureSystolic)
        }
        if let bloodPressureDiastolic = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) {
            types.insert(bloodPressureDiastolic)
        }
        if let bodyTemperature = HKObjectType.quantityType(forIdentifier: .bodyTemperature) {
            types.insert(bodyTemperature)
        }

        // Workouts
        types.insert(HKObjectType.workoutType())

        return types
    }()

    init() {
        checkHealthKitAvailability()
    }

    private func checkHealthKitAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device"
            return
        }
    }

    func requestAuthorization() async {
        do {
            try await healthStore.requestAuthorization(toShare: [], read: healthDataTypes)
            await MainActor.run {
                self.isAuthorized = true
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to request authorization: \(error.localizedDescription)"
            }
        }
    }

    func fetchAllMetrics() async {
        guard isAuthorized else {
            await requestAuthorization()
            return
        }

        let metrics = HealthMetrics()

        // Fetch all metrics concurrently
        await withTaskGroup(of: Void.self) { group in
            // Activity metrics
            group.addTask { await self.fetchSteps(metrics: metrics) }
            group.addTask { await self.fetchDistance(metrics: metrics) }
            group.addTask { await self.fetchFlightsClimbed(metrics: metrics) }
            group.addTask { await self.fetchActiveEnergy(metrics: metrics) }
            group.addTask { await self.fetchExerciseTime(metrics: metrics) }

            // Heart metrics
            group.addTask { await self.fetchHeartRate(metrics: metrics) }
            group.addTask { await self.fetchRestingHeartRate(metrics: metrics) }
            group.addTask { await self.fetchHeartRateVariability(metrics: metrics) }

            // Body measurements
            group.addTask { await self.fetchWeight(metrics: metrics) }
            group.addTask { await self.fetchBodyMassIndex(metrics: metrics) }
            group.addTask { await self.fetchHeight(metrics: metrics) }

            // Sleep
            group.addTask { await self.fetchSleep(metrics: metrics) }

            // Workouts
            group.addTask { await self.fetchWorkouts(metrics: metrics) }

            await group.waitForAll()
        }

        await MainActor.run {
            self.latestMetrics = metrics
        }
    }

    // MARK: - Activity Metrics

    private func fetchSteps(metrics: HealthMetrics) async {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let todaySteps = await fetchTodaySum(for: stepType, unit: .count())
        let weeklySteps = await fetchWeeklySum(for: stepType, unit: .count())

        await MainActor.run {
            metrics.stepsToday = todaySteps
            metrics.stepsWeekly = weeklySteps
        }
    }

    private func fetchDistance(metrics: HealthMetrics) async {
        guard let distanceType = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return }

        let todayDistance = await fetchTodaySum(for: distanceType, unit: .meter())
        let weeklyDistance = await fetchWeeklySum(for: distanceType, unit: .meter())

        await MainActor.run {
            metrics.distanceToday = todayDistance
            metrics.distanceWeekly = weeklyDistance
        }
    }

    private func fetchFlightsClimbed(metrics: HealthMetrics) async {
        guard let flightsType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else { return }

        let todayFlights = await fetchTodaySum(for: flightsType, unit: .count())

        await MainActor.run {
            metrics.flightsClimbedToday = todayFlights
        }
    }

    private func fetchActiveEnergy(metrics: HealthMetrics) async {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        let todayEnergy = await fetchTodaySum(for: energyType, unit: .kilocalorie())

        await MainActor.run {
            metrics.activeEnergyToday = todayEnergy
        }
    }

    private func fetchExerciseTime(metrics: HealthMetrics) async {
        guard let exerciseType = HKQuantityType.quantityType(forIdentifier: .appleExerciseTime) else { return }

        let todayExercise = await fetchTodaySum(for: exerciseType, unit: .minute())

        await MainActor.run {
            metrics.exerciseMinutesToday = todayExercise
        }
    }

    // MARK: - Heart Metrics

    private func fetchHeartRate(metrics: HealthMetrics) async {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let latest = await fetchLatestSample(for: heartRateType, unit: .count().unitDivided(by: .minute()))
        let avg = await fetchTodayAverage(for: heartRateType, unit: .count().unitDivided(by: .minute()))

        await MainActor.run {
            metrics.heartRateCurrent = latest
            metrics.heartRateAverage = avg
        }
    }

    private func fetchRestingHeartRate(metrics: HealthMetrics) async {
        guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }

        let latest = await fetchLatestSample(for: restingHRType, unit: .count().unitDivided(by: .minute()))

        await MainActor.run {
            metrics.restingHeartRate = latest
        }
    }

    private func fetchHeartRateVariability(metrics: HealthMetrics) async {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }

        let latest = await fetchLatestSample(for: hrvType, unit: .secondUnit(with: .milli))

        await MainActor.run {
            metrics.heartRateVariability = latest
        }
    }

    // MARK: - Body Measurements

    private func fetchWeight(metrics: HealthMetrics) async {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return }

        let latest = await fetchLatestSample(for: weightType, unit: .gramUnit(with: .kilo))

        await MainActor.run {
            metrics.weightKg = latest
        }
    }

    private func fetchBodyMassIndex(metrics: HealthMetrics) async {
        guard let bmiType = HKQuantityType.quantityType(forIdentifier: .bodyMassIndex) else { return }

        let latest = await fetchLatestSample(for: bmiType, unit: .count())

        await MainActor.run {
            metrics.bodyMassIndex = latest
        }
    }

    private func fetchHeight(metrics: HealthMetrics) async {
        guard let heightType = HKQuantityType.quantityType(forIdentifier: .height) else { return }

        let latest = await fetchLatestSample(for: heightType, unit: .meter())

        await MainActor.run {
            metrics.heightMeters = latest
        }
    }

    // MARK: - Sleep

    private func fetchSleep(metrics: HealthMetrics) async {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        // Get sleep from last night (previous day's sleep data)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!

        let predicate = HKQuery.predicateForSamples(withStart: startOfYesterday, end: now, options: .strictStartDate)

        let sleepDuration = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard let samples = samples as? [HKCategorySample], error == nil else {
                    continuation.resume(returning: 0.0)
                    return
                }

                var totalSleepTime: TimeInterval = 0

                for sample in samples {
                    // Only count actual sleep (asleep, core, deep, REM)
                    if sample.value == HKCategoryValueSleepAnalysis.asleep.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
                       sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                        totalSleepTime += sample.endDate.timeIntervalSince(sample.startDate)
                    }
                }

                continuation.resume(returning: totalSleepTime / 3600.0) // Convert to hours
            }

            healthStore.execute(query)
        }

        await MainActor.run {
            metrics.sleepHoursLastNight = sleepDuration
        }
    }

    // MARK: - Workouts

    private func fetchWorkouts(metrics: HealthMetrics) async {
        let workoutType = HKObjectType.workoutType()

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(withStart: startOfToday, end: now, options: .strictStartDate)

        let count = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                guard let samples = samples, error == nil else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: samples.count)
            }

            healthStore.execute(query)
        }

        await MainActor.run {
            metrics.workoutsToday = Double(count)
        }
    }

    // MARK: - Helper Methods

    private func fetchTodaySum(for quantityType: HKQuantityType, unit: HKUnit) async -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                guard let statistics = statistics, let sum = statistics.sumQuantity(), error == nil else {
                    continuation.resume(returning: 0.0)
                    return
                }
                continuation.resume(returning: sum.doubleValue(for: unit))
            }

            healthStore.execute(query)
        }
    }

    private func fetchWeeklySum(for quantityType: HKQuantityType, unit: HKUnit) async -> Double {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!

        let predicate = HKQuery.predicateForSamples(withStart: weekAgo, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                guard let statistics = statistics, let sum = statistics.sumQuantity(), error == nil else {
                    continuation.resume(returning: 0.0)
                    return
                }
                continuation.resume(returning: sum.doubleValue(for: unit))
            }

            healthStore.execute(query)
        }
    }

    private func fetchTodayAverage(for quantityType: HKQuantityType, unit: HKUnit) async -> Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: quantityType, quantitySamplePredicate: predicate, options: .discreteAverage) { _, statistics, error in
                guard let statistics = statistics, let avg = statistics.averageQuantity(), error == nil else {
                    continuation.resume(returning: 0.0)
                    return
                }
                continuation.resume(returning: avg.doubleValue(for: unit))
            }

            healthStore.execute(query)
        }
    }

    private func fetchLatestSample(for quantityType: HKQuantityType, unit: HKUnit) async -> Double {
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                guard let samples = samples as? [HKQuantitySample], let sample = samples.first, error == nil else {
                    continuation.resume(returning: 0.0)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }

            healthStore.execute(query)
        }
    }
}

// MARK: - Health Metrics Model

class HealthMetrics: ObservableObject {
    @Published var stepsToday: Double = 0
    @Published var stepsWeekly: Double = 0
    @Published var distanceToday: Double = 0
    @Published var distanceWeekly: Double = 0
    @Published var flightsClimbedToday: Double = 0
    @Published var activeEnergyToday: Double = 0
    @Published var exerciseMinutesToday: Double = 0

    @Published var heartRateCurrent: Double = 0
    @Published var heartRateAverage: Double = 0
    @Published var restingHeartRate: Double = 0
    @Published var heartRateVariability: Double = 0

    @Published var weightKg: Double = 0
    @Published var bodyMassIndex: Double = 0
    @Published var heightMeters: Double = 0

    @Published var sleepHoursLastNight: Double = 0

    @Published var workoutsToday: Double = 0
}
