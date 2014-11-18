package AppState::Plugins::ConfigManager;

use Modern::Perl;
use version; our $VERSION = version->parse("v0.9.6");
use 5.010001;

use namespace::autoclean;

use Moose;
extends qw(AppState::Plugins::Log::Constants);

use AppState;
use AppState::Ext::ConfigFile;
use AppState::Plugins::Log::Meta_Constants;

#-------------------------------------------------------------------------------
# Error codes
#
def_sts( 'C_CFM_CFGSELECTED'   , 'M_INFO', 'Config %s selected');
def_sts( 'C_CFM_CFGNOTEXIST'   , 'M_F_WARNING', 'Config %s not existent');
def_sts( 'C_CFM_CFGADDED'      , 'M_INFO', 'Config %s added');
def_sts( 'C_CFM_CFGEXISTS'     , 'M_F_WARNING', 'Config %s already exists');
def_sts( 'C_CFM_CFGMODIFIED'   , 'M_INFO', 'Config %s modified and selected');
def_sts( 'C_CFM_CFGDROPPED'    , 'M_INFO', 'Config %s dropped');
def_sts( 'C_CFM_CFGSELDEFAULT' , 'M_INFO', 'Current config set to %s');
def_sts( 'C_CFM_CFGFLREMOVED'  , 'M_INFO', 'Config %s removed');

#-------------------------------------------------------------------------------
# Config objects is a hash which is used to find an AppState::Ext::ConfigFile
# object. There is always one object used as a default. The purpose of that
# object is to keep track of where a storage is to be found and what type of
# storage is used. The following fields are needed but can be set later;
# store_type, location and request_file.
#
has _config_objects =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , init_arg          => undef
    , traits            => ['Hash']
    , handles           =>
      { _set_config_object      => 'set'
      , _get_config_object      => 'get'
      , nbr_config_objects        => 'count'
      , has_config_object         => 'exists'
      , get_config_object_names    => 'keys'
      , _drop_config_object     => 'delete'
      }
    );

has current_config_object_name =>
    ( is                => 'ro'
    , isa               => 'Str'
#    , default          => 'defaultConfigObject'
    , writer            => '_set_current_config_object_name'
    , init_arg          => undef
    );

has _current_config_object =>
    ( is                => 'ro'
    , isa               => 'AppState::Ext::ConfigFile'
    , writer            => '_set_current_config_object'
    , init_arg          => undef
    , handles           =>
      [ qw( get_documents set_documents get_current_document
            select_document nbr_documents add_documents
            get_document set_document request_file

            get_keys get_value set_value drop_value get_kvalue
            set_kvalue drop_kvalue pop_value push_value
            shift_value unshift_value

            store_type location config_file
            load save clone_documents
            clone_document init delete
          )

        # From ConfigFile
        #
      , qw( C_CFF_CONFIGDIR C_CFF_WORKDIR C_CFF_FILEPATH
            C_CFF_TEMPDIR
          )

        # From Documents via ConfigFile
        #
      , qw( C_DOC_SELOUTRANGE C_DOC_DOCRETRIEVED C_DOC_NODOCUMENTS
            C_DOC_NOHASHREF C_DOC_EVALERROR C_DOC_NOVALUE C_DOC_NOKEY
            C_DOC_NOARRAYREF C_DOC_KEYNOTEXIST C_DOC_MODTRACE C_DOC_MODKTRACE
            C_DOC_MODERR
          )

        # From ConfigIO via ConfigFile
        #
      , qw( C_CIO_CFGREAD C_CIO_CFGWRITTEN C_CIO_CFGNOTREAD C_CIO_CFGNOTWRITTEN
            C_CIO_IOERROR C_CIO_SERIALIZEFAIL C_CIO_DESERIALFAIL
            C_CIO_CLONEFAIL C_CIO_DATACLONED C_CIO_NOSERVER
          )
       ]
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;
  $self->log_init('=CM');
}

#-------------------------------------------------------------------------------
# Remove all but the default config
#
sub plugin_cleanup
{
  my($self) = @_;

  foreach my $config_object_name ($self->get_config_object_names)
  {
    next if $config_object_name eq 'defaultConfigObject';
    $self->drop_config_object($config_object_name);
  }
}

