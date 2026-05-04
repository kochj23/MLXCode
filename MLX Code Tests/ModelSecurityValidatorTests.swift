//
//  ModelSecurityValidatorTests.swift
//  MLX Code Tests
//
//  Security tests for ModelSecurityValidator: dangerous format blocking,
//  SafeTensors validation, Python script scanning, source trust verification,
//  and hash verification.
//
//  Created by Jordan Koch.
//

import XCTest
@testable import MLX_Code

final class ModelSecurityValidatorTests: XCTestCase {

    private let validator = ModelSecurityValidator.shared
    private let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("mlxcode-test-\(UUID().uuidString)")

    override func setUp() async throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - Dangerous Format Blocking

    func testBlocksPickleFormat() async {
        let file = tempDir.appendingPathComponent("model.pkl")
        FileManager.default.createFile(atPath: file.path, contents: Data("dummy".utf8))

        let result = await validator.validateModel(path: file.path)
        XCTAssertFalse(result.isSafe, "Pickle files should be blocked")
        XCTAssertTrue(result.issues.contains { if case .dangerousFormat = $0 { return true } else { return false } })
    }

    func testBlocksPyTorchPt() async {
        let file = tempDir.appendingPathComponent("model.pt")
        FileManager.default.createFile(atPath: file.path, contents: Data("dummy".utf8))

        let result = await validator.validateModel(path: file.path)
        XCTAssertFalse(result.isSafe, ".pt files should be blocked")
    }

    func testBlocksPyTorchPth() async {
        let file = tempDir.appendingPathComponent("model.pth")
        FileManager.default.createFile(atPath: file.path, contents: Data("dummy".utf8))

        let result = await validator.validateModel(path: file.path)
        XCTAssertFalse(result.isSafe, ".pth files should be blocked")
    }

    func testBlocksPythonScript() async {
        let file = tempDir.appendingPathComponent("loader.py")
        FileManager.default.createFile(atPath: file.path, contents: Data("import os".utf8))

        let result = await validator.validateModel(path: file.path)
        XCTAssertFalse(result.isSafe, ".py files should be blocked")
    }

    func testBlocksBinFormat() async {
        let file = tempDir.appendingPathComponent("weights.bin")
        FileManager.default.createFile(atPath: file.path, contents: Data("dummy".utf8))

        let result = await validator.validateModel(path: file.path)
        XCTAssertFalse(result.isSafe, ".bin files should be blocked (often pickle)")
    }

    // MARK: - Safe Format Acceptance

    func testAcceptsJSONConfig() async {
        let file = tempDir.appendingPathComponent("config.json")
        let jsonContent = #"{"model_type": "llama", "hidden_size": 4096}"#
        FileManager.default.createFile(atPath: file.path, contents: Data(jsonContent.utf8))

        let result = await validator.validateModel(path: file.path)
        XCTAssertTrue(result.isSafe, "JSON config files should be accepted")
    }

    func testAcceptsTextFile() async {
        let file = tempDir.appendingPathComponent("tokenizer.txt")
        FileManager.default.createFile(atPath: file.path, contents: Data("vocab data".utf8))

        let result = await validator.validateModel(path: file.path)
        XCTAssertTrue(result.isSafe, "Text files should be accepted")
    }

    // MARK: - SafeTensors Validation

    func testValidSafeTensorsHeader() async {
        // SafeTensors format: first 8 bytes = little-endian uint64 (header size)
        // followed by JSON header of that size
        let file = tempDir.appendingPathComponent("model.safetensors")
        var data = Data()
        // Header size = 32 (as little-endian uint64)
        var headerSize: UInt64 = 32
        withUnsafeBytes(of: &headerSize) { data.append(contentsOf: $0) }
        // JSON header (padded to 32 bytes)
        let header = #"{"tensor": {"dtype": "F32"}}  "#  // exactly 32 bytes
        data.append(Data(header.utf8))
        FileManager.default.createFile(atPath: file.path, contents: data)

        let result = await validator.validateModel(path: file.path)
        XCTAssertTrue(result.isSafe, "Valid SafeTensors file should be accepted")
        XCTAssertEqual(result.format, "safetensors")
    }

