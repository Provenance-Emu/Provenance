#!/usr/bin/perl

use File::Basename;

usage() if @ARGV != 2;

# Generate md5sums for source and destination directories
my @src_files = `md5sum $ARGV[0]/*`;
my @dest_files = `md5sum $ARGV[1]/*`;

# Build hash for source ROMs
my %src_md5 = ();
foreach $file (@src_files) {
  chomp $file;
  ($md5, $name) = split("  ", $file);
  $src_md5{ $md5 } = $name;
}
print "Found " . keys( %src_md5 ) . " ROMs in " . $ARGV[0] . "\n";

# Build hash for destination ROMs
my %dest_md5 = ();
foreach $file (@dest_files) {
  chomp $file;
  ($md5, $name) = split("  ", $file);
  $dest_md5{ $md5 } = $name;
}
print "Found " . keys( %dest_md5 ) . " ROMs in " . $ARGV[1] . "\n";

my @added = (), @removed = (), @changed = ();

# Check for added ROMs
for my $key ( keys %dest_md5 ) {
  if (defined $src_md5{$key}) {
    ($src_rom,$path,$type) = fileparse($src_md5{$key});
    ($dest_rom,$path,$type) = fileparse($dest_md5{$key});
    if($src_rom ne $dest_rom) {
      push(@changed, $dest_md5{$key});
    }
  }
  else {
    push(@added, $dest_md5{$key});
  }
}

# Check for removed ROMs
for my $key ( keys %src_md5 ) {
  if (!defined $dest_md5{$key}) {
    push(@removed, $src_md5{$key});
  }
}

# Report our findings, create directories and copy files
print "\n";
my $numAdded = @added;
print "Added ROMs: $numAdded\n";
if ($numAdded > 0) {
  system("mkdir -p ADDED");
  foreach $rom (@added) {
    system("cp \"$rom\" ADDED/");
  }
}
my $numRemoved = @removed;
print "Removed ROMs: $numRemoved\n";
if ($numRemoved > 0) {
  system("mkdir -p REMOVED");
  foreach $rom (@removed) {
    system("cp \"$rom\" REMOVED/");
  }
}
my $numChanged = @changed;
print "Changed ROMs: $numChanged\n";
if ($numChanged > 0) {
  system("mkdir -p CHANGED");
  foreach $rom (@changed) {
    system("cp \"$rom\" CHANGED/");
  }
}


sub usage {
  print "rom_diff.pl <source directory> <destination directory>\n";
  print "\n";
  print "Analyze the ROMs in both directories by md5sum and name.\n";
  print "Three directories are created named 'ADDED', 'REMOVED' and 'CHANGED',\n";
  print "indicating the differences in ROMs from the source and destination\n";
  print "directories.  ROMs are then copied into these new directories as specified.\n";
  exit(0);
}
