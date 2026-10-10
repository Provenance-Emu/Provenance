#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Removes retired native cores from the shipping project, workspace and submodules
# (docs/superpowers/specs/2026-10-10-core-audit.md; batch 5 of the dev-workspace plan).
# Atari800 and Gambatte are deliberately not listed: they ship deprecated (`PVCore.deprecatedCores`).
#
#   ruby Scripts/dev/prune_cores.rb            # dry run: edits a temp copy, prints the diff + counts
#   ruby Scripts/dev/prune_cores.rb --apply    # edits in place, `git rm`s the core dirs, trims .gitmodules
#
# The pbxproj is edited as TEXT, not through the xcodeproj gem: an xcodeproj (1.28.1) open/save
# reorders hand-placed objects and drops `attributesByRelativePath` (CodeSignOnCopy for the
# embedded FFmpeg/OpenSSL xcframeworks). This script only deletes whole object definitions and
# `UUID /* comment */,` list lines, so every other byte is preserved.
#
# Cores/Debug is NOT pruned: Mupen64Plus, Dolphin, PPSSPP and Provenance.xcodeproj use its
# PVDebug.c simulator stub.

require 'fileutils'
require 'open3'
require 'set'
require 'tmpdir'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

ROOT = File.expand_path('../..', __dir__)
APPLY = ARGV.include?('--apply')
PBXPROJ = 'Provenance.xcodeproj/project.pbxproj'
WORKSPACE = 'Provenance.xcworkspace/contents.xcworkspacedata'

# dir => frameworks (file-reference basenames, incl. the pre-SPM group-only refs), SPM products,
# local package paths
CORES = {
  'Bliss' => { frameworks: %w[PVBliss.framework PVBliss-tvOS.framework], products: %w[PVBliss-Dynamic], packages: %w[Cores/Bliss] },
  'CrabEMU' => { frameworks: %w[PVCrabEmu.framework], products: %w[PVCrabEmu-Dynamic], packages: %w[Cores/CrabEMU] },
  'PokeMini' => { frameworks: %w[PVPokeMini.framework], products: %w[PVPokeMini-Dynamic], packages: %w[Cores/PokeMini] },
  'VisualBoyAdvance-M' => { frameworks: %w[PVGBA.framework], products: %w[PVVisualBoyAdvance-Dynamic], packages: %w[Cores/VisualBoyAdvance-M] },
  'VirtualJaguar' => { frameworks: %w[PVVirtualJaguar.framework], products: %w[PVVirtualJaguar-Dynamic], packages: %w[Cores/VirtualJaguar] },
  'O2EM' => { frameworks: %w[PVO2EM.framework] },
  'Desmume2015' => { frameworks: %w[PVDesmume2015.framework] },
  'melonDS' => { frameworks: %w[PVMelonDS.framework PVMelonDSRetro.framework] },
  'BeetlePSX' => { frameworks: %w[PVBeetlePSX.framework] },
  'DosBox' => { frameworks: %w[PVDosBox.framework PVDosBoxRetro.framework] },
  'DuckStation' => { frameworks: %w[PVDuckStation.framework] },
  'FreeIntv' => { frameworks: %w[PVFreeIntv.framework] },
  'GameMusicEmu' => { frameworks: %w[PVGME.framework] },
  'Gearcoleco' => { frameworks: %w[PVGearcoleco.framework] },
  'Mini_vMac' => { frameworks: %w[PVMiniVMac.framework PVMiniVMacRetro.framework] },
  'Mu' => { frameworks: %w[PVMu.framework] },
  'Mupen64Plus-NX' => { frameworks: %w[PVMupen64Plus-NX.framework] },
  'Potator' => { frameworks: %w[PVPotator.framework] },
  'Reicast' => { frameworks: %w[PVReicast.framework] },
  'VecX' => { frameworks: %w[PVVecX.framework PVVecXGL.framework] },
  'Yabause' => { frameworks: %w[PVYabause.framework] },
  'fuse' => { frameworks: %w[PVFuse.framework] },
  'opera' => { frameworks: %w[PVOpera.framework] },
  'pcsx_rearmed' => { frameworks: %w[PVPCSXRearmed.framework] },
  'supergrafx' => { frameworks: %w[PVSupergrafx.framework] },
  'snesticle' => { frameworks: %w[PVSnesticle.framework] },
  'Play' => { frameworks: %w[PVPlay.framework] },
  'JollyGoodEmulation' => {},
  'Sudachi' => {},
  'sm64ex' => {},
}.freeze

# Embedded frameworks with no producer anywhere (PVFreeDO-Dynamic, 4DO's product, stays).
ORPHAN_FRAMEWORKS = %w[PVLibRetro.framework PVFreeDO.framework].freeze

