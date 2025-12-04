#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'MLX Code.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Find the Views group
views_group = project.main_group['MLX Code']['Views']

# Add HelpView.swift
help_view_file = views_group.new_file('HelpView.swift')
target.add_file_references([help_view_file])

# Find the Resources/Help group or create it
resources_group = project.main_group['MLX Code']['Resources']
if resources_group.nil?
  resources_group = project.main_group['MLX Code'].new_group('Resources')
end

help_group = resources_group['Help']
if help_group.nil?
  help_group = resources_group.new_group('Help')
end

# Add markdown files as resources
md_files = [
  'GettingStarted.md',
  'Features.md',
  'KeyboardShortcuts.md',
  'Troubleshooting.md'
]

md_files.each do |filename|
  file_ref = help_group.new_file("Help/#{filename}")
  target.add_resources([file_ref])
end

project.save
puts "Successfully added files to Xcode project"
