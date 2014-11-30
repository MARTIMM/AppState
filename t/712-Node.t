# Tests of several node object types
#
use Modern::Perl;
use Test::Most;
require File::Path;

use AppState;
use AppState::Plugins::NodeTree::Node;
use AppState::Plugins::NodeTree::NodeDOM;
use AppState::Plugins::NodeTree::NodeAttr;
use AppState::Plugins::NodeTree::NodeText;

use Data::Dumper ();

#-------------------------------------------------------------------------------
# Init
#
my $as = AppState->instance;
$as->initialize( config_dir => 't/Node');
$as->check_directories;

my $log = $as->get_app_object('Log');
$log->do_append_log(0);
$log->start_file_logging;
$log->file_log_level($log->M_TRACE);

#-------------------------------------------------------------------------------
# DOM and root
#
# D - R
#
my $dom = AppState::Plugins::NodeTree::NodeDOM->new;
my $root = AppState::Plugins::NodeTree::NodeRoot->new;
$dom->link_with_node($root);

#-------------------------------------------------------------------------------
# Drie kleine kindertjes die zaten op een hek...
# 3 child nodes
#
# D - R +- n0_0
#       +- n0_1
#       +- n0_2
#
my $n0_0 = AppState::Plugins::NodeTree::Node->new(name => 'n0_0');
$root->link_with_node($n0_0);
my $n0_1 = AppState::Plugins::NodeTree::Node->new(name => 'n0_1');
$root->link_with_node($n0_1);
my $n0_2 = AppState::Plugins::NodeTree::Node->new(name => 'n0_2');
$root->link_with_node($n0_2);

#-------------------------------------------------------------------------------
# Text node inserted in between
#
# D - R +- n0_0
#       +- n0_1
#       +- n0_2 +- n1_0
#               +- n1_1
#               +- 'text'
#               +- n1_2
#
my $n1_0 = AppState::Plugins::NodeTree::Node->new(name => 'n1_0');
$n0_2->link_with_node($n1_0);
my $n1_1 = AppState::Plugins::NodeTree::Node->new(name => 'n1_1');
$n0_2->link_with_node($n1_1);
my $t1_0 = AppState::Plugins::NodeTree::NodeText->new(value => 'text 1 0');
$n0_2->link_with_node($t1_0);
my $n1_2 = AppState::Plugins::NodeTree::Node->new(name => 'n1_2');
$n0_2->link_with_node($n1_2);

is( $n0_2->nbr_children, 4, 'n0_2 has 4 children');

my $str = join( ' '
              , map { ref $_ eq 'AppState::Plugins::NodeTree::NodeText'
                        ? 'text'
                        : $_->name
                    }
                    $n0_2->get_children
              );
is( $str, 'n1_0 n1_1 text n1_2', "Check all n0_2 kiddies");

#-------------------------------------------------------------------------------
# Attributes
#
# D - R +- n0_0(D)
#       +- n0_1(A)
#       +- n0_2(A) +- n1_0(D)
#                  +- n1_1
#                  +- 'text'
#                  +- n1_2(A)
#
my @nds = ( AppState::Plugins::NodeTree::NodeAttr->new( name => 'class', value => 'c1')
          , AppState::Plugins::NodeTree::NodeAttr->new( name => 'id', value => 1)
          );
$n0_1->link_with_node(@nds);

@nds = ( AppState::Plugins::NodeTree::NodeAttr->new( name => 'class', value => 'c2')
       , AppState::Plugins::NodeTree::NodeAttr->new( name => 'id', value => 2)
       );
$n0_2->link_with_node(@nds);

@nds = ( AppState::Plugins::NodeTree::NodeAttr->new( name => 'class', value => 'c1')
       , AppState::Plugins::NodeTree::NodeAttr->new( name => 'id', value => 3)
       );
$n1_2->link_with_node(@nds);

$n1_0->set_local_data( d1 => 'v1', d2 => 'v2');
$n0_0->set_local_data( d1 => 'v1a', d3 => 'v3');