FRAMEWORKS = (CORES.values.flat_map { |c| c[:frameworks] || [] } + ORPHAN_FRAMEWORKS).to_set
PRODUCTS = CORES.values.flat_map { |c| c[:products] || [] }.to_set
PACKAGES = CORES.values.flat_map { |c| c[:packages] || [] }.to_set
CORE_ALT = CORES.keys.map { |k| Regexp.escape(k) }.join('|')
# A path inside a pruned core directory, with or without a $(PROJECT_DIR)/ or group: prefix.
CORE_PATH = %r{(?:\A|/|:)Cores/(?:#{CORE_ALT})(?:/|\z)}

# Objects that only exist to point at another object; they go when their target goes.
DEPENDENT_ISAS = %w[
  PBXBuildFile PBXTargetDependency PBXContainerItemProxy PBXReferenceProxy XCSwiftPackageProductDependency
].to_set
# Object IDs: Xcode's 24-hex form plus hand-made 16-hex and alphanumeric ones (C0C0CA01..., B3THUMB...).
UUID = /\b(?=[0-9A-Z]*\d)[0-9A-Z]{16,32}\b/
OBJECT_START = /\A\t\t(#{UUID})(?: \/\*.*?\*\/)? = \{/
LIST_ENTRY = /\A\s*(#{UUID})(?: \/\*.*?\*\/)?,\s*\z/

PbxObject = Struct.new(:uuid, :isa, :first, :last, :text)

def unquote(value)
  value = value.strip
  value.start_with?('"') ? value[1..-2] : value
end

def field(text, key)
  m = text.match(/(?:\A|[\s{;])#{key} = ("(?:[^"\\]|\\.)*"|[^;]+);/)
  m && unquote(m[1])
end

def parse_objects(lines)
  objects = {}
  i = 0
  while i < lines.size
    m = lines[i].match(OBJECT_START)
    unless m
      i += 1
      next
    end
    first = i
    i += 1 until lines[i].rstrip.end_with?('};') && (i == first || lines[i] == "\t\t};\n" || lines[i] == "\t\t};")
    text = lines[first..i].join
    objects[m[1]] = PbxObject.new(m[1], field(text, 'isa'), first, i, text)
    i += 1
  end
  objects
end

def seed?(obj)
  case obj.isa
  when 'PBXFileReference', 'PBXReferenceProxy'
    path = field(obj.text, 'path') || ''
    FRAMEWORKS.include?(File.basename(path)) || path.match?(CORE_PATH)
  when 'PBXGroup'
    (field(obj.text, 'path') || '').match?(CORE_PATH)
  when 'XCLocalSwiftPackageReference'
    PACKAGES.include?(field(obj.text, 'relativePath').to_s.chomp('/'))
  when 'XCSwiftPackageProductDependency'
    PRODUCTS.include?(field(obj.text, 'productName').to_s)
  else
    false
  end
end

# UUIDs an object points at through `key = UUID` (not list members).
def scalar_refs(obj)
  obj.text.scan(/(\w+) = (#{UUID})/).reject { |key, _| key == 'remoteGlobalIDString' }.map(&:last)
end

def children(obj)
  body = obj.text[/children = \((.*?)\);/m, 1]
  body ? body.scan(UUID) : []
end

def referenced_uuids(text)
  # Every UUID used as a reference (everything except object keys and remote IDs in other projects).
  text.each_line.flat_map do |line|
    next [] if line.include?('remoteGlobalIDString')
    line = line.sub(OBJECT_START, '')
    line.scan(UUID)
  end.to_set
end

def prune_pbxproj(path, counts)
  original = File.read(path)
  lines = original.lines
  objects = parse_objects(lines)
  removed = objects.values.select { |o| seed?(o) }.map(&:uuid).to_set

  loop do
    before = removed.size
    objects.each_value do |obj|
      next if removed.include?(obj.uuid)
      hits = scalar_refs(obj).select { |u| removed.include?(u) }
      next if hits.empty?
      abort "#{obj.uuid} (#{obj.isa}) points at removed #{hits.join(', ')} and is not a dependent kind" unless DEPENDENT_ISAS.include?(obj.isa)
      removed << obj.uuid
    end
    objects.each_value { |obj| children(obj).each { |c| removed << c } if obj.isa == 'PBXGroup' && removed.include?(obj.uuid) }
    break if removed.size == before
  end

  drop = Set.new
  removed.each do |uuid|
    obj = objects[uuid] or next
    counts[obj.isa] += 1
    (obj.first..obj.last).each { |n| drop << n }
  end
  lines.each_with_index do |line, n|
    next if drop.include?(n)
    if (m = line.match(LIST_ENTRY)) && removed.include?(m[1])
      drop << n
      counts['list entries'] += 1
    elsif line.match?(/\A\s*"[^"]*",\s*\z/) && unquote(line.strip.chomp(',')).match?(CORE_PATH)
      drop << n
      counts['build-setting path entries'] += 1
    end
  end

  pruned = lines.each_with_index.reject { |_, n| drop.include?(n) }.map(&:first).join
  leftovers = removed.select { |u| pruned.include?(u) }
  abort "removed UUIDs still referenced: #{leftovers.to_a.join(', ')}" unless leftovers.empty?
  if (line = pruned.each_line.find { |l| l.match?(CORE_PATH) && !l.include?('/*') })
    abort "pruned core path still present: #{line.strip}"
  end

  defined_before = objects.keys.to_set
  dangling_before = referenced_uuids(original) - defined_before
  defined_after = parse_objects(pruned.lines).keys.to_set
  dangling_after = referenced_uuids(pruned) - defined_after
  new_dangling = dangling_after - dangling_before
  abort "new dangling references: #{new_dangling.to_a.join(', ')}" unless new_dangling.empty?
  counts['objects before'] = defined_before.size
  counts['objects after'] = defined_after.size
  counts['dangling refs (pre-existing)'] = dangling_after.size

  File.write(path, pruned)
end

def prune_workspace(path, counts)
  lines = File.read(path).lines
  drop = Set.new
  lines.each_with_index do |line, n|
    next unless line.strip == '<FileRef'
    location = lines[n + 1].to_s[/location = "([^"]*)"/, 1]
    next unless location&.match?(CORE_PATH) && lines[n + 2].to_s.strip == '</FileRef>'
    drop.merge([n, n + 1, n + 2])
    counts['workspace FileRef'] += 1
  end
  File.write(path, lines.each_with_index.reject { |_, n| drop.include?(n) }.map(&:first).join)
end

def verify(project_dir, counts)
  out, status = Open3.capture2e('plutil', '-lint', File.join(project_dir, 'project.pbxproj'))
  abort "plutil -lint failed:\n#{out}" unless status.success?
  puts out
  script = <<~RUBY
    Encoding.default_external = Encoding::UTF_8
    require 'xcodeproj'
    p = Xcodeproj::Project.open(ARGV[0])
    puts "xcodeproj \#{Xcodeproj::VERSION} open OK: \#{p.objects.size} objects, \#{p.targets.size} targets"
  RUBY
  out, status = Open3.capture2e({ 'LANG' => 'en_US.UTF-8', 'LC_ALL' => 'en_US.UTF-8' }, 'ruby', '-e', script, project_dir)
  if status.success?
    puts out.lines.reject { |l| l.start_with?('[!]', 'If this attribute') }.join
  elsif out.include?('cannot load such file -- xcodeproj')
    puts 'xcodeproj gem not installed; skipped the read-only open check'
  else
    abort "xcodeproj open failed:\n#{out}"
  end
  counts
end

def gitmodule_paths
  out, = Open3.capture2('git', '-C', ROOT, 'config', '-f', '.gitmodules', '--get-regexp', '\.path$')
  out.lines.map(&:split).select { |_, p| p&.match?(CORE_PATH) }
end

def git_rm_targets
  CORES.keys.map { |dir| "Cores/#{dir}" }.select do |path|
    out, = Open3.capture2('git', '-C', ROOT, 'ls-files', '--', path)
    !out.empty?
  end
end

counts = Hash.new(0)
if APPLY
  prune_pbxproj(File.join(ROOT, PBXPROJ), counts)
  prune_workspace(File.join(ROOT, WORKSPACE), counts)
  verify(File.join(ROOT, 'Provenance.xcodeproj'), counts)
  git_rm_targets.each do |path|
    system('git', '-C', ROOT, 'rm', '-r', '-q', '-f', '--', path) || abort("git rm #{path} failed")
    FileUtils.rm_rf(File.join(ROOT, path))
    counts['core directories'] += 1
  end
  gitmodule_paths.each do |key, _|
    section = key.delete_suffix('.path')
    system('git', '-C', ROOT, 'config', '-f', '.gitmodules', '--remove-section', section) || abort("remove #{section} failed")
    counts['stale .gitmodules sections'] += 1
  end
  system('git', '-C', ROOT, 'add', '.gitmodules') || abort('git add .gitmodules failed')
else
  Dir.mktmpdir('prune-cores') do |tmp|
    FileUtils.cp_r(File.join(ROOT, 'Provenance.xcodeproj'), tmp)
    FileUtils.mkdir_p(File.join(tmp, 'Provenance.xcworkspace'))
    FileUtils.cp(File.join(ROOT, WORKSPACE), File.join(tmp, 'Provenance.xcworkspace'))
    prune_pbxproj(File.join(tmp, PBXPROJ), counts)
    prune_workspace(File.join(tmp, WORKSPACE), counts)
    [PBXPROJ, WORKSPACE].each do |rel|
      system('git', '--no-pager', 'diff', '--no-index', '--', File.join(ROOT, rel), File.join(tmp, rel))
    end
    verify(File.join(tmp, 'Provenance.xcodeproj'), counts)
  end
  git_rm_targets.each do |path|
    puts "would run: git rm -r -q -f -- #{path}"
    counts['core directories'] += 1
  end
  gitmodule_paths.each { |_, path| puts "would drop .gitmodules entry: #{path}" }
  counts['.gitmodules entries'] = gitmodule_paths.size
end

puts "\nprune_cores (#{APPLY ? 'applied' : 'dry run'}):"
counts.sort.each { |kind, n| puts format('  %-34s %d', kind, n) }
