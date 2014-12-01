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
# Make a few status messages in main package
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
my $tagName = '104';
my $log = $app->get_app_object('Log');
$log->die_on_fatal(0);
$log->do_flush_log(1);
$log->start_file_logging;
$log->add_tag($tagName);

#-------------------------------------------------------------------------------
#
subtest 'Test wrong input' =>
sub
{
  # A wrong input to die_on_fatal()
  #
#  $log->die_on_fatal('abc');
  throws_ok { $log->die_on_fatal('abc'); }
            qr/Attribute \(die_on_fatal\) does not pass the type constraint/
           , 'Moose dies on wrong input'
           ;
};

#-------------------------------------------------------------------------------
#
subtest 'Die myself' =>
sub
{
  # A wrong input to die_on_fatal()
  #
#  die "Testing die here and now";
  throws_ok { die "Testing die here and now"; }
            qr/Testing die here and now/
           , 'Testing die here and now'
           ;
};

#-------------------------------------------------------------------------------
$app->cleanup;
File::Path::remove_tree($config_dir);
done_testing();
exit(0);




################################################################################
#
sub clike
{
  my($test) = @_;
#  diag("Test like: qr/$test/");
  content_like( qr/104.*\.log$/, qr/$test/, $config_dir);
}

################################################################################
#
sub cunlike
{
  my($test) = @_;
#  diag("Test unlike: qr/$test/");
  content_unlike( qr/104.*\.log$/, qr/$test/, $config_dir);
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
  isa_ok( $eobj, 'AppState::Plugins::Log::Status');
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
  is( ref $source, 'AppState::Plugins::Log', 'Check source of notify');
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
  is( ref $source, 'AppState::Plugins::Log', 'Check source of notify');
  is( $tag, $tagName, 'Check tag name of the event');
  ok( $status->is_error, 'is error');
  ok( $status->get_eventcode, "Check eventcode == " . $status->get_eventcode);

  $self->log( $self->C_ERR_2, [ 10, 11]);
  is( ref $source, 'AppState::Plugins::Log', 'Check source of notify');
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
  $log->start_file_logging;
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
  $log->stop_file_logging;
};

#-------------------------------------------------------------------------------
$app->cleanup;
#File::Path::remove_tree($config_dir);

done_testing();
exit(0);

