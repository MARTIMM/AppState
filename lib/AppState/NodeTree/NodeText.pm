package AppState::NodeTree::NodeText;

use Modern::Perl;
use version; our $VERSION = '' . version->parse("v0.0.1");
use 5.010001;

use namespace::autoclean;

use Moose;
use AppState::NodeTree::Node;
extends 'AppState::NodeTree::NodeRoot';

#-------------------------------------------------------------------------------
has value =>
    ( is                => 'rw'
    , isa               => 'Str'
    );

#has parent =>
#    ( is               => 'rw'
#    , isa              => 'AppState::NodeTree::Node'
#    , predicate        => 'has_parent'
#    , clearer          => 'reset_parent'
#    );

#-------------------------------------------------------------------------------
#sub BUILD
#{
#  my($self) = @_;
#}

#-------------------------------------------------------------------------------
sub xpath_is_document_node              { return 0; }
sub xpath_is_element_node               { return 0; }
sub xpath_is_text_node                  { return 1; }
sub xpath_is_attribute_node             { return 0; }

sub xpath_get_parent_node               { return $_[0]->parent; }
sub xpath_string_value                  { return $_[0]->value; }

#sub xpath_to_string                    { return $_[0]->value; }
#sub xpath_to_number                    { return 0; }

#sub xpath_cmp
#{
#  my( $self, $other) = @_;
#
#say "XP text cmp: ", $self, ' <-> ', $other;
#
#}

sub xpath_get_child_nodes               { return (); }
#sub xpath_get_attributes               { return []; }

#-------------------------------------------------------------------------------
sub nbr_children                        { return 0; }
sub get_children                        { return (); }
#sub children                           { return []; }
sub name                               { return 'T'; }
#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

__END__

#-------------------------------------------------------------------------------
