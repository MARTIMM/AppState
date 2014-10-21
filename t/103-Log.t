#-------------------------------------------------------------------------------
package Foo
{
  use Modern::Perl;
  use Test::Most;
  use Moose;
  extends 'AppState::Ext::Constants';

  use AppState;
  use AppState::Ext::Meta_Constants;

  my $sts_texts = [qw( M_TRACE M_DEBUG M_INFO M_WARN M_WARNING M_ERROR M_FATAL)];
  my $count = 1;
  foreach my $sts_text (@$sts_texts)
  {
    def_sts( "FOO$count", $sts_text, 'Status is %08X with %s severity');
    $count++;
  }

  sub BUILD
  {
    my( $self) = @_;
    my $log = AppState->instance->get_app_object('Log');
    $log->add_tag('Foo');
  }
  __PACKAGE__->meta->make_immutable;

  # Foo logger name testing
  #
  sub t0
  {
    my $log = AppState->instance->get_app_object('Log');
    subtest 't0, Foo logger names' =>
    sub
    {
      is( $log->get_logger_name($log->ROOT_STDERR), 'A::Stderr::Foo', 'Stderr logger name = A::Stderr::Foo');
      is( $log->get_logger_name($log->ROOT_FILE), 'A::File::Foo', 'File logger name = A::File::Foo');
      is( $log->get_logger_name($log->ROOT_EMAIL), 'A::Email::Foo', 'Email logger name = A::Email::Foo');
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

  # Test level change in Foo
  #
  sub t2
  {
    my $log = AppState->instance->get_app_object('Log');
    subtest 't2, Foo level change' =>
    sub
    {
      $log->file_log_level($log->M_WARN);
      is( $log->file_log_level, $log->M_WARN, 'File log level changed, is now WARN');
    };
  }

  sub log_all_log_levels
  {
    my( $self, $sts_texts) = @_;
    my $log = AppState->instance->get_app_object('Log');

    my $count = 1;
    foreach my $sts_text (@$sts_texts)
    {
      my $ecode = 'FOO' . $count++;
      $log->log( $self->$ecode, [ $self->$ecode, $sts_text]);
    }
  }
};

#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
package Foo::Bar
{
  use Modern::Perl;
  use Test::Most;
  use Moose;
  extends 'AppState::Ext::Constants';

  use AppState;
  use AppState::Ext::Meta_Constants;

  my $sts_texts = [qw( M_TRACE M_DEBUG M_INFO M_WARN M_WARNING M_ERROR M_FATAL)];
  my $count = 1;
  foreach my $sts_text (@$sts_texts)
  {
    def_sts( "BAR$count", $sts_text, 'Status is %08X with %s severity');
    $count++;
  }

  sub BUILD
  {
    my( $self) = @_;
    my $log = AppState->instance->get_app_object('Log');
    $log->add_tag('Bar');
  }
  __PACKAGE__->meta->make_immutable;

  # Bar logger name testing
  #
  sub t0
  {
    my $log = AppState->instance->get_app_object('Log');
    subtest 't0, Foo::Bar logger names' =>
    sub
    {
      is( $log->get_logger_name($log->ROOT_STDERR), 'A::Stderr::Foo::Bar', 'Stderr logger name = A::Stderr::Foo::Bar');
      is( $log->get_logger_name($log->ROOT_FILE), 'A::File::Foo::Bar', 'File logger name = A::File::Foo::Bar');
      is( $log->get_logger_name($log->ROOT_EMAIL), 'A::Email::Foo::Bar', 'Email logger name = A::Email::Foo::Bar');
    };
  }

  # Bar log levels are from root level and higher. WARN is set in Foo.
  #
  sub t1
  {
    my $log = AppState->instance->get_app_object('Log');
    subtest 't1, Foo::Bar root level' =>
    sub
    {
      is( $log->stderr_log_level, $log->M_FATAL, 'Stderr log level is FATAL from root');
      is( $log->file_log_level, $log->M_TRACE, 'File log level is TRACE from root');
      is( $log->email_log_level, $log->M_FATAL, 'Email log level is FATAL from root');
    };
  }

  # Test level change in Bar
  #
  sub t2
  {
    my $log = AppState->instance->get_app_object('Log');
    subtest 't2, Foo::Bar level change' =>
    sub
    {
      $log->file_log_level($log->M_ERROR);
      is( $log->file_log_level, $log->M_ERROR, 'File log level changed, is now ERROR');
    };
  }

  sub log_all_log_levels
  {
    my( $self, $sts_texts) = @_;
    my $log = AppState->instance->get_app_object('Log');
    $log->email_log_level($log->M_TRACE);

    my $count = 1;
    foreach my $sts_text (@$sts_texts)
    {
      my $ecode = 'BAR' . $count++;
      $log->log( $self->$ecode, [ $self->$ecode, $sts_text]);
    }
  }
};

#-------------------------------------------------------------------------------
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
# Make a few status messages in main package
#
my $sts_texts = [qw( M_TRACE M_DEBUG M_INFO M_WARN M_WARNING M_ERROR M_FATAL)];
my $count = 1;
foreach my $sts_text (@$sts_texts)
{
  def_sts( "MAIN$count", $sts_text, 'Status is %08X with %s severity');
  $count++;
}

#-------------------------------------------------------------------------------
# Make object from main package.
#
has foo =>
    ( is                => 'rw'
    , isa               => 'Foo'
    );

#-------------------------------------------------------------------------------
# Make object from main package.
#
has bar =>
    ( is                => 'rw'
    , isa               => 'Foo::Bar'
    );

__PACKAGE__->meta->make_immutable;
my $self = main->new;

#-------------------------------------------------------------------------------
# Init
#
my $config_dir = 't/Log';
my $app = AppState->instance;
$app->initialize( config_dir => $config_dir, check_directories => 1);

$self->foo(Foo->new);
$self->bar(Foo::Bar->new);

#-------------------------------------------------------------------------------
# Get log object
#
my $tagName = '103';
my $log = $app->get_app_object('Log');
$log->die_on_fatal(0);
$log->do_append_log(0);
$log->do_flush_log(1);
$log->start_logging;
$log->add_tag($tagName);

#-------------------------------------------------------------------------------
# Test for default rootlogger level values
#
subtest 'Test logger names' =>
sub
{
  is( $log->get_logger_name($log->ROOT_STDERR), 'A::Stderr::main', 'Stderr logger name = A::Stderr::main');
  is( $log->get_logger_name($log->ROOT_FILE), 'A::File::main', 'File logger name = A::File::main');
  is( $log->get_logger_name($log->ROOT_EMAIL), 'A::Email::main', 'Email logger name = A::mail::main');

  # Test logger names in Foo and Foo::Bar
  #
  $self->foo->t0;
  $self->bar->t0;
};

#-------------------------------------------------------------------------------
#
subtest 'Test rootlogger levels' =>
sub
{
  is( $log->stderr_log_level, $log->M_FATAL, 'Stderr log level is FATAL from root');
  is( $log->file_log_level, $log->M_TRACE, 'File log level is TRACE from root');
  is( $log->email_log_level, $log->M_FATAL, 'Email log level is FATAL from root');

  # Test root logger levels in Foo, Change main logger level and check
  # again in Foo and test change in Foo.
  #
  $self->foo->t1;
  $self->bar->t1;
  $log->file_log_level($self->M_INFO);
  $self->foo->t1;
  $self->bar->t1;
  $self->foo->t2;
  $self->bar->t2;
};

#-------------------------------------------------------------------------------
# Change default stderr root level
#
### $log->stderr_log_level({ package => 'root', level => $self->M_TRACE});

#-------------------------------------------------------------------------------
# Check log messages from MAIN
#
subtest 'Log messages from MAIN' =>
sub
{
  $self->log_all_log_levels($sts_texts);

  # file level for main was set to INFO above
  #
  &cunlike("Ts 103 \\d+ MAIN1 - Status is 10120... with M_TRACE severity");
  &cunlike("Ds 103 \\d+ MAIN2 - Status is 10240... with M_DEBUG severity");
  &clike("Is 103 \\d+ MAIN3 - Status is 11060... with M_INFO severity");
  &clike("W- 103 \\d+ MAIN4 - Status is 02080... with M_WARN severity");
  &clike("W- 103 \\d+ MAIN5 - Status is 02080... with M_WARNING severity");
  &clike("Ef 103 \\d+ MAIN6 - Status is 240A0... with M_ERROR severity");
  &clike("Ff 103 \\d+ MAIN7 - Status is 204C0... with M_FATAL severity");
};

#-------------------------------------------------------------------------------
# Check log messages from Foo
#
subtest 'Log messages from Foo' =>
sub
{
  $self->foo->log_all_log_levels($sts_texts);

  # file level for FOO was set to WARN above
  #
  &cunlike("Ts Foo \\d+ FOO1 - Status is 10120... with M_TRACE severity");
  &cunlike("Ds Foo \\d+ FOO2 - Status is 10240... with M_DEBUG severity");
  &cunlike("Is Foo \\d+ FOO3 - Status is 11060... with M_INFO severity");
  &clike("W- Foo \\d+ FOO4 - Status is 02080... with M_WARN severity");
  &clike("W- Foo \\d+ FOO5 - Status is 02080... with M_WARNING severity");
  &clike("Ef Foo \\d+ FOO6 - Status is 240A0... with M_ERROR severity");
  &clike("Ff Foo \\d+ FOO7 - Status is 204C0... with M_FATAL severity");
};

#-------------------------------------------------------------------------------
# Check log messages from Foo::Bar
#
subtest 'Log messages from Foo::Bar' =>
sub
{
  $self->bar->log_all_log_levels($sts_texts);

  # file level for Foo::Bar was set to Error above
  #
  &cunlike("Ts Bar \\d+ BAR1 - Status is 10120... with M_TRACE severity");
  &cunlike("Ds Bar \\d+ BAR2 - Status is 10240... with M_DEBUG severity");
  &cunlike("Is Bar \\d+ BAR3 - Status is 11060... with M_INFO severity");
  &cunlike("W- Bar \\d+ BAR4 - Status is 02080... with M_WARN severity");
  &cunlike("W- Bar \\d+ BAR5 - Status is 02080... with M_WARNING severity");
  &clike("Ef Bar \\d+ BAR6 - Status is 240A0... with M_ERROR severity");
  &clike("Ff Bar \\d+ BAR7 - Status is 204C0... with M_FATAL severity");
};

#-------------------------------------------------------------------------------
# Stop logging
#
subtest 'Test finish/restarting logging' =>
sub
{
  # Trace level wil log all to file but turning of logging will inhibit
  #
  $log->file_log_level($log->M_TRACE);
  $log->stop_logging;
  $log->wlog( $log->C_LOG_TRACE, ['Finish log']);
  &cunlike("Ts 103 \\d+ TRACE - Finish log");

  # Start again and log
  #
  $log->start_logging;
  $log->wlog( $log->C_LOG_DEBUG, ['Start log again']);
  &clike("Ds 103 \\d+ DEBUG - Start log again");
};

#-------------------------------------------------------------------------------
$app->cleanup;
File::Path::remove_tree($config_dir);
done_testing();
exit(0);




################################################################################
#
sub log_all_log_levels
{
  my( $self, $sts_texts) = @_;

  my $log = AppState->instance->get_app_object('Log');

  my $count = 1;
  foreach my $sts_text (@$sts_texts)
  {
    my $ecode = 'MAIN' . $count++;
    $log->log( $self->$ecode, [ $self->$ecode, $sts_text]);
  }
}

################################################################################
#
sub clike
{
  my($test) = @_;
#  diag("Test like: qr/$test/");
  content_like( qr/103.*\.log$/, qr/$test/, $config_dir);
}

################################################################################
#
sub cunlike
{
  my($test) = @_;
#  diag("Test unlike: qr/$test/");
  content_unlike( qr/103.*\.log$/, qr/$test/, $config_dir);
}

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
subtest 'finish logging' =>
sub
{
  $log->stop_logging;
};

#-------------------------------------------------------------------------------
$app->cleanup;
#File::Path::remove_tree($config_dir);

done_testing();
exit(0);

