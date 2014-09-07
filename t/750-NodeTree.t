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
$log->do_append_log(0);

$log->start_logging;

$log->log_level($log->M_TRACE);

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
# Testing node data
#
isa_ok( $dom, 'AppState::NodeTree::NodeDOM', 'Top level node is a dom node');
is( $dom->nbr_children, 1, 'Number of children should be 1');

my $child = $dom->get_child(0);
is( $child->name, 'R', "Below is a root node");

#-------------------------------------------------------------------------------
# Search for nodes and attributes. No data stored. Some tests from 711/712 to see
# if all works the same.
#
&doSearchAndTest( 'CMP_NAME *', $dom
                , { type => $dom->C_NDM_CMP_NAME
                  , strings => [qw( n1_0 not-existent-node n0_1)]
                  }
                , 'n1_0 n0_1'
                );
&doSearchAndTest( 'CMP_NAME 1', $dom
                , { type => $dom->C_NDM_CMP_NAME
                  , getOneItem => 1
                  , strings => [qw( n1_0 not-existent-node n0_1)]
                  }
                , 'n1_0'
                );
&doSearchAndTest( 'CMP_NAME R', $dom
                , { type => $dom->C_NDM_CMP_NAME
                  , strings => [qr/n0_\d/]
                  }
                , 'n0_0 n0_1 n0_2 n0_2 n0_2'
                );


&doSearchAndTest( 'CMP_ATTR *', $dom
                , { type => $dom->C_NDM_CMP_ATTR
                  , strings => [qw( c1 c3)]
                  , attrname => 'class'
                  }
                , 'n0_1 n1_2'
                );
&doSearchAndTest( 'CMP_ATTR 1', $dom
                , { type => $dom->C_NDM_CMP_ATTR
                  , strings => [qw( c1 c3)]
                  , attrname => 'class'
                  , getOneItem => 1
                  }
                , 'n0_1'
                );
&doSearchAndTest( 'CMP_ATTR R', $dom
                , { type => $dom->C_NDM_CMP_ATTR
                  , strings => [qr/c\d/]
                  , attrname => 'class'
                  }
                , 'n0_1 n0_2 n0_2 n1_2'
                );

#-------------------------------------------------------------------------------
# Search for nodes using xpath like syntax
#
&doXPathAndTest( $dom, '/', 'D');

&doXPathAndTest( $dom, '/R', 'R');
&doXPathAndTest( $dom, '/R/n0_1', 'n0_1');
&doXPathAndTest( $dom, '//n0_1', 'n0_1');
&doXPathAndTest( $dom, '//n0_2', 'n0_2 n0_2 n0_2');

my @nds = $dom->get_found_nodes;
&doXPathAndTest( $nds[2], './n1_0', 'n1_0');
&doXPathAndTest( $nds[2], 'n1_0', 'n1_0');

&doXPathAndTest( $dom, '/R/n0_2/n1_2', 'n1_2');
&doXPathAndTest( $dom, '//n1_2', 'n1_2');

@nds = $dom->get_found_nodes;
is( $nds[0]->parent->name, 'n0_2', 'Name parent = n0_2');
&doXPathAndTest( $nds[0], '/', 'D');

&doXPathAndTest( $dom, '/R/n0_2/n1_2[attribute::class]', 'n1_2');

@nds = $dom->get_found_nodes;
is( $nds[0]->get_attribute('class'), 'c1', 'Class value = c1');

&doXPathAndTest( $dom, q(//n0_2[attribute::id]), 'n0_2 n0_2');
&doXPathAndTest( $dom, q(//n0_2[@class='c2']), 'n0_2 n0_2');

&doXPathAndTest( $dom, qw(//n0_1[@class='c1']), 'n0_1');
&doXPathAndTest( $dom, qw(//n0_2/*[@class='c1']), 'n1_2');


@nds = $dom->get_found_nodes;
&doXPathAndTest( $nds[0], qw(../*[@class='c1']), 'n1_2');

&doXPathAndTest( $dom, qw(//n0_1[@id=1]), 'n0_1');

#$dom->xpath_debug(1);
&doXPathAndTest( $dom, "//*[string()='text 1 0']", 'n0_1 n0_2');
#$dom->xpath_debug(0);

#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
$app->cleanup;
File::Path::remove_tree('t/NodeTree');

done_testing();
#-------------------------------------------------------------------------------


################################################################################
#
sub doSearchAndTest
{
  my( $note, $node, $searchCfg, $nodeList) = @_;

  my $message = "$note: $nodeList";

  $node->search_nodes($searchCfg);
  my $str = join( ' '
                , map { ref $_ eq 'AppState::NodeTree::NodeDOM'
                        ? 'D'
                        : $_->name
                      } $node->get_found_nodes
                );
  is( $str, $nodeList, substr( $message, 0, 70));
}

################################################################################
#
sub doXPathAndTest
{
  my( $node, $path, $nodeList) = @_;

  my $nodeStr = ref $node eq 'AppState::NodeTree::NodeDOM' ? 'D' : $node->name;
  my $message = sprintf "%-40.40s: %-30.30s", "$path", "$nodeList (From $nodeStr)";
  $node->xpath($path);
  my $str = join( ' '
                , map { ref $_ eq 'AppState::NodeTree::NodeDOM'
                        ? 'D'
                        : $_->name
                      } $node->get_found_nodes
                );
  is( $str, $nodeList, $message);
}

__END__

