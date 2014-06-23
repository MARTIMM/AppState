# Tests of attribute nodes
#
use Modern::Perl;
use Test::Most;
use AppState::NodeTree::NodeAttr;

#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/NodeAttr');
$app->check_directories;

my $log = $app->get_app_object('Log');
#$log->show_on_error(0);
#$log->show_on_warning(1);
#$log->do_append_log(0);
#$log->do_flush_log(1);

$log->start_logging;

$log->log_mask($log->M_ERROR);
$app->log_init('701');

#-------------------------------------------------------------------------------
my $nt = AppState::NodeTree::NodeAttr->new;
isa_ok( $nt, 'AppState::NodeTree::NodeAttr');

#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
done_testing();
$app->cleanup;
File::Path::remove_tree('t/NodeAttr');
exit(0);
