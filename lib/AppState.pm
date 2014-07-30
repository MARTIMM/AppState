package AppState;

use Modern::Perl;
use version; our $VERSION = qv('v0.4.15');
#use 5.010001 ;
use 5.10.1;

use namespace::autoclean;

require Cwd;
require File::Basename;
require File::HomeDir;
require File::Path;

use AppState::Plugins::Feature::PluginManager;
use AppState::Ext::Meta_Constants;

use Moose;
use MooseX::NonMoose;
#use MooseX::NonMoose::Meta::Role::Constructor;

extends qw( Class::Singleton AppState::Ext::Constants);


#-------------------------------------------------------------------------------
# Error codes
#
const( 'C_APP_UNLINKTEMP', 'M_F_WARNING', 'Unlink %s/%s');
const( 'C_APP_APPDESTROY', 'M_F_WARNING', 'AppState set to be deleted after destroying plugins');
const( 'C_APP_ILLAPPINIT', 'M_F_ERROR', 'Called new() directly, use instance() instead! %s');

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

  $self->log( $self->C_APP_ILLAPPINIT, [$callInfo]) unless $start and $found;

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

    # Search for any modules
    #
    $pm->search_plugins( { base => $path
                         , max_depth => 4
                         , search_regex => qr@/AppState/Plugins/Feature/[A-Z][\w]+.pm$@
                         , api_test => [ qw()]
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
    my $cdir = Cwd::cwd();
    $temp_dir =~ s@$cdir/?@@;
    File::Path::remove_tree( $self->temp_dir
                           , { keep_root => 1
                             , result => \my $unlinkList
                             }
                           );

    $self->log( $self->C_APP_UNLINKTEMP, [ $temp_dir, $_]) for @$unlinkList;
  }

  # First make a log. After destroying plugins this will not be possible.
  #
  $self->log($self->C_APP_APPDESTROY);

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
#    , initOptions => {appState => $self}
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
__PACKAGE__->meta->make_immutable;
no Moose;

1;
#-------------------------------------------------------------------------------
__END__

