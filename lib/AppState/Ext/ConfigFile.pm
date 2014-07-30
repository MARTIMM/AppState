package AppState::Ext::ConfigFile;

use Modern::Perl;
use version; our $VERSION = '' . version->parse("v0.0.3");
use 5.010001;

use namespace::autoclean;

use Moose;
use Moose::Util::TypeConstraints;

extends qw(AppState::Ext::Constants);

require Storable;

use AppState;
use AppState::Ext::Documents;

use AppState::Ext::Meta_Constants;

#-------------------------------------------------------------------------------
# Error codes. These codes must also be handled by ConfigManager.
#
const( 'C_CFF_STORETYPESET', 'M_INFO', 'Store type set to %s');
const( 'C_CFF_LOCCODESET',   'M_INFO', 'Location code set to %s');
const( 'C_CFF_REQFILESET',   'M_INFO', 'Request for file %s');
const( 'C_CFF_CFGFILESET',   'M_INFO', 'Config filename set to %s');
const( 'C_CFF_CANNOTDELDOC', 'M_WARNING', 'Cannot delete() documents');
const( 'C_CFF_DOCCLONED',    'M_INFO', 'Document cloned = %s');
const( 'C_CFF_CANNOTCLODOC', 'M_WARNING', 'Cannot clone() documents in %s');
const( 'C_CFF_STOREPLGINIT', 'M_INFO', 'Config %s initialized');

# Location values
#
const( 'C_CFF_CONFIGDIR',    'M_CODE', 'Config dir location');
const( 'C_CFF_WORKDIR',      'M_CODE', 'Workdir location');
const( 'C_CFF_FILEPATH',     'M_CODE', 'Users filepath location');
const( 'C_CFF_TEMPDIR',      'M_CODE', 'Tempdir location');

# Reset values, only used locally
#
const( 'C_CFF_NORESETCFG',   'M_CODE', 'Do not reset the plugin configuration');
const( 'C_CFF_RESETCFG',     'M_CODE', 'Reset the plugin configuration');

#-------------------------------------------------------------------------------
# Possible types for storage. This is set by the plugin manager default
# initialization. Need to use non-moose variable because of test in subtype
# can not use $self to use a getter such as $self->storeTypes().
#
my $__store_types__ = '';
has _storeTypes =>
    ( is                => 'ro'
    , isa               => 'Str'
    , init_arg          => undef
    , writer            => '_set_store_types'
#    , default          => ''
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;
        $__store_types__ = $n;
      }
    );

# Subtype to be used to test store_type against.
#
subtype 'AppState::Ext::ConfigFile::Types::Storage'
    => as 'Str'
    => where { $_ =~ m/$__store_types__/ }
    => message { "The store type '$_' is not correct" };


# Type of storage plugin used.
#
has store_type =>
    ( is                => 'rw'
    , isa               => 'AppState::Ext::ConfigFile::Types::Storage'
#    , default          => 'Yaml'
#    , lazy             => 1
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;
        if( !defined $o or $n ne $o )
        {
          $self->log( $_[0]->C_CFF_STORETYPESET, [$n]);
          $self->_set_config_file($self->C_CFF_RESETCFG);
        }
      }
    );

has _store_type_object =>
    ( is                => 'ro'
    , isa               => 'Maybe[Object]'
    , init_arg          => undef
    , writer            => '_set_store_type_object'
    , predicate         => '_has_store_type_object'
    , handles           => [
                            # Make handle in ConfigManager.
                            #
                            qw( config_file
                                C_CIO_CFGREAD C_CIO_CFGWRITTEN C_CIO_CFGNOTREAD
                                C_CIO_CFGNOTWRITTEN C_CIO_IOERROR
                                C_CIO_SERIALIZEFAIL C_CIO_DESERIALFAIL
                                C_CIO_CLONEFAIL C_CIO_DATACLONED C_CIO_NOSERVER
                              )
                           ]
    );

# Subtype to be used to test location against. Type must be 'Any' because
# dualvars are used.
#
my $_test_location = sub {return 0;};
subtype 'AppState::Ext::ConfigFile::Types::Location'
    => as 'Any'
    => where {$_test_location->($_);}
    => message {'The location code is not correct'};

