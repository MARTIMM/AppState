package AppState::Plugins::ConfigDriver::FreezeThaw;

use Modern::Perl;
use version; our $VERSION = '' . version->parse("v0.1.4");
use 5.010001;

use namespace::autoclean;

use Moose;
extends qw(AppState::Plugins::ConfigManager::ConfigIO);

require FreezeThaw;

#-------------------------------------------------------------------------------
has '+file_ext' => ( default => 'fth');

#-------------------------------------------------------------------------------
sub BUILD
{
  my($self) = @_;
  $self->log_init('==F');
}

#-------------------------------------------------------------------------------
# Serialize to text
#
sub serialize
{
  my( $self, $documents) = @_;
  my $frozen;
  eval('$frozen = FreezeThaw::freeze(@$documents)');
  if( my $err = $@ )
  {
    $self->log( $self->C_CIO_SERIALIZEFAIL
              , [ 'FreezeThaw', $self->config_file, $err]
              );
  }

  return $frozen;
}

#-------------------------------------------------------------------------------
# Deserialize to data
#
sub deserialize
{
  my( $self, $text) = @_;
  $text //= '';
  my $documents;

  if( $text eq '' )
  {
    $documents = undef;
  }

  else
  {
    eval('$documents = [FreezeThaw::thaw($text)]');
    if( my $err = $@ )
    {
      $self->log( $self->C_CIO_DESERIALIZEFAIL
                , [ 'FreezeThaw', $self->config_file, $err]
                );
    }
  }

  return $documents;
}

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;
1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState::Config::FreezeThaw - Storage plugin using FreeseThaw

