# Testing module AppState/Config.pm
#
use Modern::Perl;
use Test::Most;
use Test::File::Content;
use File::Path();

use AppState;

#-------------------------------------------------------------------------------
# Init
#
my $config_dir = 't/Log';
my $a = AppState->instance;
$a->initialize( config_dir => $config_dir
              , use_work_dir => 0
              , use_temp_dir => 0
              );
$a->check_directories;

#-------------------------------------------------------------------------------
# Get log object
#
my $tagName = '100';
my $log = $a->get_app_object('Log');
subtest 'check object' =>
sub
{
  isa_ok( $log, 'AppState::Plugins::Feature::Log');
  $log->add_tag($tagName);
};

#-------------------------------------------------------------------------------
# Check last error system
#
subtest 'last error tests' =>
sub
{
  my $lineNbr = __LINE__; $log->write_log( 'This has gone ok ....'
                                         , 0xAB | $a->M_INFO
                                         );
  ok( $log->is_last_success == 1, 'Is success');
  ok( $log->is_last_fail == 0, 'Is not a failure');
  ok( $log->is_last_forced == 0, 'Check if forced');
  is( $log->get_last_message, 'This has gone ok ....', 'Check message');
  ok( $log->get_last_error == (0xAB | $a->M_INFO | $a->M_SUCCESS), 'Check error code');
  ok( $log->get_last_severity == ($a->M_INFO | $a->M_SUCCESS), 'Check severity code');
  ok( $log->get_last_eventcode == 0xAB, 'Check event code');
  ok( $log->get_sender_line_no == $lineNbr, 'Check sender line number in file');
  is( $log->get_sender_file, 't/100-Log.t', 'Check sender file name');
  is( $log->get_sender_package, 'main', 'Check sender package name');
};

#-------------------------------------------------------------------------------
subtest 'check error object' =>
sub
{
  my $lineNbr = __LINE__;
  my $eobj = $log->write_log( 'Tracing this time', 0x2A9 | $a->M_F_TRACE);
  isa_ok( $eobj, 'AppState::Ext::Status');
  
  ok( $eobj->is_success == 1, 'Is success');
  ok( $eobj->is_fail == 0, 'Is not a failure');
  ok( $eobj->is_forced == 1, 'Check if trace');
  ok( $eobj->is_trace == 1, 'Check if forced');
  is( $eobj->get_message, 'Tracing this time', 'message ok');
  ok( $eobj->get_error == (0x2A9 | $a->M_F_TRACE), 'error code ok');
  ok( $eobj->get_severity == ($a->M_TRACE | $a->M_FORCED), 'severity ok');
  ok( $eobj->get_eventcode == 0x2A9, 'event code ok');
  ok( $eobj->get_line == $lineNbr + 1, 'Check sender line number in file');
  is( $eobj->get_file, 't/100-Log.t', 'Check sender file name');
  is( $eobj->get_package, 'main', 'Check sender package name');
};

#-------------------------------------------------------------------------------
# Check notify system. Must work even logfile is closed.
#
subtest 'subscriber tests' =>
sub
{
  my( $source, $tag, $error) = ( 0, '', 0, 0);
  my $subscriber = sub
                   {
                     ( $source, $tag, $error) = @_;
                     pass sprintf( "Tag: %s, Err: 0x%08x", $tag, $error);
                   };
  $log->add_subscriber( $tagName, $subscriber);
  $log->write_log( ['This has gone ok ....'], 0x3aB | $a->M_INFO);
  is( ref $source, 'AppState::Plugins::Feature::Log', 'Check source of notify');
  is( $tag, $tagName, 'Check tag name of the event');
  is( $error, 0x3aB | $a->M_INFO, 'Check error of the event');
  $log->delete_subscriber( $tagName, $subscriber);
};

