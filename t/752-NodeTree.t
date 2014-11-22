# Testing module NodeTree.pm
#
use Modern::Perl;
use Test::Most;
#use Data::Dumper ();

require File::Path;

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Object to test for node object handlers
#
package Class1;
sub new
{
  my($class) = @_;
  return bless {}, $class;
}

sub handler_up
{
  my( $self, $node) = @_;
  my $htext = $node->get_global_data('handler_text') . 'C1UP';
  $node->set_global_data(handler_text => $htext);
}

sub handler_end
{
  my( $self, $node) = @_;
  my $htext = $node->get_global_data('handler_text') . 'C1END';
  $node->set_global_data(handler_text => $htext);
}

sub handler
{
  my( $self, $node) = @_;
  my $htext = $node->get_global_data('handler_text') . 'C1-';
  $node->set_global_data(handler_text => $htext);
}

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Object to test for node object handlers
#
package Class2;
sub new
{
  my($class) = @_;
  return bless {}, $class;
}

sub handler_up
{
  my( $self, $node) = @_;
  my $htext = $node->get_global_data('handler_text') . 'C2UP';
  $node->set_global_data(handler_text => $htext);
}

sub handler_down
{
  my( $self, $node) = @_;
  my $htext = $node->get_global_data('handler_text') . 'C2DOWN';
  $node->set_global_data(handler_text => $htext);
}

sub handler
{
  my( $self, $node) = @_;
  my $htext = $node->get_global_data('handler_text') . 'C2-';
  $node->set_global_data(handler_text => $htext);
}

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# Loading AppState module
#
package main;

use AppState;
use AppState::Plugins::NodeTree::Node;

#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/NodeTree');
$app->check_directories;

my $log = $app->get_app_object('Log');
$log->do_append_log(0);
$log->do_flush_log(1);
$log->start_logging;
$log->file_log_level($log->M_TRACE);

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
my( $elm, $e, $rex, $r, $t, $phase);

my $nh = sub
         { my($n) = @_;
           $e = shift @$elm;
           my $class = ref $n;
           my $str = $class =~ m/NodeDOM$/ ? 'D' : undef;
           $str //= $class =~ m/NodeText$/ ? 'T' : undef;
           $str //= $n->name;
           is( $str, $e, "$phase: $e");
           
           if( $n->nbr_objects )
           {
             $r = shift @$rex;
             $t = $n->get_global_data('handler_text');
             ok( $t =~ $r, "Test handler text '$t'");
           }
         };

$nt->node_handler($nh);
$nt->node_handler_up($nh);
$nt->node_handler_down($nh);
$nt->node_handler_end($nh);

# Locate some nodes to store objects there.
#
my $n1_0 = $dom->xpath('/n0_2/n1_0');
is( $n1_0->name, 'n1_0', 'Node n1_0');

my $tnode1 = $dom->xpath("/n0_1/text()[1]");
isa_ok( $tnode1, 'AppState::Plugins::NodeTree::NodeText');
is( $tnode1->value, 'text 1 0', "Text is 'text 1 0'");

# Create object and store in the nodes
#
my $c1 = Class1->new;
my $c2 = Class2->new;
$n1_0->set_object( Class1 => $c1, Class2 => $c2);
$tnode1->set_object( Class1 => $c1);


subtest 'depth first method 1' =>
sub
{
  $dom->set_global_data(handler_text => '');
  $rex = [ qr/C1UP/, qr/C1UP(C[12]UP){2,2}/];
  $elm = [qw( D R n0_0 T n0_1 n0_2 T T n0_2 n2_0 T T n2_1 T n0_2 n1_0 T n1_1 T T n1_2 T)];
  $phase = 'Df 1';
  $nt->traverse( $dom, $nt->C_NT_DEPTHFIRST1);
};

subtest 'depth first method 2' =>
sub
{
  $dom->set_global_data(handler_text => '');
  $rex = [ qr/C1END/, qr/C1END(C[12]UP){2,2}/, qr/C1END(C[12]UP){2,2}C2DOWN/];
  $elm = [qw( D R n0_0 T n0_0 n0_1 n0_2 T n0_2 T n0_2
              n2_0 T n2_0
              T n2_1 T n2_1 n0_2 n0_1
              n0_2 n1_0 T n1_0 n1_1 T n1_1 T n1_2 T
              n1_2 n0_2 R D)];
  $phase = 'Df 2';
  $nt->traverse( $dom, $nt->C_NT_DEPTHFIRST2);
};

subtest 'breath first method 1' =>
sub
{
  $dom->set_global_data(handler_text => '');
  $rex = [ qr/C1\-/, qr/C1\-(C[12]\-){2,2}/];
  $elm = [qw( D R n0_0 n0_1 n0_2 T n0_2 T n0_2 T n2_0 T
              n2_1 T T n1_0 n1_1 T n1_2 T T T)];
  $phase = 'Bf 1';
  $nt->traverse( $dom, $nt->C_NT_BREADTHFIRST1);
};

subtest 'breath first method 2' =>
sub
{
  $dom->set_global_data(handler_text => '');
  $rex = [ qr/C1\-/, qr/C1\-(C[12]\-){2,2}/];
  $elm = [qw( D R n0_0 n0_1 n0_2 T n0_2 T n0_2 n1_0 n1_1 T
              n1_2 T n2_0 T n2_1 T T T T T)];
  $phase = 'Bf 2';
  $nt->traverse( $dom, $nt->C_NT_BREADTHFIRST2);
};

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

