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
# line 60 "006-Status.t"
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
# line 90 "006-Status.t"

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
subtest 'Test status with arguments' =>
sub
{
  $sts->clear_error;
  ok( !$sts->is_success($sts->C_STS_UNKNKEY), 'is not successfull');
  ok( !$sts->is_fail($sts->C_STS_UNKNKEY), 'is not a failure');
  ok( !$sts->is_info($sts->C_STS_UNKNKEY), 'is not info');
  ok( $sts->is_warning($sts->C_STS_UNKNKEY), 'is a warning');
  ok( !$sts->is_error($sts->C_STS_UNKNKEY), 'is not an error');
  ok( $sts->is_trace($sts->C_STS_INITOK), 'is trace');
  ok( !$sts->is_debug($sts->C_STS_INITOK), 'is not debug');
  ok( !$sts->is_warn($sts->C_STS_INITOK), 'is not a warn');
  ok( !$sts->is_fatal($sts->C_STS_INITOK), 'is not fatal');
  ok( !$sts->is_forced($sts->C_STS_INITOK), 'is not forced');
};

#-------------------------------------------------------------------------------
#
subtest 'compare levels' =>
sub
{
  ok( $sts->cmp_levels( $sts->M_FATAL, $sts->M_TRACE) == 1, 'Fatal higher than trace');
  ok( $sts->cmp_levels( $sts->M_TRACE, $sts->M_DEBUG) == -1, 'Trace lower than debug');
  ok( $sts->cmp_levels( $sts->M_WARN, $sts->M_WARNING) == 0, 'Warn equal to warning');
};

#-------------------------------------------------------------------------------
done_testing();

exit(0);
