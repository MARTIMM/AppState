package AppState::Plugins::NodeTree::NodeDOM;

use Modern::Perl;
use version; our $VERSION = version->parse('v0.0.4');
use 5.010001;

use namespace::autoclean;

use Moose;
extends qw(AppState::Plugins::Log::Constants);

require AppState::Plugins::NodeTree::NodeGlobal;
require Tree::XPathEngine;
use AppState::Plugins::Log::Meta_Constants;

#-------------------------------------------------------------------------------
# Error codes
#
def_sts( 'E_NODENOTROOT',  'M_ERROR', 'Node not of proper type. Must be a root node. Type = %s');
def_sts( 'E_NODENOTNODE',  'M_ERROR', 'Node not of proper type. Type = %s');
def_sts( 'E_NODENOTNTA',   'M_ERROR', 'Child node not of proper type, This node is '
                                      . 'AppState::Plugins::NodeTree::Node. Node ref = %s');

def_sts( 'C_CMP_NAME', 'M_CODE', 'Search comparing name of node');
def_sts( 'C_CMP_ATTR', 'M_CODE', 'Search comparing attribute of node');
def_sts( 'C_CMP_DATA', 'M_CODE', 'Search comparing data of node');

#-------------------------------------------------------------------------------
has child =>
    ( is                => 'ro'
    , isa               => 'AppState::Plugins::NodeTree::NodeRoot'
    , writer            => 'set_child'
    , predicate         => 'has_child'
    , init_arg          => undef
    );

has shared_data =>
    ( is                => 'ro'
    , isa               => 'AppState::Plugins::NodeTree::NodeGlobal'
    , init_arg          => undef
    , default           =>
      sub
      { return AppState::Plugins::NodeTree::NodeGlobal->instance;
      }
    , handles           => [ qw( nbr_found_nodes get_found_node get_found_nodes

                                 set_all_global_data
                                 set_global_data get_global_data del_global_data
                                 get_global_data_keys global_data_exists
                                 global_data_defined clear_global_data
                                 nbr_global_data
                               )
                           ]
    );

has xpath_debug =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 0
    , trigger           =>
      sub
      { my( $self, $n, $o) = @_;
        $o //= 0;
        return if $n == $o;
        $Tree::XPathEngine::DEBUG = $n;
      }
    );

has _xpath_regexpr =>
    ( is                => 'rw'
    , isa               => 'Regexp'
    , default           => sub { return qr/[A-Za-z_][\w.-]*/; }
    , trigger           =>
      sub
      { my( $self, $n, $o) = @_;
        $o //= 0;
        return if $n == $o;
        $Tree::XPathEngine::DEBUG = $n;
      }
    );

# Storage of objects in a node. Must be done by the users of the node, not by
# the NodeTree module. A good point is when the NodeTree builds the tree it will
# call the method process() of the created perl module. It can then decide to
# store the object in any node it likes (read 'created thus far').
#
has _perl_objects =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , init_arg          => undef
    , default           => sub { return {}; }
    , traits            => ['Hash']
    , handles           =>
      { get_object      => 'get'
      , set_object      => 'set'
      , nbr_objects     => 'count'
      , get_object_keys => 'keys'
      , clear_objects   => 'clear'
      , clear_objects   => 'clear'
      }
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;
  $self->log_init('=ND');
}

#-------------------------------------------------------------------------------
sub has_parent          { return ''; }
sub parent              { return; }
sub nbr_children        { return $_[0]->has_child ? 1 : 0; }
sub get_children        { return $_[0]->has_child ? ($_[0]->child) : (); }
sub get_child           { return $_[0]->has_child ? $_[0]->child : undef; }
sub push_child          { $_[0]->link_with_node($_[1]); }
sub name                { return 'D'; }

