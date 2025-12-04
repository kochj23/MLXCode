#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'MLX Code.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.first

# Get the resources build phase
resources_phase = target.resources_build_phase

# Find and remove duplicate Python script references
files_to_remove = []

resources_phase.files.each do |build_file|
  file_ref = build_file.file_ref
  next unless file_ref

  path = file_ref.path
  # Remove references with the wrong path
  if path && path.include?('Python/') && !path.include?('MLX Code/Python/')
    files_to_remove << build_file
    puts "Removing duplicate: #{path}"
  end
end

files_to_remove.each do |build_file|
  resources_phase.remove_file_reference(build_file.file_ref)
end

# Also clean up from file references
python_group = project.main_group.find_subpath('Python', false)
if python_group
  refs_to_remove = []
  python_group.files.each do |file_ref|
    if file_ref.path && !file_ref.path.include?('MLX Code/Python/')
      refs_to_remove << file_ref
      puts "Removing file reference: #{file_ref.path}"
    end
  end

  refs_to_remove.each { |ref| ref.remove_from_project }
end

project.save

puts "\n✅ Removed duplicate Python script references"
