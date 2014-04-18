package AppState::Plugins::Feature::NodeTree;

use Modern::Perl;
use version; our $VERSION = '' . version->parse("v0.3.3");
use 5.010001;

use namespace::autoclean;

use Moose;

extends qw(AppState::Ext::Constants);

require AppState;
require AppState::NodeTree::Node;
require AppState::NodeTree::NodeDOM;
require AppState::NodeTree::NodeText;
require AppState::NodeTree::NodeAttr;


#-------------------------------------------------------------------------------
# Nodetree structure
#
#has node_tree =>
#    ( is               => 'ro'
#    , isa              => 'ArrayRef'
#    , default          => sub { return []; }
#    , init_arg         => undef
#    );

has _loaded_modules =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , default           => sub { return {}; }
    , init_arg          => undef
    , traits            => ['Hash']
    , handles           =>
      { _get_loaded_module      => 'get'
      , _set_loaded_module      => 'set'
      , _loaded_module_exists   => 'exists'
      }
    );

has tree_build_data =>
    ( is                => 'rw'
    , isa               => 'HashRef'
    , default           => sub { return {}; }
    , init_arg          => undef
    );

# Helper structure to do breathfirst tree traversal
#
has _BF1 =>
    ( is                => 'ro'
    , isa               => 'ArrayRef'
    , default           => sub { return []; }
    , init_arg          => undef
#    , writer           => '_setBF1'
    , traits            => ['Array']
    , handles           =>
      { _add_bf1_node     => 'push'
      , _get_bf1_node     => 'shift'
      }
    );

# Handler called when doing type 1 breath first tree traversal.
# Method is called on every node.
#
has node_handler =>
    ( is                => 'rw'
    , isa               => 'CodeRef'
    , predicate         => 'has_handler'
    , init_arg          => undef
    );

# Handler used when doing type 1 and 2 depth first tree traversal.
# Method is called before going higher up in the tree.
#
has node_handler_up =>
    ( is                => 'rw'
    , isa               => 'CodeRef'
    , predicate         => 'has_handler_up'
    , init_arg          => undef
    );

# Handler used when doing type 2 depth first tree traversal
# Method is called after being at the top op the tree.
#
has node_handler_down =>
    ( is                => 'rw'
    , isa               => 'CodeRef'
    , predicate         => 'has_handler_down'
    , init_arg          => undef
    );

# Handler used when doing type 2 depth first tree traversal
# Method is called when there are no children in the node. node_handler_up
# and node_handler_down are not used in those cases.
#
has node_handler_end =>
    ( is                => 'rw'
    , isa               => 'CodeRef'
    , predicate         => 'has_handler_end'
    , init_arg          => undef
    );

#-------------------------------------------------------------------------------
sub BUILD
{
  my($self) = @_;

  if( $self->meta->is_mutable )
  {
    $self->log_init('NT');

    # Error codes
    #
    $self->code_reset;
    $self->const( 'C_NT_NOTNODE',               qw(M_ERROR));
    $self->const( 'C_NT_ADDATTR',               qw(M_SUCCESS M_INFO));
    $self->const( 'C_NT_NODEADDTOPARENT',       qw(M_SUCCESS M_INFO));
    $self->const( 'C_NT_ADDTEXTTOPARENT',       qw(M_SUCCESS M_INFO));
    $self->const( 'C_NT_ADDATTRTOPARENT',       qw(M_SUCCESS M_INFO));
    $self->const( 'C_NT_FORCEDINFO',            qw(M_INFO M_FORCED));
    $self->const( 'C_NT_PARSEERROR',            qw(M_ERROR M_FAIL));
    $self->const( 'C_NT_MODINIT',               qw(M_SUCCESS M_INFO));
    $self->const( 'C_NT_MODINCOMPLETE',         qw(M_WARNING M_FORCED));
    $self->const( 'C_NT_NOUPHANDLER',           qw(M_WARNING M_FORCED));
    $self->const( 'C_NT_NOHANDLER',             qw(M_WARNING M_FORCED));
#    $self->const( 'C_NT_',qw(M_SUCCESS M_INFO));

    # Tree traversing codes
    #
    $self->const('C_NT_DEPTHFIRST1');
    $self->const('C_NT_DEPTHFIRST2');
    $self->const('C_NT_BREADTHFIRST1');
    $self->const('C_NT_BREADTHFIRST2');

    # Tree building codes
    #
    $self->const('C_NT_NODEMODULE');
    $self->const('C_NT_VALUEDMODULE');
    $self->const('C_NT_ATTRIBUTEMODULE');

    __PACKAGE__->meta->make_immutable;
  }
}

