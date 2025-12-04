#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'MLX Code.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Find the Views group
views_group = project.main_group['MLX Code']['Views']

# Add ThinkingIndicatorView.swift
thinking_view_file = views_group.new_file('ThinkingIndicatorView.swift')
target.add_file_references([thinking_view_file])

project.save
puts "Successfully added ThinkingIndicatorView.swift to Xcode project"
