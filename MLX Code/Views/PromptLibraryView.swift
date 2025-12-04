//
//  PromptLibraryView.swift
//  MLX Code
//
//  Created on 2025-11-18.
//  Copyright © 2025. All rights reserved.
//

import SwiftUI

/// View displaying the prompt template library
struct PromptLibraryView: View {
    @StateObject private var manager = PromptTemplateManager.shared
    @State private var searchText = ""
    @State private var selectedCategory: TemplateCategory?
    @State private var selectedTemplate: PromptTemplate?
    @State private var showingTemplateEditor = false
    @State private var variableValues: [String: String] = [:]

    let onSelectTemplate: (String) -> Void

    var filteredTemplates: [PromptTemplate] {
        var templates = manager.allTemplates

        // Filter by category
        if let category = selectedCategory {
            templates = templates.filter { $0.category == category }
        }

        // Filter by search
        if !searchText.isEmpty {
            templates = templates.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }

        return templates
    }

    var body: some View {
        NavigationSplitView {
            // Category sidebar
            categoryList
        } content: {
            // Template list
            templateList
        } detail: {
            // Template detail/editor
            templateDetail
        }
        .navigationTitle("Prompt Library")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingTemplateEditor = true }) {
                    Label("New Template", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingTemplateEditor) {
            TemplateEditorView(template: nil) { newTemplate in
                manager.addCustomTemplate(newTemplate)
            }
        }
    }

    // MARK: - Subviews

    private var categoryList: some View {
        List(selection: $selectedCategory) {
            Section("Categories") {
                ForEach(TemplateCategory.allCases) { category in
                    Button(action: { selectedCategory = category }) {
                        HStack {
                            Image(systemName: category.icon)
                                .frame(width: 20)

                            Text(category.rawValue)

                            Spacer()

                            Text("\(manager.templates(in: category).count)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(category)
                }
            }

            Section("Quick Actions") {
                Button(action: { selectedCategory = nil }) {
                    Label("All Templates", systemImage: "list.bullet")
                }

                Button(action: { /* Show favorites */ }) {
                    Label("Favorites", systemImage: "star.fill")
                }

                Button(action: { /* Show recent */ }) {
                    Label("Recently Used", systemImage: "clock")
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180)
    }

    private var templateList: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search templates...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()

            Divider()

            // Template list
            List(filteredTemplates, selection: $selectedTemplate) { template in
                TemplateRowView(template: template)
                    .tag(template)
            }
            .listStyle(.plain)
        }
        .frame(minWidth: 300)
    }

    private var templateDetail: some View {
        Group {
            if let template = selectedTemplate {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: template.category.icon)
                                    .foregroundColor(.accentColor)

                                Text(template.name)
                                    .font(.title)
                                    .fontWeight(.bold)

                                Spacer()

                                if template.isBuiltIn {
                                    Text("Built-in")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }

                            Text(template.description)
                                .foregroundColor(.secondary)

                            // Tags
                            FlowLayout(spacing: 8) {
                                ForEach(template.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.2))
                                        .cornerRadius(4)
                                }
                            }
                        }

                        Divider()

                        // Variables
                        if !template.variables.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Variables")
                                    .font(.headline)

                                ForEach(template.variables) { variable in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(variable.name)
                                                .fontWeight(.medium)

                                            if variable.isRequired {
                                                Text("*")
                                                    .foregroundColor(.red)
                                            }
                                        }

                                        Text(variable.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)

                                        TextField(variable.placeholder ?? variable.name, text: binding(for: variable.name))
                                            .textFieldStyle(.roundedBorder)
                                    }
                                }
                            }

                            Divider()
                        }

                        // Template preview
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Template Preview")
                                .font(.headline)

                            Text(template.render(with: variableValues))
                                .font(.system(.body, design: .monospaced))
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                        }

                        // Actions
                        HStack {
                            Button(action: { useTemplate(template) }) {
                                Label("Use Template", systemImage: "paperplane.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canUseTemplate(template))

                            Button(action: { copyTemplate(template) }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }

                            if !template.isBuiltIn {
                                Button(action: { editTemplate(template) }) {
                                    Label("Edit", systemImage: "pencil")
                                }

                                Button(role: .destructive, action: { deleteTemplate(template) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }

                        // Stats
                        if template.useCount > 0 {
                            Divider()

                            HStack {
                                Text("Used \(template.useCount) times")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if let lastUsed = template.lastUsedAt {
                                    Text("• Last used \(lastUsed, style: .relative) ago")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding()
                }
            } else {
                VStack {
                    Image(systemName: "doc.text")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    Text("Select a template")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 400)
    }

    // MARK: - Helper Methods

    private func binding(for variableName: String) -> Binding<String> {
        Binding(
            get: { variableValues[variableName] ?? "" },
            set: { variableValues[variableName] = $0 }
        )
    }

    private func canUseTemplate(_ template: PromptTemplate) -> Bool {
        // Check all required variables are filled
        for variable in template.variables where variable.isRequired {
            if variableValues[variable.name]?.isEmpty ?? true {
                return false
            }
        }
        return true
    }

    private func useTemplate(_ template: PromptTemplate) {
        let rendered = template.render(with: variableValues)
        onSelectTemplate(rendered)

        // Record usage
        manager.recordTemplateUsage(template)

        // Clear variables
        variableValues.removeAll()
    }

    private func copyTemplate(_ template: PromptTemplate) {
        let rendered = template.render(with: variableValues)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(rendered, forType: .string)
    }

    private func editTemplate(_ template: PromptTemplate) {
        selectedTemplate = template
        showingTemplateEditor = true
    }

    private func deleteTemplate(_ template: PromptTemplate) {
        manager.deleteTemplate(template)
        selectedTemplate = nil
    }
}

// MARK: - Template Row View

struct TemplateRowView: View {
    let template: PromptTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: template.category.icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)

                Text(template.name)
                    .fontWeight(.medium)

                Spacer()

                if template.isBuiltIn {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
            }

            Text(template.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Template Editor View

struct TemplateEditorView: View {
    let template: PromptTemplate?
    let onSave: (PromptTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var category: TemplateCategory = .custom
    @State private var description = ""
    @State private var templateText = ""
    @State private var tags = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Information") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(TemplateCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    TextField("Description", text: $description)
                }

                Section("Template") {
                    TextEditor(text: $templateText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 200)

                    Text("Use {{variable}} syntax for variables")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Tags") {
                    TextField("Comma-separated tags", text: $tags)
                }
            }
            .navigationTitle(template == nil ? "New Template" : "Edit Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(name.isEmpty || templateText.isEmpty)
                }
            }
        }
        .frame(width: 600, height: 500)
        .onAppear {
            loadTemplate()
        }
    }

    private func loadTemplate() {
        guard let template = template else { return }
        name = template.name
        category = template.category
        description = template.description
        templateText = template.template
        tags = template.tags.joined(separator: ", ")
    }

    private func saveTemplate() {
        let tagArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        let newTemplate = PromptTemplate(
            id: template?.id ?? UUID(),
            name: name,
            category: category,
            description: description,
            template: templateText,
            variables: extractVariables(from: templateText),
            tags: tagArray,
            isBuiltIn: false
        )

        onSave(newTemplate)
        dismiss()
    }

    private func extractVariables(from text: String) -> [TemplateVariable] {
        var variables: [TemplateVariable] = []
        let pattern = "\\{\\{([^}]+)\\}\\}"

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let variableName = String(text[range])
                    if !variables.contains(where: { $0.name == variableName }) {
                        variables.append(TemplateVariable(
                            name: variableName,
                            description: variableName.capitalized,
                            isRequired: true
                        ))
                    }
                }
            }
        }

        return variables
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize
        var frames: [CGRect]

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var frames: [CGRect] = []
            var lineFrames: [CGRect] = []
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            func newLine() {
                let lineWidth = lineFrames.map({ $0.width }).reduce(0, +) + spacing * CGFloat(lineFrames.count - 1)
                var x: CGFloat = 0
                for frame in lineFrames {
                    frames.append(CGRect(x: x, y: y, width: frame.width, height: frame.height))
                    x += frame.width + spacing
                }
                y += lineHeight + spacing
                lineFrames.removeAll()
                lineHeight = 0
            }

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                let currentLineWidth = lineFrames.map({ $0.width }).reduce(0, +) + spacing * CGFloat(lineFrames.count)

                if !lineFrames.isEmpty && currentLineWidth + size.width > maxWidth {
                    newLine()
                }

                lineFrames.append(CGRect(origin: .zero, size: size))
                lineHeight = max(lineHeight, size.height)
            }

            if !lineFrames.isEmpty {
                newLine()
            }

            self.size = CGSize(width: maxWidth, height: y)
            self.frames = frames
        }
    }
}

// MARK: - Preview

struct PromptLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        PromptLibraryView { prompt in
            print("Selected: \(prompt)")
        }
        .frame(width: 1000, height: 700)
    }
}
