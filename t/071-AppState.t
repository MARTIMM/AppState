# Testing module AppState.pm
#
use Modern::Perl;
use Test::More;
use Test::Trap;

require File::Basename;
require File::HomeDir;
require File::Path;
require Class::Load;
require Devel::Size;

use AppState;

#-------------------------------------------------------------------------------
# Init
#
my( $cdir, $wdir, $tdir) = qw( t/AppState t/AppState-WD t/AppState-TD);

# First time arguments can be given.
#
$a = AppState->instance;
$a->initialize( config_dir => $cdir, use_work_dir => 1, use_temp_dir => 1);
$a->check_directories;

ok( -d $cdir, "Test config directory $cdir");
ok( -d "$cdir/Work", "Test work directory $cdir/Work");
ok( -d "$cdir/Temp", "Test temp directory $cdir/Temp");

#-------------------------------------------------------------------------------
# Drop the instance and remove directories for next tests
#
$a->cleanup;
File::Path::remove_tree($cdir);

# And again other directories and paths.
#
$cdir = 't/AppState';
$a = AppState->instance;
$a->initialize( config_dir => $cdir
              , work_dir => $wdir
              , temp_dir => $tdir
              , use_work_dir => 1
              , use_temp_dir => 1
              , check_directories => 1
             );

ok( -d $cdir, "Test config directory $cdir");
ok( -d $wdir, "Test work directory $wdir");
ok( -d "$tdir", "Test temp directory $tdir");

#done_testing();
#exit(0);

#-------------------------------------------------------------------------------
# Get size of AppState object
#
my $size = Devel::Size::total_size($a);
ok( $size > 0, "AppState object size (1): $size");

#-------------------------------------------------------------------------------
# Get all pluginnames found by AppState
#
my @pns = sort $a->get_plugin_names;
my $features = join( ' ', @pns);
is( $features
  , 'CommandLine ConfigManager Log NodeTree PluginManager Process'
  , 'Test list of plugins'
  );

#-------------------------------------------------------------------------------
# Test if all classes can be loaded by the plugin_manager
#
@pns = qw(Log);
foreach my $pn (@pns)
{
  my $l = $a->get_app_object($pn);
  my $class = $a->get_plugin($pn)->{class};
  ok( Class::Load::is_class_loaded($class), "$pn Should now be loaded");
  ok( $a->has_object($pn), "$pn Should now be created");
}

#-------------------------------------------------------------------------------
# Get size of AppState object
#
$size = Devel::Size::total_size($a);
ok( $size > 0, "AppState object size (2): $size");

#-------------------------------------------------------------------------------
# Test if second call gets same adres and information
#
my $b = AppState->instance;

is( $a, $b, 'Test singletonnity 1');
$b = undef;

#-------------------------------------------------------------------------------
my $log = $a->get_app_object('Log');
$log->start_logging;
$log->add_tag('011');
$log->die_on_error(0);
$log->die_on_fatal(0);
$log->show_on_error(0);
#$log->show_on_warning(1);
$log->do_append_log(0);
$log->log_level($a->M_WARNING);

#-------------------------------------------------------------------------------
#my( $msgCode, $severity, $source, $modTag, $errCode) = ( '', 0, '', '', 0);
my $errCode = 0;
$log->add_subscriber( '=AP'
                    , sub
                      { my( $source, $modTag, $status) = @_;

#                        $msgCode = $errCode & $a->M_EVNTCODE;
#                        $severity = $errCode & $a->M_SEVERITY;
                        $errCode = $status->get_error;

#say sprintf( "Tag: %s, Err: 0x%08x, Event: 0x%03x, Sev: 0x%01x"
#           , $modTag, $errCode, $msgCode, $severity
#          );
                      }
                    );

#-------------------------------------------------------------------------------
# Test to see that calling new() directly will fail
#
my $c = AppState->new( config_dir => $cdir, work_dir => $wdir);
is( $errCode, $a->C_APP_ILLAPPINIT, 'Test singletonnity 2');

#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
$a->cleanup;
File::Path::remove_tree( $cdir, $wdir, $tdir);
done_testing();
exit(0);

#-------------------------------------------------------------------------------

__END__

################
done_testing();
exit(0);
################
