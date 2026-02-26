//
//  XcodeService.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import Foundation

/// Service for Xcode integration
/// Provides functionality to build, test, and interact with Xcode projects
actor XcodeService {
    /// Shared singleton instance
    static let shared = XcodeService()

    /// Current Xcode project path
    private var projectPath: String?

    private init() {}

    // MARK: - Project Management

    /// Sets the current Xcode project
    /// - Parameter path: Path to .xcodeproj or .xcworkspace
    /// - Throws: XcodeServiceError if project is invalid
    func setProject(path: String) async throws {
        guard SecurityUtils.validateFilePath(path) else {
            throw XcodeServiceError.invalidPath(path)
        }

        let expandedPath = (path as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw XcodeServiceError.projectNotFound(expandedPath)
        }

        // Verify it's an Xcode project or workspace
        let pathExtension = (expandedPath as NSString).pathExtension
        guard pathExtension == "xcodeproj" || pathExtension == "xcworkspace" else {
            throw XcodeServiceError.invalidProjectType
        }

        projectPath = expandedPath
        await SecureLogger.shared.info("Set Xcode project: \(path)", category: "XcodeService")
    }

    /// Gets the current project path
    /// - Returns: Current project path, or nil if not set
    func getCurrentProject() -> String? {
        return projectPath
    }

    // MARK: - Build Operations

    /// Builds the Xcode project
    /// - Parameters:
    ///   - scheme: Build scheme name
    ///   - configuration: Build configuration (Debug/Release)
    ///   - outputHandler: Optional callback for build output
    /// - Returns: Build result
    /// - Throws: XcodeServiceError if build fails
    func build(
        scheme: String? = nil,
        configuration: String = "Debug",
        outputHandler: ((String) -> Void)? = nil
    ) async throws -> BuildResult {
        guard let project = projectPath else {
            throw XcodeServiceError.noProjectSet
        }

        await SecureLogger.shared.info("Building project: \(project)", category: "XcodeService")

        var arguments = ["build"]

        // Add project/workspace flag
        if project.hasSuffix(".xcworkspace") {
            arguments.append(contentsOf: ["-workspace", project])
        } else {
            arguments.append(contentsOf: ["-project", project])
        }

        // Add scheme if provided
        if let scheme = scheme {
            arguments.append(contentsOf: ["-scheme", scheme])
        }

        // Add configuration
        arguments.append(contentsOf: ["-configuration", configuration])

        // Execute xcodebuild
        let output = try await executeXcodebuild(arguments: arguments, outputHandler: outputHandler)

        // Parse build result
        let succeeded = !output.contains("** BUILD FAILED **")
        let warnings = countOccurrences(of: "warning:", in: output)
        let errors = countOccurrences(of: "error:", in: output)

        let result = BuildResult(
            succeeded: succeeded,
            output: output,
            warnings: warnings,
            errors: errors
        )

        await SecureLogger.shared.info("Build \(succeeded ? "succeeded" : "failed") - Warnings: \(warnings), Errors: \(errors)", category: "XcodeService")

        return result
    }

    /// Cleans the build directory
    /// - Throws: XcodeServiceError if clean fails
    func clean() async throws {
        guard let project = projectPath else {
            throw XcodeServiceError.noProjectSet
        }

        await SecureLogger.shared.info("Cleaning project: \(project)", category: "XcodeService")

        var arguments = ["clean"]

        if project.hasSuffix(".xcworkspace") {
            arguments.append(contentsOf: ["-workspace", project])
        } else {
            arguments.append(contentsOf: ["-project", project])
        }

        _ = try await executeXcodebuild(arguments: arguments)

        await SecureLogger.shared.info("Clean completed", category: "XcodeService")
    }

    // MARK: - Test Operations

    /// Runs tests for the Xcode project
    /// - Parameters:
    ///   - scheme: Test scheme name
    ///   - testTarget: Optional specific test target
    ///   - outputHandler: Optional callback for test output
    /// - Returns: Test result
    /// - Throws: XcodeServiceError if tests fail to run
    func test(
        scheme: String,
        testTarget: String? = nil,
        outputHandler: ((String) -> Void)? = nil
    ) async throws -> TestResult {
        guard let project = projectPath else {
            throw XcodeServiceError.noProjectSet
        }

        await SecureLogger.shared.info("Running tests for project: \(project)", category: "XcodeService")

        var arguments = ["test"]

        if project.hasSuffix(".xcworkspace") {
            arguments.append(contentsOf: ["-workspace", project])
        } else {
            arguments.append(contentsOf: ["-project", project])
        }

        arguments.append(contentsOf: ["-scheme", scheme])

        if let target = testTarget {
            arguments.append(contentsOf: ["-only-testing", target])
        }

        let output = try await executeXcodebuild(arguments: arguments, outputHandler: outputHandler)

        // Parse test results
        let succeeded = output.contains("** TEST SUCCEEDED **")
        let totalTests = countOccurrences(of: "Test Case", in: output)
        let failedTests = countOccurrences(of: "failed", in: output)
        let passedTests = totalTests - failedTests

        let result = TestResult(
            succeeded: succeeded,
            output: output,
            totalTests: totalTests,
            passedTests: passedTests,
            failedTests: failedTests
        )

        await SecureLogger.shared.info("Tests \(succeeded ? "passed" : "failed") - Total: \(totalTests), Passed: \(passedTests), Failed: \(failedTests)", category: "XcodeService")

        return result
    }

    // MARK: - Project Information

    /// Lists all schemes in the project
    /// - Returns: Array of scheme names
    /// - Throws: XcodeServiceError if listing fails
    func listSchemes() async throws -> [String] {
        guard let project = projectPath else {
            throw XcodeServiceError.noProjectSet
        }

        var arguments = ["-list"]

        if project.hasSuffix(".xcworkspace") {
            arguments.append(contentsOf: ["-workspace", project])
        } else {
            arguments.append(contentsOf: ["-project", project])
        }

        let output = try await executeXcodebuild(arguments: arguments)

        // Parse schemes from output
        var schemes: [String] = []
        var inSchemesSection = false

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "Schemes:" {
                inSchemesSection = true
                continue
            }

            if inSchemesSection {
                if trimmed.isEmpty {
                    break
                }
                schemes.append(trimmed)
            }
        }

        return schemes
    }

    /// Lists all targets in the project
    /// - Returns: Array of target names
    /// - Throws: XcodeServiceError if listing fails
    func listTargets() async throws -> [String] {
        guard let project = projectPath else {
            throw XcodeServiceError.noProjectSet
        }

        var arguments = ["-list"]

        if project.hasSuffix(".xcworkspace") {
            arguments.append(contentsOf: ["-workspace", project])
        } else {
            arguments.append(contentsOf: ["-project", project])
        }

        let output = try await executeXcodebuild(arguments: arguments)

        // Parse targets from output
        var targets: [String] = []
        var inTargetsSection = false

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed == "Targets:" {
                inTargetsSection = true
                continue
            }

            if inTargetsSection {
                if trimmed.isEmpty || trimmed.hasSuffix(":") {
                    break
                }
                targets.append(trimmed)
            }
        }

        return targets
    }

    // MARK: - Archive & Export Operations

    /// Archives the Xcode project
    /// - Parameters:
    ///   - scheme: Build scheme name
    ///   - configuration: Build configuration (Release recommended for archives)
    /// - Returns: Archive result with paths
    /// - Throws: XcodeServiceError if archive fails
    func archive(
        scheme: String,
        configuration: String = "Release"
    ) async throws -> ArchiveResult {
        guard let project = projectPath else {
            throw XcodeServiceError.noProjectSet
        }

        await SecureLogger.shared.info("Archiving project: \(project) scheme: \(scheme)", category: "XcodeService")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let archivePath = NSTemporaryDirectory() + "MLXCode_\(scheme)_\(timestamp).xcarchive"

        var arguments: [String] = []

        if project.hasSuffix(".xcworkspace") {
            arguments.append(contentsOf: ["-workspace", project])
        } else {
            arguments.append(contentsOf: ["-project", project])
        }

        arguments.append(contentsOf: [
            "-scheme", scheme,
            "-configuration", configuration,
            "-archivePath", archivePath,
            "archive"
        ])

        let output = try await executeXcodebuild(arguments: arguments)

        let succeeded = !output.contains("** ARCHIVE FAILED **")
        guard succeeded else {
            throw XcodeServiceError.commandFailed(1, output)
        }

        // Find .app inside the archive
        let productsPath = (archivePath as NSString).appendingPathComponent("Products/Applications")
        let appName = try findAppBundle(in: productsPath)
        let appPath = (productsPath as NSString).appendingPathComponent(appName)

        // Read version info from the archive's Info.plist
        let versionInfo = try readVersionFromArchive(archivePath: archivePath)

        await SecureLogger.shared.info("Archive succeeded: \(archivePath)", category: "XcodeService")

        return ArchiveResult(
            archivePath: archivePath,
            appPath: appPath,
            appName: appName,
            version: versionInfo.marketing,
            build: versionInfo.build
        )
    }

    /// Exports an archive to a .app bundle
    /// - Parameters:
    ///   - archivePath: Path to .xcarchive
    ///   - exportMethod: Export method (development, ad-hoc, enterprise, developer-id)
    /// - Returns: Path to exported .app
    /// - Throws: XcodeServiceError if export fails
    func exportArchive(
        archivePath: String,
        exportMethod: String = "developer-id"
    ) async throws -> String {
        await SecureLogger.shared.info("Exporting archive: \(archivePath)", category: "XcodeService")

        let outputPath = NSTemporaryDirectory() + "MLXCode_Export_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: outputPath, withIntermediateDirectories: true)

        // Create export options plist
        let exportOptionsPlist = NSTemporaryDirectory() + "ExportOptions_\(UUID().uuidString).plist"
        let exportOptions: [String: Any] = [
            "method": exportMethod,
            "destination": "export"
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: exportOptions, format: .xml, options: 0)
        try plistData.write(to: URL(fileURLWithPath: exportOptionsPlist))

        let arguments = [
            "-exportArchive",
            "-archivePath", archivePath,
            "-exportPath", outputPath,
            "-exportOptionsPlist", exportOptionsPlist
        ]

        let _ = try await executeXcodebuild(arguments: arguments)

        // Clean up plist
        try? FileManager.default.removeItem(atPath: exportOptionsPlist)

        // Find the exported .app
        let appName = try findAppBundle(in: outputPath)
        let appPath = (outputPath as NSString).appendingPathComponent(appName)

        await SecureLogger.shared.info("Export succeeded: \(appPath)", category: "XcodeService")
        return appPath
    }

    /// Creates a DMG installer from an .app bundle
    /// - Parameters:
    ///   - appPath: Path to the .app bundle
    ///   - outputPath: Directory to save the DMG
    ///   - appName: Application name
    ///   - version: Marketing version string
    ///   - build: Build number string
    /// - Returns: Path to created DMG
    /// - Throws: XcodeServiceError if DMG creation fails
    func createDMG(
        appPath: String,
        outputPath: String,
        appName: String,
        version: String,
        build: String
    ) async throws -> String {
        await SecureLogger.shared.info("Creating DMG for \(appName) v\(version) build \(build)", category: "XcodeService")

        let dmgName = "\(appName)-v\(version)-build\(build).dmg"
        let dmgPath = (outputPath as NSString).appendingPathComponent(dmgName)

        // Create a temporary directory for DMG contents
        let stagingDir = NSTemporaryDirectory() + "DMGStaging_\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: stagingDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: stagingDir) }

        // Copy app to staging
        let stagedApp = (stagingDir as NSString).appendingPathComponent((appPath as NSString).lastPathComponent)
        try FileManager.default.copyItem(atPath: appPath, toPath: stagedApp)

        // Create symbolic link to /Applications
        let applicationsLink = (stagingDir as NSString).appendingPathComponent("Applications")
        try FileManager.default.createSymbolicLink(atPath: applicationsLink, withDestinationPath: "/Applications")

        // Remove existing DMG if present
        if FileManager.default.fileExists(atPath: dmgPath) {
            try FileManager.default.removeItem(atPath: dmgPath)
        }

        // Create DMG using hdiutil
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "create",
            "-volname", "\(appName) v\(version)",
            "-srcfolder", stagingDir,
            "-ov",
            "-format", "UDZO",
            dmgPath
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw XcodeServiceError.commandFailed(process.terminationStatus, "DMG creation failed: \(errorOutput)")
        }

        await SecureLogger.shared.info("DMG created: \(dmgPath)", category: "XcodeService")
        return dmgPath
    }

    /// Installs an .app to the user's Applications folder
    /// - Parameter appPath: Path to the .app bundle
    /// - Returns: Path where the app was installed
    /// - Throws: XcodeServiceError if install fails
    func installToApplications(appPath: String) async throws -> String {
        let appName = (appPath as NSString).lastPathComponent
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let applicationsDir = (homeDir as NSString).appendingPathComponent("Applications")
        let destinationPath = (applicationsDir as NSString).appendingPathComponent(appName)

        await SecureLogger.shared.info("Installing \(appName) to \(applicationsDir)", category: "XcodeService")

        // Create ~/Applications if it doesn't exist
        if !FileManager.default.fileExists(atPath: applicationsDir) {
            try FileManager.default.createDirectory(atPath: applicationsDir, withIntermediateDirectories: true)
        }

        // Remove existing version
        if FileManager.default.fileExists(atPath: destinationPath) {
            try FileManager.default.removeItem(atPath: destinationPath)
        }

        // Copy app
        try FileManager.default.copyItem(atPath: appPath, toPath: destinationPath)

        await SecureLogger.shared.info("Installed \(appName) to \(destinationPath)", category: "XcodeService")
        return destinationPath
    }

    /// Exports app and DMG to standard binary directories
    /// Copies to both /Volumes/Data/xcode/binaries/ and /Volumes/NAS/binaries/
    /// - Parameters:
    ///   - appPath: Path to the .app bundle
    ///   - dmgPath: Path to the DMG file (optional)
    ///   - appName: Application name
    ///   - version: Marketing version string
    /// - Returns: ExportResult with all destination paths
    /// - Throws: XcodeServiceError if export fails
    func exportToBinaries(
        appPath: String,
        dmgPath: String?,
        appName: String,
        version: String
    ) async throws -> ExportResult {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateStr = dateFormatter.string(from: Date())
        let dirName = "\(dateStr)-\(appName)-v\(version)"

        var localBinaryPath: String?
        var nasBinaryPath: String?
        var localDMGPath: String?
        var nasDMGPath: String?

        // Export to /Volumes/Data/xcode/binaries/
        let localBinariesBase = "/Volumes/Data/xcode/binaries"
        if FileManager.default.fileExists(atPath: localBinariesBase) {
            let localDir = (localBinariesBase as NSString).appendingPathComponent(dirName)
            try FileManager.default.createDirectory(atPath: localDir, withIntermediateDirectories: true)

            let destApp = (localDir as NSString).appendingPathComponent((appPath as NSString).lastPathComponent)
            try FileManager.default.copyItem(atPath: appPath, toPath: destApp)
            localBinaryPath = destApp

            if let dmg = dmgPath {
                let destDMG = (localDir as NSString).appendingPathComponent((dmg as NSString).lastPathComponent)
                try FileManager.default.copyItem(atPath: dmg, toPath: destDMG)
                localDMGPath = destDMG
            }

            await SecureLogger.shared.info("Exported to local binaries: \(localDir)", category: "XcodeService")
        }

        // Export to /Volumes/NAS/binaries/ (mandatory per CLAUDE.md)
        let nasBinariesBase = "/Volumes/NAS/binaries"
        if FileManager.default.fileExists(atPath: nasBinariesBase) {
            let nasDir = (nasBinariesBase as NSString).appendingPathComponent(dirName)
            try FileManager.default.createDirectory(atPath: nasDir, withIntermediateDirectories: true)

            let destApp = (nasDir as NSString).appendingPathComponent((appPath as NSString).lastPathComponent)
            try FileManager.default.copyItem(atPath: appPath, toPath: destApp)
            nasBinaryPath = destApp

            if let dmg = dmgPath {
                let destDMG = (nasDir as NSString).appendingPathComponent((dmg as NSString).lastPathComponent)
                try FileManager.default.copyItem(atPath: dmg, toPath: destDMG)
                nasDMGPath = destDMG
            }

            await SecureLogger.shared.info("Exported to NAS binaries: \(nasDir)", category: "XcodeService")
        } else {
            await SecureLogger.shared.warning("NAS not available at \(nasBinariesBase)", category: "XcodeService")
        }

        return ExportResult(
            appPath: appPath,
            dmgPath: dmgPath,
            localBinaryPath: localBinaryPath,
            nasBinaryPath: nasBinaryPath,
            localDMGPath: localDMGPath,
            nasDMGPath: nasDMGPath
        )
    }

    // MARK: - Version Management

    /// Gets version info from the project's Info.plist
    /// - Parameter infoPlistPath: Path to Info.plist (auto-detected if nil)
    /// - Returns: Version information
    /// - Throws: XcodeServiceError if version info cannot be read
    func getVersionInfo(infoPlistPath: String? = nil) async throws -> VersionInfo {
        guard let project = projectPath else {
            throw XcodeServiceError.noProjectSet
        }

        let plistPath: String
        if let path = infoPlistPath {
            plistPath = path
        } else {
            plistPath = try findInfoPlist(projectPath: project)
        }

        guard let plistData = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            throw XcodeServiceError.commandFailed(1, "Cannot read Info.plist at \(plistPath)")
        }

        let marketing = plist["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = plist["CFBundleVersion"] as? String ?? "1"
        let bundleId = plist["CFBundleIdentifier"] as? String ?? "unknown"

        return VersionInfo(marketing: marketing, build: build, bundleId: bundleId)
    }

    /// Increments the version in the project's Info.plist
    /// - Parameters:
    ///   - component: Which version component to increment (major, minor, patch, build)
    ///   - infoPlistPath: Path to Info.plist (auto-detected if nil)
    /// - Returns: New version info
    /// - Throws: XcodeServiceError if version cannot be updated
    func incrementVersion(
        component: VersionComponent,
        infoPlistPath: String? = nil
    ) async throws -> VersionInfo {
        guard let project = projectPath else {
            throw XcodeServiceError.noProjectSet
        }

        let plistPath: String
        if let path = infoPlistPath {
            plistPath = path
        } else {
            plistPath = try findInfoPlist(projectPath: project)
        }

        guard let plistData = FileManager.default.contents(atPath: plistPath),
              var plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            throw XcodeServiceError.commandFailed(1, "Cannot read Info.plist at \(plistPath)")
        }

        let currentVersion = plist["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let currentBuild = plist["CFBundleVersion"] as? String ?? "1"

        let versionParts = currentVersion.components(separatedBy: ".")
        var major = Int(versionParts.indices.contains(0) ? versionParts[0] : "1") ?? 1
        var minor = Int(versionParts.indices.contains(1) ? versionParts[1] : "0") ?? 0
        var patch = Int(versionParts.indices.contains(2) ? versionParts[2] : "0") ?? 0
        var build = Int(currentBuild) ?? 1

        switch component {
        case .major:
            major += 1
            minor = 0
            patch = 0
        case .minor:
            minor += 1
            patch = 0
        case .patch:
            patch += 1
        case .build:
            build += 1
        }

        let newVersion = "\(major).\(minor).\(patch)"
        let newBuild = "\(build)"

        plist["CFBundleShortVersionString"] = newVersion
        plist["CFBundleVersion"] = newBuild

        let newPlistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try newPlistData.write(to: URL(fileURLWithPath: plistPath))

        let bundleId = plist["CFBundleIdentifier"] as? String ?? "unknown"

        await SecureLogger.shared.info("Version incremented: \(currentVersion) -> \(newVersion), build \(currentBuild) -> \(newBuild)", category: "XcodeService")

        return VersionInfo(marketing: newVersion, build: newBuild, bundleId: bundleId)
    }

    // MARK: - Full Build Pipeline

    /// Executes the full build pipeline: build -> archive -> DMG -> install -> export
    /// - Parameters:
    ///   - scheme: Build scheme name
    ///   - configuration: Build configuration
    ///   - bumpVersion: Version component to bump before building (nil to skip)
    /// - Returns: Full pipeline result
    /// - Throws: XcodeServiceError if any step fails
    func fullBuildPipeline(
        scheme: String,
        configuration: String = "Release",
        bumpVersion: VersionComponent? = nil
    ) async throws -> PipelineResult {
        await SecureLogger.shared.info("Starting full build pipeline for \(scheme)", category: "XcodeService")

        // Step 1: Bump version if requested
        var versionInfo: VersionInfo?
        if let component = bumpVersion {
            versionInfo = try await incrementVersion(component: component)
        } else {
            versionInfo = try? await getVersionInfo()
        }

        // Step 2: Clean build
        try await clean()

        // Step 3: Build
        let buildResult = try await build(scheme: scheme, configuration: configuration)
        guard buildResult.succeeded else {
            throw XcodeServiceError.commandFailed(1, "Build failed with \(buildResult.errors) errors")
        }

        // Step 4: Archive
        let archiveResult = try await archive(scheme: scheme, configuration: configuration)

        // Step 5: Create DMG
        let appName = archiveResult.appName.replacingOccurrences(of: ".app", with: "")
        let version = versionInfo?.marketing ?? archiveResult.version
        let build = versionInfo?.build ?? archiveResult.build
        let dmgOutputDir = NSTemporaryDirectory()
        let dmgPath = try await createDMG(
            appPath: archiveResult.appPath,
            outputPath: dmgOutputDir,
            appName: appName,
            version: version,
            build: build
        )

        // Step 6: Install to Applications
        let installedPath = try await installToApplications(appPath: archiveResult.appPath)

        // Step 7: Export to binaries
        let exportResult = try await exportToBinaries(
            appPath: archiveResult.appPath,
            dmgPath: dmgPath,
            appName: appName,
            version: version
        )

        await SecureLogger.shared.info("Full pipeline completed for \(appName) v\(version)", category: "XcodeService")

        return PipelineResult(
            buildResult: buildResult,
            archiveResult: archiveResult,
            dmgPath: dmgPath,
            installedPath: installedPath,
            exportResult: exportResult,
            version: version,
            build: build
        )
    }

    // MARK: - Streaming Build

    /// Builds the project with streaming output via AsyncStream
    /// - Parameters:
    ///   - scheme: Build scheme name
    ///   - configuration: Build configuration
    /// - Returns: AsyncStream of build output events
    func streamingBuild(
        scheme: String? = nil,
        configuration: String = "Debug"
    ) -> AsyncStream<BuildOutput> {
        AsyncStream { continuation in
            Task {
                do {
                    guard let project = projectPath else {
                        continuation.yield(.error("No Xcode project set"))
                        continuation.finish()
                        return
                    }

                    var arguments = ["build"]

                    if project.hasSuffix(".xcworkspace") {
                        arguments.append(contentsOf: ["-workspace", project])
                    } else {
                        arguments.append(contentsOf: ["-project", project])
                    }

                    if let scheme = scheme {
                        arguments.append(contentsOf: ["-scheme", scheme])
                    }

                    arguments.append(contentsOf: ["-configuration", configuration])

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
                    process.arguments = arguments

                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe

                    continuation.yield(.progress("Starting build..."))

                    outputPipe.fileHandleForReading.readabilityHandler = { handle in
                        let data = handle.availableData
                        guard !data.isEmpty, let line = String(data: data, encoding: .utf8) else { return }

                        for singleLine in line.components(separatedBy: .newlines) where !singleLine.isEmpty {
                            if singleLine.contains("error:") {
                                continuation.yield(.error(singleLine))
                            } else if singleLine.contains("warning:") {
                                continuation.yield(.warning(singleLine))
                            } else {
                                continuation.yield(.line(singleLine))
                            }
                        }
                    }

                    try process.run()
                    process.waitUntilExit()

                    outputPipe.fileHandleForReading.readabilityHandler = nil

                    let succeeded = process.terminationStatus == 0
                    continuation.yield(.complete(succeeded))
                    continuation.finish()

                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                }
            }
        }
    }

    // MARK: - Private Helpers

    /// Finds an .app bundle in a directory
    private func findAppBundle(in directory: String) throws -> String {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: directory) else {
            throw XcodeServiceError.commandFailed(1, "Cannot read directory: \(directory)")
        }

        guard let app = contents.first(where: { $0.hasSuffix(".app") }) else {
            throw XcodeServiceError.commandFailed(1, "No .app bundle found in \(directory)")
        }

        return app
    }

    /// Reads version info from an archive's Info.plist
    private func readVersionFromArchive(archivePath: String) throws -> VersionInfo {
        let infoPlistPath = (archivePath as NSString).appendingPathComponent("Info.plist")

        guard let plistData = FileManager.default.contents(atPath: infoPlistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let appProperties = plist["ApplicationProperties"] as? [String: Any] else {
            return VersionInfo(marketing: "1.0.0", build: "1", bundleId: "unknown")
        }

        let version = appProperties["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = appProperties["CFBundleVersion"] as? String ?? "1"
        let bundleId = appProperties["CFBundleIdentifier"] as? String ?? "unknown"

        return VersionInfo(marketing: version, build: build, bundleId: bundleId)
    }

    /// Finds Info.plist for a project
    private func findInfoPlist(projectPath: String) throws -> String {
        let projectURL = URL(fileURLWithPath: projectPath)
        let projectDir = projectURL.deletingLastPathComponent()
        let projectName = projectURL.deletingPathExtension().lastPathComponent

        // Common locations for Info.plist
        let candidates = [
            projectDir.appendingPathComponent("\(projectName)/Info.plist").path,
            projectDir.appendingPathComponent("Info.plist").path,
            projectDir.appendingPathComponent("\(projectName)/Supporting Files/Info.plist").path
        ]

        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }

        throw XcodeServiceError.commandFailed(1, "Info.plist not found for project")
    }

    // MARK: - Private Methods

    /// Executes xcodebuild with given arguments
    /// - Parameters:
    ///   - arguments: Command line arguments
    ///   - outputHandler: Optional callback for output
    /// - Returns: Command output
    /// - Throws: XcodeServiceError if execution fails
    private func executeXcodebuild(
        arguments: [String],
        outputHandler: ((String) -> Void)? = nil
    ) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Setup output handlers if callback provided
        if let handler = outputHandler {
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                    handler(output)
                }
            }
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw XcodeServiceError.executionFailed(error)
        }

        // Read output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        var fullOutput = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        if !errorOutput.isEmpty {
            fullOutput += "\n" + errorOutput
        }

        // Check exit status
        guard process.terminationStatus == 0 else {
            throw XcodeServiceError.commandFailed(process.terminationStatus, fullOutput)
        }

        return fullOutput
    }

    /// Counts occurrences of a substring in a string
    /// - Parameters:
    ///   - substring: Substring to count
    ///   - string: String to search
    /// - Returns: Number of occurrences
    private func countOccurrences(of substring: String, in string: String) -> Int {
        return string.components(separatedBy: substring).count - 1
    }
}

