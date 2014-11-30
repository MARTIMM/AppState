# Tests of node object type
#
use Modern::Perl;
use Test::Most;
require File::Path;

use AppState;
use AppState::Plugins::NodeTree::NodeGlobal;

#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/NodeGlobal');
$app->check_directories;

my $log = $app->get_app_object('Log');
$log->start_file_logging;
$log->file_log_level($log->M_ERROR);
$app->log_init('710');

#-------------------------------------------------------------------------------
my $ng;
subtest 'Create global node' =>
sub
{
  $ng = AppState::Plugins::NodeTree::NodeGlobal->new;
  isa_ok( $ng, 'AppState::Plugins::NodeTree::NodeGlobal');

  $ng->set_global_data( a => 5, b => 2, c => undef);
  is( $ng->nbr_global_data, 3, '3 data items');

#  ok( $ng->nbr_found_nodes == 0, 'Number of nodes found (Not set here!)');
};

#-------------------------------------------------------------------------------
my $ng2;
subtest 'Create second global node' =>
sub
{
  $ng2 = AppState::Plugins::NodeTree::NodeGlobal->new;
  isa_ok( $ng2, 'AppState::Plugins::NodeTree::NodeGlobal');
  my $dk = join( ' ', sort $ng2->get_global_data_keys);
  is( $dk, 'a b c', "data item keys = '$dk'");
};

#-------------------------------------------------------------------------------
subtest 'Check data via second node, set in first node' =>
sub
{
  is( $ng2->get_global_data('a'), 5, 'Check data in global store 1');
  is( $ng2->get_global_data('b'), 2, 'Check data in global store 2');
  is( join( ' ', (sort $ng2->get_global_data_keys)), 'a b c'
    , 'Check keys in global data'
    );

  ok( $ng2->global_data_exists('a'), 'key a does exist');
  ok( $ng2->global_data_exists('c'), 'key c does exist');
  isnt( $ng2->global_data_defined('c'), 1, 'key c is not defined');
  isnt( $ng2->global_data_exists('d'), 1, 'key d does not exist');
  isnt( $ng2->global_data_defined('d'), 1, 'key d is not defined');
};

#-------------------------------------------------------------------------------
subtest 'Check deletion of data via first node, check via second node' =>
sub
{
  my $a = $ng->del_global_data('a');
  is( $a, 5, 'Check deleted data from global store');
  is( $ng2->get_global_data('a'), undef, 'Check removed data in global store');

  is( $ng2->nbr_global_data, 2, 'Number of data is 2');
  $ng->clear_global_data;
  is( $ng2->nbr_global_data, 0, 'Number of data is 0');
};

#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
done_testing();
$app->cleanup;
File::Path::remove_tree('t/NodeGlobal');
exit(0);
