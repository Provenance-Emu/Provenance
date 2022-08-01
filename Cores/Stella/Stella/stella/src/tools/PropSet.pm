package PropSet;

# NOTE: If the property types ever change in Stella, the following hashmap
#       and array must be updated (and stay in sequence)
my %prop_type = (
  "Cart.MD5"                  => 0,
  "Cart.Manufacturer"         => 1,
  "Cart.ModelNo"              => 2,
  "Cart.Name"                 => 3,
  "Cart.Note"                 => 4,
  "Cart.Rarity"               => 5,
  "Cart.Sound"                => 6,
  "Cart.StartBank"            => 7,
  "Cart.Type"                 => 8,
  "Cart.Highscore"            => 9,
  "Cart.Url"                  => 10,
  "Console.LeftDiff"          => 11,
  "Console.RightDiff"         => 12,
  "Console.TVType"            => 13,
  "Console.SwapPorts"         => 14,
  "Controller.Left"           => 15,
  "Controller.Left1"          => 16,
  "Controller.Left2"          => 17,
  "Controller.Right"          => 18,
  "Controller.Right1"         => 19,
  "Controller.Right2"         => 20,
  "Controller.SwapPaddles"    => 21,
  "Controller.PaddlesXCenter" => 22,
  "Controller.PaddlesYCenter" => 23,
  "Controller.MouseAxis"      => 24,
  "Display.Format"            => 25,
  "Display.VCenter"           => 26,
  "Display.Phosphor"          => 27,
  "Display.PPBlend"           => 28
);
my @prop_type_as_string = (
  "Cart.MD5",
  "Cart.Manufacturer",
  "Cart.ModelNo",
  "Cart.Name",
  "Cart.Note",
  "Cart.Rarity",
  "Cart.Sound",
  "Cart.StartBank",
  "Cart.Type",
  "Cart.Highscore",
  "Cart.Url",
  "Console.LeftDiff",
  "Console.RightDiff",
  "Console.TVType",
  "Console.SwapPorts",
  "Controller.Left",
  "Controller.Left1",
  "Controller.Left2",
  "Controller.Right",
  "Controller.Right1",
  "Controller.Right2",
  "Controller.SwapPaddles",
  "Controller.PaddlesXCenter",
  "Controller.PaddlesYCenter",
  "Controller.MouseAxis",
  "Display.Format",
  "Display.VCenter",
  "Display.Phosphor",
  "Display.PPBlend"
);

my @prop_defaults = (
  "",       # Cart.MD5
  "",       # Cart.Manufacturer
  "",       # Cart.ModelNo
  "",       # Cart.Name
  "",       # Cart.Note
  "",       # Cart.Rarity
  "MONO",   # Cart.Sound
  "AUTO",   # Cart.StartBank
  "AUTO",   # Cart.Type
  "",       # Cart.Highscore
  "",       # Cart.Url
  "B",      # Console.LeftDiff
  "B",      # Console.RightDiff
  "COLOR",  # Console.TVType
  "NO",     # Console.SwapPorts
  "",       # Controller.Left
  "",       # Controller.Left1
  "",       # Controller.Left2
  "",       # Controller.Right
  "",       # Controller.Right1
  "",       # Controller.Right2
  "NO",     # Controller.SwapPaddles
  "0",      # Controller.PaddlesXCenter
  "0",      # Controller.PaddlesYCenter
  "AUTO",   # Controller.MouseAxis
  "AUTO",   # Display.Format
  "0",      # Display.VCenter
  "NO",     # Display.Phosphor
  "0"       # Display.PPBlend
);

# Load and parse a properties file into an hash table of property
# objects, indexed by md5sum
sub load_prop_set($) {
  my $file = $_[0];
  print "Loading properties from file: $file\n";

  my @props = ();
  while(($key, $value) = each(%prop_type)) {
    $props[$value] = "";
  }

  my %propset = ();
  open(INFILE, $file);
  foreach $line (<INFILE>) {
    chomp $line;

    # Start a new item
    if ($line =~ /^""/) {
      my $key = $props[$prop_type{'Cartridge.MD5'}];
#     print "Inserting properties for key = $key\n";

      if(defined($propset{$key})) {
        print "Duplicate: $key\n";
      }
      $propset{$key} = [ @props ];

      undef @props;
      while(($key, $value) = each(%prop_type)) {
        $props[$value] = "";
      }
    } elsif ($line !~ /^$/) {
      ($key, $value) = ($line =~ m/"(.*)" "(.*)"/);
      if (defined $prop_type{$key}) {
        $index = $prop_type{$key};
        $props[$index] = $value;
      } else {
        print "ERROR: $line\n";
        print "Invalid key = \'$key\' for md5 = \'$props[0]\', ignoring ...\n";
      }
    }
  }
  close(INFILE);
  return %propset;
}

# Load and parse a properties file into an hash table of property
# objects, indexed by md5sum
sub save_prop_set {
  my $file = shift;
  my $hashref = shift;
  print "Saving " . keys(%$hashref) . " properties to file: $file\n";

  open(OUTFILE, ">$file");
  foreach my $md5 (sort keys %$hashref) {
    my $props = %$hashref{$md5};
    my @array = @$props;
    for (my $i = 0; $i < @array; $i++) {
      if ($array[$i] ne "") {
        print OUTFILE "\"$prop_type_as_string[$i]\" \"$array[$i]\"\n";
      }
    }
    print OUTFILE "\"\"\n\n";
  }
  close(OUTFILE);
}

# Get the number of property tags in one PropSet element
sub num_prop_types {
  return keys( %prop_type );
}

# Convert a properties set into a C++ compatible string
sub build_prop_string {
  my @array = @_;
  my $result = "  { ";
  my @items = ();
  for (my $i = 0; $i < @array; $i++) {
    if($prop_defaults[$i] ne $array[$i]) {
      push(@items, "\"$array[$i]\"");
    } else {
      push(@items, "\"\"");
    }
  }

  $result .= join(", ", @items);
  $result .= " }";

  return $result;
}
