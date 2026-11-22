import Foundation

/// The words for each suggestion rule (D7). Human-written, shown with the reason
/// the event was picked; Ben approves the wording (AGENTS.md: no AI-written copy).
enum SuggestionWords {
    static func reason(_ kind: String) -> String {
        switch kind {
        case "first_visit": "First time here"
        case "biggest_month": "Biggest this month"
        case "busy_day": "Your busiest day this month"
        case "year_ago": "A year ago you wrote"
        default: ""
        }
    }
    static func prompt(_ kind: String) -> String? {
        switch kind {
        case "first_visit": "What brought you here?"
        case "biggest_month": "What was it for?"
        case "busy_day": "What was the day about?"
        default: nil
        }
    }
}
