package AppState::Plugins::ConfigDriver::Json;

use Modern::Perl;
use version; our $VERSION = '' . version->parse("v0.1.3");
use 5.010001;

use namespace::autoclean;

use Moose;
extends qw(AppState::Plugins::ConfigManager::ConfigIO);

require JSON;

#-------------------------------------------------------------------------------
has '+file_ext' => ( default => 'jsn');

#-------------------------------------------------------------------------------
sub BUILD
{
  my($self) = @_;

  if( $self->meta->is_mutable )
  {
    $self->log_init('==J');

    __PACKAGE__->meta->make_immutable;
  }
}

#-------------------------------------------------------------------------------
# Serialize to text
#
sub serialize
{
  my( $self, $documents) = @_;
  return JSON::to_json( $documents, $self->options);
}

#-------------------------------------------------------------------------------
# Deserialize to data
#
sub deserialize
{
  my( $self, $text) = @_;
  $text //= '';
  my $documents = $text eq '' ? undef : JSON::from_json( $text, $self->options);
  return $documents;
}

#-------------------------------------------------------------------------------

1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState::Config::Json - Storage plugin using JSON
