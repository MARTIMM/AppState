package AppState;

use Modern::Perl;
use version; our $VERSION = qv('v0.4.15');
#use 5.010001 ;
use 5.10.1;

use namespace::autoclean;

use Moose;
use MooseX::NonMoose;
use MooseX::NonMoose::Meta::Role::Constructor;

extends qw( Class::Singleton AppState::Ext::Constants);

require Cwd;
require File::Basename;
require File::HomeDir;
require File::Path;

use AppState::Plugins::Feature::PluginManager;

#-------------------------------------------------------------------------------
#
has config_dir =>
    ( is                => 'ro'
    , isa               => 'Str'
    , default           =>
      sub
      { # Get the name of the program stripped of of its extention
        # like .pl or .t
        #
        my $basename = File::Basename::fileparse( $0, qr/\.[^.]*/);
        my $homeDir = File::HomeDir->my_home;
        my $path = '';

        # Check if directory is writable. There are accounts like apache
        # who cannot write in their home directory. When that happens, build
        # in the /tmp directory.
        #
        if( -w $homeDir )
        {
          $path = "$homeDir/.$basename";
        }

        else
        {
          $path = "/tmp/$homeDir/.$basename";
        }

        return $path;
      }
    , writer            => '_config_dir'
    );

has work_dir =>
    ( is                => 'ro'
    , isa               => 'Str'
    , writer            => '_work_dir'
    );

has temp_dir =>
    ( is                => 'ro'
    , isa               => 'Str'
    , writer            => '_temp_dir'
    );

# Cleanup temp directory when cleanup() is called, default is no cleanup.
#
has cleanup_temp_dir =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 0
    );

has use_work_dir =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 1
    );

has use_temp_dir =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 1
    );

has _plugin_manager =>
    ( is                => 'ro'
    , isa               => 'AppState::Plugins::Feature::PluginManager'
    , init_arg          => undef
    , default           => sub { AppState::Plugins::Feature::PluginManager->new; }
    , handles           => [qw( list_plugin_names check_plugin has_object
                                get_object cleanup_plugin add_plugin get_plugin
                                get_plugin_names plugin_exists nbr_plugins
                                add_subscriber
                              )
                           ]
    );

#-------------------------------------------------------------------------------
# Do some work after the object is build
#
sub BUILD
{
  my($self) = @_;

  # Cannot use method log_init() here which will use an instance of AppState
  # because it must get to the plugin manager.
  # _plugin_manager is created when the AppState is in its instantiation phase
  # and when executing a line such as 'AppState->instance()' the program will
  # get into deep recursion loop.

  # Error codes
  #
  if( $self->meta->is_mutable )
  {
    $self->code_reset;
    $self->const( 'C_APP_UNLINKTEMP', 'M_F_WARNING');
    $self->const( 'C_APP_APPDESTROY', 'M_F_WARNING');
    $self->const( 'C_APP_ILLAPPINIT', 'M_F_ERROR');

    __PACKAGE__->meta->make_immutable;
  }

  # Check the call stack. On this stack there must be the following entries in
  # the proper order to see to it that the new() function is not called
  # directly. Throw an exeption when the tests fail. This is maybe a costly
  # check but it will be once in the lifetime of the object.
  # Also do not use '__PACKAGE__->meta->make_immutable;' at the end of the
  # module.
  #
  # Class                               Calls
  # -----                               -----
  # AppState                            (Moose::Object | AppState)::new
  # Class::Singleton                    AppState::_new_instance
  # <Some user classs>                  Class::Singleton::instance
  #
  my $start = 0;
  my $found = 0;
  my $count = 0;
  my $i = 0;
  my $callInfo = '';
  while( my( $p, $f, $l, $s) = caller($i++) )
  {
#print  STDERR "X:  $p, $l, $s\n";
    if( $p eq 'Class::Singleton' and $s eq 'AppState::_new_instance' )
    {
      $start = 1;
      $found = 1;
    }

    elsif( $p eq 'Class::Singleton' and $s eq 'AppState::_new_instance' )
    {
      $found = 1;
    }

    elsif( $s =~ m/(Moose::Object|AppState)::new/ )
    {
      $callInfo = "At $f, line $l\n";
    }
  }
#print STDERR "\n";

  unless( $start and $found )
  {
    $self->wlog( "Called new() directly, use instance() instead! $callInfo"
               , $self->C_APP_ILLAPPINIT
               );
  }

  return;
}

