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
  my $log_modulename = 'AppState::Plugins::Feature::Log';
  isa_ok( $log, $log_modulename);
  $log->add_tag($tagName);

  is( $log->ROOT_FILE, 'A_File', 'Check root file loggername');
  is( $log->ROOT_STDERR, 'A_Stderr', 'Check root stderr loggername');
  is( $log->ROOT_EMAIL, 'A_Email', 'Check root email loggername');

  ok( $log->do_append_log == 1, 'Append to log turned on');
  ok( $log->do_flush_log == 0, 'Flushing turned off');
  is( $log->log_file, '100-Log.log', 'Logfile is 100-Log.log');
  is( $log->log_file_size, 10485760, 'Logfile size 10485760');
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
  
  ok( !$log->_logger_initialized, 'Logger not initialized');
#  ok( $log->_nbr_loggers == 0, 'No Log::Log4perl logger defined');
#  ok( $log->_nbr_layouts == 0, 'No Log::Log4perl layouts defined');
};

#-------------------------------------------------------------------------------
subtest 'Check error messages' =>
sub
{
  # Don't whish to die.
  #
  $log->die_on_fatal(0);

  # We want to log all.
  #
  $log->file_log_level($log->M_TRACE);

  # Don't show stack dumps now
  #
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
  # Start a new logfile
  #
  $log->do_append_log(0);
  
  # Flush to check file contents
  #
  $log->do_flush_log(1);

  $log->start_logging;
  ok( $log->_is_logging, 'Logging is started');

  $log->stop_logging;
  ok( !$log->_is_logging, 'Logging stopped again');
  
  ok( -e "$config_dir/100-Log.log", 'Logfile created');
  
  ok( $log->_logger_initialized, 'Logger is initialized');
#  ok( $log->_nbr_loggers == 2, '2 Log::Log4perl loggers defined');
#  isa_ok( $log->_get_logger($log->C_LOG_LOGGERFILE), 'Log::Log4perl::Logger');
  ok( $log->_nbr_layouts == 5, '5 Log::Log4perl layouts defined');
  is( join( ' ', sort $log->_get_layouts)
    , 'log.date log.millisec log.startmsg log.stderr log.time'
    , 'Layout keys check'
    );
  isa_ok( $log->_get_layout('log.date'), 'Log::Log4perl::Layout');
};

#-------------------------------------------------------------------------------
done_testing();
$app->cleanup;
File::Path::remove_tree($config_dir);
exit(0);

