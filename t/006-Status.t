# Testing module AppState::Plugins::Log::Status
#
use Modern::Perl;

use Test::Most;
use AppState::Plugins::Log::Status;

use Moose;
extends 'AppState::Plugins::Log::Constants';

#use AppState;
use AppState::Plugins::Log::Meta_Constants;

#-------------------------------------------------------------------------------
#
my $sts = AppState::Plugins::Log::Status->new;
isa_ok( $sts, 'AppState::Plugins::Log::Status');

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
};

#-------------------------------------------------------------------------------
subtest 'Test filling object' =>
sub
{
  # Set code and status
  #
  $sts->set_message( 'test of');
  $sts->set_error($sts->M_ERROR | 24);

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
  is( $sts->get_message, 'State object initialized ok', 'init message');
  like( $sts->get_file, qr/Status\.pm/, 'Status.pm');
  is( $sts->get_package, 'AppState::Plugins::Log::Status', 'Status package');

#  is( $sts->get_line('line'), 352, 'Line 352');
# There is a line number but changes everytime when maintaining Status.pm

};

#-------------------------------------------------------------------------------
subtest 'Fill object using set_status()' =>
sub
{
  # Set code and status
  #
# -- Keep this line below for the test!!
# line 52000 "test-file2.pm"
  $sts->set_status( { message => 'test 2'
                    , error => $sts->M_DEBUG | 27
                    , line => __LINE__                  # this is line 52002
                    , file => __FILE__
                    , package => __PACKAGE__
                    }
                  );
# line 95 "006-Status.t"

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

  ok( $sts->get_eventcode == 27, 'second event code is 24');

  is( $sts->get_message, 'test 2', 'message test 2');

  like( $sts->get_file('file'), qr/test-file2.pm/, 'File test-file2.pm');
  is( $sts->get_line('line'), 52002, 'Line 52002');
  is( $sts->get_package('package'), 'main', 'Package main');
};

#-------------------------------------------------------------------------------
subtest 'Failing fill of status object using set_status()' =>
sub
{
  # Too little information for set_status
  #
  my $s = $sts->set_status( { message => 'test 3'});

  is( ref $s, 'AppState::Plugins::Log::Status', 'Should be set_status error');
  ok( $s->is_error, 'is an error');
  is( $s->get_message, 'UNKNKEY - Unknown/insufficient status information', 'error message');
};

#-------------------------------------------------------------------------------
subtest 'Fill object using set_status() and call_level' =>
sub
{
  # File, line and package keywords are optional. Without using call_level
  # they will not be set.
  #
# -- Keep this line below for the test!!
# line 53000 "test-file3.pm"
  my $s = $sts->set_status
                ( { message => 'test 3'
                  , error => $sts->M_TRACE | 28
                  , line => __LINE__                 # this is line 52003
                  , package => __PACKAGE__
                  }
                );

  is( ref $s, '', 'Should be no set_status error');

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

  ok( $sts->get_eventcode == 28, 'second event code is 28');

  is( $sts->get_message, 'test 3', 'message test 3');

  is( $sts->get_file, '', 'File test-file3.pm');
  ok( $sts->get_line == 53003, 'Line 53003');
  is( $sts->get_package, 'main', 'Package main');

  # Now call with call_level == 0               <=== Line 53032 !!!!
  #
  $s = $sts->set_status( { message => 'test 3'
                         , error => $sts->M_TRACE | 28
                         }
                       , 0
                       );

  is( ref $s, '', 'Should be no set_status error');

  like( $sts->get_file, qr/test-file3.pm/, 'File test-file3.pm');
  is( $sts->get_line, 53032, 'Line 53032');
  is( $sts->get_package, 'main', 'Package main');

};

#-------------------------------------------------------------------------------
#
subtest 'compare levels' =>
sub
{
  ok( cmp_levels( $sts->M_FATAL, $sts->M_TRACE) == 1, 'Fatal higher than trace');
  ok( cmp_levels( $sts->M_TRACE, $sts->M_DEBUG) == -1, 'Trace lower than debug');
  ok( cmp_levels( $sts->M_WARN, $sts->M_WARNING) == 0, 'Warn equal to warning');
};

#-------------------------------------------------------------------------------
done_testing();

exit(0);