# Location code where to find the file.
#
has location =>
    ( is                => 'rw'
    , isa               => 'AppState::Ext::ConfigFile::Types::Location'
    , lazy              => 1
    , default           => sub {return $_[0]->C_CFF_CONFIGDIR; }
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;

        if( !defined $o or $n != $o )
        {
          $self->log( $self->C_CFF_LOCCODESET, [$n]);
          $self->_set_config_file($self->C_CFF_NORESETCFG);
        }
      }
    );

# Path of file as input, relative or absolute
#
has request_file =>
    ( is                => 'rw'
    , isa               => 'Str'
    , lazy             => 1
    , default          => sub { return 'config.xyz'; }
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;
        if( !defined $o or $n ne $o )
        {
          $self->log( $self->C_CFF_REQFILESET, [$n]);
          $self->_set_config_file($self->C_CFF_NORESETCFG);
        }
      }
    );

# The documents object
#
has documents =>
    ( is                => 'ro'
    , isa               => 'AppState::Ext::Documents'
    , default           => sub { return AppState::Ext::Documents->new; }
    , init_arg          => undef
    , handles           =>
      [ qw( get_documents set_documents get_current_document select_document
            nbr_documents add_documents get_document set_document

            get_keys get_value set_value drop_value get_kvalue set_kvalue drop_kvalue
            pop_value push_value shift_value unshift_value
          )

        # Handle also in ConfigManager
        #
      , qw( C_DOC_SELOUTRANGE C_DOC_DOCRETRIEVED C_DOC_NODOCUMENTS
            C_DOC_NOHASHREF C_DOC_EVALERROR C_DOC_NOVALUE C_DOC_NOKEY
          )
      ]
    );

has _plugin_manager =>
    ( is                => 'ro'
    , isa               => 'AppState::Plugins::Feature::PluginManager'
    , init_arg          => undef
    , default           =>
      sub
      {
        my( $self) = @_;
        my $pm = AppState::Plugins::Feature::PluginManager->new;

        # Prepare search of feature plugins
        #
        my $path = Cwd::realpath($INC{"AppState.pm"});
        $path =~ s@/AppState.pm@@;

        # Search for any modules
        #
        $pm->search_plugins( { base => $path
                             , max_depth => 4
                             , search_regex => qr@/AppState/Plugins/ConfigDriver/[A-Z][\w]+.pm$@
                             , api_test => [ qw()]
                             }
                           );

        $pm->initialize;
        $self->_set_store_types(join '|', $pm->get_plugin_names);

        return $pm;
      }
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;

  $self->log_init('=CF');

#  if( $self->meta->is_mutable )
#  {
    # Overwrite the sub at _test_location. It is used for testing the subtype
    # 'AppState::Ext::ConfigFile::Types::Location'. At that point we do not
    # know the constant values to test against.
    #
    $_test_location =
    sub
    {
      # Codes are dualvars. doesn't matter if code is compared as string
      # or as number. But using a number might compare quicker.
      #
      return 0 + $_[0] ~~ [ $self->C_CFF_CONFIGDIR, $self->C_CFF_WORKDIR
                          , $self->C_CFF_FILEPATH, $self->C_CFF_TEMPDIR
                          ];
    };

#  }
}

#-------------------------------------------------------------------------------
#
sub initialize
{
#  my( $self) = @_;
}

#-------------------------------------------------------------------------------
#
sub _set_config_file
{
  my( $self, $reset) = @_;

#my $n = 0;
#while(1)
#{
#  my(@sr) = caller($n++);
#  last unless @sr;
#  say join( ', ', @sr[2,0]);
#}

  my $requestFilename = $self->request_file;
  my $location = $self->location;
  my $config_file;

  return unless defined $requestFilename
            and defined $location
         ;

  my $basename = File::Basename::fileparse( $requestFilename, qr/\.[^.]*/);

  # Get structure and according to location devise the filename and path
  #
  if( $location == $self->C_CFF_CONFIGDIR )
  {
    my $config_dir = AppState->instance->config_dir;
    $config_file = "$config_dir/$basename";
  }

  elsif( $location == $self->C_CFF_WORKDIR )
  {
    my $work_dir = AppState->instance->work_dir;
    $config_file = "$work_dir/$basename";
  }

  elsif( $location == $self->C_CFF_TEMPDIR )
  {
    my $temp_dir = AppState->instance->temp_dir;
    $config_file = "$temp_dir/$basename";
  }

  elsif( $location == $self->C_CFF_FILEPATH )
  {
    $config_file = Cwd::realpath($requestFilename);
  }

  # Change the filename extension and save the filename in the store object.
  #
  my $plObj = $self->_getStoragePlugin( undef, undef, $reset);
  my $extension = $plObj->file_ext;
  if( $config_file !~ m/\.$extension$/ )
  {
    $config_file =~ s/\.\w+$//;
    $config_file .= ".$extension";
  }

  $plObj->_configFile($config_file);
  $self->log( $self->C_CFF_CFGFILESET, [$config_file]);
}

