# Tests of node object type
#
use Modern::Perl;
use Test::Most;
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
$log->start_logging;
$log->file_log_level($log->M_ERROR);
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