#-------------------------------------------------------------------------------
#
sub cleanup
{
  my($self) = @_;
}

#-------------------------------------------------------------------------------
# Convert raw in memory data into a tree of nodes and place it as a child
# on given node. If node is undefined, place the tree on a Dom and a Root
# node.
#
sub convert_to_node_tree
{
  my( $self, $rawData, $node) = @_;

  my( $dom, $root);
  if( ref($node) =~ m/AppState::NodeTree::Node(Root)?/ )
  {
    $root = $node;
  }

  elsif( ref $node )
  {
    $self->wlog( "Cannot use other types of node than"
               . " 'AppState::NodeTree::Node or NodeRoot'"
               , $self->C_NT_NOTNODE
               );
    return undef;
  }

  else
  {
    $dom = AppState::NodeTree::NodeDOM->new;
    $root = AppState::NodeTree::NodeRoot->new;
    $dom->link_with_node($root);
  }

  my $node_tree = $self->_convert_to_node_tree( $root, $rawData);

  # Attach an element on top of the node tree denoting a Document DOM node
  #
  $node = $node_tree->xpath_get_root_node;
  if( ref $node eq 'AppState::NodeTree::Node' )
  {
    $dom = AppState::NodeTree::NodeDOM->new;
    $root = AppState::NodeTree::NodeRoot->new;
    $dom->link_with_node($root);
    $root->link_with_node($node);
    $node = $dom;
  }

  elsif( ref $node eq 'AppState::NodeTree::NodeRoot' )
  {
    $dom = AppState::NodeTree::NodeDOM->new;
    $dom->link_with_node($node);
    $node = $dom;
  }

  elsif( ref $node eq 'AppState::NodeTree::NodeDOM' )
  {
  }

  return $node;
}

