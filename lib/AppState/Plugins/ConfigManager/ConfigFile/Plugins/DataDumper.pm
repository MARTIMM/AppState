package AppState::Plugins::ConfigManager::ConfigFile::Plugins::DataDumper;

use Modern::Perl;
use version; our $VERSION = '' . version->parse("v0.2.6");
use 5.010001;

use namespace::autoclean;

use Moose;
extends qw(AppState::Plugins::ConfigManager::ConfigIO);

use Data::Dumper ();

#-------------------------------------------------------------------------------
#
has '+file_ext' => ( default => 'dd');

#-------------------------------------------------------------------------------
sub BUILD
{
  my($self) = @_;
  $self->log_init('==D');
}

#-------------------------------------------------------------------------------
# Serialize to text
#
sub serialize
{
  my( $self, $documents) = @_;
  my( $script, $result);

  # Get all options and set them locally
  #
  $script .= "local \$Data::Dumper::$_ = '" . $self->options->{$_} . "';\n"
    for (keys %{$self->options});

  # Get a control option for network save actions and dump data into result
  #
  $script .= "\$result = Data::Dumper->Dump( [\$documents], ['documents'])";

  # Evaluate and check for errors.
  #
  eval($script);
  if( my $err = $@ )
  {
    $self->log( $self->C_CIO_SERIALIZEFAIL
              , [ 'DataDumper', $self->config_file, $err]
              );
  }

  return $result;
}

#-------------------------------------------------------------------------------
# Deserialize to data
#
sub deserialize
{
  my( $self, $text) = @_;
  my( $script, $documents);

  $script = '';
  $text //= '';

  # Get all options and set them locally
  #
  $script .= "local \$Data::Dumper::$_ = '" . $self->options->{$_} . "';\n"
    for (keys %{$self->options});

  # Load yaml text and convert into result
  #
  $script .= "if( \$text ) { $text }";

  # Evaluate and check for errors.
  #
  eval($script);
  if( my $err = $@ )
  {
    $self->log( $self->C_CIO_DESERIALFAIL
              , [ 'DataDumper', $self->config_file, $err]
              );
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

AppState::Config::DataDumper - Storage plugin using Data::Dumper
