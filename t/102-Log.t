# Testing module AppState/Config.pm
#
use Modern::Perl;
use Test::Most;
use Test::File::Content;
use File::Path();

use Moose;
extends 'AppState::Plugins::Log::Constants';

use AppState;
use AppState::Plugins::Log::Meta_Constants;

#-------------------------------------------------------------------------------
# Make a few status messages
#
def_sts( "C_LOOP", 'M_DEBUG', 'Loop counters %s and %s');

#-------------------------------------------------------------------------------
# Make object from main package.
#
__PACKAGE__->meta->make_immutable;
my $self = main->new;

#-------------------------------------------------------------------------------
# Init
#
my $config_dir = 't/Log';
my $app = AppState->instance;
$app->initialize( config_dir => $config_dir
                , use_work_dir => 0
                , use_temp_dir => 0
                , check_directories => 1
                );

#-------------------------------------------------------------------------------
# Get log object
#
my $tagName = '102';
my $log = $app->get_app_object('Log');
$log->die_on_fatal(0);

$log->do_append_log(0);
$log->do_flush_log(1);
$log->start_file_logging;
#$log->stderr_log_level($self->M_TRACE);
$log->file_log_level($self->M_TRACE);
$log->add_tag($tagName);

#-------------------------------------------------------------------------------
# Check last error system
#
subtest 'Output log file tests' =>
sub
{
  $log->file_log_level($self->M_TRACE);
  foreach my $count1 (1..3)
  {
    foreach my $count2 (1..5)
    {
      $self->log( $self->C_LOOP, [ $count1, $count2]);
    }
    sleep(1);
  }

  # After sleep of one sec, a full time stamp is given. Next entry in msec
  #
  content_like( qr/.*\.log$/, qr/\d\d:\d\d:\d\d Ds 102 \d\d\d\d LOOP - Loop counters 2 and 1/, $config_dir);
  content_like( qr/.*\.log$/, qr/\s+\d\d\d Ds 102 \d\d\d\d LOOP - Loop counters 2 and 2/, $config_dir);

  # Same a sec later
  #
  content_like( qr/.*\.log$/, qr/\d\d:\d\d:\d\d Ds 102 \d\d\d\d LOOP - Loop counters 3 and 1/, $config_dir);
  content_like( qr/.*\.log$/, qr/\s+\d\d\d Ds 102 \d\d\d\d LOOP - Loop counters 3 and 2/, $config_dir);
};

$app->cleanup;
File::Path::remove_tree($config_dir);
done_testing();
exit(0);
