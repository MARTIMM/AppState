#-------------------------------------------------------------------------------
package Foo
{
  use Modern::Perl;
  use Test::Most;
  use Moose;
  extends 'AppState::Ext::Constants';

  use AppState;
  use AppState::Ext::Meta_Constants;
  sub BUILD
  {
    my $log = AppState->instance->get_app_object('Log');
    $log->add_tag('Foo');
  }

  # Foo logger name testing
  #
  sub t0
  {
    my $log = AppState->instance->get_app_object('Log');
    subtest 't0, Foo logger names' =>
    sub
    {
      is( $log->get_logger_name($log->ROOT_STDERR), 'A_Stderr::Foo', 'Stderr logger name = A_Stderr::Foo');
      is( $log->get_logger_name($log->ROOT_FILE), 'A_File::Foo', 'File logger name = A_File::Foo');
      is( $log->get_logger_name($log->ROOT_EMAIL), 'A_Email::Foo', 'Email logger name = A_Email::Foo');
    };
  }

  # Foo log levels are from root level.
  #
  sub t1
  {
    my $log = AppState->instance->get_app_object('Log');
    subtest 't1, Foo root level' =>
    sub
    {
      is( $log->stderr_log_level, $log->M_FATAL, 'Stderr log level is FATAL from root');
      is( $log->file_log_level, $log->M_TRACE, 'File log level is TRACE from root');
      is( $log->email_log_level, $log->M_FATAL, 'Email log level is FATAL from root');
    };
  }

  # Still same as root level after change in main
  #
  sub t2
  {
    my $log = AppState->instance->get_app_object('Log');
    subtest 't2, Foo root level' =>
    sub
    {
      is( $log->file_log_level, $log->M_TRACE, 'File log level is TRACE from root');
      is( $log->stderr_log_level, $log->M_FATAL, 'Stderr log level is FATAL from root');
      is( $log->email_log_level, $log->M_FATAL, 'Email log level is FATAL from root');

      $log->file_log_level($log->M_WARN);
      is( $log->file_log_level, $log->M_WARN, 'File log level changed, is now WARN');
    };
  }

  sub x
  {
    my( $self, $main, $sts_texts) = @_;
#say STDERR sprintf( "Running x() show STS2 = %08X", $main->STS2);
    my $log = AppState->instance->get_app_object('Log');

#say STDERR "Log 1: @$sts_texts";
    my $count = 1;
    foreach my $sts_text (@$sts_texts)
    {
      my $ecode = 'STS' . $count++;
      $log->log( $main->$ecode, [ $main->$ecode, $sts_text]);
#say STDERR "Log: $ecode, $main->$ecode, $sts_text";
    }
  }
};

#-------------------------------------------------------------------------------
package Foo::Bar
{
};

#-------------------------------------------------------------------------------
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
# Make a few status messages
#
my $sts_texts = [qw( M_TRACE M_DEBUG M_INFO M_WARN M_WARNING M_ERROR M_FATAL)];
my $count = 1;
foreach my $sts_text (@$sts_texts)
{
  def_sts( "STS$count", $sts_text, 'Status is %08X with %s severity');
  $count++;
}
say STDERR "Log 1: @$sts_texts";

#-------------------------------------------------------------------------------
# Make object from main package.
#
has foo =>
    ( is                => 'rw'
    , isa               => 'Foo'
    );

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

$self->foo(Foo->new);

#-------------------------------------------------------------------------------
# Get log object
#
my $tagName = '103';
my $log = $app->get_app_object('Log');
$log->die_on_fatal(0);

$log->do_append_log(0);
$log->do_flush_log(1);
$log->start_logging;

#-------------------------------------------------------------------------------
# Test for default rootlogger level values
#
subtest 'Test logger names' =>
sub
{
  is( $log->get_logger_name($log->ROOT_STDERR), 'A_Stderr::main', 'Stderr logger name = A_Stderr::main');
  is( $log->get_logger_name($log->ROOT_FILE), 'A_File::main', 'File logger name = A_File::main');
  is( $log->get_logger_name($log->ROOT_EMAIL), 'A_Email::main', 'Email logger name = A_Email::main');

  $self->foo->t0;
};

subtest 'Test rootlogger levels' =>
sub
{
  is( $log->stderr_log_level, $log->M_FATAL, 'Stderr log level is FATAL from root');
  is( $log->file_log_level, $log->M_TRACE, 'File log level is TRACE from root');
  is( $log->email_log_level, $log->M_FATAL, 'Email log level is FATAL from root');

  $self->foo->t1;
  $log->file_log_level($self->M_INFO);
  $self->foo->t2;
};

#-------------------------------------------------------------------------------

  $log->stderr_log_level({ package => 'root', level => $self->M_TRACE});
  $log->file_log_level($self->M_TRACE);
  $log->add_tag($tagName);

#-------------------------------------------------------------------------------
# Check last error system
#
subtest 'Test sub packages tests' =>
sub
{
  pass "Tests";
  $self->foo->x( $self, $sts_texts);
};

$app->cleanup;
#File::Path::remove_tree($config_dir);
done_testing();
exit(0);

__END__

#-------------------------------------------------------------------------------
# Info and warnings are not sent to the log unless forced.
#
#subtest 'log file tests 2' =>
#sub
#{
#  $log->write_log( "Message 1", 1|$log->M_INFO);
#};

$log->file_log_level($self->M_TRACE);
foreach my $count1 (1..3)
{
  foreach my $count2 (1..5)
  {
    $self->log( $self->C_LOOP, [ $count1, $count2]);
  }
  sleep(1);
}

$app->cleanup;
#File::Path::remove_tree($config_dir);
done_testing();
exit(0);

__END__



#-------------------------------------------------------------------------------
subtest 'check error object' =>
sub
{
  my $lineNbr = __LINE__;
  my $eobj = $log->write_log( 'Tracing this time', 0x2A9 | $app->M_F_TRACE);
  isa_ok( $eobj, 'AppState::Ext::Status');
if(0)
{
  ok( $eobj->is_success == 1, 'Is success');
  ok( $eobj->is_fail == 0, 'Is not a failure');
  ok( $eobj->is_forced == 1, 'Check if trace');
  ok( $eobj->is_trace == 1, 'Check if forced');
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
  ok( $status->is_warning, 'is warning');
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
  ok( $status->is_error, 'is error');
  ok( $status->get_eventcode, "Check eventcode == " . $status->get_eventcode);

  $self->log( $self->C_ERR_2, [ 10, 11]);
  is( ref $source, 'AppState::Plugins::Feature::Log', 'Check source of notify');
  is( $tag, $tagName, 'Check tag name of the event');
  ok( $status->is_error, 'is error');
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
  $log->do_append_log(0);

  $log->do_flush_log(1);
  $log->file_log_level($log->M_INFO);
  $log->write_start_message(0);

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
  $log->file_log_level($log->M_INFO);

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
  $log->file_log_level($log->M_ERROR);
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

$log->file_log_level($self->M_TRACE);
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
#File::Path::remove_tree($config_dir);

done_testing();
exit(0);

