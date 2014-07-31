package AppState::Ext::Meta_Constants;

use Modern::Perl;
use version; our $VERSION = version->parse('v0.0.2');
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
sub def_sts
{
  my( $meta, $name, $modifier, $message) = @_;

  # One time initialization
  #
  state $const_code = 9;
  state $aes = AppState::Ext::Constants->new;

  # 1) Make sure that message is defined
  # 2) Make sure that users error code is not larger than allowed.
  # 3) Make sure that the users severity code is not larger than allowed.
  #
  $message //= '';
  my $code = $aes->M_EVNTCODE & $const_code;
  $code |= $aes->M_SEVERITY & $aes->$modifier;
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
         , is => 'ro'
         , isa => 'Any'
         , default => $default
         );

  $const_code++;
  return;
}

#-------------------------------------------------------------------------------
# Export the function
#
Moose::Exporter->setup_import_methods( with_meta => [qw(def_sts)]);

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;

1;

__END__

