package FTLLibraryRecord;
use FTLConfig;
use NetAddr::IP::Lite;
use OLBP::Hash;
use strict;

my $libhashfile         = $FTL::IDXDIR . "libraries.hsh";
my $iprangefile         = $FTL::IDXDIR . "ipranges";

my $idhash;
my $rangestotry = [];
my $gotranges   = 0;

sub get_default_url {
  my ($self) = @_;
  my $url = $self->{BASEURL};
  if ($self->{DEFAULT}) {
    $url = $self->{DEFAULT};
    if ($self->{DEFAULT} =~ /DOMAIN/) {
      $url = $self->{BASEURL};
      if ($url =~ m!(^[a-z]*://[^/]*/)!) {
        $url = $1;
      }
    }
  }
  return $url;
}

# note that this is not validating hash keys; it assumes the
# strings we parse are under our control

sub _init_from_string {
  my ($self, $str) = @_;
  my @lines = split /\n/, $str;
  foreach my $line (@lines) {
    if ($line =~ /^(\S+)\s+(.*\S)/) {
      $self->{$1} = $2;
      if ($1 eq "STATE") {
        $self->{COUNTRY} = "US";
      } elsif ($1 eq "PROVINCE") {
        $self->{COUNTRY} = "CA";
      }
    }
  }
  return $self;
}

sub _init_from_id {
  my ($self, $libid) = @_;
  return undef if (!$libid);
  if (!$idhash) {
    $idhash = new OLBP::Hash(name=>"libhash",
                            filename=>$self->{hashfile}, cache=>1);
  }
  my $str = $idhash->get_value(key=>$libid);
  if ($str) {
    $self->_init_from_string($str);
  }
  if ($self && !$self->{ID}) {
    $self->{ID} = $libid;
  }
}

sub _get_ranges {
  $gotranges = 1;
  open RANGES, "< $iprangefile" or return undef;
  while (my $line = <RANGES>) {
    my $rec = {};
    if ($line =~ /^(\S+)\s+(.*)/) {
      $rec->{ID} = $1;
      $rec->{RANGE} = $2;
      push @{$rangestotry}, $rec;
    }
  }
  close RANGES;
}

sub _init_from_ip {
  my ($self, $ipstr) = @_;
  my $ip;
  if ($ipstr) {
    $ip = new NetAddr::IP::Lite($ipstr);
  }
  if ($ip) {
    $self->_get_ranges() if (!$gotranges);
    foreach my $rec (@{$rangestotry}) {
      if ($rec->{RANGE}) {
        my $range = new NetAddr::IP::Lite($rec->{RANGE});
        if ($range && $ip->within($range)) {
          # IP range files are not full records; need to get one of them
          $self->_init_from_id($rec->{ID});
        }
      }
    }
  }
  return undef;
}

sub _initialize {
  my ($self, %params) = @_;
  $self->{hashfile} = $libhashfile;
  if ($params{hashfile}) {
    $self->{hashfile} = $params{hashfile};
  }
  if ($params{id}) {
    $self->_init_from_id($params{id});
  } elsif ($params{ip}) {
    $self->_init_from_ip($params{ip});
  }
  if ($params{string}) {
    $self->_init_from_string($params{string});
  }
  if (!$self->{ID}) {
    return undef;
  }
  return $self;
}

sub name { return shift->{NAME}; }
sub id { return shift->{ID}; }
sub address { return shift->{ADDRESS}; }
sub homepage { return shift->{HOMEPAGE}; }
sub reference { return shift->{VREF}; }
sub number_of_branches { return shift->{BRANCHES}; }

sub worldcat_registry_id { return shift->{WCRID}; }

sub location { return shift->{LOCATION}; }
sub country { return shift->{COUNTRY}; }
sub state { return shift->{STATE}; }
sub province { return shift->{PROVINCE}; }

sub forwarder { return shift->{FORWARDER}; }

sub geocoords {
  my ($self) = @_;
  if ($self->{LONGITIDE} || $self->{LATITUDE}) {
    return ($self->{LONGITUDE}, $self->{LATITUDE});
  }
  return ();
}

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  return $self->_initialize(@_);  # uses remaining arguments
}


1;