#-------------------------------------------------------------------------------
# Overwrite Class::Singleton's _new_instance function to call this modules
# new function. Need it here to check the call stack done above in BUILD().
# Instance() is called from many places without arguments and therefore can
# initialize the module by accident with the wrong defaults. Now creation of
# directories is disabled so the user must now call initialize() and
# check_directories() to get all in a proper state. The passing of arguments is
# now disabled because of that.
#
sub _new_instance
{
  return $_[0]->new;
}

#-------------------------------------------------------------------------------
# Overwrite and/or initialize any object variables
#
sub initialize
{
  my( $self, %o) = @_;

  # Set tag of AppState
  #
  $self->log_init('=AP');

  # Initialize plugin manager
  #
  if( !$self->nbr_plugins )
  {
    my $pm = $self->_plugin_manager;

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
                        , searchRegex => qr@/AppState/Plugins/Feature/[A-Z][\w]+.pm$@
                        , apiTest => [ qw()]
                        }
                      );
#say "Features: ";
#$pm->list_plugin_names;
#say "Keys: ", join( ', ', $pm->get_plugin_names);

    $pm->initialize;
  }

  # Setup directory names
  #
  $self->_config_dir($o{config_dir}) if defined $o{config_dir} and $o{config_dir};
  $self->_work_dir($o{work_dir}) if defined $o{work_dir} and $o{work_dir};
  $self->_temp_dir($o{temp_dir}) if defined $o{temp_dir} and $o{temp_dir};

  $self->use_work_dir($o{use_work_dir}) if exists $o{use_work_dir};
  $self->use_temp_dir($o{use_temp_dir}) if exists $o{use_temp_dir};

  $self->cleanup_temp_dir($o{cleanup_temp_dir}) if defined $o{cleanup_temp_dir};

  return;
}

#-------------------------------------------------------------------------------
# Check directories for existence before usage. Create the directories if not
# available.
#
sub check_directories
{
  my($self) = @_;

  # Check config directory.
  #
  my $cdir = $self->config_dir;
  File::Path::make_path( $cdir, { verbose => 0, mode => oct(750)});
  $cdir = Cwd::realpath($cdir);
  $self->_config_dir($cdir);

  # Check workdir directory
  #
  if( $self->use_work_dir )
  {
    my $wdir = $self->work_dir;
    $wdir //= $cdir . "/Work";
    File::Path::make_path( $wdir, { verbose => 0, mode => oct(750)});
    $wdir = Cwd::realpath($wdir);
    $self->_work_dir($wdir);
  }

  # Check tempdir directory
  #
  if( $self->use_temp_dir )
  {
    my $tdir = $self->temp_dir;
    $tdir //= $cdir . "/Temp";
    File::Path::make_path( $tdir, { verbose => 0, mode => oct(750)});
    $tdir = Cwd::realpath($tdir);
    $self->_temp_dir($tdir);
  }

  return;
}

#-------------------------------------------------------------------------------
# Cleanup of objects.
#
sub cleanup
{
  my($self) = @_;

  if( $self->cleanup_temp_dir )
  {
    my $temp_dir = $self->temp_dir;
    my $cdir = Cwd::cwd;
    $temp_dir =~ s@$cdir/?@@;
    File::Path::remove_tree( $self->temp_dir
                           , { keep_root => 1
                             , result => \my $unlinkList
                             }
                           );

    $self->write_log( "Unlink $temp_dir/$_", $self->C_APP_UNLINKTEMP)
      for @$unlinkList;
  }

  # First make a log. After destroying plugins this will not be possible.
  #
  $self->wlog( "AppState set to be deleted after destroying plugins"
             , $self->C_APP_APPDESTROY
             );

  # Destroy plugin objects in this sequences
  #
  $self->_plugin_manager->cleanup( [qw( CommandLine YmlNodeTree
                                      PluginManager Process Config Log
                                    )
                                 ]
                               );

  # Kill myself. Next instance will create new object
  #
  $AppState::_instance = undef;

  return;
}

