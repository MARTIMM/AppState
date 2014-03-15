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
use AppState::NodeTree::Node;

#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/NodeTree');
$app->check_directories;

my $log = $app->get_app_object('Log');
#$log->die_on_error(1);
#$log->show_on_error(0);
$log->show_on_warning(1);
$log->do_append_log(0);

$log->start_logging;

$log->do_flush_log(1);
$log->log_mask($log->M_SEVERITY);

my $nt = $app->get_app_object('NodeTree');

#-------------------------------------------------------------------------------
# Create node data
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
               , { 'n0_2' =>
                   [ { n2_0 => 'Some line' }
                   , 'text 3'
                   , { n2_1 => '' }
                   ]
                 }
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
#                  +- n0_2 +- n2_0 +- 'text'
#                          +- 'text'
#                          +- n2_1
#       +- n0_2(A) +- n1_0(D)
#                  +- n1_1
#                  +- 'text'
#                  +- n1_2(A)
#
my $dom = $nt->convert_to_node_tree($data);

#-------------------------------------------------------------------------------
# Testing traversal of tree
#
my( $elm, $e, $phase, $fail);
my $nh = sub
         { my($n) = @_;
           $e = shift @$elm;
           my $class = ref $n;
           my $str = $class =~ m/NodeDOM$/ ? 'D' : undef;
           $str //= $class =~ m/NodeText$/ ? 'T' : undef;
           $str //= $n->name;
           is( $str, $e, "$phase: $e");
           $fail = 1 unless $str eq $e;
         };

$nt->node_handler($nh);
$nt->node_handler_up($nh);
$nt->node_handler_down($nh);
$nt->node_handler_end($nh);

$elm = [qw( D R n0_0 n0_1 n0_2 T n0_2 n2_0 T T n2_1 n0_2 n1_0 n1_1 T n1_2)];
$phase = 'Df 1';
$fail = 0;
$nt->traverse( $dom, $nt->C_NT_DEPTHFIRST1);
$fail ? fail('Depth first method 1 failed')
      : pass('Depth first method 1 passed');

$elm = [qw( D R n0_0 n0_1 n0_2 T n0_2 n2_0 T n2_0 T n2_1 n0_2 n0_1 n0_2 n1_0 n1_1 T n1_2 n0_2 R D)];
$phase = 'Df 2';
$fail = 0;
$nt->traverse( $dom, $nt->C_NT_DEPTHFIRST2);
$fail ? fail('Depth first method 2 failed')
      : pass('Depth first method 2 passed');

$elm = [qw( D R n0_0 n0_1 n0_2 n0_2 T n0_2 n2_0 T n2_1 T n1_0 n1_1 T n1_2)];
$phase = 'Bf 1';
$fail = 0;
$nt->traverse( $dom, $nt->C_NT_BREADTHFIRST1);
$fail ? fail('Breadth first method 1 failed')
      : pass('Breadth first method 1 passed');

$elm = [qw( D R n0_0 n0_1 n0_2 n0_2 T n0_2 n1_0 n1_1 T n1_2 n2_0 T n2_1 T)];
$phase = 'Bf 2';
$fail = 0;
$nt->traverse( $dom, $nt->C_NT_BREADTHFIRST2);
$fail ? fail('Breadth first method 2 failed')
      : pass('Breadth first method 2 passed');

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

