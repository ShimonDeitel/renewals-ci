import SwiftData
import Foundation

enum BillingCycle: String, Codable, CaseIterable {
    case weekly, monthly, yearly

    var days: Int {
        switch self {
        case .weekly: return 7
        case .monthly: return 30
        case .yearly: return 365
        }
    }

    var label: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

@Model
final class Subscription {
    var name: String
    var amount: Double
    var cycleRaw: String
    var nextRenewal: Date
    var notes: String

    init(name: String, amount: Double, cycle: BillingCycle, nextRenewal: Date) {
        self.name = name
        self.amount = amount
        self.cycleRaw = cycle.rawValue
        self.nextRenewal = nextRenewal
        self.notes = ""
    }

    var cycle: BillingCycle {
        get { BillingCycle(rawValue: cycleRaw) ?? .monthly }
        set { cycleRaw = newValue.rawValue }
    }

    var monthlyEquivalent: Double {
        switch cycle {
        case .weekly: return amount * 4.33
        case .monthly: return amount
        case .yearly: return amount / 12
        }
    }

    func advanceIfPast() {
        let cal = Calendar.current
        while nextRenewal < Date() {
            nextRenewal = cal.date(byAdding: .day, value: cycle.days, to: nextRenewal) ?? nextRenewal
        }
    }
}
