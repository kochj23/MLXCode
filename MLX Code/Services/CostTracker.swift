//
//  CostTracker.swift
//  MLX Code
//
//  Tracks usage and calculates savings vs Claude Code
//  Created on 2025-12-09
//

import Foundation
import Combine

/// Tracks token usage and calculates cost savings
@MainActor
class CostTracker: ObservableObject {
    static let shared = CostTracker()

    // MARK: - Published Properties

    /// Total tokens generated (lifetime)
    @Published var totalTokensGenerated: Int64 = 0

    /// Total tokens this month
    @Published var monthlyTokens: Int64 = 0

    /// Total tokens today
    @Published var dailyTokens: Int64 = 0

    /// Total sessions
    @Published var totalSessions: Int = 0

    /// Lifetime savings
    @Published var lifetimeSavings: Double = 0.0

    // MARK: - Constants

    /// Claude Code pricing (estimated)
    private let claudeCodePricePerToken = 0.000015 // $0.015 per 1K tokens

    /// API subscription cost estimate
    private let monthlyAPICost = 20.0 // $20/month minimum

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    private enum Keys {
        static let totalTokens = "cost_total_tokens"
        static let monthlyTokens = "cost_monthly_tokens"
        static let dailyTokens = "cost_daily_tokens"
        static let totalSessions = "cost_total_sessions"
        static let lastResetDate = "cost_last_reset_date"
        static let startDate = "cost_start_date"
    }

    private init() {
        loadStats()
        setupObservers()
        resetDailyIfNeeded()
        resetMonthlyIfNeeded()
    }

    // MARK: - Recording

    /// Records tokens generated
    func recordTokens(_ count: Int) {
        totalTokensGenerated += Int64(count)
        monthlyTokens += Int64(count)
        dailyTokens += Int64(count)

        calculateSavings()
        saveStats()
    }

    /// Records a new session
    func recordSession() {
        totalSessions += 1
        saveStats()
    }

    // MARK: - Calculations

    /// Calculates total savings vs Claude Code
    private func calculateSavings() {
        // API cost for tokens
        let apiCost = Double(totalTokensGenerated) * claudeCodePricePerToken

        // Subscription cost (months since start)
        let startDate = userDefaults.object(forKey: Keys.startDate) as? Date ?? Date()
        let monthsSinceStart = max(1, Int(Date().timeIntervalSince(startDate) / (30 * 24 * 60 * 60)))
        let subscriptionCost = Double(monthsSinceStart) * monthlyAPICost

        lifetimeSavings = apiCost + subscriptionCost
    }

    /// Gets savings report
    func getSavingsReport() -> CostReport {
        let claudeCodeCost = (Double(totalTokensGenerated) * claudeCodePricePerToken)
            + (Double(totalSessions) * monthlyAPICost / 30) // Pro-rated subscription

        return CostReport(
            totalTokens: totalTokensGenerated,
            monthlyTokens: monthlyTokens,
            dailyTokens: dailyTokens,
            totalSessions: totalSessions,
            hypotheticalCost: claudeCodeCost,
            actualCost: 0.0,
            savings: claudeCodeCost,
            savingsFormatted: formatCurrency(claudeCodeCost)
        )
    }

    // MARK: - Formatting

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$0.00"
    }

    func formatTokens(_ count: Int64) -> String {
        if count < 1000 {
            return "\(count)"
        } else if count < 1_000_000 {
            return String(format: "%.1fK", Double(count) / 1000)
        } else {
            return String(format: "%.2fM", Double(count) / 1_000_000)
        }
    }

    // MARK: - Persistence

    private func loadStats() {
        totalTokensGenerated = Int64(userDefaults.integer(forKey: Keys.totalTokens))
        monthlyTokens = Int64(userDefaults.integer(forKey: Keys.monthlyTokens))
        dailyTokens = Int64(userDefaults.integer(forKey: Keys.dailyTokens))
        totalSessions = userDefaults.integer(forKey: Keys.totalSessions)

        // Set start date if not exists
        if userDefaults.object(forKey: Keys.startDate) == nil {
            userDefaults.set(Date(), forKey: Keys.startDate)
        }

        calculateSavings()
    }

    private func saveStats() {
        userDefaults.set(Int(totalTokensGenerated), forKey: Keys.totalTokens)
        userDefaults.set(Int(monthlyTokens), forKey: Keys.monthlyTokens)
        userDefaults.set(Int(dailyTokens), forKey: Keys.dailyTokens)
        userDefaults.set(totalSessions, forKey: Keys.totalSessions)
    }

    private func setupObservers() {
        $totalTokensGenerated
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.saveStats() }
            .store(in: &cancellables)
    }

    // MARK: - Resets

    private func resetDailyIfNeeded() {
        let lastReset = userDefaults.object(forKey: Keys.lastResetDate) as? Date ?? Date()
        let calendar = Calendar.current

        if !calendar.isDateInToday(lastReset) {
            dailyTokens = 0
            userDefaults.set(Date(), forKey: Keys.lastResetDate)
        }
    }

    private func resetMonthlyIfNeeded() {
        let lastReset = userDefaults.object(forKey: Keys.lastResetDate) as? Date ?? Date()
        let calendar = Calendar.current

        if !calendar.isDate(lastReset, equalTo: Date(), toGranularity: .month) {
            monthlyTokens = 0
        }
    }

    /// Resets all statistics
    func resetAll() {
        totalTokensGenerated = 0
        monthlyTokens = 0
        dailyTokens = 0
        totalSessions = 0
        lifetimeSavings = 0.0

        userDefaults.set(Date(), forKey: Keys.startDate)
        saveStats()
    }
}

// MARK: - Supporting Types

/// Cost report for a period
struct CostReport {
    let totalTokens: Int64
    let monthlyTokens: Int64
    let dailyTokens: Int64
    let totalSessions: Int
    let hypotheticalCost: Double  // What it would cost with Claude Code
    let actualCost: Double         // Always $0
    let savings: Double
    let savingsFormatted: String

    var monthlyHypotheticalCost: String {
        let cost = Double(monthlyTokens) * 0.000015 + 20.0
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        return formatter.string(from: NSNumber(value: cost)) ?? "$0"
    }
}