#-------------------------------------------------------------------------------
# Bind this node as a parent to the given node as a child.
# When $self is a:
# - DOM node, $node can only be a Root node.
# - Root node, $node can only be a normal node
# - Normal node, $node can be one of normal-, text- or attribute node.
#
sub link_with_node
{
  my( $self, @nodes) = @_;

  foreach my $node (@nodes)
  {
    if( ref $self eq 'AppState::Plugins::NodeTree::NodeDOM' )
    {
      if( ref $node eq 'AppState::Plugins::NodeTree::NodeRoot' )
      {
        $self->set_child($node);
        $node->parent($self);
      }

      else
      {
        $self->log( $self->E_NODENOTROOT, [ref $node]);
      }
    }

    elsif( ref $self eq 'AppState::Plugins::NodeTree::NodeRoot' )
    {
      if( ref $node eq 'AppState::Plugins::NodeTree::Node' )
      {
        $self->push_child($node);
        $node->parent($self);
      }

      else
      {
        $self->log( $self->E_NODENOTNODE, [ref $node]);
      }
    }

    elsif( ref $self eq 'AppState::Plugins::NodeTree::Node' )
    {
      if( ref $node eq 'AppState::Plugins::NodeTree::Node'
       or ref $node eq 'AppState::Plugins::NodeTree::NodeText'
        )
      {
        $self->push_child($node);
        $node->parent($self);
      }

      elsif(ref $node eq 'AppState::Plugins::NodeTree::NodeAttr' )
      {
        # When pushing the attribute, the attribute name can already be
        # used. The function will return the modified attribute address in
        # that case.
        #
        my $selectedAttrNode = $self->push_attribute($node);
        $node->parent($self) if $selectedAttrNode == $node;
      }

      else
      {
        $self->log( $self->E_NODENOTNTA, [ref $node]);
      }
    }
  }
}

#-------------------------------------------------------------------------------
# Search tree for nodes
#
sub search_nodes
{
  my( $self, $searchCfg) = @_;
  my $strings = $searchCfg->{strings};
  my $type = $searchCfg->{type};

  $self->shared_data->_clear_found_nodes;

  if( $type == $self->C_CMP_NAME )
  {
    foreach my $string (@$strings)
    {
      $self->_search_name( $string, $searchCfg);
    }
  }

  elsif( $type == $self->C_CMP_ATTR )
  {
    $searchCfg->{attrname} //= '';
    foreach my $string (@$strings)
    {
      $self->_search_attr( $string, $searchCfg);
    }
  }

  elsif( $type == $self->C_CMP_DATA )
  {
    $searchCfg->{dataname} //= '';
    foreach my $string (@$strings)
    {
      $self->_search_data( $string, $searchCfg);
    }
  }
}

#-------------------------------------------------------------------------------
#
sub _search_name
{
  my( $self, $str, $searchCfg) = @_;

  # NodeDOM, NodeRoot and NodeText have no name to check on
  #
  if( ref($self) eq 'AppState::Plugins::NodeTree::Node' )
  {
    if( ref $str eq 'Regexp' )
    {
      $self->shared_data->_add_found_node($self) if $self->name =~ m/$str/;
    }

    else
    {
      $self->shared_data->_add_found_node($self) if $self->name eq $str;
    }
  }

  # Loop through the children of the current node
  #
  foreach my $child ($self->get_children)
  {
    next if ref $child eq 'AppState::Plugins::NodeTree::NodeText';

    # Some searches only require one node to return. getOneItem is used
    # to stop the search when a node is found.
    #
    last if $searchCfg->{getOneItem} and $self->nbr_found_nodes;
    $child->_search_name( $str, $searchCfg);
  }
}

#-------------------------------------------------------------------------------
#
sub _search_attr
{
  my( $self, $str, $searchCfg) = @_;

  if( ref($self) eq 'AppState::Plugins::NodeTree::Node' )
  {
    my $attrval = $self->get_attribute($searchCfg->{attrname});
    $attrval //= '';

    if( ref $str eq 'Regexp' )
    {
      $self->shared_data->_add_found_node($self) if $attrval =~ m/$str/;
    }

    else
    {
      $self->shared_data->_add_found_node($self) if $attrval eq $str;
    }
  }

  # Loop through the children of the current node
  #
  foreach my $child ($self->get_children)
  {
    next if ref($child) eq 'AppState::Plugins::NodeTree::NodeText';

    # Some searches only require one node to return. getOneItem is used
    # to stop the search when a node is found.
    #
    last if $searchCfg->{getOneItem} and $self->nbr_found_nodes;
    $child->_search_attr( $str, $searchCfg);
  }
}

