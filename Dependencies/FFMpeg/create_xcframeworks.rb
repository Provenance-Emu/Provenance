#!/usr/bin/env ruby

require 'fileutils'
require 'tty-table'
require 'tty-spinner'

# Define the framework names
FRAMEWORKS = %w[
  ffmpegkit
  libavcodec
  libavdevice
  libavfilter
  libavformat
  libavutil
  libswresample
  libswscale
]

# Define source directories
SOURCE_DIRS = {
  ios: 'ffmpeg-kit-full-gpl-6.0-ios-xcframework',
  tvos: 'ffmpeg-kit-full-gpl-6.0-tvos-xcframework',
  macos: 'ffmpeg-kit-full-gpl-6.0-macos-xcframework'
}

# Create output directory
FileUtils.mkdir_p('xcframeworks')

def collect_framework_variants(framework_name)
  variants = []

  SOURCE_DIRS.each do |platform, source_dir|
    xcframework_path = "#{source_dir}/#{framework_name}.xcframework"
    if File.directory?(xcframework_path)
      Dir["#{xcframework_path}/*"].each do |variant_path|
        if File.directory?(variant_path)
          variant_name = File.basename(variant_path)
          is_simulator = variant_name.include?('simulator')
          variants << {
            path: variant_path,
            platform: platform,
            arch: variant_name.split('-').last,
            type: is_simulator ? 'simulator' : 'device'
          }
        end
      end
    end
  end

  variants
end

def create_unified_xcframework(framework_name, variants)
  spinner = TTY::Spinner.new("[:spinner] Creating #{framework_name}.xcframework", format: :dots)
  spinner.auto_spin

  begin
    # Prepare xcodebuild command
    xcodebuild_args = ['xcodebuild', '-create-xcframework']

    variants.each do |variant|
      framework_path = Dir["#{variant[:path]}/*.framework"].first
      if framework_path
        xcodebuild_args += ['-framework', framework_path]
      end
    end

    xcodebuild_args += ['-output', "xcframeworks/#{framework_name}.xcframework"]

    # Execute xcodebuild command
    unless system(*xcodebuild_args)
      raise "Failed to create XCFramework for #{framework_name}"
    end

    spinner.success("Successfully created #{framework_name}.xcframework")
  rescue => e
    spinner.error("Failed to create #{framework_name}.xcframework: #{e.message}")
    raise if ENV['DEBUG']
  end
end

def print_framework_summary
  table = TTY::Table.new(
    header: ['Framework', 'Platforms', 'Architectures', 'Type']
  )

  FRAMEWORKS.each do |framework|
    xcframework_path = "xcframeworks/#{framework}.xcframework"
    next unless File.directory?(xcframework_path)

    platforms = []
    arches = []
    types = []

    Dir["#{xcframework_path}/*"].each do |variant_path|
      if File.directory?(variant_path)
        variant_name = File.basename(variant_path)
        platform, arch = variant_name.split('-')
        is_simulator = variant_name.include?('simulator')

        platforms << platform
        arches << arch
        types << (is_simulator ? 'simulator' : 'device')
      end
    end

    formatted_platforms = platforms.uniq.sort.map(&:capitalize).join(' ')
    formatted_arches = arches.uniq.sort.join(' ')
    formatted_types = types.uniq.sort.join('/')

    table << [framework, formatted_platforms, formatted_arches, formatted_types]
  end

  puts "\nGenerated XCFrameworks Summary:"
  puts table.render(:unicode, padding: [0, 1], alignments: [:left, :left, :left, :left])
end

# Main execution
begin
  FRAMEWORKS.each do |framework|
    variants = collect_framework_variants(framework)
    if variants.any?
      create_unified_xcframework(framework, variants)
    else
      puts "No variants found for #{framework}"
    end
  end

  # Print summary table
  print_framework_summary

  puts "\nAll XCFrameworks created in xcframeworks directory"
rescue => e
  puts "\nError: #{e.message}"
  puts "Run with DEBUG=1 for more details" unless ENV['DEBUG']
  exit 1
end
