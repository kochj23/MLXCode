#!/usr/bin/env ruby

require 'xcodeproj'

project_path = 'MLX Code.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Find the Views group
views_group = project.main_group.find_subpath('MLX Code/Views', true)

# Remove incorrectly added files first
target.source_build_phase.files.to_a.each do |build_file|
  if build_file.file_ref && build_file.file_ref.path&.include?('MLX Code/Views/')
    if build_file.file_ref.path =~ /ImageGenerationPanel|VoiceCloningPanel/
      build_file.remove_from_project
      puts "🗑️  Removed incorrect reference: #{build_file.file_ref.path}"
    end
  end
end

# Remove from file references
views_group.files.to_a.each do |file_ref|
  if file_ref.path =~ /MLX Code\/Views\//
    file_ref.remove_from_project
    puts "🗑️  Removed incorrect file ref: #{file_ref.path}"
  end
end

# Add files correctly with just the filename
files_to_add = [
  'ImageGenerationPanel.swift',
  'VoiceCloningPanel.swift'
]

files_to_add.each do |filename|
  # Add file reference with just the filename
  file_ref = views_group.new_reference(filename)
  file_ref.source_tree = '<group>'

  # Add to target
  target.add_file_references([file_ref])

  puts "✅ Added #{filename} correctly"
end

# Save the project
project.save

puts "✅ Project saved"
