//
//  MLXServiceTests.swift
//  MLX Code Tests
//
//  Unit tests for MLXService model loading
//

import XCTest
@testable import MLX_Code

@MainActor
class MLXServiceTests: XCTestCase {

    func testPythonResponseDecoding() throws {
        // Test all response types the daemon can send
        let testCases: [(json: String, shouldSucceed: Bool, description: String)] = [
            (
                json: #"{"type":"ready","message":"Daemon started and ready"}"#,
                shouldSucceed: true,
                description: "Ready response"
            ),
            (
                json: #"{"type":"debug","message":"load_model() called with: /path"}"#,
                shouldSucceed: true,
                description: "Debug response"
            ),
            (
                json: #"{"success":true,"path":"/Users/testuser/.mlx/models/phi-3.5-mini","name":"phi-3.5-mini","cached":false,"message":"Model loaded successfully"}"#,
                shouldSucceed: true,
                description: "Load success response (missing 'type' field)"
            ),
            (
                json: #"{"type":"token","token":"Hello"}"#,
                shouldSucceed: true,
                description: "Token response"
            ),
            (
                json: #"{"type":"complete","message":"Generation finished"}"#,
                shouldSucceed: true,
                description: "Complete response"
            ),
            (
                json: #"{"type":"error","error":"Something failed"}"#,
                shouldSucceed: true,
                description: "Error response"
            )
        ]

        print("\n=== Testing JSON Response Decoding ===\n")

        for (index, testCase) in testCases.enumerated() {
            print("Test \(index + 1): \(testCase.description)")
            print("  JSON: \(testCase.json)")

            guard let jsonData = testCase.json.data(using: .utf8) else {
                XCTFail("Failed to convert JSON string to data")
                continue
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(PythonResponse.self, from: jsonData)
                print("  ✅ Decoded successfully")
                print("     type: \(response.type)")
                print("     success: \(response.success ?? false)")
                print("     message: \(response.message ?? "nil")")
                print("     path: \(response.path ?? "nil")")

                if testCase.shouldSucceed {
                    print("  ✅ PASS\n")
                } else {
                    XCTFail("Should have failed but succeeded")
                    print("  ❌ FAIL: Should have thrown error\n")
                }
            } catch {
                print("  ❌ Decode error: \(error)")

                if !testCase.shouldSucceed {
                    print("  ✅ PASS (expected to fail)\n")
                } else {
                    XCTFail("Decoding failed: \(error)")
                    print("  ❌ FAIL: \(error)\n")
                }
            }
        }
    }

    func testModelPathValidation() throws {
        print("\n=== Testing Model Path Validation ===\n")

        let fileManager = FileManager.default
        let testPaths = [
            "~/.mlx/models/phi-3.5-mini",
            "/Users/testuser/.mlx/models/phi-3.5-mini",
            "/Users/testuser/Downloads/MLXCode/phi-3.5-mini"
        ]

        for path in testPaths {
            let expanded = (path as NSString).expandingTildeInPath
            print("Path: \(path)")
            print("  Expanded: \(expanded)")

            var isDir: ObjCBool = false
            let exists = fileManager.fileExists(atPath: expanded, isDirectory: &isDir)
            print("  Exists: \(exists)")
            print("  Is directory: \(isDir.boolValue)")

            if exists {
                let configPath = (expanded as NSString).appendingPathComponent("config.json")
                let configExists = fileManager.fileExists(atPath: configPath)
                print("  config.json exists: \(configExists)")

                if configExists {
                    print("  ✅ VALID MODEL\n")
                } else {
                    print("  ❌ Missing config.json\n")
                }
            } else {
                print("  ❌ Path does not exist\n")
            }
        }
    }

    func testDaemonCommunication() async throws {
        print("\n=== Testing Daemon JSON Communication ===\n")

        // Simulate what the daemon sends
        let daemonResponses = [
            #"{"type":"ready","message":"Daemon started and ready"}"#,
            #"{"success":true,"path":"/Users/testuser/.mlx/models/phi-3.5-mini","name":"phi-3.5-mini","cached":false,"message":"Model loaded successfully"}"#
        ]

        for response in daemonResponses {
            print("Response: \(response)")

            guard let data = response.data(using: .utf8) else {
                print("  ❌ Cannot convert to data\n")
                XCTFail("Failed to convert response to data")
                continue
            }

            do {
                let decoded = try JSONDecoder().decode(PythonResponse.self, from: data)
                print("  ✅ Decoded: type=\(decoded.type), success=\(decoded.success ?? false)\n")
            } catch {
                print("  ❌ Decode failed: \(error)\n")
                XCTFail("Failed to decode: \(error)")
            }
        }
    }

    func testFileSystemAccess() throws {
        print("\n=== Testing File System Access ===\n")

        let paths = [
            "~/.mlx/models",
            "/Users/testuser/.mlx/models",
            "/Users/testuser/Downloads/MLXCode"
        ]

        for path in paths {
            let expanded = (path as NSString).expandingTildeInPath
            print("Testing: \(expanded)")

            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: expanded)
                print("  ✅ Can list directory (\(contents.count) items)")

                // Try reading first few items
                for item in contents.prefix(2) {
                    let itemPath = (expanded as NSString).appendingPathComponent(item)
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir) {
                        if isDir.boolValue {
                            print("    📁 \(item)")
                        } else {
                            print("    📄 \(item)")
                        }
                    }
                }
                print("")
            } catch {
                print("  ❌ Cannot access: \(error)\n")
            }
        }
    }
}

// Make PythonResponse accessible for testing
private struct PythonResponse: Codable {
    let type: String
    let success: Bool?
    let error: String?
    let message: String?
    let token: String?
    let text: String?
    let cached: Bool?
    let path: String?
    let name: String?
    let stage: String?
    let skipped: Bool?
    let repo_id: String?
    let size_bytes: Int?
    let size_gb: Double?
    let quantization: String?
    let converted_to_mlx: Bool?
}
