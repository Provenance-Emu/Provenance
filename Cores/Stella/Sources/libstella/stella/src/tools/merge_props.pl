#!/usr/bin/perl

# Locate the 'PropSet' module
use FindBin;
use lib "$FindBin::Bin";
use PropSet;

my $usr_file  = "";
my $sys_file = "";

if (@ARGV != 2)
{
  if (@ARGV == 1 && $ARGV[0] == "-help")
  {
    usage();
  }
  # Saves me from having to type these paths *every single time*
  $usr_file  = "$ENV{HOME}/.config/stella/stella.pro";
  $sys_file = "src/emucore/stella.pro";
}
else
{
  $usr_file = $ARGV[0];
  $sys_file = $ARGV[1];
}

print "$usr_file\n";

my %usr_propset = PropSet::load_prop_set($usr_file);
my %sys_propset = PropSet::load_prop_set($sys_file);

print "\n";
print "Valid properties found in user file: " . keys (%usr_propset) . "\n";
print "Valid properties found in system file: " . keys (%sys_propset) . "\n";

# Determine which properties exist in both files
for my $key ( keys %usr_propset ) {
  if (defined $sys_propset{$key}) {
    $sys_propset{$key} = $usr_propset{$key};
    delete $usr_propset{$key};
  }
}

print "\n";
print "Updated properties found in user file: " . keys (%usr_propset) . "\n";
print "Updated properties found in system file: " . keys (%sys_propset) . "\n";
print "\n";

# Write both files back to disk
PropSet::save_prop_set($usr_file, \%usr_propset);
PropSet::save_prop_set($sys_file, \%sys_propset);

print "\nRun create_props [yN]: ";
chomp ($input = <STDIN>);
if($input eq 'y')
{
  system("./src/tools/create_props.pl");
}


sub usage {
  print "merge_props.pl <USER properties file> <SYSTEM properties file>\n";
  print "\n";
  print "Scan both properties files, and for every entry found in both files,\n";
  print "remove it from the USER file and overwrite it in the SYSTEM file.\n";
  exit(0);
}
