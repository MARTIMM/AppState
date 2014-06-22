package AppState::Ext::ConfigIO;

use Modern::Perl;
use version; our $VERSION = version->parse('v0.1.4');
use 5.010001;

use namespace::autoclean;
use English qw(-no_match_vars); # Avoids regex perf penalty, perl < v5.016000

use Moose;

extends qw(AppState::Ext::Constants);

use AppState;
require Encode;

#-------------------------------------------------------------------------------
has fileExt =>
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

has _configText =>
    ( is                => 'rw'
#    , isa              => 'Str'
    , default           => ''
    , init_arg          => undef
    );

has configFile =>
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
      { getControl      => 'get'
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

  if( $self->meta->is_mutable )
  {
    $self->log_init('=IO');

    # Error codes. Make handle in ConfigFile.
    #
#    $self->code_reset;
    $self->const( 'C_CIO_CFGREAD'       , 'M_INFO');
    $self->const( 'C_CIO_CFGWRITTEN'    , 'M_INFO');
    $self->const( 'C_CIO_CFGNOTREAD'    , 'M_WARNING');
    $self->const( 'C_CIO_CFGNOTWRITTEN' , 'M_WARNING');
    $self->const( 'C_CIO_IOERROR'       , 'M_ERROR');
    $self->const( 'C_CIO_SERIALIZEFAIL' , 'M_ERROR');
    $self->const( 'C_CIO_DESERIALFAIL'  , 'M_ERROR');
    $self->const( 'C_CIO_CLONEFAIL'     , 'M_ERROR');
    $self->const( 'C_CIO_DATACLONED'    , 'M_INFO');
    $self->const( 'C_CIO_NOSERVER'      , 'M_ERROR');
#    $self->const( 'C_CIO_'     , '');

    __PACKAGE__->meta->make_immutable;
  }
};

#-------------------------------------------------------------------------------
# Cleanup
#
sub cleanup
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

  $self->readTextFromConfigFile;
  my $docs = $self->deserialize($self->_configText);
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

  $self->_configText($self->serialize($documents));
  $self->writeTextToConfigFile;
}

#-------------------------------------------------------------------------------
# Read text from configfile before deserialization
#
sub readTextFromConfigFile
{
  my($self) = @_;

  my $configText = undef;
  my $configFile = $self->configFile;
  if( -r $configFile )
  {
    local $INPUT_RECORD_SEPARATOR;

    my $sts = open my $text, '<', $configFile;
    if( !$sts )
    {
      $self->wlog( "$configFile: $!", $self->C_CIO_IOERROR);
    }

    else
    {
      $configText = <$text>;
      $text->close;

      $self->wlog( "Config text read from file $configFile"
                 , $self->C_CIO_CFGREAD
                 );
    }
  }

  else
  {
    $self->wlog( "File $configFile not readable or not existent"
               , $self->C_CIO_CFGNOTREAD
               );
  }

  $self->_configText(Encode::decode( 'UTF-8', $configText));
}

#-------------------------------------------------------------------------------
# Write text to configfile after serialization
#
sub writeTextToConfigFile
{
  my($self) = @_;

  my $configFile = $self->configFile;
#  if( !-e $configFile or -w $configFile )
#  {
    local $INPUT_RECORD_SEPARATOR;

    my $sts = open my $textf, '>', $configFile;
    if( !$sts )
    {
      $self->wlog( "$configFile: $!", $self->C_CIO_CFGNOTWRITTEN);
    }

    else
    {
      $textf->print(Encode::encode( 'UTF-8', $self->_configText));
      $textf->close;

      $self->wlog( "Data written to file $configFile"
                 , $self->C_CIO_CFGWRITTEN
                 );
    }
#  }
#
#  else
#  {
#    $self->wlog( "File $configFile not writable", $self->C_CIO_CFGNOTWRITTEN);
#  }
}

#-------------------------------------------------------------------------------

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
