package AppState::Plugins::ConfigDriver::FreezeThaw;

use Modern::Perl;
use version; our $VERSION = '' . version->parse("v0.1.3");
use 5.010001;

use namespace::autoclean;

use Moose;
extends qw(AppState::Ext::ConfigIO);

require FreezeThaw;

#-------------------------------------------------------------------------------
has '+fileExt' => ( default => 'fth');

#-------------------------------------------------------------------------------
sub BUILD
{
  my($self) = @_;

  if( $self->meta->is_mutable )
  {
    $self->log_init('==F');

    __PACKAGE__->meta->make_immutable;
  }
}

#-------------------------------------------------------------------------------
# Serialize to text
#
sub serialize
{
  my( $self, $documents) = @_;
  return FreezeThaw::freeze(@$documents);
}

#-------------------------------------------------------------------------------
# Deserialize to data
#
sub deserialize
{
  my( $self, $text) = @_;
  $text //= '';
  my $documents = $text eq '' ? undef : [FreezeThaw::thaw($text)];
  return $documents;
}

#-------------------------------------------------------------------------------

1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState::Config::FreezeThaw - Storage plugin using FreeseThaw

