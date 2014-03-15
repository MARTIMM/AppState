package AppState::Plugins::ConfigDriver::DataDumper;

use Modern::Perl;
use version; our $VERSION = '' . version->parse("v0.2.5");
use 5.010001;

use namespace::autoclean;

use Moose;
extends qw(AppState::Ext::ConfigIO);

use Data::Dumper ();

#-------------------------------------------------------------------------------
#
has '+fileExt' => ( default => 'dd');

#-------------------------------------------------------------------------------
sub BUILD
{
  my($self) = @_;

  if( $self->meta->is_mutable )
  {
    $self->log_init('==D');

    __PACKAGE__->meta->make_immutable;
  }
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
  if( my $e = $@ )
  {
    $self->_log( "Failed to serialize data dumper file: $e"
               , $self->C_CIO_SERIALIZEFAIL
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
  if( my $e = $@ )
  {
    $self->_log( [ "Failed to deserialize data dumper file"
                 , $self->configFile . ":"
                 , $e
                 ]
               , $self->C_CIO_DESERIALFAIL
               );
  }

  return $documents;
}

#-------------------------------------------------------------------------------

1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState::Config::DataDumper - Storage plugin using Data::Dumper
