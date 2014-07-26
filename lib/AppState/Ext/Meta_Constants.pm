package AppState::Ext::Meta_Constants;

use Modern::Perl;
use version; our $VERSION = version->parse('v0.0.1');
use 5.010001;

use namespace::autoclean;
require Scalar::Util;
use Moose;
use Moose::Exporter;

use AppState::Ext::Constants;

#-------------------------------------------------------------------------------
# Make a Moose constant in the callers namespace. It is a combination of a
# dual variable comprising the constant code or'ed with the severity level and
# the error message.
#
sub const
{
  my( $meta, $name, $modifier, $message) = @_;

  # One time initialization
  #
  state $const_code = 9;
  state $__AES__ = AppState::Ext::Constants->new;

#say "\nConst: $name, $const_code, $message, mutable="
#  , $meta->is_mutable ? 'Y' : 'N';
#my $cnt = 0;
#while( my @c = caller($cnt++) )
#{
#  say join( ', ', @c[0,2,3]);
#}

#  return unless $meta->is_mutable;

  # 1) Make sure that message is defined
  # 2) Make sure that users error code is not larger than allowed.
  # 3) Make sure that the users severity code is not larger than allowed.
  #
  $message //= '';
             my $code = $__AES__->M_EVNTCODE & $const_code;
             $code |= $__AES__->M_SEVERITY & $__AES__->$modifier;
             my $default = Scalar::Util::dualvar( $code, $message);

  # Make the code for the user. It boils down to moose's
  # has $name => ( default => ..., ...);
  # The result is not overwritable, not settable when initializing the
  # callers module and is lazy so only comes into view when using. The
  # value of the variable is a dualvar holding a constant and its message.
  #
  $meta->add_attribute
         ( $name
         , init_arg => undef
#         , lazy => 1
         , is => 'ro'
         , isa => 'Any'
         , default => $default
         );

  $const_code++;
  return;
}
#say "Constants DC: ", __PACKAGE__
#  , ', ', __PACKAGE__->can('DC') ? 'Y' : 'N';
#DC( 'CCC', 'M_INFO', 'Test v');

#-------------------------------------------------------------------------------
# Export the functions
#
Moose::Exporter->setup_import_methods
    ( with_meta => [ qw(const)]
#    , as_is => [ qw( super inner )
#               ]
    );

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;

1;

__END__



           sub
           { 
             my( $self) = @_;
say "\nMC Mutable: ", $meta->is_mutable ? 'Y' : 'N';
say "MC attr name: $name ", $meta->find_attribute_by_name($name) ? 'Y' : 'N';

             # 2) Make sure that users error code is not larger than allowed.
             # 3) Make sure that the users severity code is not larger than allowed.
             #
             my $code = $self->M_EVNTCODE & $const_code;
             $code |= $self->M_SEVERITY & $self->$modifier;
say "Const: $name, $const_code, $code, $message, ";
my $cnt = 0;
while( my @c = caller($cnt++) )
{
  say join( ', ', @c[0,2,3]);
}

             return Scalar::Util::dualvar( $code, $message);
           }
