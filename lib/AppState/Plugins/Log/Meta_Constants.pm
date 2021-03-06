package AppState::Plugins::Log::Meta_Constants;

use Modern::Perl;
use version; our $VERSION = version->parse('v0.0.2');
use 5.010001;

use namespace::autoclean;
require Scalar::Util;
use Moose;
use Moose::Exporter;

use AppState::Plugins::Log::Constants;
state $_aes = AppState::Plugins::Log::Constants->new;

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

  # 1) Make sure that message is defined
  # 2) Make sure that users error code is not larger than allowed.
  # 3) Make sure that the users severity code is not larger than allowed.
  #
  $message //= '';
  my $code = $_aes->M_EVNTCODE & $const_code;
  $code |= $_aes->M_SEVERITY & $_aes->$modifier;
  
  # Modify message to include part of the code except when $modifier = 'M_CODE'
  #
  if( $modifier ne 'M_CODE' )
  {
    my $mname = $name;
    $mname =~ s/(.*_)//g;
    $message = "$mname - $message";
  }
  
  # Setup default code as a dual variable
  #
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
# Compare the level numbers in the error and return -1, 0 or 1 for less, equal
# or greater than resp.
#
sub cmp_levels
{
  my( $error1, $error2) = @_;

  my $lvl_msk = $_aes->M_LEVELMSK;
  return ($error1 & $lvl_msk) <=> ($error2 & $lvl_msk);
}

#-------------------------------------------------------------------------------
#
sub is_success
{
  my($error) = @_;

  $error //= 0;
  return !!($error & $_aes->M_SUCCESS);
}

#-------------------------------------------------------------------------------
#
sub is_fail
{
  my($error) = @_;

  $error //= 0;
  return !!($error & $_aes->M_FAIL);
}

#-------------------------------------------------------------------------------
#
sub is_info
{
  my($error) = @_;

  $error //= 0;
  return !!($error & $_aes->M_NOTMSFF & $_aes->M_INFO);
}

#-------------------------------------------------------------------------------
#
sub is_error
{
  my($error) = @_;

  $error //= 0;
  return !!($error & $_aes->M_NOTMSFF & $_aes->M_ERROR);
}

#-------------------------------------------------------------------------------
#
sub is_trace
{
  my($error) = @_;

  $error //= 0;
  return !!($error & $_aes->M_NOTMSFF & $_aes->M_TRACE);
}

#-------------------------------------------------------------------------------
#
sub is_debug
{
  my($error) = @_;

  $error //= 0;
  return !!($error & $_aes->M_NOTMSFF & $_aes->M_DEBUG);
}

#-------------------------------------------------------------------------------
# Same as warning because M_WARN == M_WARN
#
sub is_warn
{
  my($error) = @_;

  $error //= 0;
  return !!($error & $_aes->M_NOTMSFF & $_aes->M_WARN);
}

#-------------------------------------------------------------------------------
#
sub is_fatal
{
  my($error) = @_;

  $error //= 0;
  return !!($error & $_aes->M_NOTMSFF & $_aes->M_FATAL);
}

#-------------------------------------------------------------------------------
# Export the function
#
Moose::Exporter->setup_import_methods
    ( with_meta => [qw(def_sts)]
    , as_is => [qw( cmp_levels is_success is_fail is_info
                    is_error is_trace is_debug is_warn is_fatal
                  )
               ]
    );

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;

1;

__END__

