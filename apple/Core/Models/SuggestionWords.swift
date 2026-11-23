import Foundation

/// The words for each suggestion rule (D7). Human-written, shown with the reason
/// the event was picked; Ben approves the wording (AGENTS.md: no AI-written copy).
/// The question fits the purchase (its moment, named by the database from the
/// merchant category) before it falls back to the rule's own question (Ben,
/// 2026-11-23: State Farm Insurance asked "What was the day about?").
/// The same words are in js/app.js (MOMENTS, PROMPTS).
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
    static func prompt(_ kind: String, moment: String? = nil) -> String? {
        switch moment {
        case "meal": return "What was the occasion?"
        case "groceries": return "What were you making?"
        case "trip": return "Where were you headed?"
        case "ride": return "Where were you going?"
        case "fuel": return "Where was the drive taking you?"
        case "car": return "What did the car need?"
        case "outing": return "What did you see?"
        case "find": return "What did you find?"
        case "care", "gift": return "Who was it for?"
        case "giving": return "What moved you to give?"
        case "shop": return "What did you bring home?"
        default: break
        }
        switch kind {
        case "first_visit": return "What brought you here?"
        case "biggest_month": return "What was it for?"
        case "busy_day": return "What was the day about?"
        default: return nil
        }
    }
}
