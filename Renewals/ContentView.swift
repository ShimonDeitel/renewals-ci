import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Subscription.nextRenewal) private var subs: [Subscription]
    @StateObject private var store = StoreManager.shared
    @State private var showAdd = false
    @State private var showPaywall = false

    let freeLimit = 3

    var monthlyTotal: Double { subs.reduce(0) { $0 + $1.monthlyEquivalent } }
    var yearlyTotal: Double { monthlyTotal * 12 }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("$\(monthlyTotal, specifier: "%.2f")/mo").font(.title.bold())
                        Text("$\(yearlyTotal, specifier: "%.2f")/year across \(subs.count) subscriptions")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section("Renewing Soon") {
                    if subs.isEmpty {
                        ContentUnavailableView("No subscriptions yet", systemImage: "calendar.badge.clock")
                    }
                    ForEach(subs) { s in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(s.name).font(.headline)
                                Text("\(s.cycle.label) · \(s.nextRenewal.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("$\(s.amount, specifier: "%.2f")")
                        }
                    }
                    .onDelete { idx in
                        for i in idx { context.delete(subs[i]) }
                        try? context.save()
                    }
                }
            }
            .navigationTitle("Renewals")
            .toolbar {
                Button {
                    if !store.isPro && subs.count >= freeLimit {
                        showPaywall = true
                    } else {
                        showAdd = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showAdd) { AddSubView() }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onAppear {
                for s in subs { s.advanceIfPast() }
                try? context.save()
            }
        }
        .tint(.blue)
    }
}

struct AddSubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var amount = ""
    @State private var cycle: BillingCycle = .monthly
    @State private var nextRenewal = Date()

    var body: some View {
        NavigationStack {
            Form {
                TextField("Service name", text: $name)
                TextField("Amount ($)", text: $amount).keyboardType(.decimalPad)
                Picker("Billing cycle", selection: $cycle) {
                    ForEach(BillingCycle.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                DatePicker("Next renewal", selection: $nextRenewal, displayedComponents: .date)
            }
            .navigationTitle("Add Subscription")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !name.isEmpty, let amt = Double(amount) else { return }
                        let sub = Subscription(name: name, amount: amt, cycle: cycle, nextRenewal: nextRenewal)
                        context.insert(sub)
                        try? context.save()
                        scheduleReminder(sub)
                        dismiss()
                    }
                }
            }
        }
    }

    func scheduleReminder(_ sub: Subscription) {
        let content = UNMutableNotificationContent()
        content.title = "\(sub.name) renews tomorrow"
        content.body = "$\(String(format: "%.2f", sub.amount)) will be charged."
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour],
                from: Calendar.current.date(byAdding: .day, value: -1, to: sub.nextRenewal) ?? sub.nextRenewal),
            repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = StoreManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill").font(.system(size: 56)).foregroundStyle(.blue)
            Text("Renewals Pro").font(.largeTitle.bold())
            Text("Track unlimited subscriptions + renewal alerts.\n$4.99/month")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Subscribe") {
                Task { await store.purchase(); if store.isPro { dismiss() } }
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            Button("Restore Purchases") { Task { await store.restore() } }
                .font(.footnote)
            Button("Not now") { dismiss() }
                .font(.footnote)
        }
        .padding()
    }
}
