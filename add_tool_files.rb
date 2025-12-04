#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'MLX Code.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Find or create Tools group
main_group = project.main_group['MLX Code']
tools_group = main_group['Tools'] || main_group.new_group('Tools')

# List of tool files to add
tool_files = [
  'ToolProtocol.swift',
  'MemorySystem.swift',
  'FileOperationsTool.swift',
  'BashTool.swift',
  'GrepTool.swift',
  'GlobTool.swift',
  'XcodeTool.swift',
  'ToolRegistry.swift',
  'SystemPrompts.swift'
]

# Add each file
tool_files.each do |filename|
  file_ref = tools_group.new_file(filename)
  target.add_file_references([file_ref])
  puts "Added: #{filename}"
end

project.save
puts "\nSuccessfully added #{tool_files.count} tool files to Xcode project"
