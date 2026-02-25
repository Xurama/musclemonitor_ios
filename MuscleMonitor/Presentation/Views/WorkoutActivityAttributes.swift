import ActivityKit
import Foundation

public struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var title: String
        public var subtitle: String?
        public var currentExercise: String?
        public var setIndex: Int
        public var totalSets: Int
        public var restRemainingSec: Int?
        public var progress: Double // 0.0...1.0

        public init(title: String,
                    subtitle: String? = nil,
                    currentExercise: String? = nil,
                    setIndex: Int,
                    totalSets: Int,
                    restRemainingSec: Int? = nil,
                    progress: Double) {
            self.title = title
            self.subtitle = subtitle
            self.currentExercise = currentExercise
            self.setIndex = setIndex
            self.totalSets = totalSets
            self.restRemainingSec = restRemainingSec
            self.progress = progress
        }
    }

    public var workoutId: String
    public var displayTitle: String

    public init(workoutId: String, displayTitle: String) {
        self.workoutId = workoutId
        self.displayTitle = displayTitle
    }
}
