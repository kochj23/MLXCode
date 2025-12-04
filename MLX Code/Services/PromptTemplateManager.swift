//
//  PromptTemplateManager.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation
import Combine

/// Manages prompt templates with persistence
@MainActor
class PromptTemplateManager: ObservableObject {
    /// Shared singleton instance
    static let shared = PromptTemplateManager()

    /// All templates (built-in + custom)
    @Published var allTemplates: [PromptTemplate] = []

    /// Custom user templates
    @Published var customTemplates: [PromptTemplate] = []

    private let fileManager = FileManager.default
    private let templatesDirectory: URL
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Setup templates directory
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        templatesDirectory = appSupport.appendingPathComponent("MLX Code/Templates", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: templatesDirectory, withIntermediateDirectories: true)

        // Load templates
        loadTemplates()
    }

    // MARK: - Public Methods

    /// Loads all templates (built-in + custom)
    func loadTemplates() {
        // Load built-in templates
        let builtIn = PromptTemplate.builtInTemplates

        // Load custom templates
        loadCustomTemplates()

        // Combine
        allTemplates = builtIn + customTemplates

        logInfo("Loaded \(allTemplates.count) templates (\(builtIn.count) built-in, \(customTemplates.count) custom)", category: "PromptTemplateManager")
    }

    /// Gets templates in a specific category
    /// - Parameter category: The category to filter by
    /// - Returns: Array of templates in that category
    func templates(in category: TemplateCategory) -> [PromptTemplate] {
        return allTemplates.filter { $0.category == category }
    }

    /// Gets the most recently used templates
    /// - Parameter limit: Maximum number to return
    /// - Returns: Array of recently used templates
    func recentlyUsedTemplates(limit: Int = 10) -> [PromptTemplate] {
        return allTemplates
            .filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? Date.distantPast) > ($1.lastUsedAt ?? Date.distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    /// Gets the most frequently used templates
    /// - Parameter limit: Maximum number to return
    /// - Returns: Array of frequently used templates
    func frequentlyUsedTemplates(limit: Int = 10) -> [PromptTemplate] {
        return allTemplates
            .filter { $0.useCount > 0 }
            .sorted { $0.useCount > $1.useCount }
            .prefix(limit)
            .map { $0 }
    }

    /// Searches templates by query
    /// - Parameter query: Search query
    /// - Returns: Matching templates
    func searchTemplates(_ query: String) -> [PromptTemplate] {
        guard !query.isEmpty else { return allTemplates }

        return allTemplates.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query) ||
            $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    /// Adds a custom template
    /// - Parameter template: The template to add
    func addCustomTemplate(_ template: PromptTemplate) {
        var newTemplate = template
        newTemplate.isBuiltIn = false

        customTemplates.append(newTemplate)
        allTemplates.append(newTemplate)

        saveCustomTemplates()

        logInfo("Added custom template: \(newTemplate.name)", category: "PromptTemplateManager")
    }

    /// Updates an existing template
    /// - Parameter template: The template to update
    func updateTemplate(_ template: PromptTemplate) {
        // Update in custom templates
        if let index = customTemplates.firstIndex(where: { $0.id == template.id }) {
            customTemplates[index] = template
            saveCustomTemplates()
        }

        // Update in all templates
        if let index = allTemplates.firstIndex(where: { $0.id == template.id }) {
            allTemplates[index] = template
        }

        logInfo("Updated template: \(template.name)", category: "PromptTemplateManager")
    }

    /// Deletes a template
    /// - Parameter template: The template to delete
    func deleteTemplate(_ template: PromptTemplate) {
        guard !template.isBuiltIn else {
            logWarning("Attempted to delete built-in template", category: "PromptTemplateManager")
            return
        }

        // Remove from custom templates
        customTemplates.removeAll { $0.id == template.id }

        // Remove from all templates
        allTemplates.removeAll { $0.id == template.id }

        // Delete file
        let fileURL = templatesDirectory.appendingPathComponent("\(template.id.uuidString).json")
        try? fileManager.removeItem(at: fileURL)

        logInfo("Deleted template: \(template.name)", category: "PromptTemplateManager")
    }

    /// Records usage of a template
    /// - Parameter template: The template that was used
    func recordTemplateUsage(_ template: PromptTemplate) {
        guard let index = allTemplates.firstIndex(where: { $0.id == template.id }) else {
            return
        }

        allTemplates[index].recordUsage()

        // Save if custom template
        if !template.isBuiltIn {
            if let customIndex = customTemplates.firstIndex(where: { $0.id == template.id }) {
                customTemplates[customIndex] = allTemplates[index]
                saveCustomTemplates()
            }
        }

        logInfo("Recorded usage of template: \(template.name)", category: "PromptTemplateManager")
    }

    /// Exports a template to JSON data
    /// - Parameter template: The template to export
    /// - Returns: JSON data or nil
    func exportTemplate(_ template: PromptTemplate) -> Data? {
        return try? JSONEncoder().encode(template)
    }

    /// Imports a template from JSON data
    /// - Parameter data: JSON data
    /// - Returns: The imported template or nil
    func importTemplate(from data: Data) -> PromptTemplate? {
        guard let template = try? JSONDecoder().decode(PromptTemplate.self, from: data) else {
            return nil
        }

        addCustomTemplate(template)
        return template
    }

    // MARK: - Private Methods

    /// Loads custom templates from disk
    private func loadCustomTemplates() {
        guard let files = try? fileManager.contentsOfDirectory(at: templatesDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        customTemplates = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> PromptTemplate? in
                guard let data = try? Data(contentsOf: url),
                      let template = try? JSONDecoder().decode(PromptTemplate.self, from: data) else {
                    return nil
                }
                return template
            }

        // Sort by name
        customTemplates.sort { $0.name < $1.name }
    }

    /// Saves all custom templates to disk
    private func saveCustomTemplates() {
        for template in customTemplates {
            let fileURL = templatesDirectory.appendingPathComponent("\(template.id.uuidString).json")

            if let data = try? JSONEncoder().encode(template) {
                try? data.write(to: fileURL)
            }
        }
    }

    // MARK: - Memory Safety

    deinit {
        cancellables.removeAll()
    }
}

// MARK: - Template Statistics

extension PromptTemplateManager {
    /// Gets statistics about template usage
    var statistics: TemplateStatistics {
        let totalUses = allTemplates.reduce(0) { $0 + $1.useCount }
        let customCount = customTemplates.count
        let builtInCount = allTemplates.count - customCount

        return TemplateStatistics(
            totalTemplates: allTemplates.count,
            builtInTemplates: builtInCount,
            customTemplates: customCount,
            totalUses: totalUses,
            mostUsed: frequentlyUsedTemplates(limit: 5)
        )
    }
}

/// Statistics about template usage
struct TemplateStatistics {
    let totalTemplates: Int
    let builtInTemplates: Int
    let customTemplates: Int
    let totalUses: Int
    let mostUsed: [PromptTemplate]
}
