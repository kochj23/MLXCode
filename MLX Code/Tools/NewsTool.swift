//
//  NewsTool.swift
//  MLX Code
//
//  Created by Jordan Koch on 1/6/26.
//  Inspired by TinyLLM project by Jason Cox (https://github.com/jasonacox/TinyLLM)
//

import Foundation

/// Tool for fetching current tech news and headlines
/// Based on news integration features from TinyLLM by Jason Cox
class NewsTool: BaseTool {

    init() {
        super.init(
            name: "news",
            description: "Fetch current tech news headlines, including Swift, iOS, macOS, Xcode, and general software development news. Useful for staying updated on latest developments and best practices.",
            parameters: ToolParameterSchema(
                properties: [
                    "category": ParameterProperty(
                        type: "string",
                        description: "News category: 'swift', 'ios', 'macos', 'xcode', 'tech', 'all'",
                        enum: ["swift", "ios", "macos", "xcode", "tech", "all"],
                        default: "all"
                    ),
                    "count": ParameterProperty(
                        type: "integer",
                        description: "Number of headlines to fetch (default: 10)",
                        default: "10"
                    )
                ],
                required: []
            )
        )
    }

    override func execute(parameters: [String: Any], context: ToolContext) async throws -> ToolResult {
        let startTime = Date()

        let category = (try? stringParameter(parameters, key: "category")) ?? "all"
        let count = (try? intParameter(parameters, key: "count")) ?? 10

        logInfo("[News] Fetching \(category) news (top \(count))", category: "NewsTool")

        // Fetch news from multiple sources
        var headlines: [NewsHeadline] = []

        // Hacker News (tech news)
        if category == "all" || category == "tech" {
            headlines.append(contentsOf: await fetchHackerNews(count: min(count, 10)))
        }

        // Swift-specific sources
        if category == "swift" || category == "all" {
            headlines.append(contentsOf: fetchSwiftNews(count: min(count, 5)))
        }

        // iOS-specific sources
        if category == "ios" || category == "all" {
            headlines.append(contentsOf: fetchiOSNews(count: min(count, 5)))
        }

        // Sort by date and limit
        headlines.sort { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        headlines = Array(headlines.prefix(count))

        // Format output
        var output = "📰 **Latest \(category.capitalized) News** (\(headlines.count) headlines)\n\n"

        for (index, headline) in headlines.enumerated() {
            output += "\(index + 1). **\(headline.title)**\n"
            if let source = headline.source {
                output += "   Source: \(source)"
            }
            if let date = headline.date {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                output += " • \(formatter.localizedString(for: date, relativeTo: Date()))"
            }
            if let url = headline.url {
                output += "\n   URL: \(url)"
            }
            output += "\n\n"
        }

        let duration = Date().timeIntervalSince(startTime)
        logInfo("[News] ✅ Fetched \(headlines.count) headlines in \(String(format: "%.2f", duration))s", category: "NewsTool")

        return .success(output, metadata: [
            "category": category,
            "count": headlines.count,
            "duration": duration,
            "sources": headlines.compactMap { $0.source }.unique()
        ])
    }

    // MARK: - News Sources

    private func fetchHackerNews(count: Int) async -> [NewsHeadline] {
        var headlines: [NewsHeadline] = []

        do {
            // Hacker News API: Get top stories
            let topStoriesURL = URL(string: "https://hacker-news.firebaseio.com/v0/topstories.json")!
            let (data, _) = try await URLSession.shared.data(from: topStoriesURL)

            guard let storyIDs = try? JSONDecoder().decode([Int].self, from: data) else {
                return headlines
            }

            // Fetch first N stories
            for storyID in storyIDs.prefix(count) {
                if let headline = await fetchHackerNewsStory(id: storyID) {
                    headlines.append(headline)
                }
            }
        } catch {
            logError("[News] HackerNews fetch failed: \(error)", category: "NewsTool")
        }

        return headlines
    }

    private func fetchHackerNewsStory(id: Int) async -> NewsHeadline? {
        do {
            let storyURL = URL(string: "https://hacker-news.firebaseio.com/v0/item/\(id).json")!
            let (data, _) = try await URLSession.shared.data(from: storyURL)

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let title = json["title"] as? String else {
                return nil
            }

            let url = json["url"] as? String
            let timestamp = json["time"] as? Int
            let date = timestamp != nil ? Date(timeIntervalSince1970: TimeInterval(timestamp!)) : nil

            return NewsHeadline(
                title: title,
                url: url,
                source: "Hacker News",
                date: date
            )
        } catch {
            return nil
        }
    }

    private func fetchSwiftNews(count: Int) -> [NewsHeadline] {
        // Static Swift community sources (would be fetched dynamically in production)
        return [
            NewsHeadline(
                title: "Swift.org - Latest News",
                url: "https://www.swift.org/blog/",
                source: "Swift.org",
                date: Date()
            ),
            NewsHeadline(
                title: "Swift Forums - Recent Discussions",
                url: "https://forums.swift.org/latest",
                source: "Swift Forums",
                date: Date()
            )
        ]
    }

    private func fetchiOSNews(count: Int) -> [NewsHeadline] {
        // Static iOS development sources (would be fetched dynamically in production)
        return [
            NewsHeadline(
                title: "Apple Developer News",
                url: "https://developer.apple.com/news/",
                source: "Apple Developer",
                date: Date()
            ),
            NewsHeadline(
                title: "iOS Dev Weekly",
                url: "https://iosdevweekly.com/",
                source: "iOS Dev Weekly",
                date: Date()
            )
        ]
    }
}

// MARK: - Models

struct NewsHeadline: Codable {
    let title: String
    let url: String?
    let source: String?
    let date: Date?
}

// MARK: - Helpers

extension Array where Element: Hashable {
    func unique() -> [Element] {
        return Array(Set(self))
    }
}
