#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Swaps one native core in the shipping project from its hand-maintained xcodeproj framework to
# its local SwiftPM package (docs/superpowers/plans/2026-10-12-shipping-core-package-swap.md).
#
#   ruby Scripts/dev/swap_core_to_package.rb snes9x            # dry run: diff of a temp copy
#   ruby Scripts/dev/swap_core_to_package.rb snes9x --apply    # edit in place
#   ruby Scripts/dev/swap_core_to_package.rb snes9x --verify   # 0 = swapped cleanly, 1 = not
#
# The xcodeproj gem is used READ-ONLY to find UUIDs. Writes are text edits, like
# Scripts/dev/prune_cores.rb: a gem open/save reorders objects and drops attributesByRelativePath.

require 'digest'
require 'fileutils'
require 'open3'
require 'set'
require 'tmpdir'
require 'xcodeproj'

# The gem warns about attributesByRelativePath on every open; this script never saves through the
# gem (the reason for the text edits), so the warning is noise here.
module Xcodeproj
  module UserInterface
    def self.warn(message)
      super unless message.include?('attributesByRelativePath')
    end
  end
end

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

TARGETS = ['Provenance', 'Provenance (AppStore)', 'Provenance-XL', 'Provenance-Lite (AppStore)'].freeze

CORES = {
  'snes9x' => { frameworks: %w[PVSNES.framework snes9x.framework], package: 'Cores/snes9x',
                products: %w[PVSNES9x-Dynamic], xcodeproj: 'Cores/snes9x/PVSNES9x.xcodeproj' },
  'fceu' => { frameworks: %w[PVFCEU.framework], package: 'Cores/FCEU',
              products: %w[PVFCEU-Dynamic], xcodeproj: 'Cores/FCEU/PVFCEU.xcodeproj' },
  'genesis' => { frameworks: %w[PVGenesis.framework], package: 'Cores/Genesis-Plus-GX',
                 products: %w[PVCoreGenesisPlus-Dynamic], xcodeproj: 'Cores/Genesis-Plus-GX/PVGenesis.xcodeproj' },
  'mupen64plus' => {
    frameworks: %w[PVMupen64Plus.framework PVMupen64PlusBridge.framework PVMupen64PlusRspHLE.framework
                   PVMupen64PlusVideoRice.framework PVMupen64PlusVideoGlideN64.framework PVRSPCXD4.framework],
    package: 'Cores/Mupen64Plus',
    products: %w[PVMupenGameCore-Dynamic PVMupen64PlusRspHLE-Dynamic PVRSPCXD4-Dynamic
                 PVMupen64PlusVideoRice-Dynamic PVMupen64PlusVideoGlideN64-Dynamic],
    xcodeproj: 'Cores/Mupen64Plus/PVMupen64Plus.xcodeproj'
  }
}.freeze

core_name = ARGV.find { |a| !a.start_with?('--') }
abort "usage: #{$PROGRAM_NAME} <#{CORES.keys.join('|')}> [--apply|--verify]" unless CORES.key?(core_name)
CORE = CORES.fetch(core_name)
ROOT = ENV.fetch('PROJECT_DIR', File.expand_path('../..', __dir__))
PBXPROJ = 'Provenance.xcodeproj/project.pbxproj'
WORKSPACE = 'Provenance.xcworkspace/contents.xcworkspacedata'

def uuid(*parts)
  'C0C0CAFE' + Digest::SHA1.hexdigest(parts.join('|'))[0, 16].upcase
end

# Old framework build files / file refs per the read-only gem model.
def old_refs(project)
  refs = project.objects.select { |o| o.isa == 'PBXFileReference' && CORE[:frameworks].include?(File.basename(o.path.to_s)) }
  ref_ids = refs.map(&:uuid).to_set
  build_files = project.objects.select { |o| o.isa == 'PBXBuildFile' && o.file_ref && ref_ids.include?(o.file_ref.uuid) }
  [refs, build_files]
end

def embed_phase(target)
  target.copy_files_build_phases.find { |p| p.dst_subfolder_spec == '10' && p.name.to_s.include?('Embed Frameworks') } ||
    target.copy_files_build_phases.find { |p| p.dst_subfolder_spec == '10' }
end

def verify(project_dir)
  project = Xcodeproj::Project.open(File.join(project_dir, 'Provenance.xcodeproj'))
  problems = []
  refs, build_files = old_refs(project)
  problems << "old file refs: #{refs.map(&:path).join(', ')}" unless refs.empty?
  problems << "old build files: #{build_files.size}" unless build_files.empty?
  TARGETS.each do |name|
    target = project.native_targets.find { |t| t.name == name } or (problems << "missing target #{name}"; next)
    have = target.package_product_dependencies.map(&:product_name)
    (CORE[:products] - have).each { |p| problems << "#{name}: no product #{p}" }
    linked = target.frameworks_build_phase.files.map { |f| f.product_ref&.product_name }.compact
    embedded = embed_phase(target)&.files&.map { |f| f.product_ref&.product_name }&.compact || []
    (CORE[:products] - linked).each { |p| problems << "#{name}: #{p} not linked" }
    (CORE[:products] - embedded).each { |p| problems << "#{name}: #{p} not embedded" }
  end
  ws = File.read(File.join(project_dir, WORKSPACE))
  problems << "workspace still lists #{CORE[:xcodeproj]}" if ws.include?(CORE[:xcodeproj])
  problems
end