#-------------------------------------------------------------------------------
# Only create a new object if not yet existent. Otherwise return stored object
#
sub get_app_object
{
  my( $self, $name, %options) = @_;

  my $plg = $self->_plugin_manager;
  my $object = $plg->get_object
  ( { name => $name
    , create => $plg->C_PLG_CREATEIF
    , initOptions => {appState => $self}
    , modifyOptions => {%options}
    }
  );

  if( !defined $object )
  {
    say STDERR 'Object not instantiated. Something went wrong';
    if( !$self->nbr_plugins )
    {
      say STDERR 'No plugins installed. Perhaps forgot to call initialize()?';
    }
  }

  return $object;
}

#-------------------------------------------------------------------------------
no Moose;

1;
#-------------------------------------------------------------------------------
__END__
#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState - Module to give an application a base of utilities using a set of plugins

=head1 SYNOPSIS

  use Moose;
  extends qw(AppState::Ext::Constants);
  use AppState;

  my $app = AppState->instance;
  $app->use_work_dir(1);
  $app->initialize( config_dir => 'LocalConfigDir', use_temp_dir => 0);
  $app->check_directories;

  # Get an AppState::Plugins::Feature::Log object
  #
  my $log = $app->get_app_object('Log');
  $log->start_logging;
  $log->add_tag('A01');

  ...
  
  $app->cleanup;
  exit(0);

=head1 DESCRIPTION

This module can be used to setup basic facilities used in almost every program
without too much thinking. The module is subdivided into other modules and are
only loaded(required) when needed using a plugin system. Where possible the
modules are using other CPAN modules. At the time of writing the following
facilities are offered;

=over 2

=item * I<Make use of configuration files>. Programs may make notes about some
configurations which can be used the next time the program starts. Several
formats are available such as YAML, JSON, DataDumper, Storable and Memcached.
See L<AppState::Plugins::Feature::ConfigManager>.

=item * I<Make use of logfiles>. Messages from several parts of the modules and
also the user program can log messages into a logfile, The messages can be
filtered before actually being written to the file. See L<AppState::Plugins::Feature::Log>.

=item * I<Process commandline arguments and create help information>. A program
can have options and arguments. The caller will setup a structure in which all
options and arguments are described. Some of the sections are given to
the Getopt::Long module and other sections are used to provide a good help info
for the program. See L<AppState::Plugins::Feature::CommandLine>.

=item * I<Constructing a nodetree from a specific datastructure>. After creation
of the nodetree the tree can be traversed in several ways. The traversal program
will be given one or more handlers from the caller. These handlers will be run
when a node object is visited. See L<AppState::Plugins::Feature::NodeTree>.

=item * I<Make use of client - server communication>. A process can be set running
in the background as a daemon process after which another process can talk to
the server using several methods. At the time of writing this is only by way of
a messagequeue. See L<AppState::Plugins::Feature::Process>.

=item * I<Make use of plugins for the program>. Plugins are an ideal way to add
functionality without changing the main program. AppState itself is using this
module to provide all the functionality described here.
See L<AppState::Plugins::Feature::PluginManager>.


=back


=head1 INSTANCE METHODS

=over 2

=item * instance(%options)

The class is a singleton class. Get object instance of the AppState class. This
function will always return the same object.

=over 2

=item * B<config_dir> => directory path

=item * B<work_dir> => directory path

=item * B<temp_dir> => temporary files path

=item * B<cleanup_temp_dir> => boolean, clean temporary directory at cleanup()

=item * B<use_work_dir> => boolean, create work directory or not

=item * B<use_temp_dir> => boolean, create temp directory or not

These arguments above can only be set when the object is created i.e. on the
first call anywhere in your program. On the second call and later the arguments
are ignored. The only way to change is to delete the object and cleanup
everything with cleanup() or make use of initialize(). Any relative path is
converted into an absolute path to the directory. See initialize() for further
explanation.

=back

=back


=head1 METHODS

=over 2

=item * initialize(%options)

Initialize module. Directories are set from given options but not yet created.
Option keys in the hash are C<config_dir>, C<work_dir> and C<temp_dir>. The
values are the paths to those directories. Any relative path is converted into
an absolute path to the directory.

Another key can be given as C<cleanup_temp_dir> which is a
boolean. When set, the temp directory will be cleaned in the cleanup() method.
The defaults are;

  config_dir            <home_dir/.program_name>
  work_dir              <home_dir/.program_name/Work>
  temp_dir              <home_dir/.program_name/Temp>
  cleanup_temp_dir      0 (false)
  use_work_dir          1 (true)
  use_temp_dir          1 (true)