#-------------------------------------------------------------------------------
# Some log settings
#
subtest 'log settings' =>
sub
{
  #$log->die_on_error(1);
  $log->show_on_error(0);
  #$log->show_on_warning(1);
  $log->do_append_log(0);

  $log->do_flush_log(1);
  $log->log_mask($log->M_SEVERITY);

  is( $log->isLogFileOpen, '', 'Logfile should still be closed');

  # Change filename
  #
  is( $log->log_file, '100-Log.log', 'Check original name');
  $log->log_file('log.t.log');
  is( $log->log_file, 'log.t.log', 'Check if new name is set');

  # Start logging
  #
  $log->start_logging;
  is( $log->isLogFileOpen, 1, 'Logfile should be open');
  is( -w 't/Log/log.t.log', 1, 'Test creation of logfile, is writable');
  is( -r 't/Log/log.t.log', 1, 'Logfile is readable');
};

#-------------------------------------------------------------------------------
# Tags from AppState, PluginManager, Log and main.
#
subtest 'tag tests' =>
sub
{
  $log->add_tag(101);
  $log->add_tag('=AP');
  my $tags = join( ' ', sort map {$log->getLogTag($_);} $log->getLogTags);
  is( $tags, "$tagName =AP =LG =PM", 'Tags from 3 modules and main');
};

#-------------------------------------------------------------------------------
# Events can still be seen even if filtered from log.
#
subtest 'error checks' =>
sub
{
  $log->log_mask($log->M_ERROR);

  my $lineNbr = __LINE__; $log->write_log( 'This has gone ok ....'
                                         , 0x4B | $a->M_INFO
                                         );
  ok( $log->is_last_success == 1, 'Check if success');
  ok( $log->is_last_fail == 0, 'Check if not a failure');
  ok( $log->is_last_forced == 0, 'Check if forced');
  is( $log->get_last_message, 'This has gone ok ....', 'Check message');
  is( $log->get_last_error, 0x4B | $a->M_INFO | $a->M_SUCCESS, 'Check error code');
  is( $log->get_last_severity, $a->M_INFO | $a->M_SUCCESS, 'Check severity code');
  is( $log->get_last_eventcode, 0x4B, 'Check event code');
  is( $log->get_sender_line_no, $lineNbr, 'Check sender line number in file');
  is( $log->get_sender_file, 't/100-Log.t', 'Check sender file name');
  is( $log->get_sender_package, 'main', 'Check sender package name');
};

#-------------------------------------------------------------------------------
# Info and warnings are not sent to the log unless forced.
#
subtest 'log file tests' =>
sub
{
  $log->log_mask($log->M_ERROR);
  $log->write_log( 'LOG 001 This has gone wrong but not so bad ....'
             , 0xAA | $a->M_INFO
             );
  content_unlike( qr/.*\.log$/, qr/$tagName \d+ is LOG 001/, $config_dir);

  $log->write_log( 'LOG 002 This has gone wrong but not so bad ....'
             , 0xAA | $a->M_WARNING | $a->M_SUCCESS
             );
  content_unlike( qr/.*\.log$/, qr/$tagName \d+ IS LOG 002/, $config_dir);

  $log->write_log( 'LOG 003 I really must say this ....', 0x18 | $a->M_F_INFO);
  content_like( qr/.*\.log$/, qr/$tagName \d+ IS LOG 003/, $config_dir);

  $log->write_log( 'LOG 004 Wrong and should change ....'
             , 0x18 | $a->M_F_WARNING | $a->M_FAIL
             );
  content_like( qr/.*\.log$/, qr/$tagName \d+ ef LOG 004/, $config_dir);

  $log->write_log( 'LOG 005 This has gone wrong badly ....', 0xFF | $a->M_ERROR);
  content_like( qr/.*\.log$/, qr/$tagName \d+ ef LOG 005/, $config_dir);
};

#-------------------------------------------------------------------------------
# Stop logging
#
subtest 'finish logging' =>
sub
{
  $log->stop_logging;
  is( $log->isLogFileOpen, '', 'Logfile should be closed again');
};

#-------------------------------------------------------------------------------
$a->cleanup;
#File::Path::remove_tree($config_dir);

done_testing();
exit(0);

