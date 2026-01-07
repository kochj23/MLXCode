//
//  WebFetchTool.swift
//  MLX Code
//
//  Created by Jordan Koch on 1/6/26.
//  Inspired by TinyLLM project by Jason Cox (https://github.com/jasonacox/TinyLLM)
//

import Foundation

/// Tool for fetching and summarizing web content (URLs, PDFs, documentation)
/// Based on web summarization features from TinyLLM by Jason Cox
class WebFetchTool: BaseTool {

    init() {
        super.init(
            name: "web_fetch",
            description: "Fetch and summarize content from URLs, including web pages, PDFs, and documentation. Useful for researching documentation, Stack Overflow, GitHub issues, or any web content.",
            parameters: ToolParameterSchema(
                properties: [
                    "url": ParameterProperty(
                        type: "string",
                        description: "The URL to fetch and summarize"
                    ),
                    "query": ParameterProperty(
                        type: "string",
                        description: "Optional specific question to answer about the content"
                    ),
                    "max_length": ParameterProperty(
                        type: "integer",
                        description: "Maximum length of summary in words (default: 500)",
                        default: "500"
                    )
                ],
                required: ["url"]
            )
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let startTime = Date()

        // Extract parameters
        let urlString = try stringParameter(parameters, key: "url")
        let query = try? stringParameter(parameters, key: "query")
        let maxLength = (try? intParameter(parameters, key: "max_length")) ?? 500

        // 🔒 SECURITY: Validate URL (prevent SSRF attacks)
        let url: URL
        do {
            url = try CommandValidator.validateSafeURL(urlString)
        } catch {
            return .failure("URL validation failed: \(error.localizedDescription)")
        }

        logInfo("[WebFetch] Fetching validated URL: \(urlString)", category: "WebFetchTool")

        do {
            // Fetch content
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("Invalid response from server")
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                return .failure("HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
            }

            // Detect content type
            let contentType = httpResponse.mimeType ?? "text/html"

            // Process content based on type
            var content: String
            var summary: String

            if contentType.contains("html") {
                // Parse HTML
                content = extractTextFromHTML(data: data)
                summary = summarizeText(content, maxWords: maxLength, query: query)
            } else if contentType.contains("pdf") {
                // Parse PDF (simplified - would need PDFKit for full implementation)
                content = "PDF content (length: \(data.count) bytes)"
                summary = "PDF document fetched. Full PDF parsing requires PDFKit integration."
            } else if contentType.contains("json") {
                // JSON response
                if let jsonString = String(data: data, encoding: .utf8) {
                    content = jsonString
                    summary = summarizeText(content, maxWords: maxLength, query: query)
                } else {
                    content = "Binary JSON data"
                    summary = "JSON data received but could not be decoded to text"
                }
            } else {
                // Plain text or other
                content = String(data: data, encoding: .utf8) ?? "Binary content"
                summary = summarizeText(content, maxWords: maxLength, query: query)
            }

            let duration = Date().timeIntervalSince(startTime)

            var result = """
            📄 **Fetched:** \(urlString)
            📊 **Content Type:** \(contentType)
            📏 **Size:** \(formatBytes(data.count))
            ⏱️ **Fetch Time:** \(String(format: "%.2f", duration))s

            **Summary:**
            \(summary)
            """

            if let query = query {
                result += "\n\n**Question:** \(query)"
            }

            logInfo("[WebFetch] ✅ Success: \(formatBytes(data.count)) in \(String(format: "%.2f", duration))s", category: "WebFetchTool")

            return .success(result, metadata: [
                "url": urlString,
                "content_type": contentType,
                "size": data.count,
                "duration": duration,
                "word_count": content.components(separatedBy: .whitespacesAndNewlines).count
            ])

        } catch {
            logError("[WebFetch] ❌ Error: \(error.localizedDescription)", category: "WebFetchTool")
            return .failure("Failed to fetch URL: \(error.localizedDescription)")
        }
    }

    // MARK: - HTML Processing

    private func extractTextFromHTML(data: Data) -> String {
        guard let html = String(data: data, encoding: .utf8) else {
            return ""
        }

        // Simple HTML tag stripping (basic implementation)
        // Production would use proper HTML parser
        var text = html

        // Remove scripts and styles
        text = text.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: .regularExpression)

        // Remove HTML tags
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)

        // Decode HTML entities
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")

        // Clean up whitespace
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        return text
    }

    // MARK: - Summarization

    private func summarizeText(_ text: String, maxWords: Int, query: String?) -> String {
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        if words.count <= maxWords {
            return text
        }

        // Simple truncation with ellipsis
        // Production would use actual summarization model
        let truncated = words.prefix(maxWords).joined(separator: " ")
        return truncated + "... (truncated from \(words.count) words)"
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
