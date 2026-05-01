//
//  PromptTemplateTests.swift
//  MLX Code Tests
//
//  Unit tests for PromptTemplate: rendering, variable substitution,
//  Codable conformance, and edge cases.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class PromptTemplateTests: XCTestCase {

    // MARK: - Template Rendering

    func testSimpleVariableSubstitution() {
        let template = PromptTemplate(
            id: "test-1",
            name: "Test",
            category: .review,
            description: "A test template",
            icon: "star",
            template: "Hello {{NAME}}!",
            variables: [
                PromptTemplate.TemplateVar(name: "NAME", label: "Name", placeholder: "e.g. World", required: true)
            ],
            tags: ["test"]
        )
        let rendered = template.render(with: ["NAME": "World"])
        XCTAssertEqual(rendered, "Hello World!", "Variable should be substituted")
    }

    func testMultipleVariableSubstitution() {
        let template = PromptTemplate(
            id: "test-2",
            name: "Test",
            category: .review,
            description: "A test template",
            icon: "star",
            template: "{{GREETING}} {{NAME}}!",
            variables: [
                PromptTemplate.TemplateVar(name: "GREETING", label: "Greeting", placeholder: "Hi", required: true),
                PromptTemplate.TemplateVar(name: "NAME", label: "Name", placeholder: "Alice", required: true)
            ],
            tags: ["test"]
        )
        let rendered = template.render(with: ["GREETING": "Hello", "NAME": "Alice"])
        XCTAssertEqual(rendered, "Hello Alice!", "Multiple variables should be substituted")
    }

    func testMissingVariableLeavesPlaceholder() {
        let template = PromptTemplate(
            id: "test-3",
            name: "Test",
            category: .review,
            description: "Test",
            icon: "star",
            template: "Hello {{NAME}}!",
            variables: [
                PromptTemplate.TemplateVar(name: "NAME", label: "Name", placeholder: "World", required: true)
            ],
            tags: ["test"]
        )
        let rendered = template.render(with: [:])
        XCTAssertEqual(rendered, "Hello {{NAME}}!", "Missing variable should leave placeholder")
    }

    func testEmptyTemplate() {
        let template = PromptTemplate(
            id: "test-4",
            name: "Empty",
            category: .debug,
            description: "Empty",
            icon: "star",
            template: "",
            variables: [],
            tags: ["test"]
        )
        let rendered = template.render(with: [:])
        XCTAssertEqual(rendered, "", "Empty template should render as empty string")
    }

    func testTemplateWithoutVariables() {
        let template = PromptTemplate(
            id: "test-5",
            name: "Static",
            category: .debug,
            description: "Static",
            icon: "star",
            template: "This is a static template.",
            variables: [],
            tags: ["test"]
        )
        let rendered = template.render(with: ["unused": "value"])
        XCTAssertEqual(rendered, "This is a static template.", "Static template should not change")
    }

    func testTemplateWithSpecialCharacters() {
        let template = PromptTemplate(
            id: "test-6",
            name: "Special",
            category: .generate,
            description: "Special chars",
            icon: "star",
            template: "Code: {{CODE}}\nNew line after",
            variables: [
                PromptTemplate.TemplateVar(name: "CODE", label: "Code", placeholder: "...", required: true)
            ],
            tags: ["test"]
        )
        let rendered = template.render(with: ["CODE": "func test() { }"])
        XCTAssertTrue(rendered.contains("func test() { }"), "Special characters should be preserved")
        XCTAssertTrue(rendered.contains("\n"), "Newlines should be preserved")
    }

    // MARK: - TemplateCategory

    func testAllCategoriesHaveRawValues() {
        for category in PromptTemplate.TemplateCategory.allCases {
            XCTAssertFalse(category.rawValue.isEmpty, "Category \(category) should have a raw value")
        }
    }

    // MARK: - Equatable

    func testEqualityByID() {
        let t1 = PromptTemplate(
            id: "same-id", name: "A", category: .review, description: "A",
            icon: "a", template: "A", variables: [], tags: ["a"]
        )
        let t2 = PromptTemplate(
            id: "same-id", name: "B", category: .debug, description: "B",
            icon: "b", template: "B", variables: [], tags: ["b"]
        )
        XCTAssertEqual(t1, t2, "Templates with the same ID should be equal")
    }

    func testInequalityByID() {
        let t1 = PromptTemplate(
            id: "id-1", name: "Same", category: .review, description: "Same",
            icon: "star", template: "Same", variables: [], tags: []
        )
        let t2 = PromptTemplate(
            id: "id-2", name: "Same", category: .review, description: "Same",
            icon: "star", template: "Same", variables: [], tags: []
        )
        XCTAssertNotEqual(t1, t2, "Templates with different IDs should not be equal")
    }

    // MARK: - Hashable

    func testHashableInSet() {
        let t1 = PromptTemplate(
            id: "a", name: "A", category: .review, description: "A",
            icon: "star", template: "A", variables: [], tags: []
        )
        let t2 = PromptTemplate(
            id: "b", name: "B", category: .debug, description: "B",
            icon: "star", template: "B", variables: [], tags: []
        )
        let set: Set<PromptTemplate> = [t1, t2]
        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let template = PromptTemplate(
            id: "codable-test",
            name: "Codable",
            category: .security,
            description: "Testing Codable",
            icon: "lock",
            template: "Audit {{SCOPE}}",
            variables: [
                PromptTemplate.TemplateVar(name: "SCOPE", label: "Scope", placeholder: "module", required: true)
            ],
            tags: ["security", "test"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(template)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PromptTemplate.self, from: data)

        XCTAssertEqual(decoded.id, template.id)
        XCTAssertEqual(decoded.name, template.name)
        XCTAssertEqual(decoded.category, template.category)
        XCTAssertEqual(decoded.variables.count, template.variables.count)
        XCTAssertEqual(decoded.tags, template.tags)
    }

    // MARK: - Performance

    func testRenderPerformance() {
        let template = PromptTemplate(
            id: "perf-test",
            name: "Perf",
            category: .generate,
            description: "Perf test",
            icon: "star",
            template: String(repeating: "{{VAR}} ", count: 100),
            variables: [
                PromptTemplate.TemplateVar(name: "VAR", label: "Var", placeholder: "v", required: true)
            ],
            tags: ["perf"]
        )
        measure {
            for _ in 0..<100 {
                _ = template.render(with: ["VAR": "value"])
            }
        }
    }
}
