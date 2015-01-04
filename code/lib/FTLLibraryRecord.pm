package FTLLibraryRecord;
use FTLConfig;
use strict;

my $libhashfile         = $FTL::IDXDIR . "libraries.hsh";

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
  my $rec;
  return undef if (!$libid);
  if (!$FTLLibraryRecord::hash) {
    $FTLLibraryRecord::hash = new OLBP::Hash(name=>"libhash",
                                             filename=>$libhashfile, cache=>1);
  }
  my $str = $FTLLibraryRecord::hash->get_value(key=>$libid);
  if ($str) {
    $self->_init_from_string($str);
  }
  if ($self && !$self->{ID}) {
    $self->{ID} = $libid;
  }
  return $rec;
}

sub _initialize {
  my ($self, %params) = @_;
  if ($params{id}) {
    $self->_init_from_id($params{id});
  }
  if ($params{string}) {
    $self->_init_from_string($params{string});
  }
  return $self;
}


sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  return $self->_initialize(@_);  # uses remaining arguments
}


1;
