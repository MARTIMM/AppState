package AppState::Plugins::ConfigManager::ConfigIO;

use Modern::Perl;
use version; our $VERSION = version->parse('v0.1.5');
use 5.010001;

use namespace::autoclean;
use English qw(-no_match_vars); # Avoids regex perf penalty, perl < v5.016000

use Moose;

extends qw(AppState::Plugins::Log::Constants);

use AppState;
require Encode;
use AppState::Plugins::Log::Meta_Constants;

#-------------------------------------------------------------------------------
# Error codes. Make handle in ConfigFile.
#
def_sts( 'C_CIO_CFGREAD',       'M_INFO', 'Config text read from file %s');
def_sts( 'C_CIO_CFGWRITTEN',    'M_INFO', 'Data written to file %s');
def_sts( 'C_CIO_CFGNOTREAD',    'M_F_WARNING', 'File %s not readable or not existent');
def_sts( 'C_CIO_CFGNOTWRITTEN', 'M_F_WARNING', '%s: %s');
def_sts( 'C_CIO_IOERROR',       'M_FATAL', '%s: %s');
def_sts( 'C_CIO_SERIALIZEFAIL', 'M_FATAL', 'Failed to serialize %s file %s: %s');
def_sts( 'C_CIO_DESERIALFAIL',  'M_FATAL', 'Failed to deserialize %s file %s: %s');
def_sts( 'C_CIO_NOSERVER',      'M_ERROR', 'No server available');

#-------------------------------------------------------------------------------
has file_ext =>
    ( is                => 'ro'
    , isa               => 'Str'
    , default           => 'dunno'
    , init_arg          => undef
    );

has encoding =>
    ( is               => 'ro'
    , isa              => 'Bool'
    , default          => 0
    , init_arg         => undef
    );

has _config_text =>
    ( is                => 'rw'
#    , isa              => 'Str'
    , default           => ''
    , init_arg          => undef
    );

has config_file =>
    ( is                => 'ro'
    , isa               => 'Str'
    , default           => 'config.xyz'
    , writer            => '_configFile'
    , init_arg          => undef
    );

# Options to control save and load
#
has control =>
    ( is                => 'rw'
    , isa               => 'HashRef'
    , default           => sub{ return {}; }
    , traits            => ['Hash']
    , handles           =>
      { get_control      => 'get'
      }
    );

# Options to control (de)serialization
#
has options =>
    ( is                => 'rw'
    , isa               => 'HashRef'
    , default           => sub{ return {}; }
    , traits            => ['Hash']
    , handles           =>
      { get_option       => 'get'
      }
    );

#-------------------------------------------------------------------------------
sub BUILD
{
  my($self) = @_;
  $self->log_init('=IO');
};

#-------------------------------------------------------------------------------
# Cleanup
#
sub plugin_cleanup
{
#  my( $self, $ds) = @_;
#  $self->save($ds);
}

#-------------------------------------------------------------------------------
# Load config
#
sub load
{
  my($self) = @_;

  $self->read_text_from_config_file;
  my $docs = $self->deserialize($self->_config_text);
#say "Docs: ", ref $docs;
#say "N docs: ", ref $docs eq 'ARRAY' ? scalar(@$docs) : 'No docs';
  return ref $docs eq 'ARRAY' ? $docs : [];
}

#-------------------------------------------------------------------------------
# Save text
#
sub save
{
  my( $self, $documents) = @_;

  $self->_config_text($self->serialize($documents));
  $self->write_text_to_config_file;
}

#-------------------------------------------------------------------------------
# Read text from configfile before deserialization
#
sub read_text_from_config_file
{
  my($self) = @_;

  my $config_text = undef;
  my $config_file = $self->config_file;
  if( -r $config_file )
  {
    local $INPUT_RECORD_SEPARATOR;

    my $sts = open my $text, '<', $config_file;
    if( !$sts )
    {
      $self->log( $self->C_CIO_IOERROR, [ $config_file, $!]);
    }

    else
    {
      $config_text = <$text>;
      $text->close;
      $self->log( $self->C_CIO_CFGREAD, [$config_file]);
    }
  }

  else
  {
    $self->log( $self->C_CIO_CFGNOTREAD, [$config_file]);
  }

  $self->_config_text(Encode::decode( 'UTF-8', $config_text));
}

#-------------------------------------------------------------------------------
# Write text to configfile after serialization
#
sub write_text_to_config_file
{
  my($self) = @_;

  my $config_file = $self->config_file;
#  local $INPUT_RECORD_SEPARATOR;

  my $sts = open my $textf, '>', $config_file;
  if( !$sts )
  {
    $self->log( $self->C_CIO_CFGNOTWRITTEN, [ $config_file, $!]);
  }

  else
  {
    $textf->print(Encode::encode( 'UTF-8', $self->_config_text));
    $textf->close;

    $self->log( $self->C_CIO_CFGWRITTEN, [$config_file]);
  }
}

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;
1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState::Roles::ConfigIO - Helper module for config plugins

=head1 SYNOPSIS

  package AppState::Config::SomeConfigExtension
  use 5.014003;
  use Modern::Perl;
  use Moose;
  ...
  extends 'AppState::Config::ConfigIO';


  ...

  sub serialize
  {
    my( $self, $docNumber) = @_;
    ...
    return $data;
  }

  sub deserialize
  {
    my( $self, $data) = @_;
    ...
  }


=head1 DESCRIPTION

This module is a role module for plugins used by the
L<AppState::Config::ConfigFile> module. It provides methods which are
independend of the documentstructure on disk or elsewhere.


=head1 METHODS

=over 2


=back

=head1 BUGS

No bugs yet.

=head1 AUTHOR

Marcel Timmerman, E<lt>mt1957@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Marcel Timmerman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
