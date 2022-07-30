#!/usr/bin/perl

use File::Basename;

usage() if @ARGV < 2;

my %builtin = ();
my %directory = ();

my @missing = ();
my @delete = ();

# Get all snapshot files from the built-in database in Stella
# This data comes from 'stella -listrominfo' (first commandline arg)
# We use a hashmap to get constant lookup time
open(INFILE, "$ARGV[0]");
foreach $line (<INFILE>)
{
  if($line =~ /\|/)
  {
    chomp $line;
    ($md5, $name, $other) = split (/\|/, $line);
    $key = $name . ".png";
    $builtin{$key} = $key;
  }
}
close(INFILE);

# Get all snapshot files from the actual directory (second commandline arg)
# We use a hashmap to get constant lookup time
opendir(SNAPDIR, $ARGV[1]) or die "Directory '$ARGV[1]' not found\n";
my @files = grep !/^\.\.?$/, readdir SNAPDIR;
close(SNAPDIR);
foreach $file (@files)
{
  ($base,$path,$type) = fileparse($file);
  $directory{$base} = $base;
}

# All files in %builtin but not in %directory are 'missing' snapshots
while(($key, $value) = each(%builtin))
{
  if(!defined $directory{$key})
  {
    push(@missing, $key);
  }
}

# All files in %directory but not in %builtin are redundant, and should be deleted
while(($key, $value) = each(%directory))
{
  if(!defined $builtin{$key})
  {
    $file = $ARGV[1] . "/" . $key;
    push(@delete, $file);
  }
}

$size = @missing;
print "Missing snapshots: ($size)\n\n";
if($size > 0)
{
  @missing = sort(@missing);
  foreach $file (@missing)
  {
    print "$file\n";
  }
}

$size = @delete;
print "\n\nExtra snapshots: ($size)\n\n";
if($size > 0)
{
  @delete = sort(@delete);
  foreach $file (@delete)
  {
    print "$file\n";
  }

  print "\nDelete extra snapshots [yN]: ";
  chomp ($input = <STDIN>);
  if($input eq 'y')
  { 
    foreach $file (@delete)
    {
      $cmd = "rm \"$file\"";
      system($cmd);
    }
  }
}


sub usage {
  print "prune_snapshots.pl [listrominfo data] [snapshot dir]\n";
  exit(0);
}
