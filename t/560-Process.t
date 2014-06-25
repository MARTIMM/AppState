# Tests of several node object types
#
use Modern::Perl;
use Test::More;
use English qw(-no_match_vars); # Avoids regex perf penalty, perl < v5.016000

#-------------------------------------------------------------------------------
# Tests probably not for windows
#
if( $^O eq 'MSWin32' )
{
  plan skip_all => 'Tests irrelevant on Windows';
}

else
{
#  plan tests => 42;
}

#-------------------------------------------------------------------------------
use AppState;

# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/Process');
$app->check_directories;

my $log = $app->get_app_object('Log');
#$log->show_on_error(0);
#$log->show_on_warning(1);
#$log->do_append_log(0);
#$log->do_flush_log(1);

$log->start_logging;

$log->log_level($log->M_ERROR);
$app->log_init('560');

#-------------------------------------------------------------------------------
my $pr = $app->get_app_object('Process');
is( ref $pr, 'AppState::Plugins::Feature::Process');

#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
done_testing();
$app->cleanup;
File::Path::remove_tree('t/Process');
exit(0);


