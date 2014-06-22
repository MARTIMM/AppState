package AppState::NodeTree::NodeRoot;

use Modern::Perl;
use version; our $VERSION = '' . version->parse("v0.0.1");
use 5.010001;

use namespace::autoclean;

use Moose;
use Moose::Util::TypeConstraints;
extends 'AppState::NodeTree::NodeDOM';

require AppState;

#-------------------------------------------------------------------------------
subtype 'AppState::NodeTree::NodeRoot::ValidParentType'
      => as 'Object'
      => where { ref $_ eq 'AppState::NodeTree::NodeDOM'
                 or ref $_ eq 'AppState::NodeTree::NodeRoot'
                 or ref $_ eq 'AppState::NodeTree::Node'
               }
      => message { 'Parent object is not of proper type' };

has parent =>
    ( is                => 'rw'
    , isa               => 'AppState::NodeTree::NodeRoot::ValidParentType'
    , predicate         => 'has_parent'
    , clearer           => 'reset_parent'
    , init_arg          => undef
#    , weak_ref         => 1
    );

has children =>
    ( is                => 'rw'
    , isa               => 'ArrayRef[AppState::NodeTree::Node]'
    , predicate         => 'hasChildren'
    , init_arg          => undef
    , default           => sub { return []; }
    , traits            => ['Array']
    , handles           =>
      { nbr_children    => 'count'
      , get_children    => 'elements'
      , get_child       => 'get'
      , push_child      => 'push'
      , popChild        => 'pop'
      , unshiftChild    => 'unshift'
      , shiftChild      => 'shift'
      , setChild        => 'set'
#      , deleteChild    => 'delete'
      , splice_children  => 'splice'
      , clearChildren   => 'clear'
      }
    );

#-------------------------------------------------------------------------------
sub BUILD
{
  my($self) = @_;

  if( $self->meta->is_mutable )
  {
    $self->log_init('=NR');

    # Error codes
    #
#    $self->code_reset;
#    $self->const( 'C_NRT_', 'M_INFO');

    __PACKAGE__->meta->make_immutable;
  }

  return;
}

#-------------------------------------------------------------------------------
# Remove child address from the childrens array
#
sub _remove_child
{
  my( $self, $child) = @_;
  my $index = $self->_find_node_in_child_list($child);
  $self->splice_children( $index, 1) if defined $index;

  return;
}

#-------------------------------------------------------------------------------
# Replace child address from the childrens array with another one
#
sub _replace_child
{
  my( $self, $child, $newChild) = @_;
  my $index = $self->_find_node_in_child_list($child);
  $self->splice_children( $index, 1, $newChild) if defined $index;

  return;
}

#-------------------------------------------------------------------------------
# Find node in list of children and return index in array. If not found, index
# is undef.
#
sub _find_node_in_child_list
{
  my( $self, $node) = @_;

  my $index = 0;
  my $found = 0;
  foreach my $c ($self->get_children)
  {
    if( $c == $node )
    {
      $found = 1;
      last;
    }

    $index++;
  }

  return $found ? $index : undef;
}

#-------------------------------------------------------------------------------
#
sub get_root
{
  my($self) = @_;

  my $root = $self;
  while( $self->has_parent )
  {
    $root = $self;
    $self = $self->parent;
  }

#say "Get root; ", $root->name;
  return $root;
}

#-------------------------------------------------------------------------------
#
sub get_parent
{
  my($self) = @_;

  my $parent = undef;
  $parent = $self->parent if $self->has_parent;
#say "Get parent; ", $self->name, ', ', defined $parent ? $parent->name : 'undef';

  return $parent;
}