#-------------------------------------------------------------------------------
#
sub _getStoragePlugin
{
  my( $self, $options, $control, $reset) = @_;

  $reset //= $self->C_CFF_NORESETCFG;
  my $storeObject;

  # Check if object is stored before and if we do not have to reset object.
  #
  if( $self->_has_store_type_object and $reset == $self->C_CFF_NORESETCFG )
  {
    $storeObject = $self->_store_type_object;
  }

  else
  {
    if( $self->_has_store_type_object )
    {
#      $storeObject = $self->_store_type_object;
#      $storeObject->cleanup if $storeObject->can('cleanup');
#      delete $storeObject;
    }

    my $pm = $self->_plugin_manager;

    # Always use C_PLG_CREATEALW to get a new object because it is possible
    # to get the same object for other config files.
    #
    $storeObject = $pm->get_object
                   ( { name => $self->store_type
                     , create => $pm->C_PLG_CREATEALW
                     }
                   );

    $self->_set_store_type_object($storeObject);
  }

  $storeObject->options($options) if ref $options eq 'HASH';
  $storeObject->control($control) if ref $control eq 'HASH';
  return $storeObject;
}

#-------------------------------------------------------------------------------
#
sub init
{
  my( $self, $options, $control) = @_;
  my $storagePlugin = $self->_getStoragePlugin( $options, $control);
  $self->log( $self->C_CFF_STOREPLGINIT, [$storagePlugin->config_file]);
}

#-------------------------------------------------------------------------------
#
sub load
{
  my( $self, $options, $control) = @_;

  my $storagePlugin = $self->_getStoragePlugin( $options, $control);
  my $documents = $storagePlugin->load;
  $self->set_documents($documents);
}

#-------------------------------------------------------------------------------
sub save
{
  my( $self, $options, $control) = @_;

  my $storagePlugin = $self->_getStoragePlugin( $options, $control);
  $storagePlugin->save($self->get_documents);
}

#-------------------------------------------------------------------------------
#
sub delete
{
  my($self) = @_;

  my $storagePlugin = $self->_getStoragePlugin;
  if( $storagePlugin->can('delete') )
  {
    $storagePlugin->delete;
  }

  else
  {
    $self->log($self->C_CFF_CANNOTDELDOC);
  }
}

#-------------------------------------------------------------------------------
#
sub clone_documents
{
  my($self) = @_;

  local $Storable::Deparse = 1;
  local $Storable::Eval = 1;
  return Storable::dclone($self->get_documents);
}

#-------------------------------------------------------------------------------
#
sub clone_document
{
  my( $self, $documentNbr) = @_;

  my $doc = $self->get_document($documentNbr);
  # test for wrong doc nbr!!!!!!!!!!
  local $Storable::Deparse = 1;
  local $Storable::Eval = 1;
  return Storable::dclone($doc);
}

#-------------------------------------------------------------------------------
# Clone any data(deep) using the Storable module.
#
sub clone
{
  my( $self, $data) = @_;
  local $Storable::Deparse = 1;
  local $Storable::Eval = 1;
  return Storable::dclone($data);
}

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;

1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState::Ext::ConfigFile - Module to control files for AppState::Config

=head1 SYNOPSIS


=head1 DESCRIPTION




=head1 SEE ALSO


=head1 AUTHOR

Marcel Timmerman, E<lt>mt1957@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Marcel Timmerman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
