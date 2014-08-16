# Testing module AppState/Config.pm
#
use Modern::Perl;
use Test::Most;
use Test::File::Content;
use File::Path();

use Moose;
extends 'AppState::Ext::Constants';

use AppState;
use AppState::Ext::Meta_Constants;

#-------------------------------------------------------------------------------
def_sts( qw( C_ERR_1 M_ERROR), 'This has gone bad ....');
def_sts( qw( C_ERR_2 M_ERROR), 'This has gone bad because %d != %d');
def_sts( qw( C_LOOP M_TRACE), 'Message %02d %02d. Test the time reset in the log');

#-------------------------------------------------------------------------------
# Make object
#
__PACKAGE__->meta->make_immutable;
my $self = main->new;
isa_ok( $self, 'main');

#-------------------------------------------------------------------------------
# Init
#
my $config_dir = 't/Log';
my $app = AppState->instance;
$app->initialize( config_dir => $config_dir
                , use_work_dir => 0
                , use_temp_dir => 0
                );
$app->check_directories;

#-------------------------------------------------------------------------------
# Get log object
#
my $tagName = '100';
my $log = $app->get_app_object('Log');

subtest 'check object and defaults' =>
sub
{
  my $log_modulename = 'AppState::Plugins::Feature::Log';
  isa_ok( $log, $log_modulename);
  $log->add_tag($tagName);

  is( $log->C_LOG_LOGGERNAME, $log_modulename, 'Check loggername');
  ok( $log->do_append_log == 1, 'Append to log turned on');
  ok( $log->do_flush_log == 0, 'Flushing turned off');
  is( $log->log_file, '100-Log.log', 'Logfile is 100-Log.log');
  ok( $log->nbr_log_tags == 4, 'Number of tags registered should be 4')
    or print "4 tags for main, AppState, PluginManager and Log modules, "
           , $log->nbr_log_tags
           , ', ', join( ', ', $log->get_tag_modules)
           , "\n";

  is( $log->get_log_tag(__PACKAGE__), $tagName, "Tag of package main=$tagName");
  ok( $log->has_log_tag(__PACKAGE__), "Package has a tag name");
  ok( $log->get_tag_modules == 4, 'Package has 4 registered modules');
  is( join( ' ', sort $log->get_tag_names), '100 =AP =LG =PM', 'Tag names check');

$log->log( $log->C_LOG_NOERRCODE);
};



done_testing();
exit(0);


$log->die_on_fatal(0);
#$log->show_on_warning(0);
#$log->show_on_error(0);
#$log->show_on_fatal(0);

#-------------------------------------------------------------------------------
# Check last error system
#
subtest 'last error tests' =>
sub
{
  $log->log_level($self->M_TRACE);

  my $sts = $log->write_log( 'This has gone ok ....', 0xAB | $app->M_INFO);
say "Sts: ", defined $sts ? 'D' : 'N';

  ok( $log->is_last_success == 1, 'Is success');
  ok( $log->is_last_fail == 0, 'Is not a failure');
  ok( $log->is_last_forced == 0, 'Check if forced');
  is( $log->get_last_message, '', 'Info message not saved');
  ok( $log->get_last_error == (0xAB | $app->M_INFO), 'Check error code');
#say sprintf "M: %08X, %08X, %08X"
#  , $log->get_last_eventcode, $log->get_last_severity, $log->get_last_eventcode;
#  ok( $log->get_last_severity == ($app->M_SUCCESS), 'Check severity code');
#  ok( $log->get_last_eventcode == 0xAB, 'Check event code');
#  ok( $log->get_sender_line_no == $lineNbr, 'Check sender line number in file');
  is( $log->get_sender_file, 't/100-Log.t', 'Check sender file name');
  is( $log->get_sender_package, 'main', 'Check sender package name');
};