#-------------------------------------------------------------------------------
#
sub plugin_initialize
{
  my($self) = @_;

  # Create default config object
  #
  if( $self->nbr_config_objects == 0 )
  {
    my $cff = AppState::Ext::ConfigFile->new;
    $cff->store_type('Yaml');

    $cff->location($cff->C_CFF_CONFIGDIR);
    $cff->request_file('config');

    # Place it in the _config_objects HashRef
    #
    $self->_set_config_object( defaultConfigObject => $cff);

    # Select the object as the current default
    #
    $self->select_config_object('defaultConfigObject');
  }
}

#-------------------------------------------------------------------------------
# Set the current config object. If the config structure is not defined the
# current config is not changed. Return 0 on failure(not found) and 1 on ok.
#
sub select_config_object
{
  my( $self, $config_object_name) = @_;

  if( $self->has_config_object($config_object_name) )
  {
    $self->log( $self->C_CFM_CFGSELECTED, [$config_object_name]);
    if( !defined $self->_current_config_object
     or $config_object_name ne $self->_current_config_object )
    {
      $self->_set_current_config_object_name($config_object_name);
      $self->_set_current_config_object($self->_get_config_object($config_object_name));
    }
  }

  else
  {
    $self->log( $self->C_CFM_CFGNOTEXIST, [$config_object_name]);
  }
}

#-------------------------------------------------------------------------------
# Add a new config file. It is automatically selected. Change current selection
# to the new object
#
sub add_config_object
{
  my( $self, $config_object_name, $config_struct) = @_;

  if( $self->has_config_object($config_object_name) )
  {
    $self->log( $self->C_CFM_CFGEXISTS, [$config_object_name]);
    $self->select_config_object($config_object_name);
  }

  else
  {
    $self->log( $self->C_CFM_CFGADDED, [$config_object_name]);
    my $config_object = AppState::Ext::ConfigFile->new(%$config_struct);
    $self->_set_config_object( $config_object_name, $config_object);
    $self->_set_current_config_object_name($config_object_name);
    $self->_set_current_config_object($config_object);
  }

  $self->log( $self->C_CFM_CFGSELECTED, [$config_object_name]);
}

#-------------------------------------------------------------------------------
# Modify config file. Return 0 on failure(config does not exists) and 1 on ok.
# Change current selection to the modified object.
#
sub modify_config_object
{
  my( $self, $config_object_name, $config_struct) = @_;

  if( $self->has_config_object($config_object_name) )
  {
    $self->_set_current_config_object_name($config_object_name);
    $self->_set_current_config_object($self->_get_config_object($config_object_name));
    $self->log( $self->C_CFM_CFGSELECTED, [$config_object_name]);

    $self->store_type($config_struct->{store_type})
      if defined $config_struct->{store_type};
    $self->location($config_struct->{location})
      if defined $config_struct->{location};
    $self->request_file($config_struct->{request_file})
      if defined $config_struct->{request_file};

    $self->log( $self->C_CFM_CFGMODIFIED, [$config_object_name]);
  }

  else
  {
    $self->log( $self->C_CFM_CFGNOTEXIST);
  }
}

#-------------------------------------------------------------------------------
# Drop config file. The structure defined by the config name
# 'defaultConfigObject' may never be dropped. Return 0 on failure(config
# does not exist or is defaultConfig) and 1 on ok. When the current config
# is dropped defaultConfigObject will be selected.
#
sub drop_config_object
{
  my( $self, $config_object_name) = @_;

  if( $config_object_name ne 'defaultConfigObject'
  and $self->has_config_object($config_object_name)
    )
  {
    if( $config_object_name eq $self->current_config_object_name )
    {
      $self->_set_current_config_object_name('defaultConfigObject');
      $self->_set_current_config_object($self->_get_config_object('defaultConfigObject'));
      $self->log( $self->C_CFM_CFGSELDEFAULT, [$config_object_name]);
    }

    $self->_drop_config_object($config_object_name);
    $self->log( $self->C_CFM_CFGDROPPED, [$config_object_name]);
  }

  else
  {
    $self->log( $self->C_CFM_CFGNOTEXIST, [$config_object_name]);
  }
}