#-------------------------------------------------------------------------------
# Some more nodes and attributes
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
@nds = ( AppState::Plugins::NodeTree::Node->new(name => 'n0_2')
       , AppState::Plugins::NodeTree::NodeText->new(value => 'text 1 0')
       , AppState::Plugins::NodeTree::Node->new(name => 'n0_2')
       );
$n0_1->link_with_node(@nds);

@nds = ( AppState::Plugins::NodeTree::NodeAttr->new( name => 'class', value => 'c2')
       , AppState::Plugins::NodeTree::NodeAttr->new( name => 'id', value => 4)
       );
($n0_1->get_children)[0]->link_with_node(@nds);

#-------------------------------------------------------------------------------
# Search for nodes using xpath like syntax
#
#$dom->xpathDebug(1);
&doXPathAndTest( $dom, '/', 'D');
#$dom->xpathDebug(0);

&doXPathAndTest( $dom, '/R', 'R');
&doXPathAndTest( $dom, '/R/n0_1', 'n0_1');
&doXPathAndTest( $dom, '//n0_1', 'n0_1');
&doXPathAndTest( $dom, '//n0_2', 'n0_2 n0_2 n0_2');

@nds = $dom->get_found_nodes;
&doXPathAndTest( $nds[2], './n1_0', 'n1_0');
&doXPathAndTest( $nds[2], 'n1_0', 'n1_0');

&doXPathAndTest( $dom, '/R/n0_2/n1_2', 'n1_2');
&doXPathAndTest( $dom, '//n1_2', 'n1_2');

@nds = $dom->get_found_nodes;
is( $nds[0]->parent->name, 'n0_2', 'Name parent = n0_2');

#say 'NFN: ', $dom->nbrFoundNodes;
#say 'NN: ', $nds[0]->name;

is( $nds[0]->get_attribute('class'), 'c1', 'Attribute class=c1 on n0_2');
&doXPathAndTest( $nds[0], '/', 'D');

#say 'NFN: ', $dom->nbrFoundNodes;
#say 'NN: ', $nds[0]->name;
#$dom->xpathDebug(1);
&doXPathAndTest( $dom, '/R/n0_2/n1_2[attribute::class]', 'n1_2');
#$dom->xpathDebug(0);

@nds = $dom->get_found_nodes;
is( $nds[0]->get_attribute('class'), 'c1', 'Class value = c1');

&doXPathAndTest( $dom, q(//n0_2[attribute::id]), 'n0_2 n0_2');
&doXPathAndTest( $dom, q(//n0_2[@class='c2']), 'n0_2 n0_2');

&doXPathAndTest( $dom, qw(//n0_1[@class='c1']), 'n0_1');
&doXPathAndTest( $dom, qw(//n0_2/*[@class='c1']), 'n1_2');


@nds = $dom->get_found_nodes;
&doXPathAndTest( $nds[0], qw(../*[@class='c1']), 'n1_2');

&doXPathAndTest( $dom, qw(//n0_1[@id=1]), 'n0_1');
&doXPathAndTest( $dom, "//*[string()='text 1 0']", 'n0_1 n0_2');

&doXPathAndTest( $dom, '//n0_1[@id=1]/amount+2', '');

#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
$as->cleanup;
File::Path::remove_tree('t/Node');

done_testing();
exit(0);

################################################################################
#
sub doXPathAndTest
{
  my( $node, $path, $nodeList) = @_;

  my $nodeStr = ref $node eq 'AppState::Plugins::NodeTree::NodeDOM' ? 'D' : $node->name;
  my $message = sprintf "%-40.40s: %-30.30s", "$path", "$nodeList (From $nodeStr)";
  $node->xpath($path);
  my $str = join( ' '
                , map { ref $_ eq 'AppState::Plugins::NodeTree::NodeDOM'
                        ? 'D'
                        : $_->name
                      } $node->get_found_nodes
                );
  is( $str, $nodeList, $message);
}
