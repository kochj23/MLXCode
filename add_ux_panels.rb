#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'MLX Code.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Find the Views group
views_group = project.main_group.find_subpath('MLX Code/Views', true)

# Files to add
files_to_add = [
  'MLX Code/Views/ImageGenerationPanel.swift',
  'MLX Code/Views/VoiceCloningPanel.swift'
]

files_to_add.each do |file_path|
  # Check if file already exists in project
  existing_file = views_group.files.find { |f| f.path == File.basename(file_path) }

  unless existing_file
    # Add file reference
    file_ref = views_group.new_reference(file_path)

    # Add to target
    target.add_file_references([file_ref])

    puts "✅ Added #{File.basename(file_path)}"
  else
    puts "⚠️  #{File.basename(file_path)} already in project"
  end
end

# Save the project
project.save

puts "✅ Project saved"
