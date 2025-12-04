#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'MLX Code.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Find ViewModels group
main_group = project.main_group['MLX Code']
viewmodels_group = main_group['ViewModels']

# Add ChatViewModel+Tools.swift
file_ref = viewmodels_group.new_file('ChatViewModel+Tools.swift')
target.add_file_references([file_ref])

project.save
puts "Successfully added ChatViewModel+Tools.swift to Xcode project"
