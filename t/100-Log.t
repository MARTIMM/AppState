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
my $a = AppState->instance;
$a->initialize( config_dir => 't/Log');
$a->check_directories;

#-------------------------------------------------------------------------------
# Get log object
#
my $log = $a->get_app_object('Log');
isa_ok( $log, 'AppState::Plugins::Feature::Log', 'Check log object class');

my $tagName = '100';
$log->add_tag($tagName);

#-------------------------------------------------------------------------------
# Check last error system
#
my $lineNbr = __LINE__; $log->write_log( 'This has gone ok ....'
                                       , 0xAB | $a->M_INFO | $a->M_SUCCESS
                                       );
is( $log->is_last_success, 1, 'Check if success');
is( $log->is_last_fail, 0, 'Check if not a failure');
is( $log->is_last_forced, 0, 'Check if forced');
is( $log->get_last_message, 'This has gone ok ....', 'Check message');
is( $log->get_last_error, 0xAB | $a->M_INFO | $a->M_SUCCESS, 'Check error code');
is( $log->get_last_severity, $a->M_INFO | $a->M_SUCCESS, 'Check severity code');
is( $log->get_last_eventcode, 0xAB, 'Check event code');
is( $log->get_sender_tag, $tagName, 'Check sender tag');
is( $log->get_sender_line_no, $lineNbr, 'Check sender line number in file');
is( $log->get_sender_file, 't/100-Log.t', 'Check sender file name');
is( $log->get_sender_package, 'main', 'Check sender package name');

#-------------------------------------------------------------------------------
# Check notify system. Must work even logfile is closed.
#
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

#-------------------------------------------------------------------------------
# Some log settings
#
#$log->die_on_error(1);
$log->show_on_error(0);
#$log->show_on_warning(1);
$log->do_append_log(0);

$log->do_flush_log(1);
$log->log_mask($log->M_SEVERITY);

is( $log->isLogFileOpen, '', 'Logfile should still be closed');

#-------------------------------------------------------------------------------
# Change filename
#
is( $log->log_file, '100-Log.log', 'Check original name');
$log->log_file('log.t.log');
is( $log->log_file, 'log.t.log', 'Check if new name is set');

#-------------------------------------------------------------------------------
# Start logging
#
$log->start_logging;
is( $log->isLogFileOpen, 1, 'Logfile should be open');
is( -w 't/Log/log.t.log', 1, 'Test creation of logfile, is writable');
is( -r 't/Log/log.t.log', 1, 'Logfile is readable');

#-------------------------------------------------------------------------------
# Tags from AppState, PluginManager, Log and main.
#
$log->add_tag(101);
$log->add_tag('=AP');
my $tags = join( ' ', sort map {$log->getLogTag($_);} $log->getLogTags);
is( $tags, "$tagName =AP =LG =PM", 'Tags from 3 modules and main');

#-------------------------------------------------------------------------------
# Events can still be seen even if filtered from log.
#
$log->log_mask($log->M_ERROR);

$lineNbr = __LINE__; $log->write_log( 'This has gone ok ....'
                                    , 0x4B | $a->M_INFO | $a->M_SUCCESS
                                    );
is( $log->is_last_success, 1, 'Check if success');
is( $log->is_last_fail, 0, 'Check if not a failure');
is( $log->is_last_forced, 0, 'Check if forced');
is( $log->get_last_message, 'This has gone ok ....', 'Check message');
is( $log->get_last_error, 0x4B | $a->M_INFO | $a->M_SUCCESS, 'Check error code');
is( $log->get_last_severity, $a->M_INFO | $a->M_SUCCESS, 'Check severity code');
is( $log->get_last_eventcode, 0x4B, 'Check event code');
is( $log->get_sender_tag, $tagName, 'Check sender tag');
is( $log->get_sender_line_no, $lineNbr, 'Check sender line number in file');
is( $log->get_sender_file, 't/100-Log.t', 'Check sender file name');
is( $log->get_sender_package, 'main', 'Check sender package name');

#-------------------------------------------------------------------------------
# Info and warnings are not sent to the log unless forced.
#
$log->write_log( 'LOG 001 This has gone wrong but not so bad ....'
           , 0xAA | $a->M_INFO
           );
content_unlike( qr/.*\.log$/, qr/$tagName \d+ is LOG 001/, 't/Log');

$log->write_log( 'LOG 002 This has gone wrong but not so bad ....'
           , 0xAA | $a->M_WARNING | $a->M_SUCCESS
           );
content_unlike( qr/.*\.log$/, qr/$tagName \d+ ws LOG 002/, 't/Log');

$log->write_log( 'LOG 003 I really must say this ....', 0x18 | $a->M_F_INFO);
content_like( qr/.*\.log$/, qr/$tagName \d+ I- LOG 003/, 't/Log');

$log->write_log( 'LOG 004 Wrong and should change ....'
           , 0x18 | $a->M_F_WARNING | $a->M_FAIL
           );
content_like( qr/.*\.log$/, qr/$tagName \d+ WF LOG 004/, 't/Log');

$log->write_log( 'LOG 005 This has gone wrong badly ....', 0xFF | $a->M_ERROR);
content_like( qr/.*\.log$/, qr/$tagName \d+ e- LOG 005/, 't/Log');


#-------------------------------------------------------------------------------
# Stop logging
#
$log->stop_logging;
is( $log->isLogFileOpen, '', 'Logfile should be closed again');

#-------------------------------------------------------------------------------
$a->cleanup;
File::Path::remove_tree('t/Log');

done_testing();
exit(0);

