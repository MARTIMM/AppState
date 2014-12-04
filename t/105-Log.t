# Testing module AppState/Config.pm
#
use Modern::Perl;
use Test::Most;
use Test::File::Content;
use File::Path();

use Moose;
extends 'AppState::Plugins::Log::Constants';

use AppState;

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
$app->initialize( config_dir => $config_dir, check_directories => 1);

#-------------------------------------------------------------------------------
# Get log object
#
my $tagName = '105';
my $log = $app->get_app_object('Log');
$log->die_on_fatal(0);
$log->message_wrapping(0);
$log->start_file_logging( { autoflush => 1, mode => 'append'
                          , size => 2048, max => 3
                          }
                        );
#$log->stderr_log_level($self->M_TRACE);
$log->file_log_level($self->M_TRACE);
$log->add_tag($tagName);

#-------------------------------------------------------------------------------
#
subtest 'Output log file tests' =>
sub
{
  # Log 5 times a message of 1024 characters; size = 2048 => generates
  # at least 3 files. A file can grow larger because it finishes the message!
  #
  foreach my $fill_char (qw(a b c e f))
  {
    my $very_long_string = $fill_char x 1024;
    $self->log( $self->C_LOG_TRACE, [ $very_long_string]);
  }

  $self->log( $self->C_LOG_INFO, [ 'Let it be the last message']);
  my $s = 2 * (1024 + 29 +1); # 2 lines, string plus log info + lf

  ok( -e $config_dir . '/105-Log.log', '105-Log.log exists start and 1 line');
  ok( -e $config_dir . '/105-Log.log.1', '105-Log.log.1 exists 2 lines');
  ok( -s $config_dir . '/105-Log.log.1' <= $s, "Size of 2nd file < $s");
  ok( -e $config_dir . '/105-Log.log.2', '105-Log.log.2 exists 2 lines');
  ok( -s $config_dir . '/105-Log.log.2' <= $s, "Size of 3rd file < $s");

#  ok( -e $config_dir . '/105-Log.log.3', '105-Log.log.3 exists closing down');
#  ok( -s $config_dir . '/105-Log.log.3' < 2048, 'Size of 4th file < 2048');
};

done_testing();
$app->cleanup;
File::Path::remove_tree($config_dir);
exit(0);