#-------------------------------------------------------------------------------
# Tree::XPathEngine needs these methods.
#-------------------------------------------------------------------------------
sub xpath_get_next_sibling
{
  my($self) = @_;

#print "NS: ", $self->name;
  my $ns = undef;
  if( $self->has_parent )
  {
    my @siblings = $self->parent->get_children;
    for( my $i = 0; $i <= $#siblings; $i++)
    {
#print " $i";
      if( $self == $siblings[$i] )
      {
        $ns = ($i == $#siblings ? undef : $siblings[$i + 1]);
        last;
      }
    }
  }

#say ", ", defined $ns ? $ns->name : 'U';
  return $ns;
}

#-------------------------------------------------------------------------------
sub xpath_get_previous_sibling
{
  my($self) = @_;

#print "PS: ", $self->name, ', Si';
  my $ns = undef;
  if( $self->has_parent )
  {
    my @siblings = $self->parent->get_children;
    for( my $i = 0; $i <= $#siblings; $i++)
    {
#print " $i";
      if( $self == $siblings[$i] )
      {
        $ns = ($i > 0 ? $siblings[$i - 1] : undef);
        last;
      }
    }
  }

#say ", ", defined $ns ? $ns->name : 'U';
  return $ns;
}

#-------------------------------------------------------------------------------
sub xpath_get_root_node
{
  my($self) = @_;
  my $root = $self;

  while( defined $root->parent and $root->parent )
  {
#say "XPGRN 0: refs: ", $root, ', ', $root->parent;
#say "XPGRN 1: n=", $root->name, ', p=', $root->has_parent ? $root->parent->name : 'no parent';
    $root = $root->parent;
  }

#say "Get root; ", ref $root;
  return $root;
}

#-------------------------------------------------------------------------------
sub xpath_get_parent_node
{
  my($self) = @_;

  my $parent = undef;
  if( $self->has_parent )
  {
    $parent = $self->parent;
  }

#say "Get parent; ", $self->name, ', ', defined $parent ? ref $parent : 'undef';

  return $parent;
}

#-------------------------------------------------------------------------------
sub xpath_get_child_nodes
{
  my($self) = @_;

#print "GCN: ", $self->can('name') ? $self->name : ref $self;
#print ', ', $self->nbr_children;
#say ', [ '
#  , join( ', '
#       , map {$_->can('name') ? $_->name : ref $_}
#             $self->get_children
#       )
#  , ']';

  return $self->get_children;
}

#-------------------------------------------------------------------------------
sub xpath_is_document_node              { return 0; }
sub xpath_is_element_node               { return 1; }
sub xpath_is_text_node                  { return 0; }
sub xpath_is_attribute_node             { return 0; }

sub xpath_get_name                      { return $_[0]->name; }
sub name                                { return 'R'; }

#-------------------------------------------------------------------------------
sub xpath_cmp
{
  my( $self, $other) = @_;

  my $rstr = ref $other;

#say "XP cmp: ", $self, ' <-> ', $other;
#  if( $rstr =~ m/AppState::NodeTree::Node(Text)?/ )
#  if( $rstr =~ m/AppState::NodeTree::Node(DOM)?/ )
#  {
    if( $rstr =~ m/AppState::NodeTree::Node(Root|Text)?$/ )
    {
#say "CMP Self = ", ref $self;
      return $self->xpath_element_cmp($other);
    }

#    elsif( $rstr eq 'AppState::NodeTree::NodeAttr' )
#    {
#say "Attribute node";
#      return 1;
#    }

    elsif( $rstr eq 'AppState::NodeTree::NodeDOM' )
    {
#say "Document node";
      return 1;
    }
#  }

  else
  {
say "Unknown object: ", $rstr ? $rstr : '(object is text)';
  }

  return;
}

#-------------------------------------------------------------------------------
sub xpath_element_cmp
{
  my( $self, $other) = @_;

#say "XEC 0 $self == $other";
  # easy cases
  return  0 if $self == $other;
  return  1 if $self->xpath_element_in($other); # a starts after b
  return -1 if $other->xpath_element_in($self); # a starts before b

#say "XEC 1";
  # ancestors does not include the element itself
  my @a_pile = ( $self, $self->xpath_element_ancestors);
  my @b_pile = ( $other, $other->xpath_element_ancestors);

#say "XEC 2";
  # the 2 elements are not in the same twig
  return unless $a_pile[-1] == $b_pile[-1];

#say "XEC 3";
  # find the first non common ancestors (they are siblings)
  my $a_anc = pop @a_pile;
  my $b_anc = pop @b_pile;

#say "XEC 4";
  while( $a_anc == $b_anc )
  {
    $a_anc = pop @a_pile;
    $b_anc = pop @b_pile;
  }

#say "XEC 5";
  # from there move left and right and figure out the order
  my( $a_prev, $a_next, $b_prev, $b_next) = ($a_anc, $a_anc, $b_anc, $b_anc);
  while( 1 )
  {
#say "XEC 5a";
    $a_prev = $a_prev->xpath_get_previous_sibling || return( -1);
    return 1 if( $a_prev == $b_next);

#say "XEC 5b";
    $a_next = $a_next->xpath_get_next_sibling || return( 1);
    return -1 if( $a_next == $b_prev);

#say "XEC 5c";
    $b_prev = $b_prev->xpath_get_previous_sibling || return( 1);
    return -1 if( $b_prev == $a_next);

#say "XEC 5d";
    $b_next = $b_next->xpath_get_next_sibling || return( -1);
    return 1 if( $b_next == $a_prev);
  }

  # We shouldn't come here
  #
  return;
}

#-------------------------------------------------------------------------------
# Check parent axis of $self and stop when an ancester is equal to ancestor.
# Return 1 if the ancestor is found, 0 otherwise
#
sub xpath_element_in
{
  my( $self, $ancestor) = @_;

  while( $self = $self->xpath_get_parent_node )
  {
    return 1 if $self == $ancestor;
  }

  return 0;
}

#-------------------------------------------------------------------------------
sub xpath_element_ancestors
{
  my( $self) = @_;
#print "XP EA: ", $self->name;

  my @ancestors;
  while( $self = $self->xpath_get_parent_node )
  {
    push @ancestors, $self;
  }

#say ', ', scalar(@ancestors);
  return @ancestors;
}

#-------------------------------------------------------------------------------
sub xpath_get_attributes
{
  my($self) = @_;

  return ref $self eq 'AppState::NodeTree::Node' ? $self->get_attributes : ();
}

#-------------------------------------------------------------------------------
#
sub xpath_string_value
{
  my($self) = @_;

  my @string_children = grep
                       {ref $_ eq 'AppState::NodeTree::NodeText'}
                       $self->get_children;
  my $str = join( ' ', map {$_->value} @string_children);

  return $str;
}

#-------------------------------------------------------------------------------
sub xpath_to_literal
{
  my($self) = @_;

say "XP 2L: ";
  return;
} # only if you want to use findnodes_as_string or findvalue

#-------------------------------------------------------------------------------

1;


__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

  AppState::NodeTree::NodeRoot - Root of a node tree.

=head1 SYNOPSIS

  use AppState::NodeTree::NodeRoot;

  my $root = AppState::NodeTree::NodeRoot->new(name => 'root');

=head1 DESCRIPTION

This module extends L<AppState::NodeTree::Node> and adds nothing. When placed
at the top of a tree one can get the classname using ref to check on the type
of node when traversing the tree.

=head1 METHODS

See L<AppState::NodeTree::Node>

=head1 BUGS

No bugs yet.

=head1 AUTHOR

Marcel Timmerman, E<lt>mt1957@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Marcel Timmerman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
