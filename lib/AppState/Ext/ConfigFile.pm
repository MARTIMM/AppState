package AppState::Ext::ConfigFile;

use Modern::Perl;
use version; our $VERSION = '' . version->parse("v0.0.2");
use 5.010001;

use namespace::autoclean;

use Moose;
use Moose::Util::TypeConstraints;

extends qw(AppState::Ext::Constants);

require Storable;

use AppState;
use AppState::Ext::Documents;

#-------------------------------------------------------------------------------
# Possible types for storage. This is set by the plugin manager default
# initialization. Need to use non-moose variable because of test in subtype
# can not use $self to use a getter such as $self->storeTypes().
#
my $__storeTypes__ = '';
has _storeTypes =>
    ( is                => 'ro'
    , isa               => 'Str'
    , init_arg          => undef
    , writer            => '_setStoreTypes'
#    , default          => ''
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;
        $__storeTypes__ = $n;
      }
    );

# Subtype to be used to test store_type against.
#
subtype 'AppState::Ext::ConfigFile::Types::Storage'
    => as 'Str'
    => where { $_ =~ m/$__storeTypes__/ }
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
          $self->wlog( "Store type set to $n", $_[0]->C_CFF_STORETYPESET);
          $self->_setConfigFile($self->C_CFF_RESETCFG);
        }
      }
    );

has _storeTypeObject =>
    ( is                => 'ro'
    , isa               => 'Maybe[Object]'
    , init_arg          => undef
    , writer            => '_setStoreTypeObject'
    , predicate         => '_hasStoreTypeObject'
    , handles           => [
                                # Make handle in ConfigManager.
                                #
                            qw( configFile
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
          $self->wlog( "Location code set to $n"
                     , $self->C_CFF_LOCCODESET
                     );
          $self->_setConfigFile($self->C_CFF_NORESETCFG);
        }
      }
    );

# Path of file as input, relative or absolute
#
has requestFile =>
    ( is                => 'rw'
    , isa               => 'Str'
    , lazy             => 1
    , default          => sub { return 'config.xyz'; }
#      sub
#      {
#       my($self) = @_;
#       my $defFilename = 'config.xyz';
#       return $defFilename;
#      }
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;
        if( !defined $o or $n ne $o )
        {
          $self->wlog( "Request for file $n", $self->C_CFF_REQFILESET);
          $self->_setConfigFile($self->C_CFF_NORESETCFG);
        }
      }
    );

# Name/path of the file given to by the storage plugins.
#
#has configFile =>
#    ( is               => 'ro'
#    , isa              => 'Str'
#    , default          => 'config.xyz'
#    , writer           => '_configFile'
#    , init_arg         => undef
#    );

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

has _pluginManager =>
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

        # Number of separators in the path is the depth of the base
        #
        my(@lseps) = $path =~ m@(/)@g;

        # Search for any modules
        #
        $pm->search_plugins( { base => $path
                            , depthSearch => 3 + @lseps
                            , searchRegex => qr@/AppState/Plugins/ConfigDriver/[A-Z][\w]+.pm$@
                            , apiTest => [ qw()]
                            }
                          );

        $pm->initialize;
        $self->_setStoreTypes(join '|', $pm->get_plugin_names);

        return $pm;
      }
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;

  if( $self->meta->is_mutable )
  {
    $self->log_init('=CF');

    # Error codes. These codes must also be handled by ConfigManager.
    #
#    $self->code_reset;
    $self->const( 'C_CFF_STORETYPESET', 'M_INFO');
    $self->const( 'C_CFF_LOCCODESET',   'M_INFO');
    $self->const( 'C_CFF_REQFILESET',   'M_INFO');
    $self->const( 'C_CFF_CFGFILESET',   'M_INFO');
    $self->const( 'C_CFF_CREATEALW',    'M_INFO');
    $self->const( 'C_CFF_CANNOTDELDOC', 'M_WARNING');
    $self->const( 'C_CFF_DOCCLONED',    'M_INFO');
    $self->const( 'C_CFF_CANNOTCLODOC', 'M_WARNING');
    $self->const( 'C_CFF_STOREPLGINIT', 'M_INFO');

    # Location values
    #
#    $self->code_reset;
    $self->const( 'C_CFF_CONFIGDIR',    'M_CODE', 'Config dir location');
    $self->const( 'C_CFF_WORKDIR',      'M_CODE', 'Workdir location');
    $self->const( 'C_CFF_FILEPATH',     'M_CODE', 'Users filepath location');
    $self->const( 'C_CFF_TEMPDIR',      'M_CODE', 'Tempdir location');

    # Reset values, only used locally
    #
#    $self->code_reset;
    $self->const( 'C_CFF_NORESETCFG',   'M_CODE');
    $self->const( 'C_CFF_RESETCFG',     'M_CODE');

    my $meta = $self->meta;

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

    __PACKAGE__->meta->make_immutable;
  }
}

