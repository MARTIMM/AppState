# Tests of several node object types
#
use Modern::Perl;
use Test::Most;
require File::Path;

use AppState;
use AppState::NodeTree::Node;
use AppState::NodeTree::NodeDOM;
use AppState::NodeTree::NodeAttr;
use AppState::NodeTree::NodeText;

use Data::Dumper ();

#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/Node');
$app->check_directories;

my $log = $app->get_app_object('Log');
#$log->die_on_error(1);
#$log->show_on_error(0);
#$log->show_on_warning(1);
#$log->do_append_log(0);
#$log->do_flush_log(1);

$log->start_logging;

$log->log_level($log->M_ERROR);

#-------------------------------------------------------------------------------
# DOM and root
#
# D - R
#
my $dom = AppState::NodeTree::NodeDOM->new;
my $root = AppState::NodeTree::NodeRoot->new;
$dom->link_with_node($root);

#-------------------------------------------------------------------------------
# Drie kleine kindertjes die zaten op een hek...
# 3 child nodes
#
# D - R +- n0_0
#       +- n0_1
#       +- n0_2
#
my $n0_0 = AppState::NodeTree::Node->new(name => 'n0_0');
$root->link_with_node($n0_0);
my $n0_1 = AppState::NodeTree::Node->new(name => 'n0_1');
$root->link_with_node($n0_1);
my $n0_2 = AppState::NodeTree::Node->new(name => 'n0_2');
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
my $n1_0 = AppState::NodeTree::Node->new(name => 'n1_0');
$n0_2->link_with_node($n1_0);
my $n1_1 = AppState::NodeTree::Node->new(name => 'n1_1');
$n0_2->link_with_node($n1_1);
my $t1_0 = AppState::NodeTree::NodeText->new(value => 'text 1 0');
$n0_2->link_with_node($t1_0);
my $n1_2 = AppState::NodeTree::Node->new(name => 'n1_2');
$n0_2->link_with_node($n1_2);

is( $n0_2->nbr_children, 4, 'n0_2 has 4 children');

my $str = join( ' '
              , map { ref $_ eq 'AppState::NodeTree::NodeText'
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
my @nds = ( AppState::NodeTree::NodeAttr->new( name => 'class', value => 'c1')
          , AppState::NodeTree::NodeAttr->new( name => 'id', value => 1)
          );
$n0_1->link_with_node(@nds);

@nds = ( AppState::NodeTree::NodeAttr->new( name => 'class', value => 'c2')
       , AppState::NodeTree::NodeAttr->new( name => 'id', value => 2)
       );
$n0_2->link_with_node(@nds);

@nds = ( AppState::NodeTree::NodeAttr->new( name => 'class', value => 'c1')
       , AppState::NodeTree::NodeAttr->new( name => 'id', value => 3)
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
@nds = ( AppState::NodeTree::Node->new(name => 'n0_2')
       , AppState::NodeTree::NodeText->new(value => 'text 1 0')
       , AppState::NodeTree::Node->new(name => 'n0_2')
       );
$n0_1->link_with_node(@nds);

@nds = ( AppState::NodeTree::NodeAttr->new( name => 'class', value => 'c2')
       , AppState::NodeTree::NodeAttr->new( name => 'id', value => 4)
       );
($n0_1->get_children)[0]->link_with_node(@nds);

#-------------------------------------------------------------------------------
# Search for nodes, attributes and data items
#
&doSearchAndTest( 'CMP_NAME *', $dom
                , { type => $n0_1->C_NDM_CMP_NAME
                  , strings => [qw( n1_0 not-existent-node n0_1)]
                  }
                , 'n1_0 n0_1'
                );
&doSearchAndTest( 'CMP_NAME 1', $dom
                , { type => $n0_1->C_NDM_CMP_NAME
                  , getOneItem => 1
                  , strings => [qw( n1_0 not-existent-node n0_1)]
                  }
                , 'n1_0'
                );
&doSearchAndTest( 'CMP_NAME R', $dom
                , { type => $n0_1->C_NDM_CMP_NAME
                  , strings => [qr/n0_\d/]
                  }
                , 'n0_0 n0_1 n0_2 n0_2 n0_2'
                );



&doSearchAndTest( 'CMP_ATTR *', $dom
                , { type => $n0_1->C_NDM_CMP_ATTR
                  , strings => [qw( c1 c3)]
                  , attrname => 'class'
                  }
                , 'n0_1 n1_2'
                );

&doSearchAndTest( 'CMP_ATTR 1', $dom
                , { type => $n0_1->C_NDM_CMP_ATTR
                  , strings => [qw( c1 c3)]
                  , attrname => 'class'
                  , getOneItem => 1
                  }
                , 'n0_1'
                );

&doSearchAndTest( 'CMP_ATTR R', $dom
                , { type => $n0_1->C_NDM_CMP_ATTR
                  , strings => [qr/c\d/]
                  , attrname => 'class'
                  }
                , 'n0_1 n0_2 n0_2 n1_2'
                );



&doSearchAndTest( 'CMP_DATA *', $dom
                , { type => $n0_1->C_NDM_CMP_DATA
                  , strings => [qw( v1 v1a)]
                  , dataname => 'd1'
                  }
                , 'n1_0 n0_0'
                );

&doSearchAndTest( 'CMP_DATA 1', $dom
                , { type => $n0_1->C_NDM_CMP_DATA
                  , strings => [qw( v1 v1a)]
                  , dataname => 'd1'
                  , getOneItem => 1
                  }
                , 'n1_0'
                );

&doSearchAndTest( 'CMP_DATA R', $dom
                , { type => $n0_1->C_NDM_CMP_DATA
                  , strings => [qr/v\d/]
                  , dataname => 'd1'
                  }
                , 'n0_0 n1_0'
                );



#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
$app->cleanup;
File::Path::remove_tree('t/Node');

done_testing();
exit(0);

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
