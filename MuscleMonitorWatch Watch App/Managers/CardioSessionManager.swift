import Foundation
import HealthKit
import Combine

/// Gère la session HealthKit (fréquence cardiaque, calories, distance) sur la Watch.
@MainActor
final class CardioSessionManager: NSObject, ObservableObject {

    // MARK: - State publié
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var isStarting: Bool = false  // en attente d'auth HK
    @Published private(set) var heartRate: Double = 0
    @Published private(set) var activeCalories: Double = 0
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var activityType: CardioActivityType = .running

    var distanceKm: Double { distanceMeters / 1000 }

    var paceSecPerKm: Double {
        guard distanceKm > 0 else { return 0 }
        return Double(elapsedSeconds) / distanceKm
    }

    var paceFormatted: String {
        let s = paceSecPerKm
        guard s > 0 else { return "--:--" }
        return String(format: "%d:%02d /km", Int(s) / 60, Int(s) % 60)
    }

    var formattedElapsed: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Privé
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var liveBuilder: HKLiveWorkoutBuilder?
    private var elapsedTimer: AnyCancellable?
    private var sessionStartDate: Date?
    private var heartRateSamples: [CardioSessionResult.HeartRateSample] = []

    // Injecté depuis l'App entry point
    var gpsManager: GPSManager?

    // MARK: - Types HealthKit
    private static let shareTypes: Set<HKSampleType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceSwimming),
    ]
    private static let readTypes: Set<HKObjectType> = [
        HKObjectType.workoutType(),
        HKQuantityType(.heartRate),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceSwimming),
    ]

    // MARK: - Autorisation
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await healthStore.requestAuthorization(
            toShare: Self.shareTypes,
            read: Self.readTypes
        )
    }

    // MARK: - API publique
    func configure(activityType: CardioActivityType) {
        self.activityType = activityType
    }

    func start() {
        guard !isRunning, !isStarting else { return }
        isStarting = true
        Task { await startSession() }
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        workoutSession?.pause()
        isPaused = true
        elapsedTimer?.cancel()
        gpsManager?.pauseTracking()
    }

    func resume() {
        guard isRunning, isPaused else { return }
        workoutSession?.resume()
        isPaused = false
        startElapsedTimer()
        gpsManager?.resumeTracking()
    }

    func end() {
        guard isRunning else { return }
        workoutSession?.end()
        elapsedTimer?.cancel()
        isRunning = false
        isPaused  = false
    }

    // MARK: - Privé
    private func startSession() async {
        defer { isStarting = false }

        await requestAuthorization()

        let config = HKWorkoutConfiguration()
        config.activityType = activityType.hkWorkoutActivityType
        config.locationType  = activityType.locationType

        // Natation : propriétés obligatoires sous watchOS
        if activityType == .swimming {
            config.swimmingLocationType = .pool
            config.lapLength = HKQuantity(unit: .meter(), doubleValue: 25)
        }

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: config
            )
            session.delegate = self
            builder.delegate = self

            self.workoutSession   = session
            self.liveBuilder      = builder
            self.heartRateSamples = []
            self.elapsedSeconds   = 0

            let now = Date()
            self.sessionStartDate = now
            session.startActivity(with: now)
            try await builder.beginCollection(at: now)

            self.isRunning = true
            self.isPaused  = false
            startElapsedTimer()
            gpsManager?.startTracking(for: activityType)
        } catch {
            print("[CardioSessionManager] startSession error:", error)
        }
    }

    private func startElapsedTimer() {
        elapsedTimer?.cancel()
        elapsedTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.elapsedSeconds += 1 }
    }

    private func buildResult(endedAt: Date) -> CardioSessionResult {
        let route = gpsManager?.stopTracking() ?? []
        return CardioSessionResult(
            activityType: activityType,
            startedAt: sessionStartDate ?? endedAt.addingTimeInterval(-Double(elapsedSeconds)),
            endedAt: endedAt,
            distanceMeters: distanceMeters,
            activeCalories: activeCalories,
            heartRateSamples: heartRateSamples,
            routeCoordinates: route
        )
    }
}

// MARK: - HKWorkoutSessionDelegate
extension CardioSessionManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        guard toState == .ended else { return }
        Task { @MainActor in
            guard let builder = self.liveBuilder else { return }
            do {
                try await builder.endCollection(at: date)
                _ = try await builder.finishWorkout()
                let result = self.buildResult(endedAt: date)
                NotificationCenter.default.post(name: .cardioSessionDidEnd, object: result)
            } catch {
                print("[CardioSessionManager] end error:", error)
            }
        }
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("[CardioSessionManager] session error:", error)
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension CardioSessionManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let qt = type as? HKQuantityType,
                      let stats = workoutBuilder.statistics(for: qt) else { continue }

                switch qt {
                case HKQuantityType(.heartRate):
                    let bpm = stats.mostRecentQuantity()?.doubleValue(
                        for: HKUnit.count().unitDivided(by: .minute())) ?? 0
                    self.heartRate = bpm
                    if bpm > 0 {
                        self.heartRateSamples.append(.init(bpm: bpm, date: Date()))
                    }

                case HKQuantityType(.activeEnergyBurned):
                    self.activeCalories = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0

                case HKQuantityType(.distanceWalkingRunning),
                     HKQuantityType(.distanceCycling),
                     HKQuantityType(.distanceSwimming):
                    self.distanceMeters = stats.sumQuantity()?.doubleValue(for: .meter()) ?? 0

                default:
                    break
                }
            }
        }
    }
}
