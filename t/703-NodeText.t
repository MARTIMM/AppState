# Tests of text node
#
use Modern::Perl;
use Test::Most;
use AppState::Plugins::NodeTree::NodeText;

#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/NodeText');
$app->check_directories;

my $log = $app->get_app_object('Log');
$log->start_file_logging;
$log->file_log_level($log->M_ERROR);
$app->log_init('701');

#-------------------------------------------------------------------------------
my $nt = AppState::Plugins::NodeTree::NodeText->new;
isa_ok( $nt, 'AppState::Plugins::NodeTree::NodeText');

#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
done_testing();
$app->cleanup;
File::Path::remove_tree('t/NodeText');
exit(0);