// MARK: - Supporting Types

/// Result from a build operation
struct BuildResult {
    let succeeded: Bool
    let output: String
    let warnings: Int
    let errors: Int
}

/// Result from a test operation
struct TestResult {
    let succeeded: Bool
    let output: String
    let totalTests: Int
    let passedTests: Int
    let failedTests: Int
}

/// Result from an archive operation
struct ArchiveResult {
    let archivePath: String
    let appPath: String
    let appName: String
    let version: String
    let build: String
}

/// Result from a binary export operation
struct ExportResult {
    let appPath: String
    let dmgPath: String?
    let localBinaryPath: String?
    let nasBinaryPath: String?
    let localDMGPath: String?
    let nasDMGPath: String?
}

/// Version information for a project
struct VersionInfo {
    let marketing: String
    let build: String
    let bundleId: String
}

/// Version component to increment
enum VersionComponent: String {
    case major
    case minor
    case patch
    case build
}

/// Output events from a streaming build
enum BuildOutput {
    case line(String)
    case warning(String)
    case error(String)
    case progress(String)
    case complete(Bool)
}

/// Result from the full build pipeline
struct PipelineResult {
    let buildResult: BuildResult
    let archiveResult: ArchiveResult
    let dmgPath: String
    let installedPath: String
    let exportResult: ExportResult
    let version: String
    let build: String
}

/// Errors that can occur during Xcode service operations
enum XcodeServiceError: LocalizedError {
    case invalidPath(String)
    case projectNotFound(String)
    case invalidProjectType
    case noProjectSet
    case executionFailed(Error)
    case commandFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .invalidPath(let path):
            return "Invalid project path: \(path)"
        case .projectNotFound(let path):
            return "Project not found: \(path)"
        case .invalidProjectType:
            return "Path must be an .xcodeproj or .xcworkspace file"
        case .noProjectSet:
            return "No Xcode project has been set"
        case .executionFailed(let error):
            return "Failed to execute xcodebuild: \(error.localizedDescription)"
        case .commandFailed(let status, let output):
            return "xcodebuild failed with exit code \(status): \(output)"
        }
    }
}
