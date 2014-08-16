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

#-------------------------------------------------------------------------------
subtest 'Check object and defaults' =>
sub
{
  my $log_modulename = 'AppState::Plugins::Feature::Log';
  isa_ok( $log, $log_modulename);
  $log->add_tag($tagName);

  is( $log->C_LOG_LOGGERNAME, $log_modulename, 'Check loggername');
  ok( $log->do_append_log == 1, 'Append to log turned on');
  ok( $log->do_flush_log == 0, 'Flushing turned off');
  is( $log->log_file, '100-Log.log', 'Logfile is 100-Log.log');

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

  ok( !defined $log->log_level, 'Log level not yet defined');
  ok( !$log->_logging_is_forced, 'No errors of which were forced logging');
  ok( !$log->_is_logging, 'Logging not started yet');

  ok( !$log->die_on_error, 'Die on error off');
  ok( $log->die_on_fatal, 'Die on error on');

  ok( !$log->show_on_warning, 'Show stack on warning off');
  ok( $log->show_on_error, 'Show stack on error on');
  ok( $log->show_on_fatal, 'Show stack on fatal on');

  ok( $log->write_start_message, 'Show start message on');
  
  ok( !$log->logger_initialized, 'Logger not initialized');
  ok( $log->nbr_loggers == 0, 'No Log::Log4perl logger defined');
  ok( $log->nbr_layouts == 0, 'No Log::Log4perl layouts defined');
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
  $log->log_level($log->M_TRACE);

  # Don't show stack dumps now
  #
  $log->show_on_warning(0);
  $log->show_on_error(0);
  $log->show_on_fatal(0);

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
  
  ok( $log->logger_initialized, 'Logger is initialized');
  ok( $log->nbr_loggers == 1, '1 Log::Log4perl logger defined');
  isa_ok( $log->get_logger($log->C_LOG_LOGGERNAME), 'Log::Log4perl::Logger');
  ok( $log->nbr_layouts == 4, '4 Log::Log4perl layouts defined');
  is( join( ' ', sort $log->get_layouts)
    , 'log.date log.millisec log.startmsg log.time'
    , 'Layout keys check'
    );
  isa_ok( $log->get_layout('log.date'), 'Log::Log4perl::Layout');
};

#-------------------------------------------------------------------------------
done_testing();
$app->cleanup;
File::Path::remove_tree($config_dir);
exit(0);