#-------------------------------------------------------------------------------
# Remove config file from disk and drop the config too. defaultConfigObject may
# never be deleted. Return 0 on failure(config does not exist or is
# defaultConfig) and 1 on ok.
#
sub remove_config_object
{
  my( $self, $config_object_name) = @_;

  if( $config_object_name ne 'defaultConfigObject'
  and $self->has_config_object($config_object_name)
    )
  {
    if( $config_object_name eq $self->current_config_object_name )
    {
      $self->_set_current_config_object_name('defaultObjectConfig');
      $self->_set_current_config_object($self->_get_config_object('defaultConfigObject'));
      $self->log( $self->C_CFM_CFGSELDEFAULT, [$config_object_name]);
    }

    my $config_file = $self->_get_config_object($config_object_name)->config_file;

    $self->_drop_config_object($config_object_name);
    $self->log( $self->C_CFM_CFGDROPPED, [$config_object_name]);
    unlink $config_file;
    $self->log( $self->C_CFM_CFGFLREMOVED, [$config_object_name]);

  }

  else
  {
    $self->log( $self->C_CFM_CFGNOTEXIST, [$config_object_name]);
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

AppState::Plugins::ConfigManager - Plugin to manage configuration files

=head1 SYNOPSIS

  # Get the top level module
  #
  use AppState;
  use AppState::Constants;

  my $m = AppState::Constants->new;
  my $a = AppState->instance();

  # Get the configuration module
  #
  my $c = $a->get_app_object('Config');

  # Add a configuration file specification
  #
  $c->addConfig( 'ChessGames'
               , { name         => 'config-file'
                 , type         => 'Storable'
                 , location     => $m->C_CFG_CONFIGDIR
                 }
               );

  # Oops, must be of Yaml type.
  #
  $c->modifyConfig( 'ChessGames', { type => 'Yaml'});

  # Select the configuration and load the file (or create if new)
  #
  $c->selectConfig('ChessGames');
  $c->load;

  # Add second document if not there already.
  #
  if( $c->nbrConfigs < 2 )
  {
    my $dn = $c->addEmptyDocument;
    print "Created document: $dn, Config type: "
        , $c->getConfigType, "\n";
  }

  # Add values to config
  #
  $c->set_value( '/chessTournament/2013/location'
              , 'IJmuiden, Netherlands');
  $c->set_value( '/chessTournament/2013/players'
              , [qw(Euwe Aljechin Botvinnik Alekhine)]
              );

  # Modify array value
  #
  $c->push_value( '/chessTournament/2013/players'
               , [qw(Fischer Spassky Capablanca)]
               );

  # Select first document
  #
  $c->select_document(1);

  # Get Program values
  #
  my $defaultBgColor = $c->get_value('/defaults/screen/background');
  my $bgColor = $c->get_value('/screen/background');
  $c->set_value( 'screen/background', $defaultBgColor)
     unless defined $bgColor;

  my $docFile = $c->get_kvalue( '/docs', '/games/chess');
  if( ! $docFile )
  {
    $docFile = '/usr/share/docs/chess/index.html';
    $c->set_kvalue( '/docs', '/games/chess', $docFile);
  }

  # Save all documents
  #
  $c->save;


=head1 DESCRIPTION

This module will help to create, get and save data from configuration files
which is often used to store control data for the program.


=head2 Changing config data

There are some methods created which help to store and retrieve data from the
configuration. For these modules a path to the values can be used in the same
way as on a filesystem. If this is not convenient, the root of the data can be
found with a call like;

  my $root = $c->get_value('/');

After that the control is all yours. Be aware that the methods will transform a
path e.g. '/usr/doc/chess' into something like C<< $root->{usr}{doc}{chess} >>.
This means that the root starts with hash references and when modified into
some other type like array ref, you are on your own because the methods can not
consume other types as a path.

Note that you can hook into any other place of this data. Take the example above
one can do this;

  my $doc = $c->get_value('/usr/doc');
  $doc->{weiqi} = '/MyLocation/Weigi/index.html';

The values of the keypaths can be anything like strings, numbers and references
to scalars, hashes and arrays. Only hash values can be followed further in a
path. When pathlike parts need to be used whithin a path there are methods
like set_kvalue, get_kvalue etcetera.


=head2 Constants

Use of codes as arguments to several methods are defined in
L<AppState::Plugins::Log::Constants>. In the examples below the following is assumed;

  use AppState::Constants;
  my $m = AppState::Constants->new;

A constant such as C<< $m->C_CFG_CONFIGDIR >> can then be used. In the
documentation below only the code C_CFG_CONFIGDIR will be mentioned.


=head2 Storage types

The types of storage will be dictated by the available plugins which
L<AppState::Plugins::ConfigManager> delivers. A list of pluginnames is returned by the following
lines;

  use AppState;
  my $c = AppState->instance->get_app_object('Config');
  my @pns = $c->plugin_manager->get_plugin_names;

See also L<AppState::PluginManager>.


=head2 Storage locations

L<AppState> controls a number of directories where other other modules can store
files into. AppsState::Config will use these places by setting the C<location>
key in the configfile description. The constants which control these locations
are C<C_CFG_CONFIGDIR>, C<C_CFG_WORKDIR>, C<C_CFG_TEMPDIR> and
C<C_CFG_FILEPATH>. All constants except for C<C_CFG_FILEPATH> will cause the
provided filename stripped from its path and placed in the config directory,
work directory or the temporary files directory respectively.

Below there is a small table to show the current formats and their measurements
and notes. The numbers used in size and speed are just rough numbers so as to
compare which is biggest(larger number) or fastest(higher number). To give an
idea of the test, the yaml configuration is about 830 Kb and about 70100 lines.

             Loading Saving       Multiple
  Format      speed   speed  Size documents
  ---------- ------- ------ ----- ---------
  Yaml                14000   811 Yes
  Storable               18   304 No
  DataDumper             86   343 No
  FreezeThaw            884   323 No
  Json

  Format     Notes
  ---------- ----------------------------------------------------------
  Yaml       Easy readable and editable which was the purpose of YAML.
             As shown above it is the slowest and generates the largest
             files. It is very good to edit a configuration or to parse
             special types of files. Examples are programs to convert
             yaml to xml.
  Storable   Not readable or editable. Binary storage. It is blinding
             fast.
  DataDumper Readable but not advisible to edit. All pretty printing
             is turned off.
  FreezeThaw Readable but not advisable to edit. Also a oneliner
             datastructure.
  Json

=head1 INSTANCE METHOD

The way to get the config object is by using the line shown below.

  my $config = AppState->instance()->get_app_object('Config');

This will always return the same address of the object. The first call will
create it. The config object manages several configuration structures of which
one is defined by default. The key to this structure is C<defaultConfig>. The
basename of the file is C<config>, the type used to store data is C<Yaml> and
the location is in the config directory which is retrieved from L<AppState>. The
typenames are shown above in the tables.


=head1 METHODS

=over 2

=item nbrConfigs()

Get the number of configuration structures.


=item hasConfig($keyname)

Check if configuration exists. Returns true if found, false if not.


=item getConfigNames()

Return a list of all structure keynames.


=item currentConfigName()

Return the keyname of the currently selected configuration structure.


=item selectConfig($keyname)

Set the keyname of an existing structure to be the current config. When the
object is created, there is one structure selected named 'defaultConfig'.


=item addConfig( $keyname, $configDescription)

Add a new configfile structure. The $configDescription is a hashreference
with the following obliged keys;

  basename      Filename or path to file. This is extended with an
                extension depending on storage method. The path is ignored
                unless code C_CFG_FILEPATH is used for location. See below.
  type          Type of storage. Look for the pluginnames to use. E.g. Yaml.
  location      Can be one of C_CFG_CONFIGDIR, C_CFG_WORKDIR, C_CFG_FILEPATH
                or C_CFG_TEMPDIR. These code can be used as follows;

                use AppState;
                my $c = AppState->instance->get_app_object('Config');
                $c->addConfig( 'ChessGames'
                             , { name           => 'config-file'
                               , type           => 'Storable'
                               , location       => $m->C_CFG_CONFIGDIR
                               }
                             );


Other keys can be used and are interpreted solely by the storage plugins. See
the plugin documentation C<AppState::Config::Yaml>, C<AppState::Config::Storable>,
C<AppState::Config::FreezeThaw>, C<AppState::Config::DataDumper>
and C<AppState::Config::Json>.

=item plugin_manager()

=item cleanup()

Cleanup all structures by saving data first to files. This function will be
called when calling cleanup() from the AppState module.


=back

=head1 SEE ALSO

Foreach of the plugins there is some info and also a module where they all
inherit from. The plugins are L<Appstate::Yaml>, L<Appstate::Storable>,
L<Appstate::DataDumper>, L<Appstate::FreezeThaw>. The module they inherit
is L<Appstate::MethodBase>.

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


