//
//  ToolParameterParsingTests.swift
//  MLX Code Tests
//
//  Unit tests for BaseTool's parameter extraction/validation helpers. Every
//  concrete tool relies on these to coerce untrusted LLM-supplied argument
//  dictionaries into typed values, so their required/default/type-mismatch
//  behavior is high-risk and worth pinning down. Also covers the ToolError
//  message surface these helpers throw.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class ToolParameterParsingTests: XCTestCase {

    /// A minimal concrete BaseTool used only to reach the protected helpers.
    private func makeTool() -> BaseTool {
        BaseTool(
            name: "test_tool",
            description: "test",
            parameters: ToolParameterSchema(properties: [:]))
    }

    // MARK: - validateParameters

    func testValidateParametersPassesWhenPresent() throws {
        let tool = makeTool()
        XCTAssertNoThrow(
            try tool.validateParameters(["a": 1, "b": "x"], required: ["a", "b"]))
    }

    func testValidateParametersThrowsMissing() {
        let tool = makeTool()
        XCTAssertThrowsError(
            try tool.validateParameters(["a": 1], required: ["a", "b"])
        ) { error in
            guard case ToolError.missingParameter(let name) = error else {
                return XCTFail("Expected .missingParameter, got \(error)")
            }
            XCTAssertEqual(name, "b")
        }
    }

    // MARK: - stringParameter

    func testStringParameterReturnsValue() throws {
        let tool = makeTool()
        XCTAssertEqual(try tool.stringParameter(["k": "hello"], key: "k"), "hello")
    }

    func testStringParameterUsesDefaultWhenMissing() throws {
        let tool = makeTool()
        XCTAssertEqual(
            try tool.stringParameter([:], key: "k", default: "fallback"), "fallback")
    }

    func testStringParameterThrowsWhenMissingAndNoDefault() {
        let tool = makeTool()
        XCTAssertThrowsError(try tool.stringParameter([:], key: "k")) { error in
            guard case ToolError.invalidParameterType(let key, let expected) = error else {
                return XCTFail("Expected .invalidParameterType, got \(error)")
            }
            XCTAssertEqual(key, "k")
            XCTAssertEqual(expected, "String")
        }
    }

    func testStringParameterThrowsOnWrongType() {
        let tool = makeTool()
        // An Int value under the key is not a String and no default is provided.
        XCTAssertThrowsError(try tool.stringParameter(["k": 123], key: "k"))
    }

    // MARK: - intParameter

    func testIntParameterReturnsValue() throws {
        let tool = makeTool()
        XCTAssertEqual(try tool.intParameter(["n": 7], key: "n"), 7)
    }

    func testIntParameterUsesDefault() throws {
        let tool = makeTool()
        XCTAssertEqual(try tool.intParameter([:], key: "n", default: 42), 42)
    }

    func testIntParameterThrowsOnWrongTypeWithoutDefault() {
        let tool = makeTool()
        XCTAssertThrowsError(try tool.intParameter(["n": "notanint"], key: "n")) { error in
            guard case ToolError.invalidParameterType = error else {
                return XCTFail("Expected .invalidParameterType, got \(error)")
            }
        }
    }

    // MARK: - boolParameter

    func testBoolParameterReturnsValue() throws {
        let tool = makeTool()
        XCTAssertTrue(try tool.boolParameter(["flag": true], key: "flag"))
        XCTAssertFalse(try tool.boolParameter(["flag": false], key: "flag"))
    }

    func testBoolParameterUsesDefault() throws {
        let tool = makeTool()
        XCTAssertTrue(try tool.boolParameter([:], key: "flag", default: true))
    }

    // MARK: - arrayParameter

    func testArrayParameterReturnsValue() throws {
        let tool = makeTool()
        let result = try tool.arrayParameter(["items": ["a", "b", "c"]], key: "items")
        XCTAssertEqual(result.count, 3)
    }

    func testArrayParameterThrowsOnWrongType() {
        let tool = makeTool()
        XCTAssertThrowsError(try tool.arrayParameter(["items": "not-an-array"], key: "items")) { error in
            guard case ToolError.invalidParameterType(let key, let expected) = error else {
                return XCTFail("Expected .invalidParameterType, got \(error)")
            }
            XCTAssertEqual(key, "items")
            XCTAssertEqual(expected, "Array")
        }
    }

    // MARK: - ToolError message surface

    func testToolErrorDescriptions() {
        XCTAssertEqual(
            ToolError.missingParameter("path").errorDescription,
            "Missing required parameter: path")
        XCTAssertEqual(
            ToolError.invalidParameterType("count", expected: "Int").errorDescription,
            "Invalid type for parameter 'count': expected Int")
        XCTAssertEqual(
            ToolError.notFound("/tmp/x").errorDescription,
            "Resource not found: /tmp/x")
    }
}
