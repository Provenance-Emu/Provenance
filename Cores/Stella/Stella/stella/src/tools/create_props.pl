#!/usr/bin/perl

# Locate the 'PropSet' module
use FindBin;
use lib "$FindBin::Bin";
use PropSet;

my $infile  = "";
my $outfile = "";

if (@ARGV != 2)
{
  if (@ARGV == 1 && $ARGV[0] == "-help")
  {
    usage();
  }
  # Saves me from having to type these paths *every single time*
  if (-f "src/emucore/stella.pro") {
    $infile  = "src/emucore/stella.pro";
  } else {
    $infile  = "../emucore/stella.pro";
  }
  if (-f "src/emucore/DefProps.hxx") {
    $outfile = "src/emucore/DefProps.hxx";
  } else {
    $outfile = "../emucore/DefProps.hxx";
  }
}
else
{
  $infile  = $ARGV[0];
  $outfile = $ARGV[1];
}

my %propset = PropSet::load_prop_set($infile);
my $setsize = keys (%propset);
my $typesize = PropSet::num_prop_types();

printf "Valid properties found: $setsize\n";

# Construct the output file in C++ format
open(OUTFILE, ">$outfile");
print OUTFILE "//============================================================================\n";
print OUTFILE "//\n";
print OUTFILE "//   SSSS    tt          lll  lll\n";
print OUTFILE "//  SS  SS   tt           ll   ll\n";
print OUTFILE "//  SS     tttttt  eeee   ll   ll   aaaa\n";
print OUTFILE "//   SSSS    tt   ee  ee  ll   ll      aa\n";
print OUTFILE "//      SS   tt   eeeeee  ll   ll   aaaaa  --  \"An Atari 2600 VCS Emulator\"\n";
print OUTFILE "//  SS  SS   tt   ee      ll   ll  aa  aa\n";
print OUTFILE "//   SSSS     ttt  eeeee llll llll  aaaaa\n";
print OUTFILE "//\n";
print OUTFILE "// Copyright (c) 1995-2022 by Bradford W. Mott, Stephen Anthony\n";
print OUTFILE "// and the Stella Team\n";
print OUTFILE "//\n";
print OUTFILE "// See the file \"License.txt\" for information on usage and redistribution of\n";
print OUTFILE "// this file, and for a DISCLAIMER OF ALL WARRANTIES.\n";
print OUTFILE "//============================================================================\n";
print OUTFILE "\n";
print OUTFILE "#ifndef DEF_PROPS_HXX\n";
print OUTFILE "#define DEF_PROPS_HXX\n";
print OUTFILE "\n";
print OUTFILE "/**\n";
print OUTFILE "  This code is generated using the 'create_props.pl' script,\n";
print OUTFILE "  located in the src/tools directory.  All properties changes\n";
print OUTFILE "  should be made in stella.pro, and then this file should be\n";
print OUTFILE "  regenerated and the application recompiled.\n";
print OUTFILE "*/\n";
print OUTFILE "\nstatic constexpr uInt32 DEF_PROPS_SIZE = " . $setsize . ";";
print OUTFILE "\n\n";
print OUTFILE "static constexpr BSPF::array2D<const char*, DEF_PROPS_SIZE, " . $typesize . "> DefProps = {{\n";

# Walk the hash map and print each item in order of md5sum
my $idx = 0;
for my $key ( sort keys %propset )
{
  print OUTFILE PropSet::build_prop_string(@{ $propset{$key} });

  if ($idx+1 < $setsize) {
    print OUTFILE ",";
  }
  print OUTFILE "\n";
  $idx++;
}

print OUTFILE "}};\n";
print OUTFILE "\n";
print OUTFILE "#endif\n";

close(OUTFILE);


sub usage {
  print "create_props.pl <INPUT properties file> <OUTPUT C++ header>\n";
  print "\n";
  print "Convert the given properties file into a C++ compatible header file.\n";
  exit(0);
}
