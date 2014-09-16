# Tests of node object type
#
use Modern::Perl;
use Test::Most;
use Test::File::Content;
require File::Path;

use AppState;
use AppState::NodeTree::Node;
use AppState::NodeTree::NodeRoot;
use AppState::NodeTree::NodeAttr;
use AppState::NodeTree::NodeDOM;

#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/Node', check_directories => 1);

my $log = $app->get_app_object('Log');
$log->do_flush_log(1);
$log->start_logging;
$log->log_level($log->M_ERROR);
#$log->stderr_log_level($log->M_TRACE);
$app->log_init('710');

#-------------------------------------------------------------------------------
# Linking up normal node with dom node
#
my $dom = AppState::NodeTree::NodeDOM->new;
isa_ok( $dom, 'AppState::NodeTree::NodeDOM');
is( $dom->parent, undef, 'No parent defined 1');
is( $dom->has_parent, '', 'No parent defined 2');

my $n = AppState::NodeTree::Node->new(name => 'root');

# Failure!
$dom->link_with_node($n);
content_like( qr/710.*\.log$/, qr/Ef =ND \d+ NODENOTROOT - Node not of proper type/, 't/Node');

# Failure!
$dom->push_child($n);
content_like( qr/710.*\.log$/, qr/Ef =ND \d+ NODENOTROOT - Node not of proper type./, 't/Node');

is( $dom->nbr_children, 0, 'Dom has no children');

########
done_testing();
$app->cleanup;
File::Path::remove_tree('t/Node');
exit(0);
########

#-------------------------------------------------------------------------------
# Linking up root node with dom node
#
my $rn = AppState::NodeTree::NodeRoot->new;
isa_ok( $rn, 'AppState::NodeTree::NodeRoot');
is( $rn->parent, undef, 'No parent defined 1');
is( $rn->has_parent, '', 'No parent defined 2');

# Ok
$dom->link_with_node($rn);
is( $dom->nbr_children, 1, 'Dom has 1 child');

my @chs = $dom->get_children;
is( $chs[0], $rn, 'Child of dom is rn');
is( $rn->parent, $dom, 'Parent of rn is dom');

#-------------------------------------------------------------------------------
# Attributes, object tests
#
my $attr = AppState::NodeTree::NodeAttr->new( name => 'class', value => 'c10');
isa_ok( $attr, 'AppState::NodeTree::NodeAttr');
is( $attr->name, 'class', 'Attribute name = class');
is( $attr->value, 'c10', 'Attribute value = c10');
is( $attr->parent, undef, 'No parent defined 1');
is( $attr->has_parent, '', 'No parent defined 2');

#-------------------------------------------------------------------------------
# Attributes, linkup
#
my $n0_1 = AppState::NodeTree::Node->new(name => 'n0_1');
is( $n0_1->name, 'n0_1', 'Name set to n0_1');

$n0_1->add_attribute( id => 'i10');
is( $n0_1->get_attribute('id'), 'i10', 'Attr id = i10');

my $n0_2 = AppState::NodeTree::Node->new(name => 'n0_2');
$n0_2->push_attribute($attr);
is( $n0_2->get_attribute('class'), 'c10', 'Attr class = c10');

# Overwrite id attribute
$n0_1->add_attribute( id => 'i11', class => 'c11');
is( $n0_1->nbr_attributes, 2, 'Nbr attrs n0_1 = 2');
is( $n0_1->get_attribute('id'), 'i11', 'Attr id = i11 overwritten');
is( $n0_1->get_attribute('class'), 'c11', 'Attr class = c11');

content_like( qr/710.*\.log$/
            , qr/==N \d+ W Attribute name 'id' overwritten with new value/
            , 't/Node'
            );

#-------------------------------------------------------------------------------
# Can use `link_with_node with same result as add/push attribute
#
$attr = AppState::NodeTree::NodeAttr->new( name => 'font', value => 'courier');

# Failure!
$dom->link_with_node($attr);
content_like( qr/710.*\.log$/, qr/=ND \d+ E Node not of proper type./, 't/Node');

# Failure!
$rn->link_with_node($attr);
content_like( qr/710.*\.log$/, qr/=ND \d+ E Node not of proper type./, 't/Node');

# Ok
$n0_1->link_with_node($attr);
is( $n0_1->nbr_attributes, 3, 'Nbr attrs n0_1 = 3');

#-------------------------------------------------------------------------------
# Text node, object tests
#
my $text = AppState::NodeTree::NodeText->new(value => 'Some text line');
isa_ok( $text, 'AppState::NodeTree::NodeText');
is( $text->value, 'Some text line', 'Text = Some text line');
is( $text->parent, undef, 'No parent defined 1');
is( $text->has_parent, '', 'No parent defined 2');

#-------------------------------------------------------------------------------
# Linkup text node with node. same result as add/push attribute
#
my $tn = AppState::NodeTree::NodeText->new(value => 'Some line');

# Failure!
$dom->link_with_node($attr);
content_like( qr/710.*\.log$/, qr/=ND \d+ E Node not of proper type./, 't/Node');

# Failure!
$rn->link_with_node($attr);
content_like( qr/710.*\.log$/, qr/=ND \d+ E Node not of proper type./, 't/Node');

# Ok
$n0_1->link_with_node($tn);
is( $n0_1->nbr_children, 1, 'Dom has 1 child');

@chs = $n0_1->get_children;
isa_ok( $chs[0], 'AppState::NodeTree::NodeText');
is( $chs[0]->value, 'Some line', 'Check text value');

#-------------------------------------------------------------------------------
# Using local node data
#
$n0_1->set_local_data( d1 => 'v1', d2 => 'v2');
$n0_1->set_local_data( d3 => 'v3', d4 => 'v4');
is( $n0_1->nbr_local_data, 4, '4 data items on node n0_1');
is( join( ' ', sort($n0_1->get_local_data_keys)), 'd1 d2 d3 d4', '4 data item keys');
ok( $n0_1->local_data_exists('d3'), 'Item d3 exists');
is( $n0_1->get_local_data('d2'), 'v2', 'Check data on n0_1 d2 = v2');

#-------------------------------------------------------------------------------
# Using global node data
#
$n0_1->setGlobalData( d1 => 'v1', d2 => 'v2');
$n0_1->setGlobalData( d3 => 'v3', d4 => 'v4');
is( $dom->nbrGlobalData, 4, '4 global data items found via dom node');
is( join( ' ', sort($n0_2->getGlobalDataKeys))
  , 'd1 d2 d3 d4'
  , '4 global data item keys found via node n0_2'
  );
ok( $rn->globalDataExists('d3'), 'Check global item d3 exists via root node');
is( $tn->getGlobalData('d2'), 'v2', 'Check global data via text node, d2 = v2');

#-------------------------------------------------------------------------------
# Using shared data and some handles accessing foundNodes structure
#
$n0_1->shared_data->clearFoundNodes;
$n0_1->shared_data->addFoundNode( $n0_1, $n0_2);
is( $n0_1->shared_data->nbrFoundNodes, 2, '1) nbr found nodes = 2 via n0_1');
is( $dom->shared_data->nbrFoundNodes, 2, '2) nbr found nodes = 2 via dom');
is( $dom->nbrFoundNodes, 2, '3) nbr found nodes = 2 via dom and handle');

#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
done_testing();
$app->cleanup;
File::Path::remove_tree('t/Node');
exit(0);
