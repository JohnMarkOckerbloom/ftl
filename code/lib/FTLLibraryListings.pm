package FTLLibraryListings;
use FTLConfig;
use FTLLibraryRecord;
use OLBP;
use Locale::Country;
use strict;

my $ONLINEBOOKS_URL = "https://onlinebooks.library.upenn.edu/";
my $SUGGEST_LIBRARY_URL = $ONLINEBOOKS_URL . "/webbin/olbpcontact?type=library";

my $liblistfile         = $FTL::IDXDIR . "libraries";

my $states = {
  'AL' => "Alabama", 'AK' => "Alaska", 'AZ' => "Arizona", 'AR' => "Arkansas",
  'CA' => "California", 'CO' => "Colorado", 'CT' => "Connecticut",
  'DE' => "Delaware", 'DC' => "District of Columbia", 'FL' => "Florida",
  'GA' => "Georgia", 'HI' => "Hawaii",
  'ID' => "Idaho", 'IL' => "Illinois", 'IN' => "Indiana", 'IA' => "Iowa",
  'KS' => "Kansas", 'KY' => "Kentucky", 'LA' => "Louisiana",
  'MD' => "Maryland", 'MA' => "Massachusetts", 'ME' => "Maine",
  'MI' => "Michigan", 'MS' => "Mississippi", 'MN' => "Minnesota",
  'MO' => "Missouri", 'MT' => "Montana",
  'NE' => "Nebraska", 'NV' => "Nevada", 'NH' => "New Hampshire",
  'NJ' => "New Jersey", 'NM' => "New Mexico",
  'NY' => "New York",
  'NC' => "North Carolina", 'ND' => "North Dakota",
  'OH' => "Ohio", 'OK' => "Oklahoma", 'OR' => "Oregon",
  'PA' => "Pennsylvania", 'RI' => "Rhode Island",
  'SC' => "South Carolina", 'SD' => "South Dakota",
  'TN' => "Tennessee", 'TX' => "Texas", 'UT' => "Utah",
  'VA' => "Virginia", 'VT' => "Vermont",
  'WA' => "Washington", "WV" => "West Virginia",
  "WI" => "Wisconsin", 'WY' => "Wyoming"
};

my $provinces = {"AB" => "Alberta", "BC" => "British Columbia",
                 "MB" => "Manitoba", "NB" => "New Brunswick",
                 "NL" => "Newfoundland and Labrador",
                 "NT" => "Northwest Territories", "NS" => "Nova Scotia",
                 "NU" => "Nunavut", "ON" => "Ontario",
                 "PE" => "Prince Edward Island",
                 "PQ" => "Qu&eacute;bec", "SK" => "Saskatchewan",
                 "YT" => "Yukon"
};

sub _sortbystate {
  my ($self, $recref) = @_;
  return  sort {    ($self->{countries}->{$a->country()}
                 cmp $self->{countries}->{$b->country()})
             || ($states->{$a->state()} cmp $states->{$b->state()})
             || ($provinces->{$a->province()} cmp $provinces->{$b->province()})
             || ($a->name() cmp $b->name())
               } @{$recref};
}

sub _show_country_links {
  my ($self, @liblist) = @_;
  my $ccode = "";
  print "<p>Jump to ";
  foreach my $rec (@liblist) {
    next if ($rec->country() eq "SUPPRESS" || $rec->country() eq '00');
    if ($rec->country() ne $ccode) {
      if ($ccode) {
        print " - ";
      }
      $ccode = $rec->country();
      my $country = $self->{countries}->{$ccode};
      print "<a href=\"#CC-$ccode\">$country</a>";
    }
  }
  print "</p>\n";
}

sub _show_local_links {
  my ($larray, $prefix) = @_;
  my $scode = "";
  my (@statelist) = sort {$larray->{$a} cmp $larray->{$b}} keys %{$larray};
  print "<p>Jump to ";
  print join (" - ",
             map {sprintf("<a href=\"#$prefix-$_\">$_</a>")} @statelist);
  print "</p>\n";
}

sub library_link {
  my (%params) = @_;
  my $id = $params{id};
  if (!$id) {
    $id = "";
  }
  my $url = "?library=" . $id;
  if ($params{args}) {
    foreach my $attr (keys %{$params{args}}) {
      my $val = $params{args}->{$attr};
      if ($val) {
        $url .= "&" . OLBP::url_encode($attr) . "=" . OLBP::url_encode($val);
      }
    }
  }
  return $url;
}

