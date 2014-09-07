# Tests of text node
#
use Modern::Perl;
use Test::Most;
use AppState::NodeTree::NodeRoot;

#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/NodeRoot');
$app->check_directories;

my $log = $app->get_app_object('Log');
$log->start_logging;

$log->log_level($log->M_ERROR);
$app->log_init('701');

#-------------------------------------------------------------------------------
my $nt = AppState::NodeTree::NodeRoot->new;
isa_ok( $nt, 'AppState::NodeTree::NodeRoot');

#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
done_testing();
$app->cleanup;
File::Path::remove_tree('t/NodeRoot');
exit(0);