#-------------------------------------------------------------------------------
#
sub _search_data
{
  my( $self, $str, $searchCfg) = @_;

  if( ref($self) eq 'AppState::Plugins::NodeTree::Node' )
  {
    my $dataval = $self->get_local_data($searchCfg->{dataname});
    $dataval //= '';
    if( ref $str eq 'Regexp' )
    {
      $self->shared_data->_add_found_node($self) if $dataval =~ m/$str/;
    }

    else
    {
      $self->shared_data->_add_found_node($self) if $dataval eq $str;
    }
  }

  # Loop through the children of the current node
  #
  foreach my $child ($self->get_children)
  {
    next if ref($child) eq 'AppState::Plugins::NodeTree::NodeText';

    # Some searches only require one node to return. getOneItem is used
    # to stop the search when a node is found.
    #
    last if $searchCfg->{getOneItem} and $self->nbr_found_nodes;
    $child->_search_data( $str, $searchCfg);
  }
}

#-------------------------------------------------------------------------------
# Search through the node tree using the famous XML xpath method.
#
sub xpath
{
  my( $self, $path, $debug) = @_;

  # Turn debugging on if true
  #
  $debug //= 0;
  $self->xpath_debug(!!$debug);

  # If there is no xpath methods set then set them first
  #
  if( !$self->shared_data->_has_xpath_methods )
  {
    my $xpobj = Tree::XPathEngine->new(xpath_name_re => $self->_xpath_regexpr);
    $self->shared_data->_set_xpath_methods($xpobj);
  }

#say "\nSearch start at: ", $self->can('name') ? $self->name : 'R';
#say "Path: ", $path;

  # Absolute pathnames are starting from the root. This tree is build like a
  # DOM-Root-Top_nodes where the root node has a name 'R'. So officially an
  # absolute path should start with /R. It cannot find anything if ommitted.
  # As a convenience the /R is prefixed to the path when not there.
  #
  if( $path =~ m@^/@                    # Starts with a /
#  and $path !~ m@^//@                   # No deeper level searches
  and $path ne '/'                      # This searches for the DOM node
  and $path =~ m@^/(?!R\b)@             # /R already there
    )
  {
    $path = "/R$path";
  }

  # Clear previous found nodes, then search them using xpath and save
  # the nodes in the global nodes data store. Any other node can retrieve
  # the results.
  #
  $self->shared_data->_clear_found_nodes;
  my @fNodes = $self->shared_data->_xpath_methods->findnodes( $path, $self);
  $self->shared_data->_add_found_node(@fNodes);

  # Give back what one needs; array, first value or nothing.
  #
  my $context = wantarray();
  if( defined $context and $context )
  {
    return @fNodes;
  }

  elsif( defined $context )
  {
    return shift @fNodes;
  }

  return undef;
}

#-------------------------------------------------------------------------------
sub xpath_is_document_node      { return 1; }
sub xpath_is_element_node       { return 0; }
sub xpath_is_text_node          { return 0; }
sub xpath_is_attribute_node     { return 0; }

sub xpath_cmp                   { return -1; }

sub xpath_get_child_nodes       { return $_[0]->has_child ? ($_[0]->child) : (); }

sub xpath_to_string             { return ''; }
sub xpath_to_number             { return 0; }
sub xpath_get_root_node         { return $_[0]; }

#sub address
#{
#  my($self) = @_;
#say "XP root address: ", $self->name;
#  return -1;
#} # the root is before all other nodes

#sub xpath_get_attributes       { return []; }
sub xpath_get_parent_node       { return; }
#sub xpath_string_value         { return; }

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;

1;

__END__

#-------------------------------------------------------------------------------