    func testInvalidSafeTensorsHeader() async {
        // SafeTensors with absurdly large header size (> 10MB limit)
        let file = tempDir.appendingPathComponent("bad.safetensors")
        var data = Data()
        var headerSize: UInt64 = 100_000_000  // 100MB header - should fail
        withUnsafeBytes(of: &headerSize) { data.append(contentsOf: $0) }
        FileManager.default.createFile(atPath: file.path, contents: data)

        let result = await validator.validateModel(path: file.path)
        XCTAssertFalse(result.isSafe, "SafeTensors with oversized header should be rejected")
    }

    func testTruncatedSafeTensorsFile() async {
        // Less than 8 bytes - cannot read header
        let file = tempDir.appendingPathComponent("tiny.safetensors")
        FileManager.default.createFile(atPath: file.path, contents: Data([0x01, 0x02, 0x03]))

        let result = await validator.validateModel(path: file.path)
        XCTAssertFalse(result.isSafe, "Truncated SafeTensors file should be rejected")
    }

    // MARK: - File Not Found

    func testFileNotFoundReturnsUnsafe() async {
        let result = await validator.validateModel(path: "/nonexistent/path/model.safetensors")
        XCTAssertFalse(result.isSafe, "Non-existent file should be unsafe")
        XCTAssertTrue(result.issues.contains { if case .fileNotFound = $0 { return true } else { return false } })
    }

    // MARK: - Source Trust

    func testTrustedHuggingFaceSource() async {
        let file = tempDir.appendingPathComponent("config.json")
        FileManager.default.createFile(atPath: file.path, contents: Data("{}".utf8))

        let result = await validator.validateModel(
            path: file.path,
            sourceURL: "https://huggingface.co/mlx-community/Qwen2.5-7B"
        )
        XCTAssertTrue(result.isSafe)
        // Trusted source should not produce source warnings (except the hash warning)
        let sourceWarnings = result.warnings.filter { $0.contains("untrusted") }
        XCTAssertTrue(sourceWarnings.isEmpty, "HuggingFace should be trusted")
    }

    func testUntrustedSourceWarning() async {
        let file = tempDir.appendingPathComponent("config.json")
        FileManager.default.createFile(atPath: file.path, contents: Data("{}".utf8))

        let result = await validator.validateModel(
            path: file.path,
            sourceURL: "https://sketchy-models.example.com/model"
        )
        XCTAssertTrue(result.isSafe, "Untrusted source produces warning, not block")
        let sourceWarnings = result.warnings.filter { $0.lowercased().contains("untrusted") }
        XCTAssertFalse(sourceWarnings.isEmpty, "Untrusted source should produce a warning")
    }

    // MARK: - Suspicious Content Detection

    func testDetectsPickleOpcodes() async {
        // Pickle protocol 2 starts with 0x80 0x02
        let file = tempDir.appendingPathComponent("sneaky.safetensors")
        var data = Data()
        // Valid SafeTensors header (8 bytes for size)
        var headerSize: UInt64 = 2
        withUnsafeBytes(of: &headerSize) { data.append(contentsOf: $0) }
        data.append(Data("{}".utf8))
        // Then inject pickle opcodes
        data.append(contentsOf: [0x80, 0x02])
        FileManager.default.createFile(atPath: file.path, contents: data)

        let result = await validator.validateModel(path: file.path)
        XCTAssertFalse(result.isSafe, "File with pickle opcodes should be rejected")
    }

    // MARK: - Python Script Validation

    func testSafePythonScript() async {
        let file = tempDir.appendingPathComponent("inference.py")
        let script = """
        import mlx.core as mx
        import mlx.nn as nn
        model = nn.Linear(10, 5)
        print(model(mx.ones((1, 10))))
        """
        try! script.write(toFile: file.path, atomically: true, encoding: .utf8)

        let result = await validator.validatePythonScript(path: file.path)
        XCTAssertTrue(result.isSafe, "Safe MLX script should be accepted")
    }