#-------------------------------------------------------------------------------
#
sub initialize
{
  my( $self) = @_;

  # Initialize plugin manager
  #
#  if( !$self->nbr_plugins )
  if( 0 )
  {
    my $pm = $self->_pluginManager;

    # Prepare search of feature plugins
    #
    my $path = Cwd::realpath($INC{"AppState.pm"});
    $path =~ s@/AppState.pm@@;

    # Number of separators in the path is the depth of the base
    #
    my(@lseps) = $path =~ m@(/)@g;

    # Search for any modules
    #
    $pm->search_plugins( { base => $path
                        , depthSearch => 3 + @lseps
                        , searchRegex => qr@/AppState/Plugins/ConfigDriver/[A-Z][\w]+.pm$@
                        , apiTest => [ qw()]
                        }
                      );
#    $pm->add_plugin( Constants => { class => 'AppState::Ext::Constants'
#                               , libdir => $path
#                               }
#                );

say "Features: ", $pm->list_plugin_names;
say "Keys: ", join( ', ', $pm->get_plugin_names);
    $pm->initialize;
    $self->_setStoreTypes(join '|', $pm->get_plugin_names);

    # Initialize attributes
    #
#    $self->store_type('Yaml');
#    $self->location($self->C_CFF_CONFIGDIR);
#    $self->requestFile('config.xyz');
  }
}

#-------------------------------------------------------------------------------
#
sub _setConfigFile
{
  my( $self, $reset) = @_;

#my $n = 0;
#while(1)
#{
#  my(@sr) = caller($n++);
#  last unless @sr;
#  say join( ', ', @sr[2,0]);
#}

  my $requestFilename = $self->requestFile;
  my $location = $self->location;
  my $configFile;

  return unless defined $requestFilename
            and defined $location
         ;

  my $basename = File::Basename::fileparse( $requestFilename, qr/\.[^.]*/);

  # Get structure and according to location devise the filename and path
  #
  if( $location == $self->C_CFF_CONFIGDIR )
  {
    my $config_dir = AppState->instance->config_dir;
    $configFile = "$config_dir/$basename";
  }

  elsif( $location == $self->C_CFF_WORKDIR )
  {
    my $work_dir = AppState->instance->work_dir;
    $configFile = "$work_dir/$basename";
  }

  elsif( $location == $self->C_CFF_TEMPDIR )
  {
    my $temp_dir = AppState->instance->temp_dir;
    $configFile = "$temp_dir/$basename";
  }

  elsif( $location == $self->C_CFF_FILEPATH )
  {
    $configFile = Cwd::realpath($requestFilename);
  }

  # Change the filename extension and save the filename in the store object.
  #
  my $plObj = $self->_getStoragePlugin( undef, undef, $reset);
  my $extension = $plObj->fileExt;
  if( $configFile !~ m/\.$extension$/ )
  {
    $configFile =~ s/\.\w+$//;
    $configFile .= ".$extension";
  }

  $plObj->_configFile($configFile);
  $self->wlog( "Config filename set to $configFile", $self->C_CFF_CFGFILESET);
}

#-------------------------------------------------------------------------------
#
sub _getStoragePlugin
{
  my( $self, $options, $control, $reset) = @_;

  $reset //= $self->C_CFF_NORESETCFG;
  my $storeObject;

  # Check if object is stored before
  #
  if( $self->_hasStoreTypeObject and $reset == $self->C_CFF_NORESETCFG )
  {
    $storeObject = $self->_storeTypeObject;
  }

  else
  {
    my $pm = $self->_pluginManager;

    # Always use C_PLG_CREATEALW to get a new object because it is possible
    # to get the same object for other config files.
    #
    $storeObject = $pm->get_object
                   ( { name => $self->store_type
                     , create => $pm->C_PLG_CREATEALW
                     }
                   );

    $self->_setStoreTypeObject($storeObject);
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

  $self->wlog( "Config", $storagePlugin->configFile, "initialized"
             , $self->C_CFF_STOREPLGINIT
             );
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
    $self->wlog( "Cannot delete() documents", $self->C_CFF_CANNOTDELDOC);
  }
}

#-------------------------------------------------------------------------------
#
sub cloneDocuments
{
  my($self) = @_;

  local $Storable::Deparse = 1;
  local $Storable::Eval = 1;
  return Storable::dclone($self->get_documents);
}

#-------------------------------------------------------------------------------
#
sub cloneDocument
{
  my( $self, $documentNbr) = @_;

  my $doc = $self->get_document($documentNbr);
  # test for wrong doc nbr!!!!!!!!!!
  local $Storable::Deparse = 1;
  local $Storable::Eval = 1;
  return Storable::dclone($doc);

#==========
  my $clonedData = undef;
  my $storagePlugin = $self->_getStoragePlugin;
  if( $storagePlugin->can('clone') )
  {
    $clonedData = $storagePlugin->clone($self->get_document($documentNbr));
    # test for wrong doc nbr!!!!!!!!!!
  }

  else
  {
    $self->wlog( "Cannot clone() documents in", ref $storagePlugin
               , $self->C_CFF_CANNOTCLODOC
               );
  }

  return $clonedData;
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

#==========
#  my( $self) = @_;
  my $clonedDocs = undef;
  my $storagePlugin = $self->_getStoragePlugin;
  if( $storagePlugin->can('clone') )
  {
    $clonedDocs = $storagePlugin->clone($self->get_documents);
    $self->wlog( "Document cloned = $clonedDocs", $self->C_CFF_DOCCLONED);
  }

  else
  {
    $self->wlog( "Cannot clone() documents", $self->C_CFF_CANNOTCLODOC);
  }

  return $clonedDocs;
}

#-------------------------------------------------------------------------------

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