#-------------------------------------------------------------------------------
#
sub _convert_to_node_tree
{
  my( $self, $parent_node, $rawData) = @_;

  my $node;

  # Process each raw data node which must be an array entry
  #
  foreach my $rawDataNode (@$rawData)
  {
    # Items can have several types of content. Recognized are hashes, arrays
    # blessed data(any type) and just text.
    #
    if( ref $rawDataNode eq 'HASH' )
    {
      # First go through all keys and values to concatenate the keys and values
      # into strings, hashes and arrays.
      #
      my $key = '';
      my $text = '';
      my $children = [];
      my $exAttrs = {};
      my $obj;

      foreach my $k (sort keys %$rawDataNode)
      {
        $key .= " $k" unless $k =~ m/^\.\w/;
        my $v = $rawDataNode->{$k};
        $v //= '';
        $obj = undef;
#say "KV: $k, $v";

        if( defined $v )
        {
          if( ref $v eq 'ARRAY' )
          {
            # Gather all children values. These will be handled later.
            #
            push @$children, @$v;
          }

          elsif( ref $v eq 'HASH' )
          {
            # Gather all extended attributes. These will be handled later.
            #
            $exAttrs = { %$exAttrs, %$v};
          }

          elsif( ref $v )
          {
            # Only one object can be used as a value. Any new object will
            # overwrite the previous object. It will overrule the
            # text value of $text later when creating the node.
            #
            ( $text, $obj) = $self->_getObject
                             ( { type => $self->C_NT_VALUEDMODULE
                               , module_name => ref $v
                               , parent_node => $parent_node
                               , node_data => $rawDataNode
                               , tree_build_data => $self->tree_build_data
                               }
                             );
          }

          else
          {
            # Text will be overwritten by any new textual value. It is only
            # useful to set the text only once because it is not possible to
            # know which key comes first. If there are objects created as a
            # value it will overwrite the textual value.
            #
            $text = $v if $v;
          }
        }
      }

#      $key =~ s/^\s+//;
#      $text =~ s/^\s+//;

      # Create node from key and text/object
      #
      $node = $self->_mkNode( $parent_node, $key, $text);
#      $node = $self->_mkNode( $parent_node, $key, '');
#      $nodeTxt = $self->_mkNode( $node, '', $text);

      # Process any extended attributes
      #
      my @exAttrKeys = keys %$exAttrs;
      if( @exAttrKeys )
      {
        foreach my $exAk (@exAttrKeys)
        {
          my $attrVal = $exAttrs->{$exAk};
#say "AK AV: $exAk, ", ref $attrVal;
          if(  ref $attrVal
           and !(ref $attrVal eq 'ARRAY')
           and !(ref $attrVal eq 'HASH')
            )
          {
            # Overwrite attribute value with the resulting object if
            # the module is instantiated properly. Errors are logged.
            #
            my $obj;
            ( $attrVal, $obj) = $self->_getObject
                                ( { type => $self->C_NT_ATTRIBUTEMODULE
                                  , node => $node
                                  , attribute_name => $exAk
                                  , module_name => ref $attrVal
                                  , parent_node => $parent_node
                                  , node_data => $rawDataNode
                                  , tree_build_data => $self->tree_build_data
                                  }
                                );

#$obj //= '';
#say "Pwd: ", `pwd`;
#say "Attr: $attrVal -> ", ref $obj;
          }

          $attrVal =~ s/^['"]//;
          $attrVal =~ s/['"]$//;
          $node->add_attribute($exAk => $attrVal);
        }

        $self->wlog( 'Add attrs to node=' . $node->name, $self->C_NT_ADDATTR);
      }

      # Process children of node
      #
      $self->_convert_to_node_tree( $node, $children) if @$children;
    }

    elsif( ref $rawDataNode eq 'ARRAY' )
    {
      # Create text node and process children
      #
      $node = $self->_mkNode( $parent_node, '', '');
#? text with children ???
      $self->_convert_to_node_tree( $node, $rawDataNode);
    }

    elsif( ref $rawDataNode )
    {
      my( $data, $obj) = $self->_getObject
                         ( { type => $self->C_NT_NODEMODULE
                           , module_name => ref $rawDataNode
                           , parent_node => $parent_node
                           , node_data => $rawDataNode
                           , tree_build_data => $self->tree_build_data
                           }
                         );
      $obj //= '';
#say "Module node '$obj', process=$data from ", ref $rawDataNode;
    }

    elsif( $rawDataNode )
    {
      # Text only will be handled as a value to an unnamed node if there are
      # strings in the item without '=' characters, that is, no attribute with
      # value.
      #
      # text                                    => node named 'text'
      # nodename att=val att=val                => node with name and attr
      # text att=val more text                  => unnamed node with value
      #
#      if( $rawDataNode )
#      {
        $node = AppState::NodeTree::NodeText->new( value => $rawDataNode);
        $parent_node->link_with_node($node);
#      }
    }
  }

  return $parent_node;
}

#-------------------------------------------------------------------------------
#
sub _mkNode
{
  my( $self, $parent_node, $rawDataNode, $value) = @_;

  my $node;
  my $nodename = $self->_getNodename($rawDataNode);
  if( $nodename =~ m/\s/ )
  {
    # If nodename is still having spaces then it is supposed to be a sentence
    # instead of a nodename with attributes. Make a text node having the
    # whole item line as its value. There will be no attributes.
    #
    $node = AppState::NodeTree::NodeText->new( value => $rawDataNode);
    $parent_node->link_with_node($node);
    $self->wlog( 'Add text to parent=' . $parent_node->name, $self->C_NT_ADDTEXTTOPARENT);
  }

  else
  {
    $node = AppState::NodeTree::Node->new( name => $nodename);
    $parent_node->link_with_node($node);
    $self->wlog( 'Add node ' . $node->name
               . ' to parent ' . $parent_node->name
               , $self->C_NT_NODEADDTOPARENT
               );

    if( defined $value and $value )
    {
      my $nodeT = AppState::NodeTree::NodeText->new( value => $value);
      $node->link_with_node($nodeT);
      $self->wlog( 'Add text to parent=' . $node->name, $self->C_NT_ADDTEXTTOPARENT );
    }

    $self->_setAttributes( $node, $rawDataNode);
  }

  return $node;
}

#-------------------------------------------------------------------------------
# Get the node name from the text. This will be the only one without an
# equal sign.
#
sub _getNodename
{
  my( $self, $text) = @_;
#say "NN 0: $text";

  # Remove all kinds of attribute descriptions
  #
  $text =~ s/([\$\%\&\@]?[:\-_\w]+='[\$\%\&\@]?[^']+')//g;      # key='value text'
  $text =~ s/([\$\%\&\@]?[:\-_\w]+="[\$\%\&\@]?[^"]+")//g;      # key="value text"
  $text =~ s/([\$\%\&\@]?[:\-_\w]+=[\$\%\&\@]?[^'"\s]+)//g;     # key=valueText

  $text =~ s/^\s+//g;                           # Remove all spaces
  $text =~ s/\s+$//g;                           # from begin and end
  $text =~ s/\s+/ /g;                           # and change double spaces
#say "NN 1: $text";
  return $text;
}

#-------------------------------------------------------------------------------
# Set simple type attributes in the node
#
sub _setAttributes
{
  my( $self, $node, $text) = @_;

  my @options = $text =~ m/([\$\%\&\@]?[:\-_\w]+='[\$\%\&\@]?[^']+')/g; # key='value text'
  push @options, ($text =~ m/([\$\%\&\@]?[:\-_\w]+="[\$\%\&\@]?[^"]+")/g);      # key="value text"
  push @options, ($text =~ m/([\$\%\&\@]?[:\-_\w]+=[\$\%\&\@]?[^'"\s]+)/g);     # key=valueText

  # Add all attributes to the node
  #
  foreach my $o (@options)
  {
    my( $ok, $ov) = split( /=/, $o);
#say "Add attr: $ok, $ov";
    $ov =~ s/^['"]//;
    $ov =~ s/['"]$//;

    my $nodeA = AppState::NodeTree::NodeAttr->new( name => $ok, value => $ov);
    $node->link_with_node($nodeA);
    $self->wlog( "Add attr $ok=$ov to parent=" . $node->name
               , $self->C_NT_ADDATTRTOPARENT
               );
  }
}

#-------------------------------------------------------------------------------
# Try to require a user module. If successful instantiate it by calling new().
#
sub _getObject
{
  my( $self, $object_data) = @_;

  my $modName = $object_data->{module_name};
  my( $processResult, $mobj);

  # Create code
  #
  if( !$self->_loaded_module_exists($modName) )
  {
    my $code = <<EOPCD;
use Modern::Perl;
require $modName;
EOPCD

    # Evaluate code
    #
    eval($code);
    if( my $e = $@ )
    {
      # Failure. If logging is on the informational messages must always be
      # written.
      #
      $self->wlog( "Parsing error found in module $modName"
                 , $self->C_NT_FORCEDINFO
                 );
      $self->wlog( "Error: " . $e, $self->C_NT_FORCEDINFO);
      $self->wlog( "Code: " . $code, $self->C_NT_PARSEERROR);
    }

    else
    {
      $self->_set_loaded_module($modName => 1);
    }
  }

#  else
  {
    # Module loaded. Check if new() and process() can be run.
    #
    if( $modName->can('new') and $modName->can('process') )
    {
      $mobj = $modName->new(object_data => $object_data);
      $self->wlog( "Object from module $modName initialized properly"
                 , $self->C_NT_MODINIT
                 );

      $processResult = $mobj->process;
    }

    else
    {
      $self->wlog( 'Object of class $modName not initialized,'
                 . ' new() and or process() not found.'
                 , $self->M_WARNING
                 );
    }
  }

  return ( $processResult, $mobj);
}


#-------------------------------------------------------------------------------
# Traverse the tree of nodes in ways dictated by the method.
#
sub traverse
{
  my( $self, $node_tree, $method) = @_;

  if( $method == $self->C_NT_DEPTHFIRST1 )
  {
    # Tree traversal has no use if the caller doesn't do
    # anything with the nodes.
    #
    if( $self->has_handler_up )
    {
      $self->_traverseDF1($node_tree);
    }

    else
    {
      $self->wlog( "No 'up'-handler. No use to traverse tree1(DF1)."
                 , $self->C_NT_NOUPHANDLER
                 );
    }
  }

  elsif( $method == $self->C_NT_DEPTHFIRST2 )
  {
    $self->_traverseDF2($node_tree);
  }

  elsif( $method == $self->C_NT_BREADTHFIRST1 )
  {
    # Tree traversal has no use if the caller doesn't do
    # anything with the nodes.
    #
    if( $self->has_handler )
    {
      my $nh = $self->node_handler;

      # Add rootnode to the array. Then add all other nodes to the array.
      #
      $self->_add_bf1_node($node_tree);
      $self->_traverseBF1($node_tree->get_children);

      # Run the handler over all collected nodes
      #
      while( my $node = $self->_get_bf1_node )
      {
        &$nh($node);
      }
    }

    else
    {
      $self->wlog( 'No handler. No use to traverse tree(BF1).'
                 , $self->C_NT_NOHANDLER
                 );
    }
  }

  elsif( $method == $self->C_NT_BREADTHFIRST2 )
  {
    # Tree traversal has no use if the caller doesn't do
    # anything with the nodes.
    #
    if( $self->has_handler )
    {
      $self->_traverseBF2($node_tree);
    }

    else
    {
      $self->wlog( 'No handler. No use to traverse tree(BF2).'
                 , $self->C_NT_NOHANDLER
                 );
    }
  }
}

#-------------------------------------------------------------------------------
# Traverse depth first. Method 1:
#
sub _traverseDF1
{
  my( $self, $node) = @_;

  my $nh = $self->node_handler_up;
  &$nh($node);

  foreach my $child ($node->get_children)
  {
    $self->_traverseDF1($child);
  }
}

#-------------------------------------------------------------------------------
# Traverse depth first. Method 2: Call handlers on going up, down and on the
# end of the tree.
#
sub _traverseDF2
{
  my( $self, $node) = @_;

  if( $node->nbr_children )
  {
    &{$self->node_handler_up}($node) if $self->has_handler_up;
    foreach my $child ($node->get_children)
    {
      $self->_traverseDF2($child);
    }

    &{$self->node_handler_down}($node) if $self->has_handler_down;
  }

  else
  {
    &{$self->node_handler_end}($node) if $self->has_handler_end;
  }
}

#-------------------------------------------------------------------------------
# Traverse breadth first method 1. This is processing the siblings of a node
# first before going deeper.
#
sub _traverseBF1
{
  my( $self, @nodes) = @_;

  $self->_add_bf1_node(@nodes);

  foreach my $n (@nodes)
  {
    $self->_traverseBF1($n->get_children);
  }
}

#-------------------------------------------------------------------------------
# Traverse breadth first method 2. This method processes the siblings of a node
# of the same level of any branch before going deeper.
#
sub _traverseBF2
{
  my( $self, $node) = @_;

  my $nh = $self->node_handler;

  my( $n, @nodesBF);
  push @nodesBF, $node;

  while( $n = shift @nodesBF)
  {
    &$nh($n);
    push @nodesBF, $n->get_children;
  }
}
#-------------------------------------------------------------------------------

1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState::NodeTree - Create a tree of nodes from a specific data structure

=head1 SYNOPSIS

use AppState;
use AppState::Ext::Constants;

my $m = AppState::Ext::Constants->new;

my $as = AppState->instance(config_dir => 't0');
my $nt = $as->get_app_object('NodeTree');

my $data =
   [ { 'top id=10' =>
       [ { w1 =>
           [ { z1 => 'abc def' }
           , { z2 => 'pqr xyz' }
           ]
         }
       , { w2 => 'And some extra'}
       ]
     }
   , { 'subtop id=11' =>
       [ { x1 => 'More items'}
       ]
     }
   ];

my $node_tree = $nt->convert_to_node_tree( 'Data', $data);

my $nh = sub { print "H: ", shift->name, "\n"};
my $nhup = sub { print "U: ", shift->name, "\n"};
my $nhdown = sub { print "D: ", shift->name}, "\n";
my $nhend = sub { print "E: ", shift->name, "\n"};

$nt->node_handler($nh);
$nt->node_handler_up($nhup);
$nt->node_handler_down($nhdown);
$nt->node_handler_end($nhend);

print '-' x 80, "\nDepth first method 1\n";
$nt->traverse( $node_tree, $m->C_NT_DEPTHFIRST1);
print '-' x 80, "\nDepth first method 2\n";
$nt->traverse( $node_tree, $m->C_NT_DEPTHFIRST2);
print '-' x 80, "\nBreath first method 1\n";
$nt->traverse( $node_tree, $m->C_NT_BREADTHFIRST1);
print '-' x 80, "\Breath first method 2\n";
$nt->traverse( $node_tree, $m->C_NT_BREADTHFIRST2);
print '-' x 80;



=head1 DESCRIPTION

Toplevel is a set of catagories which the user program must understand
Any of those catagories can be handed over to NodeTree to let this
'raw' data be converted to a node tree. The selected catagory must comply
to the following rules.

# Piece of YAML
#
# Nodes:
#  - na:
#  - nb a1=v1:
#  - nc a2=v2: abc
#  - nd:
#     - nd1 a1=v6
#  - nd: v1
#    a1=b1 t2=v23
#    uvw='abc def'
#
#  -
#    - a
#    - b
#
# 'Nodes' is given to AppState::NodeTree::convert_to_node_tree() to be converted
# into a tree of nodes. Below the 'Nodes' there is an array of items. Each item
# represents a node. While the Yaml data description can be used to describe
# more complex structures the module will understand only the following types of
# node information;
#
#  - na:
# This is an array item which is converted into a node. The name is 'na'. A
# nodename may not have whitespace or other characters except for the following
# Letters A to Z, a to z, 0 to 9, '_', '$' and ':'. Some utilities using the
# program may have restrictions above that.
#
#  - nb a1=v1:
# This item will be a node with an attribute named 'a1' and value 'v1'. Spaces
# are removed around '='. Attribute names have the same restrictions as
# nodenames.
#
#  - nc a2=v2: abc
# Node now also has a value besides an attribute 'a2'.
#
#  - nd:
#     - nd1 a1=v6
# The value of node 'nd' is now another array. The value is converted
# into children nodes. Each child will have node 'nd' as its parent.
#
#  - nd: v1
#    a1=b1 t2=v23:
#    uvw='abc def':
# With very long lines the line can be broken up into smaller parts. In the
# process it will become the same as saying;
#  - nd a1=b1 t2=v23 uvw='abc def': v1
# Yaml now dictates that all lines now must end in a colon (':'). Notice also
# that the value of attribute uvw has a space in it. To do that we need to quote
# that string. By the way, each line can now have a value which are stored
# as one string separated by spaces. With this construction it is also
# possible to store values while also having children nodes.
#
#  -
#    - n5 a=10: attr text
# ??
#
#
#
#

=head2 EXPORT

None by default.



=head1 SEE ALSO


=head1 AUTHOR

Marcel Timmerman, E<lt>mt1957@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Marcel Timmerman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.3 or,
at your option, any later version of Perl 5 you may have available.


=cut

1;

