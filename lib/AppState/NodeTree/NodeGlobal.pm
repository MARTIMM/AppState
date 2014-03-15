# Package used as a global storage between the several node objects
#
package AppState::NodeTree::NodeGlobal;

use Modern::Perl;
use version; our $VERSION = version->parse('v0.0.2');
use 5.010001;

use namespace::autoclean;

use MooseX::Singleton;
use Tree::XPathEngine;

#-------------------------------------------------------------------------------
#
has _found_nodes =>
    ( is                => 'ro'
    , isa               => 'ArrayRef'
    , traits            => ['Array']
    , handles           =>
      { nbr_found_nodes         => 'count'
      , get_found_node          => 'get'
      , get_found_nodes         => 'elements'
      , _clear_found_nodes      => 'clear'
      , _add_found_node         => 'push'
      }
    , init_arg          => undef
    , default           => sub { return []; }
    );

has _xpath_methods =>
    ( is                => 'ro'
    , isa               => 'Tree::XPathEngine'
    , init_arg          => undef
    , predicate         => '_has_xpath_methods_set'
    , writer            => '_xpath_methods_set'
    );

has _global_data =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , init_arg          => undef
    , default           => sub { return {}; }
    , traits            => ['Hash']
    , handles           =>
      { set_global_data         => 'set'
      , get_global_data         => 'get'
      , del_global_data         => 'delete'
      , get_global_data_keys    => 'keys'
      , global_data_exists      => 'exists'
      , global_data_defined     => 'defined'
      , clear_global_data       => 'clear'
      , nbr_global_data         => 'count'
      }
    );

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

#-------------------------------------------------------------------------------
__END__
#-------------------------------------------------------------------------------
