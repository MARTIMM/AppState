# Tests of node object type
#
use Modern::Perl;
use Test::Most;
use Test::File::Content;
require File::Path;

use AppState;
use AppState::NodeTree::Node;

#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/Node');
$app->check_directories;

my $log = $app->get_app_object('Log');
#$log->show_on_error(0);
$log->show_on_warning(1);
$log->do_append_log(0);

$log->start_logging;

#$log->do_flush_log(1);
$log->log_mask($log->M_SEVERITY);
$app->log_init('705');


#-------------------------------------------------------------------------------
#
my $nt = AppState::NodeTree::Node->new;
isa_ok( $nt, 'AppState::NodeTree::Node');

#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
done_testing();
$app->cleanup;
File::Path::remove_tree('t/Node');
exit(0);


