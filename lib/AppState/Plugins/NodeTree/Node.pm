package AppState::Plugins::NodeTree::Node;

use Modern::Perl;
use version; our $VERSION = version->parse('v0.0.5');
use 5.010001;

use namespace::autoclean;

use Moose;
use Moose::Util::TypeConstraints;
extends 'AppState::Plugins::NodeTree::NodeRoot';

require AppState;
require AppState::Plugins::NodeTree::NodeAttr;
use AppState::Ext::Meta_Constants;

#-------------------------------------------------------------------------------
# Error codes
#
def_sts( 'C_NDE_ATTROVERWR', 'M_WARNING', 'Attribute name %s overwritten with new value');

#-------------------------------------------------------------------------------
has name =>
    ( is                => 'ro'
    , isa               => 'Str'
    , writer            => 'rename'
    );

subtype 'AppState::Plugins::NodeTree::Node::ValidNodeChildType'
      => as 'Object'
      => where { ref($_) =~ m/AppState::Plugins::NodeTree::Node(Text)?/ }
      => message { 'Child object is not of proper type' };

has '+children' => (isa => 'ArrayRef[AppState::Plugins::NodeTree::Node::ValidNodeChildType]');

has attributes =>
    ( is                => 'rw'
    , isa               => 'ArrayRef[AppState::Plugins::NodeTree::NodeAttr]'
    , predicate         => 'has_attributes'
    , init_arg          => undef
    , default           => sub { return []; }
    , traits            => ['Array']
    , handles           =>
      { nbr_attributes          => 'count'
      , get_attributes          => 'elements'
      , clear_attributes        => 'clear'
      , set_attribute           => 'set'
      , _pop_attribute          => 'pop'
      , _push_attribute         => 'push'
      , _get_attribute          => 'get'
      , _splice_attributes      => 'splice'
#      , unshift_attribute       => 'unshift'
#      , shift_attribute         => 'shift'
      }
    );

has _local_data =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , init_arg          => undef
    , default           => sub { return {}; }
    , writer            => 'set_all_local_data'
    , traits            => ['Hash']
    , handles           =>
      { set_local_data          => 'set'
      , get_local_data          => 'get'
      , del_local_data          => 'delete'
      , get_local_data_keys     => 'keys'
      , local_data_exists       => 'exists'
      , local_data_defined      => 'defined'
      , clear_local_data        => 'clear'
      , nbr_local_data          => 'count'
      }
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;
  AppState->instance->log_init('==N');
}

#-------------------------------------------------------------------------------
# Insert a given node between the parent and this node. It is assumed that the
# node does not have a parent. When the node has a parent, the parentfield will
# be overwritten and in the original parent the child node removed.
#
sub insert_above_node
{
  my( $self, $node) = @_;

  # Get node's parent and check if defined. Only the root node hasn't one
  # and a freshly created nodes. If there is a parent defined, remove
  # the node address from that parent.
  #
  $node->parent->_remove_child($node)
    if ref $node->parent eq 'AppState::Plugins::NodeTree::Node';

  # Set the new parent of the node by replacing the old child node address.
  # Can not do remove and then add because the order of the child list
  # will change.
  #
  $self->parent->_replace_child( $self, $node)
    if ref $self->parent eq 'AppState::Plugins::NodeTree::Node';

  # Set the parent of self node to the new node.
  #
  $self->parent($node);
  $node->push_child($self);
}

#-------------------------------------------------------------------------------
# Insert before current node
#
sub insert_before_node
{
  my( $self, $node) = @_;

  my $index;
  $index = $self->parent->_find_node_in_child_list($self) if defined $self->parent;
  if( defined $index )
  {
    # Get node's parent and check if there is one. Only the root node hasn't
    # one and a freshly independend created node. If there is a parent defined,
    # remove the node address from that parent.
    #
    $node->parent->_remove_child($node)
      if ref $node->parent eq 'AppState::Plugins::NodeTree::Node';

    $node->parent($self->parent);
    $self->parent->splice_children( $index, 0, $node);
  }

  else
  {
    # No parent perhaps?
  }
}

#-------------------------------------------------------------------------------
# Insert after current node
#
sub insert_after_node
{
  my( $self, $node) = @_;

  my $index;
  $index = $self->parent->_find_node_in_child_list($self) if defined $self->parent;
  if( defined $index )
  {
    # Get node's parent and check if there is one. Only the root node hasn't
    # one and a freshly independend created node. If there is a parent defined,
    # remove the node address from that parent.
    #
    $node->parent->_remove_child($node)
      if ref $node->parent eq 'AppState::Plugins::NodeTree::Node';

    $node->parent($self->parent);
    $self->parent->splice_children( $index + 1, 0, $node);
  }

  else
  {
    # No parent perhaps?
  }
}

#-------------------------------------------------------------------------------
#
#sub substitute_node
#{
#  my( $self, $node, $newNode) = @_;
#
#  my $nbr_children = $self->nbr_children;
#  return unless $nbr_children;
#
#  my @chs = $self->get_children;
#  for( my $i = 0; $i < $nbr_children; $i++)
#  {
#    if( $self->get_child($i) == $node )
#    {
#      $self->set_child( $i, $newNode);
#      last;
#    }
#  }
#}

#-------------------------------------------------------------------------------
#
sub cut_node_from_tree
{
  my( $self, $node) = @_;
}

#-------------------------------------------------------------------------------
#
sub cut_node_tree
{
  my( $self, $node) = @_;
}

#-------------------------------------------------------------------------------
# A few of the original hash trait handles needs to be reimplemented because
# the type is changed from hash into array. Furthermore a number of the new
# functions needs to be rewritten
#.
# add_attribute           => 'set'
# get_attribute           => 'get'
# getAttributeNames      => 'keys'
# nbr_attributes         => 'count'
# delAttribute           => 'delete'
# attributeExists        => 'exists'
# attributeDefined       => 'defined'
# clear_attributes       => 'clear'
#-------------------------------------------------------------------------------
#
sub get_attribute
{
  my( $self, $attrName) = @_;

  my $value = undef;
  foreach my $attrNode ($self->get_attributes)
  {
    if( $attrName eq $attrNode->name )
    {
      $value = $attrNode->value;
      last;
    }
  }

#say "GA $attrName == $value";
  return $value;
}

#-------------------------------------------------------------------------------
#
sub add_attribute
{
  my( $self, %attrs) = @_;
  foreach my $an (keys %attrs)
  {
    my $av = $attrs{$an};
    my $node = AppState::Plugins::NodeTree::NodeAttr->new( name => $an, value => $av);
    $self->push_attribute($node);
  }
}

#-------------------------------------------------------------------------------
#
sub push_attribute
{
  my( $self, $attrNode1) = @_;

  my $found = $attrNode1;
  foreach my $attrNode2 ($self->get_attributes)
  {
#say "PA 1: ", $attrNode1->name, " == ", $attrNode2->name;
    if( $attrNode1->name eq $attrNode2->name )
    {
      $self->log( $self->C_NDE_ATTROVERWR, [$attrNode1->name]);
      $attrNode2->value($attrNode1->value);
      $found = $attrNode2;
      last;
    }
  }

#say "PA 2: $found == $attrNode1";
  $self->_push_attribute($attrNode1) if $found == $attrNode1;
  return $found;
}

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;
1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState::Plugins::NodeTree::Node - Node in the NodeTree

=head1 SYNOPSIS





=head1 DESCRIPTION



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

