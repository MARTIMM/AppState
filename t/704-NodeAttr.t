# Tests of attribute nodes
#
use Modern::Perl;
use Test::Most;
use AppState::Plugins::Feature::NodeTree::NodeAttr;

#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/NodeAttr');
$app->check_directories;

my $log = $app->get_app_object('Log');
$log->start_logging;
$log->file_log_level($log->M_ERROR);
$app->log_init('701');

#-------------------------------------------------------------------------------
my $nt = AppState::Plugins::Feature::NodeTree::NodeAttr->new;
isa_ok( $nt, 'AppState::Plugins::Feature::NodeTree::NodeAttr');

#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
done_testing();
$app->cleanup;
File::Path::remove_tree('t/NodeAttr');
exit(0);
