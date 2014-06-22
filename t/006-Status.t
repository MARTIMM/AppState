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
  ok( !$sts->is_fail, 'is not a failure');
  ok( !$sts->is_info, 'is not info');
  ok( !$sts->is_warning, 'is not a warning');
  ok( !$sts->is_error, 'is not an error');
  ok( $sts->is_trace, 'is trace');
  ok( !$sts->is_debug, 'is not a debug');
  ok( !$sts->is_warn, 'is not a warn');
  ok( !$sts->is_fatal, 'is not a fatal');
  ok( !$sts->is_forced, 'is not a forced');
};

#-------------------------------------------------------------------------------
subtest 'Test filling object' =>
sub
{
  # Set code and status
  #
  $sts->set_message( 'test', 'of');
  $sts->set_error($sts->M_F_ERROR | 24);
  
  # Test them
  #
  ok( !$sts->is_success, 'is not successfull');
  ok( $sts->is_fail, 'is a failure');
  ok( !$sts->is_info, 'is not info');
  ok( !$sts->is_warning, 'is not a warning');
  ok( $sts->is_error, 'is an error');
  ok( !$sts->is_trace, 'is not a trace');
  ok( !$sts->is_debug, 'is not a debug');
  ok( !$sts->is_warn, 'is not a warn');
  ok( !$sts->is_fatal, 'is not a fatal');
  ok( $sts->is_forced, 'is forced');

  ok( $sts->get_eventcode == 24, 'event code is 24');

  is( $sts->get_message, 'test of', 'message still the same');

# -- Keep this line below for the test!!
# line 51000 "test-file.pm"
  $sts->set_caller_info;
  like( $sts->get_caller_info('file'), qr/test-file.pm/, 'File test-file.pm');
  ok( $sts->get_caller_info('line') == 51000, 'Line 51000');
  is( $sts->get_caller_info('package'), 'main', 'Package main');
};

#-------------------------------------------------------------------------------
subtest 'Test cleared status' =>
sub
{
  $sts->clear_error;
  ok( $sts->is_success, 'is successfull');
  ok( !$sts->is_warning, 'is not a warning');
  ok( !$sts->is_error, 'is not an error');
};

#-------------------------------------------------------------------------------
subtest 'Fill object using set_status()' =>
sub
{
  # Set code and status
  #
# -- Keep this line below for the test!!
# line 52000 "test-file2.pm"
  $sts->set_status( message => 'test 2'
                  , error => $sts->M_DEBUG | 27
                  , line => __LINE__
                  , file => __FILE__
                  , package => __PACKAGE__
                  );

  # Test them
  #
  ok( $sts->is_success, 'is successfull');
  ok( !$sts->is_fail, 'is not a failure');
  ok( !$sts->is_info, 'is not info');
  ok( !$sts->is_warning, 'is not a warning');
  ok( !$sts->is_error, 'is not an error');
  ok( !$sts->is_trace, 'is not a trace');
  ok( $sts->is_debug, 'is a debug');
  ok( !$sts->is_warn, 'is not a warn');
  ok( !$sts->is_fatal, 'is not fatal');
  ok( !$sts->is_forced, 'is not forced');

  ok( $sts->get_eventcode == 27, 'second event code is 24');

  is( $sts->get_message, 'test 2', 'message test 2');

  like( $sts->get_file('file'), qr/test-file2.pm/, 'File test-file2.pm');
  ok( $sts->get_line('line') == 52002, 'Line 52002');
  is( $sts->get_package('package'), 'main', 'Package main');
};

#-------------------------------------------------------------------------------
subtest 'Fill object using set_status() and call_level' =>
sub
{
  # Set code and status
  #
# -- Keep this line below for the test!!
# line 53000 "test-file3.pm"
  $sts->set_status( message => 'test 3'
                  , error => $sts->M_F_TRACE | 28
                  , call_level => 0
                  );

  # Test them
  #
  ok( $sts->is_success, 'is successfull');
  ok( !$sts->is_fail, 'is not a failure');
  ok( !$sts->is_info, 'is not info');
  ok( !$sts->is_warning, 'is not a warning');
  ok( !$sts->is_error, 'is not an error');
  ok( $sts->is_trace, 'is trace');
  ok( !$sts->is_debug, 'is not debug');
  ok( !$sts->is_warn, 'is not a warn');
  ok( !$sts->is_fatal, 'is not fatal');
  ok( $sts->is_forced, 'is forced');

  ok( $sts->get_eventcode == 28, 'second event code is 24');

  is( $sts->get_message, 'test 3', 'message test 3');

  like( $sts->get_file('file'), qr/test-file3.pm/, 'File test-file3.pm');
  ok( $sts->get_line('line') == 53000, 'Line 53000');
  is( $sts->get_package('package'), 'main', 'Package main');
};

#-------------------------------------------------------------------------------
done_testing();

exit(0);
