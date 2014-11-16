# Testing module NodeTree.pm
#
use Modern::Perl;
use Test::Most;
#use Data::Dumper ();

require File::Path;

#-------------------------------------------------------------------------------
# Loading AppState module
#
use AppState;
use AppState::Plugins::Feature::NodeTree::Node;

#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/NodeTree');
$app->check_directories;

my $log = $app->get_app_object('Log');
$log->do_append_log(0);

$log->start_logging;

$log->file_log_level($log->M_TRACE);

my $nt = $app->get_app_object('NodeTree');

#-------------------------------------------------------------------------------
# Create node data. Same build as in 711/712-Node.t => same checks possible
#
# - n0_0
# - n0_1(A) +- n0_2(A)
#           +- 'text'
#           +- n0_2
# - n0_2(A) +- n1_0
#           +- n1_1
#           +- 'text'
#           +- n1_2(A)
#
my $data = [ { 'n0_0' => ''}
           , { 'n0_1 class=c1 id=1' =>
               [ { 'n0_2 class=c2 id=4' => ''}
               , 'text 1 0'
               , { 'n0_2' => ''}
               ]
             }
           , { 'n0_2 class=c2 id=2' =>
               [ { 'n1_0' => ''}
               , { 'n1_1' => ''}
               , 'text 1 0'
               , { 'n1_2 class=c1 id=3' => ''}
               ]
             }
           ];

#-------------------------------------------------------------------------------
# Create node tree.
#
# D - R +- n0_0(D)
#       +- n0_1(A) +- n0_2(A)
#                  +- 'text'
#                  +- n0_2
#       +- n0_2(A) +- n1_0(D)
#                  +- n1_1
#                  +- 'text'
#                  +- n1_2(A)
#
my $dom = $nt->convert_to_node_tree($data);

#$dom->shared_data->clearFoundNodes;
#say Data::Dumper->Dump( [$dom->parent], ['DOM']);
#-------------------------------------------------------------------------------
# Tests for modules !perl/foo::bar
#
pass('Planned for more tests');
#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
$app->cleanup;
File::Path::remove_tree('t/NodeTree');

done_testing();
#-------------------------------------------------------------------------------


__END__

#########
done_testing();
exit(0);
#########

