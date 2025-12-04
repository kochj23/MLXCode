#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'MLX Code.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Get or create Python group
python_group = project.main_group.find_subpath('Python', true)
python_group.set_source_tree('SOURCE_ROOT')

# Python scripts to add (relative to project directory)
scripts = [
  'Python/huggingface_downloader.py',
  'Python/mlx_inference.py',
  'Python/rag_system.py'
]

scripts.each do |script_path|
  # Add file reference
  file_ref = python_group.new_reference(script_path)
  file_ref.last_known_file_type = 'text.script.python'

  # Add to Copy Bundle Resources phase
  target.add_resources([file_ref])

  puts "Added #{script_path} to project"
end

project.save

puts "\n✅ Python scripts added to Xcode project"
puts "They will now be bundled in the app's Resources folder"