#-------------------------------------------------------------------------------
subtest 'check error object' =>
sub
{
  my $lineNbr = __LINE__;
  my $eobj = $log->write_log( 'Tracing this time', 0x2A9 | $app->M_F_TRACE);
  isa_ok( $eobj, 'AppState::Ext::Status');
if(0)
{
  ok( $eobj->s_is_success == 1, 'Is success');
  ok( $eobj->s_is_fail == 0, 'Is not a failure');
  ok( $eobj->s_is_forced == 1, 'Check if trace');
  ok( $eobj->s_is_trace == 1, 'Check if forced');
  is( $eobj->get_message, 'Tracing this time', 'message ok');
  ok( $eobj->get_error == (0x2A9 | $app->M_F_TRACE), 'error code ok');
  ok( $eobj->get_severity == ($app->M_F_TRACE), 'severity ok');
  ok( $eobj->get_eventcode == 0x2A9, 'event code ok');
  ok( $eobj->get_line == $lineNbr + 1, 'Check sender line number in file');
  is( $eobj->get_file, 't/100-Log.t', 'Check sender file name');
  is( $eobj->get_package, 'main', 'Check sender package name');
}
};

#-------------------------------------------------------------------------------
# Check notify system.
#
subtest 'subscriber tests 1' =>
sub
{
  my( $source, $tag, $error, $status) = ( 0, '', 0, 0, 0);
  my $subscriber = sub
                   {
                     ( $source, $tag, $status) = @_;
                     pass sprintf( "Tag: %s, Err: 0x%08x"
                                 , $tag
                                 , $status->get_error
                                 );
                   };
  $log->add_subscriber( $tagName, $subscriber);

  $log->write_log( ['This has gone ok ....'], 0x3aB | $app->M_WARNING);
  is( ref $source, 'AppState::Plugins::Feature::Log', 'Check source of notify');
  is( $tag, $tagName, 'Check tag name of the event');
  ok( $status->s_is_warning, 'is warning');
  ok( $status->get_eventcode == 0x3aB, 'Check eventcode');

  $self->wlog( ['This has gone ok ....'], 0x3aB | $app->M_WARNING);
  is( ref $source, 'AppState::Plugins::Feature::Log', 'Check source of notify');
  is( $tag, $tagName, 'Check tag name of the event');
  ok( $status->s_is_warning, 'is warning');
  ok( $status->get_eventcode == 0x3aB, 'Check eventcode');

  $log->delete_subscriber( $tagName, $subscriber);
};

#-------------------------------------------------------------------------------
# Check notify system.
#
subtest 'subscriber tests 2' =>
sub
{
  my( $source, $tag, $error, $status) = ( 0, '', 0, 0, 0);
  my $subscriber = sub
                   {
                     ( $source, $tag, $status) = @_;
                     pass sprintf( "Tag: %s, Err: 0x%08x"
                                 , $tag
                                 , $status->get_error
                                 );
                   };
  $log->add_subscriber( $tagName, $subscriber);

  $log->log($self->C_ERR_1);
  is( ref $source, 'AppState::Plugins::Feature::Log', 'Check source of notify');
  is( $tag, $tagName, 'Check tag name of the event');
  ok( $status->s_is_error, 'is error');
  ok( $status->get_eventcode, "Check eventcode == " . $status->get_eventcode);

  $self->log( $self->C_ERR_2, [ 10, 11]);
  is( ref $source, 'AppState::Plugins::Feature::Log', 'Check source of notify');
  is( $tag, $tagName, 'Check tag name of the event');
  ok( $status->s_is_error, 'is error');
  ok( $status->get_eventcode, 'Check eventcode == ' . $status->get_eventcode);

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
  $log->log_level($log->M_INFO);
  $log->dont_log_start_message;

#  is( $log->isLogFileOpen, '', 'Logfile should still be closed');

  # Change filename
  #
  is( $log->log_file, '100-Log.log', 'Check original name');
  $log->log_file('log.t.log');
  is( $log->log_file, 'log.t.log', 'Check if new name is set');

  # Start logging
  #
  $log->start_logging;
#  is( $log->isLogFileOpen, 1, 'Logfile should be open');
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
  my $tags = join( ' ', sort map {$log->get_log_tag($_);} $log->get_tag_modules);
  is( $tags, "$tagName =AP =LG =PM", 'Tags from 3 modules and main');
};

