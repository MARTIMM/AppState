# Testing module AppState.pm
#
use Modern::Perl;
use Test::More;
use Test::Trap;
use Test::Exception;

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
#              , init_logging => 1
              );

ok( -d $cdir, "Test config directory $cdir");
ok( -d $wdir, "Test work directory $wdir");
ok( -d "$tdir", "Test temp directory $tdir");

#-------------------------------------------------------------------------------
# Get all pluginnames found by AppState
#
my @pns = sort $a->get_plugin_names;
my $features = join( ' ', @pns);
is( $features
  , 'CommandLine ConfigManager Log NodeTree PluginManager'
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
# Test if second call gets same adres and information
#
my $b = AppState->instance;

is( $a, $b, 'Test singletonnity 1');
$b = undef;

#-------------------------------------------------------------------------------
# Test to see that calling new() directly will fail
#
my $c;
dies_ok( sub{$c = AppState->new( config_dir => $cdir, work_dir => $wdir)}
       , 'Test singletonnity 2, dies ok'
       );
like( $@, qr/=AP \d+ ILLAPPINIT - Called new\(\) directly/);

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
