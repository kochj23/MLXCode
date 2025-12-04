#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'MLX Code.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Find the Views group
views_group = project.main_group['MLX Code']['Views']

# Add GaugeView.swift
gauge_view_file = views_group.new_file('GaugeView.swift')
target.add_file_references([gauge_view_file])

project.save
puts "Successfully added GaugeView.swift to Xcode project"
