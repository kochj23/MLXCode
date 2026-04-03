//
//  PromptTemplatesView.swift
//  MLX Code
//
//  Browse, filter, and launch prompt templates from the curated library.
//  Variables are filled in an inline form before sending to the chat.
//
//  Written by Jordan Koch.
//

import SwiftUI

struct PromptTemplatesView: View {
    @EnvironmentObject var chatVM: ChatViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedCategory: PromptTemplate.TemplateCategory? = nil
    @State private var searchText = ""
    @State private var selectedTemplate: PromptTemplate? = nil
    @State private var variableValues: [String: String] = [:]
    @State private var showingPreview = false

    private var filteredTemplates: [PromptTemplate] {
        PromptTemplateLibrary.all.filter { t in
            let matchesCategory = selectedCategory == nil || t.category == selectedCategory
            let matchesSearch   = searchText.isEmpty
                || t.name.localizedCaseInsensitiveContains(searchText)
                || t.description.localizedCaseInsensitiveContains(searchText)
                || t.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            if let template = selectedTemplate {
                templateDetailView(template)
            } else {
                emptyDetailView
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .navigationTitle("Prompt Templates")
    }

    // MARK: - Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            searchBar
            categoryPicker
            Divider()
            templateList
        }
        .navigationSplitViewColumnWidth(min: 240, ideal: 260)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Search templates…", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .padding([.horizontal, .top], 10)
        .padding(.bottom, 6)
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                categoryChip(nil, label: "All")
                ForEach(PromptTemplate.TemplateCategory.allCases, id: \.self) { cat in
                    categoryChip(cat, label: cat.rawValue)
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
    }

    private func categoryChip(_ cat: PromptTemplate.TemplateCategory?, label: String) -> some View {
        let selected = selectedCategory == cat
        return Button {
            selectedCategory = cat
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(selected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .foregroundColor(selected ? .white : .primary)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var templateList: some View {
        List(filteredTemplates, selection: $selectedTemplate) { template in
            TemplateRow(template: template)
                .tag(template)
        }
        .listStyle(.sidebar)
        .onChange(of: selectedTemplate) { _, newTemplate in
            if let t = newTemplate {
                variableValues = Dictionary(uniqueKeysWithValues: t.variables.map { ($0.name, "") })
            }
        }
    }

    // MARK: - Detail View

    private func templateDetailView(_ template: PromptTemplate) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                templateHeader(template)
                if !template.variables.isEmpty {
                    variableForm(template)
                }
                promptPreview(template)
                actionButtons(template)
            }
            .padding(20)
        }
    }

    private func templateHeader(_ t: PromptTemplate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: t.icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.name)
                        .font(.title3).fontWeight(.semibold)
                    Text(t.description)
                        .font(.subheadline).foregroundColor(.secondary)
                }
            }
            HStack(spacing: 6) {
                tagChip(t.category.rawValue, color: .accentColor)
                ForEach(t.tags.prefix(4), id: \.self) { tag in
                    tagChip(tag, color: .secondary)
                }
            }
        }
    }

    private func tagChip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.12))
            .foregroundColor(color)
            .cornerRadius(5)
    }

    private func variableForm(_ template: PromptTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fill in the blanks")
                .font(.subheadline).fontWeight(.semibold)
            ForEach(template.variables) { variable in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(variable.label)
                            .font(.caption).fontWeight(.medium)
                        if variable.required {
                            Text("required").font(.caption2).foregroundColor(.red)
                        }
                    }
                    TextField(variable.placeholder,
                              text: Binding(
                                get: { variableValues[variable.name] ?? "" },
                                set: { variableValues[variable.name] = $0 }
                              ))
                    .textFieldStyle(.roundedBorder)
                }
            }
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(10)
    }

    private func promptPreview(_ template: PromptTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Preview")
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(template.render(with: variableValues), forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            ScrollView {
                Text(template.render(with: variableValues))
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(height: 180)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2)))
        }
    }

    private func actionButtons(_ template: PromptTemplate) -> some View {
        let canSend = template.variables.filter { $0.required }
            .allSatisfy { !(variableValues[$0.name]?.isEmpty ?? true) }

        return HStack(spacing: 12) {
            Button("Send to Chat") {
                chatVM.userInput = template.render(with: variableValues)
                Task { await chatVM.sendMessage() }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canSend)

            Button("Load into Input") {
                chatVM.userInput = template.render(with: variableValues)
                dismiss()
            }
            .buttonStyle(.bordered)
            .disabled(!canSend)

            Spacer()
            Text(canSend ? "" : "Fill in required fields")
                .font(.caption).foregroundColor(.secondary)
        }
    }

    private var emptyDetailView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.largeTitle).foregroundColor(.secondary)
            Text("Select a template")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Template Row

struct TemplateRow: View {
    let template: PromptTemplate

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: template.icon)
                .frame(width: 22)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name)
                    .font(.subheadline)
                Text(template.description)
                    .font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