#-------------------------------------------------------------------------------
# Events can still be seen even if filtered from log.
#
subtest 'error checks' =>
sub
{
  $log->log_level($log->M_INFO);

  my $lineNbr = __LINE__; $log->write_log( 'This has gone ok ....'
                                         , 0x4B | $app->M_INFO
                                         );
  ok( $log->is_last_success == 1, 'Check if success');
  ok( $log->is_last_fail == 0, 'Check if not a failure');
  ok( $log->is_last_forced == 0, 'Check if forced');
  is( $log->get_last_message, 'This has gone ok ....', 'Check message');
  is( $log->get_last_error, 0x4B | $app->M_INFO | $app->M_SUCCESS, 'Check error code');
  is( $log->get_last_severity, $app->M_INFO | $app->M_SUCCESS, 'Check severity code');
  is( $log->get_last_eventcode, 0x4B, 'Check event code');
  is( $log->get_sender_line_no, $lineNbr, 'Check sender line number in file');
  is( $log->get_sender_file, 't/100-Log.t', 'Check sender file name');
  is( $log->get_sender_package, 'main', 'Check sender package name');
};

#-------------------------------------------------------------------------------
# Info and warnings are not sent to the log unless forced.
#
subtest 'log file tests 1' =>
sub
{
  $log->log_level($log->M_ERROR);
  $log->write_log( 'LOG 001 This has gone wrong but not so bad ....'
             , 0xAA | $app->M_INFO
             );
  content_unlike( qr/.*\.log$/, qr/$tagName \d+ is LOG 001/, $config_dir);

  $log->write_log( 'LOG 002 This has gone wrong but not so bad ....'
             , 0xAA | $app->M_WARNING | $app->M_SUCCESS
             );
  content_unlike( qr/.*\.log$/, qr/$tagName \d+ ws LOG 002/, $config_dir);

  $log->write_log( 'LOG 003 I really must say this ....', 0x18 | $app->M_F_INFO);
  content_like( qr/.*\.log$/, qr/$tagName \d+ IS LOG 003/, $config_dir);

  $log->write_log( 'LOG 004 Wrong and should change ....'
             , 0x18 | $app->M_F_WARNING | $app->M_FAIL
             );
  content_unlike( qr/.*\.log$/, qr/$tagName \d+ ef LOG 004/, $config_dir);
# Done later forced...

  $log->write_log( 'LOG 005 This has gone wrong badly ....', 0xFF | $app->M_ERROR);
  content_like( qr/.*\.log$/, qr/$tagName \d+ ef LOG 005/, $config_dir);

  $log->write_log( 'LOG 006 Failed from begin to end', 0xFF | $app->M_FATAL);
  content_like( qr/.*\.log$/, qr/$tagName \d+ ff LOG 006/, $config_dir);
};

#-------------------------------------------------------------------------------
# Info and warnings are not sent to the log unless forced.
#
#subtest 'log file tests 2' =>
#sub
#{
#  $log->write_log( "Message 1", 1|$log->M_INFO);
#};

$log->log_level($self->M_TRACE);
foreach my $count1 (1..2)
{
  foreach my $count2 (1..10)
  {
    $self->log( $self->C_LOOP, [ $count1, $count2]);
  }
  sleep(1);
}

#-------------------------------------------------------------------------------
# Stop logging
#
#subtest 'finish logging' =>
#sub
#{
  $log->stop_logging;
#  is( $log->isLogFileOpen, '', 'Logfile should be closed again');
#};

#-------------------------------------------------------------------------------
$app->cleanup;
File::Path::remove_tree($config_dir);

done_testing();
exit(0);

