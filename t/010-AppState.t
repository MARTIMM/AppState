# Testing module AppState.pm
#
use Modern::Perl;
use Test::Most;

require File::Basename;
require File::HomeDir;
require File::Path;
require Class::Load;
require Devel::Size;

#require AppState::PluginManager;

#-------------------------------------------------------------------------------
# Loading AppState module
#
BEGIN { use_ok('AppState') };

#-------------------------------------------------------------------------------
# Create AppState object. All default values.
#
my $a = AppState->instance;

is( $a->C_APP_UNLINKTEMP
  , 0x91000001
  , 'Check constant C_APP_UNLINKTEMP = 0x91000001'
  );

#my $m = $a->get_app_object('Constants');
$a->check_directories;

isa_ok( $a, 'AppState', 'Check config object type');
ok( $a->has_instance, 'Test has_instance of AppState object');

#-------------------------------------------------------------------------------
# This is what Appstate does for its config directory by default
#
my $basename = File::Basename::fileparse( $0, qr/\.[^.]*/);
my $cdir = File::HomeDir->my_home . "/.$basename";

ok( -d $cdir, "Test config directory $cdir");
ok( -d "$cdir/Work", "Test work directory $cdir/Work");
ok( -d "$cdir/Temp", "Test temp directory $cdir/Temp");

#-------------------------------------------------------------------------------
# Check 'has' variables of AppState
#
my $result;
dies_ok { $a->config_dir('t/AppState') } 'Not able to change config_dir';
dies_ok { $a->work_dir('t/AppState') } 'Not able to change work_dir';
dies_ok { $a->temp_dir('t/AppState') } 'Not able to change temp_dir';
#dies_ok { $a->plugin_manager(AppState::PluginManager->new) } 'Not able to initialize plugin_manager';

$a->cleanup_temp_dir(1);
ok( $a->cleanup_temp_dir, 'Cleaning up tempdir set');

$a->cleanup_temp_dir(0);
ok( !$a->cleanup_temp_dir, 'Cleaning up tempdir unset');

#-------------------------------------------------------------------------------
# Get size of AppState object
#
my $size = Devel::Size::total_size($a);
pass "AppState object size: $size";

#-------------------------------------------------------------------------------
# Drop the instance and remove directories for next tests
#
$a->cleanup;
File::Path::remove_tree($cdir);

#-------------------------------------------------------------------------------
# New start
#
$cdir = 't/AppState';
$a = AppState->instance;
$a->initialize( config_dir => 'ABC');
is( $a->config_dir, 'ABC', "Check configdir name = ABC");
ok( !-d 'ABC', "Directory 'ABC' does not exist");

$a = AppState->instance;
$a->initialize(config_dir => $cdir, cleanup_temp_dir => 1);
is( $a->config_dir, $cdir, "Check configdir name = $cdir");
$a->check_directories;

ok( -d $cdir, "Test config directory $cdir");
ok( -d "$cdir/Work", "Test work directory $cdir/Work");
ok( -d "$cdir/Temp", "Test temp directory $cdir/Temp");

#-------------------------------------------------------------------------------
my $log = $a->get_app_object('Log');
#$log->die_on_error(1);
#$log->show_on_error(0);
$log->show_on_warning(1);
$log->do_append_log(0);

$log->start_logging;

$log->do_flush_log(1);
#$log->log_mask($m->M_ALL);
#$log->log_mask($m->M_WARNING | $m->M_ERROR);

my $tagName = '010';
$log->add_tag($tagName);

#-------------------------------------------------------------------------------
# Destroy apps
#
my( $msgCode, $severity, $source, $modTag, $errCode) = ( '', 0, '', '', 0);
$log->add_subscriber( '=AP'
                    , sub
                      { ( $source, $modTag, $errCode) = @_;

                        $msgCode = $errCode & $a->M_EVNTCODE;
                        $severity = $errCode & $a->M_SEVERITY;

#say sprintf( "Tag: %s, Err: 0x%08x, Event: 0x%03x, Sev: 0x%01x"
#           , $modTag, $errCode, $msgCode, $severity
#          );
                      }
                    );

# Need to save code before destroying all modules.
#
my $appDestroyCode = $a->C_APP_APPDESTROY;
$a->cleanup;

# Checkout this log message
#  =AP 0285 F AppState set to be deleted after destroying plugins
is( $errCode, $appDestroyCode, 'Check last code from AppState');

#-------------------------------------------------------------------------------
File::Path::remove_tree($cdir);

done_testing();
