# Testing module AppState::Ext::Status
#
use Modern::Perl;

use Test::Most;
use AppState::Ext::Status;


#-------------------------------------------------------------------------------
#
my $sts = AppState::Ext::Status->new;
isa_ok( $sts, 'AppState::Ext::Status');

#-------------------------------------------------------------------------------
subtest 'Test empty status' =>
sub
{
  ok( $sts->is_success, 'is successfull');
  ok( !$sts->is_warning, 'is not a warning');
  ok( !$sts->is_error, 'is not an error');
};

#-------------------------------------------------------------------------------
subtest 'Test filling object' =>
sub
{
  $sts->set_error_type($sts->M_L4P_ERROR | 24);
  ok( !$sts->is_success, 'is not successfull');
  ok( !$sts->is_warning, 'is not a warning');
  ok( $sts->is_error, 'is an error');

  ok( $sts->get_error_type == $sts->M_L4P_ERROR | 24, 'error type M_L4P_ERROR');

  $sts->set_message( 'test', 'of');
  is( $sts->get_message, 'test of', 'message still the same');

# -- Keep this line below for the test!!
# line 51000 "test-file.pm"
  $sts->set_stack;
  like( $sts->get_stack('file'), qr/test-file.pm/, 'File ok');
  ok( $sts->get_stack('line') == 51000, 'Line ok');
  is( $sts->get_stack('package'), 'main', 'Package ok');
};

#-------------------------------------------------------------------------------
done_testing();

exit(0);
