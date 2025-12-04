#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'MLX Code.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Find the Tools group
main_group = project.main_group['MLX Code']
tools_group = main_group['Tools']

if tools_group.nil?
  puts "Error: Tools group not found"
  exit 1
end

# List of tool files
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

# Remove old references and add new ones with correct paths
tool_files.each do |filename|
  # Remove any existing file reference
  existing_ref = tools_group.files.find { |f| f.path == filename }
  if existing_ref
    target.source_build_phase.remove_file_reference(existing_ref)
    existing_ref.remove_from_project
  end

  # Add file with correct path
  file_ref = tools_group.new_reference("Tools/#{filename}")
  target.source_build_phase.add_file_reference(file_ref)

  puts "Fixed: #{filename}"
end

project.save
puts "\nSuccessfully fixed #{tool_files.count} tool file paths"
