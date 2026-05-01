//
//  PromptTemplateLibraryTests.swift
//  MLX Code Tests
//
//  Unit tests for the curated PromptTemplate library: template rendering,
//  variable substitution, category coverage, and API completeness.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class PromptTemplateLibraryTests: XCTestCase {

    // MARK: - Library Completeness

    func testLibraryHasExpectedTemplateCount() {
        XCTAssertEqual(PromptTemplateLibrary.all.count, 15,
            "Library should contain exactly 15 templates")
    }

    func testAllTemplatesHaveUniqueIds() {
        let ids = PromptTemplateLibrary.all.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count, "All template IDs must be unique")
    }

    func testAllTemplatesHaveNonEmptyNames() {
        for template in PromptTemplateLibrary.all {
            XCTAssertFalse(template.name.isEmpty, "Template \(template.id) should have a name")
        }
    }

    func testAllTemplatesHaveNonEmptyTemplateBody() {
        for template in PromptTemplateLibrary.all {
            XCTAssertFalse(template.template.isEmpty, "Template \(template.id) should have a body")
        }
    }

    func testAllTemplatesHaveIcons() {
        for template in PromptTemplateLibrary.all {
            XCTAssertFalse(template.icon.isEmpty, "Template \(template.id) should have an icon")
        }
    }

    func testAllTemplatesHaveTags() {
        for template in PromptTemplateLibrary.all {
            XCTAssertFalse(template.tags.isEmpty, "Template \(template.id) should have tags")
        }
    }

    // MARK: - Category Coverage

    func testCategoryCoverage() {
        let coveredCategories = Set(PromptTemplateLibrary.all.map { $0.category })
        let expectedCategories: Set<PromptTemplate.TemplateCategory> = [
            .review, .debug, .generate, .refactor, .document,
            .test, .security, .performance, .deploy
        ]
        for category in expectedCategories {
            XCTAssertTrue(coveredCategories.contains(category),
                "Category '\(category.rawValue)' should have at least one template")
        }
    }

    func testFilterByCategory() {
        let reviewTemplates = PromptTemplateLibrary.templates(for: .review)
        XCTAssertGreaterThan(reviewTemplates.count, 0, "Should have review templates")
        for template in reviewTemplates {
            XCTAssertEqual(template.category, .review)
        }
    }

    func testLookupById() {
        let template = PromptTemplateLibrary.template(id: "swift-code-review")
        XCTAssertNotNil(template, "Should find template by ID")
        XCTAssertEqual(template?.name, "Swift Code Review")
    }

    func testLookupByInvalidIdReturnsNil() {
        let template = PromptTemplateLibrary.template(id: "nonexistent-template")
        XCTAssertNil(template, "Non-existent ID should return nil")
    }

    // MARK: - Variable Rendering

    func testRenderSubstitutesVariables() {
        let template = PromptTemplateLibrary.swiftCodeReview
        let rendered = template.render(with: ["FILE_PATH": "Sources/MyView.swift"])
        XCTAssertTrue(rendered.contains("Sources/MyView.swift"),
            "Variable {{FILE_PATH}} should be replaced")
        XCTAssertFalse(rendered.contains("{{FILE_PATH}}"),
            "Template placeholder should not remain")
    }

    func testRenderWithMissingVariableLeavesPlaceholder() {
        let template = PromptTemplateLibrary.swiftCodeReview
        let rendered = template.render(with: [:])
        XCTAssertTrue(rendered.contains("{{FILE_PATH}}"),
            "Missing variable should leave placeholder in output")
    }

    func testRenderBugFixMultipleVariables() {
        let template = PromptTemplateLibrary.bugFix
        let rendered = template.render(with: [
            "DESCRIPTION": "Crash on launch",
            "FILE": "AppDelegate.swift"
        ])
        XCTAssertTrue(rendered.contains("Crash on launch"))
        XCTAssertTrue(rendered.contains("AppDelegate.swift"))
    }

    func testRenderFeatureImplementation() {
        let template = PromptTemplateLibrary.featureImplementation
        let rendered = template.render(with: [
            "FEATURE": "Dark mode support",
            "CONTEXT": "SwiftUI app"
        ])
        XCTAssertTrue(rendered.contains("Dark mode support"))
        XCTAssertTrue(rendered.contains("SwiftUI app"))
    }

    // MARK: - Template Variable Definitions

    func testRequiredVariablesAreMarked() {
        let template = PromptTemplateLibrary.swiftCodeReview
        let requiredVars = template.variables.filter { $0.required }
        XCTAssertGreaterThan(requiredVars.count, 0, "Code review should have required variables")
    }

    func testVariablesHavePlaceholders() {
        for template in PromptTemplateLibrary.all {
            for variable in template.variables {
                XCTAssertFalse(variable.placeholder.isEmpty,
                    "Variable '\(variable.name)' in \(template.id) should have a placeholder")
            }
        }
    }

    func testVariablesHaveLabels() {
        for template in PromptTemplateLibrary.all {
            for variable in template.variables {
                XCTAssertFalse(variable.label.isEmpty,
                    "Variable '\(variable.name)' in \(template.id) should have a label")
            }
        }
    }

    // MARK: - Codable

    func testTemplateCodableRoundTrip() throws {
        let template = PromptTemplateLibrary.swiftCodeReview
        let encoder = JSONEncoder()
        let data = try encoder.encode(template)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PromptTemplate.self, from: data)

        XCTAssertEqual(decoded.id, template.id)
        XCTAssertEqual(decoded.name, template.name)
        XCTAssertEqual(decoded.category, template.category)
        XCTAssertEqual(decoded.variables.count, template.variables.count)
    }

    // MARK: - Hashable

    func testTemplatesAreHashable() {
        let set: Set<PromptTemplate> = Set(PromptTemplateLibrary.all)
        XCTAssertEqual(set.count, PromptTemplateLibrary.all.count,
            "All templates should be hashable with unique identities")
    }

    // MARK: - Category CaseIterable

    func testAllCategoriesExist() {
        let allCategories = PromptTemplate.TemplateCategory.allCases
        XCTAssertGreaterThanOrEqual(allCategories.count, 9, "Should have at least 9 categories")
    }
}