sub show_library_links {
  my ($self, %params) = @_;
  return if (!$self->{librecs});
  my $statecode = "";
  my $pcode = "";
  my $ccode = "";
  if (!$self->{countries}) { 
    $self->_init_countries();
  }
  my @liblist = $self->_sortbystate($self->{librecs});
  $self->_show_country_links(@liblist);
  foreach my $rec (@liblist) {
    next if ($rec->country() eq "SUPPRESS");
    next if ($rec->id() eq $params{omit});
    if ($rec->country() ne $ccode) {
      if ($ccode) {
        print "</ul>";
        if ($ccode eq "CA" || $ccode eq "US") {
          print "</ul>";
        }
      }
      $ccode = $rec->country();
      my $country = $self->{countries}->{$ccode};
      $country =~ s/^\s+//;
      print qq!<b id="CC-$ccode">$country</b>!;
      if ($ccode eq "US") {
        _show_local_links($states, "ST");
      } elsif ($ccode eq "CA") {
        _show_local_links($provinces, "PR");
      }
      print qq!<ul>!;
    }
    if ($rec->state() && $rec->state() ne $statecode) {
      if ($statecode) {
        print "</ul>";
      }
      $statecode = $rec->state();
      print qq!<li> <b id="ST-$statecode">$states->{$statecode}</b><ul>!;
    }
    if ($rec->province() && $rec->province() ne $pcode) {
      if ($pcode) {
        print "</ul>";
      }
      $pcode = $rec->province();
      print qq!<li> <b id="PR-$pcode">$provinces->{$pcode}</b><ul>!;
    }
    my $url = library_link(id=>$rec->id(), args=>$params{args});
    print qq!<li> <a href="$url">! . $rec->name() . "</a> (";
    print $rec->location() . ")\n";
  }
  if ($ccode eq "US") {
    print qq!</ul>\n!;
  }
  print qq!</ul>\n!;
}

sub _suggest_exits {
  my ($self, $chosenrec) = @_;
  my @links = ();
  print "<p>\n";
  if (scalar(@FTL::CLIENTS)) {
    foreach my $cname (@FTL::CLIENTS) {
      my $rec = new FTLLibraryRecord(id=>$cname);
      next if (!$rec);
      my $name = $rec->name();
      my $url = $rec->get_default_url();
      if ($url && $name) {
        push @links, qq!<a href="$url">$name</a>!;
      }
    }
  }
  if (scalar(@links)) {
    print "This forwarder is used for links from ";
    print join ' and ', @links;
    print ".\n";
  }
  @links = ();
  if (scalar(@FTL::OTHERS)) {
    my $chosenid = "";
    if ($chosenrec && $chosenrec->id()) {
      $chosenid = $chosenrec->id();
    }
    foreach my $cname (@FTL::OTHERS) {
      my $rec = new FTLLibraryRecord(id=>$cname);
      next if (!$rec);
      my $name = $rec->name();
      my $url = $rec->forwarder();
      if ($url && $name) {
        if ($chosenid) {
          $url .= "?library=$chosenid";
        }
        push @links, qq!<a href="$url">$name</a>!;
      }
    }
  }
  if (scalar(@links)) {
    print "You can also set this as the library for links from ";
    print join ' and ', @links;
    print ".";
  }
  print "</p>\n";
}

sub choose_library_form {
  my ($self, %params) = @_;
  my $from = $params{from};
  my $fromrec = $params{fromrec};
  my $libchosen = $params{libchosen};
  my $librec;
  if (!$fromrec && $params{from}) {
    $fromrec = new FTLLibraryRecord(id=>$from);
  } elsif ($fromrec) {
    $from = $fromrec->id();
  }
  if ($libchosen) {
    $librec = new FTLLibraryRecord(id=>$libchosen);
  }
  my $referralnote = "";
  if ($fromrec) {
    $referralnote .= " for referrals from " . $fromrec->name();
  }
  my $heading = "Choose a library$referralnote";
  if ($librec) {
    $heading = "Your library$referralnote is " . $librec->name();
  }
  print qq!<h2 align="center">$heading</h2>!;
  if ($self->{librecs}) {
    if ($librec) {
      print "<p>If you would like to switch to a different library, choose";
    } else {
      print "<p>We don't yet know which library you prefer ";
      print "to use$referralnote. Choose";
    }
    print " from one below, or ";
    print qq!<a href="$SUGGEST_LIBRARY_URL">let us know</a>!;
    print " about another library you'd like us to include.</p>";
    if ($librec) {
      $self->_suggest_exits($librec);
    }
    $self->show_library_links(args=>$params{args}, omit=>$from);
  }
}

sub _init_countries {
  my ($self, %params) = @_;
  my @codes = all_country_codes();
  foreach my $code (@codes) {
    $self->{countries}->{uc($code)} = code2country($code);
  }
  $self->{countries}->{"00"} = " Global library services";
  $self->{countries}->{"TW"} = "Taiwan";
  $self->{countries}->{"UK"} = "United Kingdom";
}

sub _init_librecs {
  my ($self, %params) = @_;
  my @liblist = ();
  open IN, "< $liblistfile" or return;
  my $str = "";
  while (my $line = <IN>) {
    if (!($line =~ /\S/)) {
      if ($str) {
        my $rec = new FTLLibraryRecord(string=>$str);
        $str = "";
        if ($rec) {
          push @liblist, $rec;
        }
       }
     }  else {
       $str .= $line;
     }
  }
  close IN;
  if ($str) {
    my $rec = new FTLLibraryRecord(string=>$str);
    if ($rec) {
      push @liblist, $rec;
    }
  }
  $self->{librecs} = \@liblist;
}

sub _initialize {
  my ($self, %params) = @_;
  $self->_init_librecs();
  return $self;
}

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  return $self->_initialize(@_);  # uses remaining arguments
}


1;
