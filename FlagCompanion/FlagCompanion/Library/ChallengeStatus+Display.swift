import ChallengeLibrary
import SwiftUI

extension ChallengeStatus {
    var title: String {
        switch self {
        case .todo: "To Do"
        case .inProgress: "In Progress"
        case .solved: "Solved"
        case .abandoned: "Abandoned"
        }
    }

    var symbolName: String {
        switch self {
        case .todo: "circle"
        case .inProgress: "circle.lefthalf.filled"
        case .solved: "checkmark.circle.fill"
        case .abandoned: "xmark.circle"
        }
    }

    var tint: Color {
        switch self {
        case .todo: .secondary
        case .inProgress: .orange
        case .solved: .green
        case .abandoned: .gray
        }
    }
}
