//
//  PromptTemplateTests.swift
//  MLX Code Tests
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import XCTest
@testable import MLX_Code

/// Unit tests for PromptTemplate
final class PromptTemplateTests: XCTestCase {

    // MARK: - Template Rendering Tests

    func testSimpleVariableSubstitution() {
        let template = PromptTemplate(
            name: "Test",
            category: .codeGeneration,
            template: "Hello {{name}}!",
            variables: [
                PromptTemplate.Variable(name: "name", description: "Name", isRequired: true)
            ]
        )

        let rendered = template.render(with: ["name": "World"])
        XCTAssertEqual(rendered, "Hello World!", "Variable should be substituted")
    }

    func testMultipleVariableSubstitution() {
        let template = PromptTemplate(
            name: "Test",
            category: .codeGeneration,
            template: "{{greeting}} {{name}}! How are you?",
            variables: [
                PromptTemplate.Variable(name: "greeting", description: "Greeting", isRequired: true),
                PromptTemplate.Variable(name: "name", description: "Name", isRequired: true)
            ]
        )

        let rendered = template.render(with: ["greeting": "Hello", "name": "Alice"])
        XCTAssertEqual(rendered, "Hello Alice! How are you?", "Multiple variables should be substituted")
    }

    func testDefaultValueUsage() {
        let template = PromptTemplate(
            name: "Test",
            category: .codeGeneration,
            template: "Hello {{name}}!",
            variables: [
                PromptTemplate.Variable(name: "name", description: "Name", isRequired: false, defaultValue: "Guest")
            ]
        )

        let rendered = template.render(with: [:]) // No values provided
        XCTAssertEqual(rendered, "Hello Guest!", "Default value should be used when no value provided")
    }

    func testMissingVariableWithoutDefault() {
        let template = PromptTemplate(
            name: "Test",
            category: .codeGeneration,
            template: "Hello {{name}}!",
            variables: [
                PromptTemplate.Variable(name: "name", description: "Name", isRequired: true)
            ]
        )

        let rendered = template.render(with: [:]) // No values provided
        XCTAssertEqual(rendered, "Hello !", "Missing required variable should result in empty substitution")
    }

    func testComplexTemplate() {
        let template = PromptTemplate(
            name: "SwiftUI View",
            category: .codeGeneration,
            template: """
            Create a SwiftUI view named {{viewName}} that {{functionality}}.
            It should use {{architecture}} architecture.
            """,
            variables: [
                PromptTemplate.Variable(name: "viewName", description: "View name", isRequired: true),
                PromptTemplate.Variable(name: "functionality", description: "Functionality", isRequired: true),
                PromptTemplate.Variable(name: "architecture", description: "Architecture", isRequired: false, defaultValue: "MVVM")
            ]
        )

        let rendered = template.render(with: [
            "viewName": "UserProfileView",
            "functionality": "displays user information"
        ])

        XCTAssertTrue(rendered.contains("UserProfileView"), "View name should be substituted")
        XCTAssertTrue(rendered.contains("displays user information"), "Functionality should be substituted")
        XCTAssertTrue(rendered.contains("MVVM"), "Default architecture should be used")
    }

    // MARK: - Template Validation Tests

    func testRequiredVariableDetection() {
        let template = PromptTemplate(
            name: "Test",
            category: .codeGeneration,
            template: "Hello {{name}}!",
            variables: [
                PromptTemplate.Variable(name: "name", description: "Name", isRequired: true)
            ]
        )

        let hasRequiredVars = template.variables.contains { $0.isRequired }
        XCTAssertTrue(hasRequiredVars, "Template should have required variables")
    }

    // MARK: - Built-in Templates Tests

    func testBuiltInTemplatesAvailability() {
        let templates = PromptTemplate.builtInTemplates()

        XCTAssertGreaterThan(templates.count, 15, "Should have at least 15 built-in templates")

        // Check for specific categories
        let categories = Set(templates.map { $0.category })
        XCTAssertTrue(categories.contains(.codeGeneration), "Should have code generation templates")
        XCTAssertTrue(categories.contains(.refactoring), "Should have refactoring templates")
        XCTAssertTrue(categories.contains(.documentation), "Should have documentation templates")
        XCTAssertTrue(categories.contains(.debugging), "Should have debugging templates")
    }

    func testSwiftUIViewTemplate() {
        let templates = PromptTemplate.builtInTemplates()
        guard let swiftUITemplate = templates.first(where: { $0.name == "SwiftUI View" }) else {
            XCTFail("SwiftUI View template should exist")
            return
        }

        XCTAssertEqual(swiftUITemplate.category, .codeGeneration, "Should be in code generation category")
        XCTAssertTrue(swiftUITemplate.template.contains("SwiftUI"), "Template should mention SwiftUI")
        XCTAssertGreaterThan(swiftUITemplate.variables.count, 0, "Should have variables")
    }

    // MARK: - Edge Cases

    func testEmptyTemplate() {
        let template = PromptTemplate(
            name: "Empty",
            category: .custom,
            template: "",
            variables: []
        )

        let rendered = template.render(with: [:])
        XCTAssertEqual(rendered, "", "Empty template should render as empty string")
    }

    func testTemplateWithoutVariables() {
        let template = PromptTemplate(
            name: "Static",
            category: .custom,
            template: "This is a static template.",
            variables: []
        )

        let rendered = template.render(with: ["unused": "value"])
        XCTAssertEqual(rendered, "This is a static template.", "Static template should not change")
    }

    func testTemplateWithSpecialCharacters() {
        let template = PromptTemplate(
            name: "Special",
            category: .custom,
            template: "Code: {{code}}\nNew line after",
            variables: [
                PromptTemplate.Variable(name: "code", description: "Code", isRequired: true)
            ]
        )

        let rendered = template.render(with: ["code": "func test() { }"])
        XCTAssertTrue(rendered.contains("func test() { }"), "Special characters in values should be preserved")
        XCTAssertTrue(rendered.contains("\n"), "Newlines in template should be preserved")
    }

    // MARK: - Performance Tests

    func testRenderPerformance() {
        let template = PromptTemplate(
            name: "Performance Test",
            category: .custom,
            template: String(repeating: "{{var}} ", count: 100),
            variables: [
                PromptTemplate.Variable(name: "var", description: "Variable", isRequired: true)
            ]
        )

        measure {
            for _ in 0..<100 {
                _ = template.render(with: ["var": "value"])
            }
        }
    }
}
