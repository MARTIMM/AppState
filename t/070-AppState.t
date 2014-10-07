# Testing module AppState.pm
#
use Modern::Perl;
use Test::Most;

require File::Basename;
require File::HomeDir;
require File::Path;
require Class::Load;
require Devel::Size;
require Cwd;

#-------------------------------------------------------------------------------
# Loading AppState module
#
BEGIN { use_ok('AppState') };

#-------------------------------------------------------------------------------
# Create AppState object. All default values.
#
my $app = AppState->instance;
$app->initialize( use_temp_dir => 1, use_work_dir => 1, check_directories => 1);

isa_ok( $app, 'AppState');
ok( $app->has_instance, 'Test has_instance of AppState object');

ok( $app->use_work_dir, "Use work directory");
ok( $app->use_temp_dir, "Use temp directory");

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
dies_ok { $app->config_dir('t/AppState') } 'Not able to change config_dir';
dies_ok { $app->work_dir('t/AppState') } 'Not able to change work_dir';
dies_ok { $app->temp_dir('t/AppState') } 'Not able to change temp_dir';
#dies_ok { $app->plugin_manager(AppState::PluginManager->new) } 'Not able to initialize plugin_manager';

$app->cleanup_temp_dir(1);
ok( $app->cleanup_temp_dir, 'Cleaning up tempdir set');

$app->cleanup_temp_dir(0);
ok( !$app->cleanup_temp_dir, 'Cleaning up tempdir unset');

#-------------------------------------------------------------------------------
# Get size of AppState object
#
my $size = Devel::Size::total_size($app);
pass "AppState object size: $size";

#-------------------------------------------------------------------------------
# Drop the instance and remove directories for next tests
#
$app->cleanup;
File::Path::remove_tree($cdir);

#-------------------------------------------------------------------------------
# New start
#
$cdir = 't/AppState';
$app = AppState->instance;
$app->initialize( config_dir => 'ABC'
                , use_temp_dir => 1
                , use_work_dir => 1
#                , check_directories => 1
                );

#$real_path = Cwd::realpath('.') . "/ABC";
my $real_path = "ABC";
is( $app->config_dir, $real_path, "Check configdir name = ABC");
ok( !-d 'ABC', "Directory 'ABC' does not exist");

$app->initialize( config_dir => $cdir, cleanup_temp_dir => 1);
is( $app->config_dir, $cdir, "Check configdir name = $cdir");
$app->check_directories;

ok( -d $cdir, "Test config directory $cdir");
ok( -d "$cdir/Work", "Test work directory $cdir/Work");
ok( -d "$cdir/Temp", "Test temp directory $cdir/Temp");

#-------------------------------------------------------------------------------
my $log = $app->get_app_object('Log');

$log->do_append_log(0);
$log->start_logging;
$log->file_log_level($log->M_TRACE);
my $tagName = '010';
$log->add_tag($tagName);

#-------------------------------------------------------------------------------
# Destroy apps
#
$app->cleanup;
File::Path::remove_tree($cdir);

done_testing();