def insert_list_line(text, owner_uuid, list_key, line)
  # Inserts `line` into the `list_key = ( ... );` list of the object owner_uuid, unless present.
  start = text.index(/^\t\t#{owner_uuid}(?: \/\*.*?\*\/)? = \{/) or raise "object #{owner_uuid} not found"
  stop = text.index(/^\t\t\};$/, start)
  body = text[start..stop]
  return text if body.include?(line.strip)

  if (m = body.match(/^(\t+)#{Regexp.escape(list_key)} = \(\n/))
    pos = start + m.end(0)
    text.insert(pos, "#{m[1]}\t#{line.strip}\n")
  else
    # list absent (e.g. a target without packageProductDependencies): add it before `name = `
    indent = body[/^(\t+)name = /, 1] or raise "cannot place #{list_key} in #{owner_uuid}"
    pos = start + body.index(/^\t+name = /)
    text.insert(pos, "#{indent}#{list_key} = (\n#{indent}\t#{line.strip}\n#{indent});\n")
  end
  text
end

def insert_object(text, section, definition)
  return text if text.include?(definition.lines.first.strip)

  marker = "/* End #{section} section */"
  if text.include?(marker)
    text.sub(marker) { "#{definition}#{marker}" }
  else
    text.sub("/* End PBXVariantGroup section */") { |m| "#{m}\n\n/* Begin #{section} section */\n#{definition}/* End #{section} section */" }
  end
end

def delete_objects_and_lines(text, ids)
  ids.each do |id|
    text = text.gsub(/^\t\t#{id}(?: \/\*.*?\*\/)? = \{[^\n]*\};\n/, '') # one-line objects
    text = text.gsub(/^\t\t#{id}(?: \/\*.*?\*\/)? = \{\n.*?^\t\t\};\n/m, '') # multi-line objects
    text = text.gsub(/^\s*#{id}(?: \/\*.*?\*\/)?,\n/, '') # list entries
  end
  text
end

def swap(project_dir)
  project = Xcodeproj::Project.open(File.join(project_dir, 'Provenance.xcodeproj'))
  path = File.join(project_dir, PBXPROJ)
  text = File.read(path)

  refs, build_files = old_refs(project)
  text = delete_objects_and_lines(text, (build_files + refs).map(&:uuid))

  pkg = uuid('pkg', CORE[:package])
  pkg_comment = %(XCLocalSwiftPackageReference "#{CORE[:package]}")
  text = insert_object(text, 'XCLocalSwiftPackageReference',
                       "\t\t#{pkg} /* #{pkg_comment} */ = {\n\t\t\tisa = XCLocalSwiftPackageReference;\n" \
                       "\t\t\trelativePath = #{CORE[:package]};\n\t\t};\n")
  text = insert_list_line(text, project.root_object.uuid, 'packageReferences', "#{pkg} /* #{pkg_comment} */,")

  TARGETS.each do |name|
    target = project.native_targets.find { |t| t.name == name } or raise "target #{name} not found"
    embed = embed_phase(target) or raise "#{name} has no Embed Frameworks phase"
    CORE[:products].each do |product|
      dep = uuid('dep', name, product)
      link = uuid('link', name, product)
      emb = uuid('embed', name, product)
      text = insert_object(text, 'XCSwiftPackageProductDependency',
                           "\t\t#{dep} /* #{product} */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n" \
                           "\t\t\tpackage = #{pkg} /* #{pkg_comment} */;\n\t\t\tproductName = \"#{product}\";\n\t\t};\n")
      text = insert_object(text, 'PBXBuildFile',
                           "\t\t#{link} /* #{product} in Frameworks */ = {isa = PBXBuildFile; productRef = #{dep} /* #{product} */; };\n")
      text = insert_object(text, 'PBXBuildFile',
                           "\t\t#{emb} /* #{product} in Embed Frameworks */ = {isa = PBXBuildFile; productRef = #{dep} /* #{product} */; " \
                           "settings = {ATTRIBUTES = (CodeSignOnCopy, ); }; };\n")
      text = insert_list_line(text, target.uuid, 'packageProductDependencies', "#{dep} /* #{product} */,")
      text = insert_list_line(text, target.frameworks_build_phase.uuid, 'files', "#{link} /* #{product} in Frameworks */,")
      text = insert_list_line(text, embed.uuid, 'files', "#{emb} /* #{product} in Embed Frameworks */,")
    end
  end
  File.write(path, text)

  ws_path = File.join(project_dir, WORKSPACE)
  ws = File.read(ws_path)
  ws = ws.gsub(%r{\s*<FileRef\s+location = "group:#{Regexp.escape(CORE[:xcodeproj])}">\s*</FileRef>}m, '')
  File.write(ws_path, ws)
end

if ARGV.include?('--verify')
  problems = verify(ROOT)
  problems.each { |p| warn p }
  exit(problems.empty? ? 0 : 1)
elsif ARGV.include?('--apply')
  swap(ROOT)
  out, status = Open3.capture2e('plutil', '-lint', File.join(ROOT, PBXPROJ))
  abort out unless status.success?
  puts "swapped #{core_name}; run with --verify"
else
  Dir.mktmpdir do |tmp|
    FileUtils.cp_r(File.join(ROOT, 'Provenance.xcodeproj'), tmp)
    FileUtils.mkdir_p(File.join(tmp, 'Provenance.xcworkspace'))
    FileUtils.cp(File.join(ROOT, WORKSPACE), File.join(tmp, WORKSPACE))
    swap(tmp)
    system('git', 'diff', '--no-index', '--stat', File.join(ROOT, PBXPROJ), File.join(tmp, PBXPROJ))
    system('git', 'diff', '--no-index', File.join(ROOT, WORKSPACE), File.join(tmp, WORKSPACE))
  end
end
