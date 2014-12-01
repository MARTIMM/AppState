# Testing module AppState/Config.pm
#
use Modern::Perl;
use Test::Most;
use File::Path();

use AppState;

#-------------------------------------------------------------------------------
# Init
#
my $config_dir = 't/Log';
my $app = AppState->instance;
$app->initialize( config_dir => $config_dir, check_directories => 1);

#-------------------------------------------------------------------------------
# Get log object
#
my $tagName = '100';
my $log = $app->get_app_object('Log');

#-------------------------------------------------------------------------------
subtest 'Check object and defaults' =>
sub
{
  my $log_modulename = 'AppState::Plugins::Log';
  isa_ok( $log, $log_modulename);
  $log->add_tag($tagName);

  is( $log->C_ROOTFILE, 'A::File', 'Check root file loggername');
  is( $log->C_ROOTSTDERR, 'A::Stderr', 'Check root stderr loggername');
  is( $log->C_ROOTEMAIL, 'A::Email', 'Check root email loggername');

  is( $log->log_file, '100-Log.log', 'Logfile is 100-Log.log');
  is( $log->nbr_log_files, 5, 'Maximum number of logfiles is 5');

  # _log_tag checks
  #
  ok( $log->nbr_log_tags == 4, 'Number of tags registered should be 4')
    or print "4 tags for main, AppState, PluginManager and Log modules, "
           , $log->nbr_log_tags
           , ', ', join( ', ', $log->get_tag_modules)
           , "\n";

  is( $log->get_log_tag(__PACKAGE__), $tagName, "Tag of package main=$tagName");
  ok( $log->has_log_tag(__PACKAGE__), "Package has a tag name");
  ok( $log->get_tag_modules == 4, 'Package has 4 registered modules');
  is( join( ' ', sort $log->get_tag_names), '100 =AP =LG =PM', 'Tag names check');

  ok( defined $log->file_log_level, 'Log level defined');
  is( $log->file_log_level, $log->M_TRACE, 'Log level set to info');

  ok( defined $log->stderr_log_level, 'Standard error log level defined');
  is( $log->stderr_log_level, $log->M_FATAL, 'Standard log level set to fatal');

  ok( !$log->_is_logging_forced, 'No errors of which were forced logging');
  ok( !$log->_is_logging, 'Logging not started yet');

  ok( !$log->die_on_error, 'Die on error off');
  ok( $log->die_on_fatal, 'Die on error on');

  ok( $log->write_start_message, 'Show start message on');

#  ok( !$log->_logger_initialized, 'Logger not initialized');
  ok( !$log->_defined_logging('file'), 'File logging not defined');
  ok( !$log->_defined_logging('stderr'), 'Stderr logging not defined');
  ok( !$log->_defined_logging('email'), 'Email logging not defined');
};

#-------------------------------------------------------------------------------
subtest 'Check error messages' =>
sub
{
  # Don't whish to die.
  #
  $log->die_on_fatal(0);

  # We want to log all from main.
  #
  $log->file_log_level($log->M_TRACE);

  my $sts = $log->log($log->C_LOG_LOGINIT);
  ok( !defined $sts, 'Informational messages will not return status objects');

  $sts = $log->log( $log->C_LOG_TAGLBLINUSE, ['XYZ']);
  like( $sts->get_message, qr/'XYZ'/, 'TAGLBLINUSE Check error message');

  $sts = $log->log( $log->C_LOG_TAGALRDYSET, [ 'PCK', 'TAG']);
  like( $sts->get_message, qr/'PCK'/, 'TAGALRDYSET Check error message');

  $sts = $log->log($log->C_LOG_NOERRCODE);
  like( $sts->get_message, qr/Error does not have an/, 'NOERRCODE Check error message');

  $sts = $log->log($log->C_LOG_NOMSG);
  like( $sts->get_message, qr/ssage given to write_/, 'NOMSG Check error message');

  $sts = $log->log($log->C_LOG_LOGALRINIT);
  like( $sts->get_message, qr/anged, logger alrea/, 'LOGALRINIT Check error message');
};

#-------------------------------------------------------------------------------
subtest 'Checks after starting' =>
sub
{
  # Flush to check file contents
  #
  $log->start_file_logging({ mode => 'append', autoflush => 1});
  ok( $log->_defined_logging('file'), 'File logging defined');
  ok( $log->_get_logging('file'), 'File logging is started');

  $log->stop_file_logging;
  ok( $log->_defined_logging('file'), 'File logging still defined');
  ok( !$log->_get_logging('file'), 'File logging stopped again');
  
  ok( -e "$config_dir/100-Log.log", 'Logfile created');
  
#  ok( $log->_logger_initialized, 'Logger is initialized');
  isa_ok( $log->_get_layout('log.date'), 'Log::Log4perl::Layout');

#  $log->stderr_log_level({level => $log->M_FATAL, package => 'root'});
  $log->start_stderr_logging;
  ok( $log->_defined_logging('stderr'), 'Stderr logging defined');
  ok( $log->_get_logging('stderr'), 'Stderr logging is started');

  $log->stop_stderr_logging;
  ok( $log->_defined_logging('stderr'), 'Stderr logging still defined');
  ok( !$log->_get_logging('stderr'), 'Stderr logging stopped again');

  $log->start_email_logging;
  ok( $log->_defined_logging('email'), 'Email logging defined');
  ok( $log->_get_logging('email'), 'Email logging is started');

  $log->stop_email_logging;
  ok( $log->_defined_logging('email'), 'Email logging still defined');
  ok( !$log->_get_logging('email'), 'Email logging stopped again');
};

#-------------------------------------------------------------------------------
done_testing();
$app->cleanup;
#File::Path::remove_tree($config_dir);
exit(0);