    func testDangerousPythonExec() async {
        let file = tempDir.appendingPathComponent("evil.py")
        let script = "exec('import os; os.system(\"rm -rf /\")')"
        try! script.write(toFile: file.path, atomically: true, encoding: .utf8)

        let result = await validator.validatePythonScript(path: file.path)
        XCTAssertFalse(result.isSafe, "Script with exec() should be blocked")
    }

    func testDangerousPythonPickleLoad() async {
        let file = tempDir.appendingPathComponent("loader.py")
        let script = """
        import pickle
        data = pickle.load(open("model.pkl", "rb"))
        """
        try! script.write(toFile: file.path, atomically: true, encoding: .utf8)

        let result = await validator.validatePythonScript(path: file.path)
        XCTAssertFalse(result.isSafe, "Script with pickle.load should be blocked")
    }

    func testDangerousPythonSubprocess() async {
        let file = tempDir.appendingPathComponent("run.py")
        let script = "import subprocess\nsubprocess.run(['ls'])"
        try! script.write(toFile: file.path, atomically: true, encoding: .utf8)

        let result = await validator.validatePythonScript(path: file.path)
        XCTAssertFalse(result.isSafe, "Script with subprocess should be blocked")
    }

    func testPythonScriptNotFound() async {
        let result = await validator.validatePythonScript(path: "/nonexistent/script.py")
        XCTAssertFalse(result.isSafe, "Non-existent script should be unsafe")
    }

    // MARK: - Hash Verification

    func testHashVerificationWithKnownContent() async {
        let file = tempDir.appendingPathComponent("test_hash.txt")
        let content = "Hello, World!"
        try! content.write(toFile: file.path, atomically: true, encoding: .utf8)

        // SHA256 of "Hello, World!" = dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f
        let expectedHash = "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f"
        let matches = await validator.verifyModelHash(filePath: file.path, expectedHash: expectedHash)
        XCTAssertTrue(matches, "Hash should match for known content")
    }

    func testHashVerificationMismatch() async {
        let file = tempDir.appendingPathComponent("test_mismatch.txt")
        try! "Some content".write(toFile: file.path, atomically: true, encoding: .utf8)

        let wrongHash = "0000000000000000000000000000000000000000000000000000000000000000"
        let matches = await validator.verifyModelHash(filePath: file.path, expectedHash: wrongHash)
        XCTAssertFalse(matches, "Wrong hash should not match")
    }

    func testHashVerificationFileNotFound() async {
        let matches = await validator.verifyModelHash(
            filePath: "/nonexistent/file.safetensors",
            expectedHash: "abc123"
        )
        XCTAssertFalse(matches, "Non-existent file should fail hash verification")
    }

    // MARK: - ValidationResult

    func testValidationResultSafeSummary() {
        let result = ValidationResult(isSafe: true, issues: [], warnings: ["minor note"])
        XCTAssertTrue(result.summary.contains("SAFE"))
        XCTAssertTrue(result.summary.contains("minor note"))
    }

    func testValidationResultUnsafeSummary() {
        let result = ValidationResult(
            isSafe: false,
            issues: [.dangerousFormat("pkl", reason: "pickle")],
            warnings: []
        )
        XCTAssertTrue(result.summary.contains("UNSAFE"))
        XCTAssertTrue(result.summary.contains("pkl"))
    }

    // MARK: - SecurityIssue Descriptions

    func testSecurityIssueDescriptions() {
        let issues: [SecurityIssue] = [
            .fileNotFound("/path"),
            .dangerousFormat("pkl", reason: "code execution"),
            .corruptedFile("bad header"),
            .suspiciousContent("pickle opcodes"),
            .dangerousCode("eval()"),
            .untrustedSource("http://evil.com"),
        ]

        for issue in issues {
            XCTAssertFalse(issue.description.isEmpty,
                "SecurityIssue should have a description: \(issue)")
        }
    }
}
