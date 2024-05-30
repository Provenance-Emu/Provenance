#!/usr/bin/env ruby

require 'xcodeproj'
project_path = ARGV[0]
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  puts "\n" + target.name + " files:" + "\n\n"

  files = target.source_build_phase.files.to_a.map do |pbx_build_file|
    pbx_build_file.file_ref.real_path.to_s

  end.select do |path|
    path.end_with?(".m", ".mm", ".swift", ".c", ".cpp")

  end.select do |path|
    File.exists?(path)
  end

  files.uniq!
  files.sort!

  puts files.join("\n")
  puts "\n"
end