The config directory is a directory where files are stored such as a pidfile
(L<AppState::Plugins::Feature::Process>), configuration files
(L<AppState::Plugins::Feature::ConfigManager>) and logfile
(L<AppState::Plugins::Feature::Log>). The default location will be a directory
derived from the programname and.the users home directory. E.g. assume the
program is C<myProgram.pl> and the username is C<thisUser> then the path to the
configuration directory will be as C</home/thisUser/.myProgram> on most unix
systems.

The work directory is a directory where to dispose other files. The AppState
modules do not use it to store files. This argument can only be set when the
object is created like the C<config_dir> argument.

The temp directory is a directory where to store any files which can be deleted
afterwards. This cleanup is left to the user when C<cleanup_temp_dir> is 0
only the directory is created.

C<use_work_dir> and C<use_temp_dir> controls if the work or temp directories are
created or not.


=item * config_dir()

Get the path of the configuration directory.


=item * work_dir()

Get the path of the work directory.


=item * use_work_dir($yes_no)

=item * temp_dir()


Get the path of the temporary files directory.

=item * use_temp_dir($yes_no)


=item * check_directories()

Check directories for existence. Create the directories if they are not
available. Call initialize() before this method if any default directories
must be changed. Work and tem directories are not created when use_work_dir(0)
and use_temp_dir(0) is called.


=item * cleanup()

When cleanup() is called it will destroy all plugin objects and finally it will
destroy itself. Therefore when you want to use this method, always call
instance() after that to get a new instance object and never rely on any saved
addresses!



=item * get_app_object( $name, %options)

Get the object of a specific plugin. Use C<$name> to select the proper plugin.
Use get_plugin_names() of the _plugin_manager to learn the found plugin names.
C<%options> are the options given to the plugin when created or retrieved. Each
call using the same plugin name will return the same object.


=item * log( $messages, $msg_log_mask, $call_level)

Make use of method write() from L<AppState::Plugins::Feature::Log>. It will only call write() when
object is instantiated by the user program. This method is therefore mostly
interresting for use in plugins. $call_level is set to 0 by default and
incremented by one before calling write().


=item * log_init( $prefix, $call_level)

Some initialization before logging on behalf of the calling module. It will make
use of method add_tag() of module L<AppState::Plugins::Feature::Log> but only if the user program
has asked for the log object from AppState with get_app_object(). When not started
the initialization will be deferred until later.


#=item * _plugin_manager()
#
#Get the plugin manager object (L<AppState::Plugins::Feature::PluginManager>). A few calls are save
#and usefull such as get_plugin_names(), plugin_defined(), check_plugin() and
#nbr_plugins(). Other functions should not be used to prevent failure of the
#installed plugins. Other functions are made available to access the plugin
#manager indirectly.


=item * version()

Get current version of AppState module.

=back



=head1 PLUGIN MANAGER HANDLES

This module make use of the plugin manager plugin. A few of the methods are
placed in in this modules namespace. The list of the methods is:
list_plugin_names(), check_plugin(), has_object(), get_object(),
cleanup_plugin(), add_plugin, get_plugin(), get_plugin_names(), plugin_exists(),
nbr_plugins() and add_subscriber(). For an explanation of these functions see
L<AppState::Plugins::Feature::PluginManager>

The method get_app_object() is calling get_object() with a fixed set of
arguments like so;

  my $object = $plgmngr_object->get_object
  ( { name => $name
    , create => $plg->C_PLG_CREATEIF
    , initOptions => {appState => $self}
    , modifyOptions => {%options}
    }
  );



=head1 BUGS

No bugs yet.


=head1 SEE ALSO

The use of the modules which are instantiated by AppState is described in the
following manuals AppState::Plugins::Feature::Log, AppState::Plugins::Feature::ConfigManager, AppState::Plugins::Feature::Process,
AppState::Plugins::Feature::CommandLine, AppState::Plugins::Feature::Constants, AppState::Plugins::Feature::PluginManager and
AppState::Plugins::Feature::NodeTree


=head1 AUTHOR

Marcel Timmerman, E<lt>mt1957@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Marcel Timmerman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
