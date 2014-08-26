package AppState::Plugins::Feature::Log;

use Modern::Perl '2010';
use 5.010001;
use version; our $VERSION = '' . version->parse("v0.4.13");

use namespace::autoclean;

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::NonMoose;
extends qw( Class::Publisher AppState::Ext::Constants);

use DateTime;
require File::Basename;
use IO::Handle;
use AppState;
use Log::Log4perl;
use Log::Log4perl::Layout;
use Log::Log4perl::Level;
use AppState::Ext::Status;
use AppState::Ext::Meta_Constants;
require Scalar::Util;

use Text::Wrap ('$columns');
$columns = 80;

#-------------------------------------------------------------------------------
# Error codes
#
def_sts( 'C_LOG_LOGINIT',      'M_F_INFO', 'Logger initialized');
def_sts( 'C_LOG_LOGSTARTED',   'M_F_INFO', 'Logging started. Log level set to \'%s\'. %s');
def_sts( 'C_LOG_LOGSTOPPED',   'M_F_INFO', 'Logging stopped');
def_sts( 'C_LOG_TAGLBLINUSE',  'M_FATAL', q@Tag label '%s' already in use@);
def_sts( 'C_LOG_TAGALRDYSET',  'M_FATAL', q@Package '%s' already has a tag '%s'@);
def_sts( 'C_LOG_LLVLCHANGED',  'M_F_INFO', "Log level changed from '%s' into '%s'");
def_sts( 'C_LOG_TAGADDED',     'M_F_INFO', 'Tag \'%s\' added for module \'%s\'');
def_sts( 'C_LOG_NOERRCODE',    'M_F_ERROR', 'Error does not have an error code and/or severity code');
def_sts( 'C_LOG_NOMSG',        'M_F_ERROR', 'No message given to write_log');
def_sts( 'C_LOG_LOGALRINIT',   'M_F_WARNING', 'Not changed, logger already initialized');

# Constant codes
#
def_sts( 'C_LOG_LOGGERNAME',   'M_CODE', 'AppState::Plugins::Feature::Log');

#-------------------------------------------------------------------------------
# Switch to append to an existing log or to start a fresh one
#
has do_append_log =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 1
    , traits            => ['Bool']
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;

        $o //= 0;
        return if $n == $o;
        $self->log($self->C_LOG_LOGALRINIT) if $self->_logger_initialized;
      }
    );

has do_flush_log =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 0
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;

        $o //= 0;
        return if $n == $o;
        $self->log($self->C_LOG_LOGALRINIT) if $self->_logger_initialized;
      }
    );

# File name of logfile in the config directory
#
has log_file =>
    ( is                => 'rw'
    , isa               => 'Str'
#    , default          => 'config.log'
    , default           =>
      sub
      { # Get the name of the program stripped of of its extention
        # like .pl or .t
        #
        my $basename = File::Basename::fileparse( $0, qr/\.[^.]*/);
        return "$basename.log";
      }
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;
        $self->stop_logging;
      }
    );

# Tag shown in the log to show which module has written a message. Can be
# added or changed with add_tag. Modules not found in this list are shown as
# '---'. This module has added 'LOG' as default.
#
has _log_tag =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , default           => sub{ return {'AppState::Plugins::Feature::Log' => '=LG'}; }
    , init_arg          => undef
    , traits            => ['Hash']
    , handles           =>
      { nbr_log_tags      => 'count'
      , get_log_tag       => 'get'
      , _set_log_tag      => 'set'
      , has_log_tag       => 'defined'
      , get_tag_modules   => 'keys'
      , get_tag_names     => 'values'
      }
    );

# Subtype to be used to test log_level against.
#
my $_test_levels = sub {return 0;};
subtype 'AppState::Plugins::Feature::Log::Types::Log_level'
    => as 'Int'
    => where { $_test_levels->($_); }
    => message { "The store type '$_' is not correct" };

# Setting the log level can only be done when Log::Log4perl is initialized by
# _make_logger_objects(). This method will set the default level to M_ERROR.
#
has log_level =>
    ( is                => 'rw'
    , isa               => 'AppState::Plugins::Feature::Log::Types::Log_level'
#    , lazy              => 1
#    , default           => sub { return $_[0]->M_ERROR; }
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;

        $o //= 0;
        return if $n == $o;

        my $logger = $self->_get_logger('AppState::Plugins::Feature::Log');
        if( defined $logger )
        {
          my $log_level_name = $self->_get_log_level_name($n);
          $logger->level($log_level_name);

          my $o_str = $self->_get_log_level_name($o);
          $self->log( $self->C_LOG_LLVLCHANGED, [ $o_str, $log_level_name]);
        }
      }
    );

has _is_logging_forced =>
    ( is                => 'ro'
    , isa               => 'Bool'
    , default           => 0
    , lazy              => 1
    , traits            => ['Bool']
    , handles           =>
      { _force_log      => 'set'
      , _normal_log     => 'unset'
      }
    , trigger           =>
      sub
      { my( $self, $n, $o) = @_;

        state $curr_level = 0;
        $o //= 0;

        # When setting forced logging, save the previous log level and set
        # new level to accept all messages
        #
        if( $o == 0 and $n )
        {
          my $logger = $self->_get_logger('' . $self->C_LOG_LOGGERNAME);
          $curr_level = $logger->level;
          $logger->level('ALL');
        }

        # When resetting forced logging, get the previously saved log level
        # and restore the old level
        #
        elsif( $n == 0 and $o )
        {
          my $logger = $self->_get_logger('' . $self->C_LOG_LOGGERNAME);
          $logger->level($curr_level);
        }
      }
    );

has _is_logging =>
    ( is                => 'ro'
    , isa               => 'Bool'
    , default           => 0
    , lazy              => 1
    , traits            => ['Bool']
    , handles           =>
      { _logging_on     => 'set'
      , _logging_off    => 'unset'
      }
    , trigger           =>
      sub
      { my( $self, $n, $o) = @_;

        state $curr_level = 0;
        $o //= 0;

        # When setting logging off, save the previous log level and turn
        # logging off.
        #
        if( $n == 0 and $o )
        {
          my $logger = $self->_get_logger('' . $self->C_LOG_LOGGERNAME);
          $curr_level = $logger->level;
          $logger->level('OFF');
        }

        # When turning logging on, get the previously saved log level
        # and restore it
        #
        elsif( $o == 0 and $n )
        {
          my $logger = $self->_get_logger('' . $self->C_LOG_LOGGERNAME);
          $logger->level($curr_level);
        }
      }
    );

has die_on_error =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 0
    );

has die_on_fatal =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 1
    );

has show_on_warning =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 0
    );

has show_on_error =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 1
    );

has show_on_fatal =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 1
    );

has write_start_message =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 1
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;

        $o //= 0;
        return if $n == $o;
        $self->log($self->C_LOG_LOGALRINIT) if $self->_logger_initialized;
      }
    );

has _logger_initialized =>
    ( is                => 'ro'
    , isa               => 'Bool'
    , default           => 0
    , writer            => '_set_logger_initialized'
    );

has _loggers =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , traits            => ['Hash']
    , handles           =>
      { _set_logger      => 'set'
      , _get_logger      => 'get'
      , _nbr_loggers     => 'count'
      , _get_loggers     => 'keys'
      }
    , init_arg          => undef
    , default           => sub{ return {}; }
    );

has _logger_layouts =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , traits            => ['Hash']
    , handles           =>
      { _set_layout      => 'set'
      , _get_layout      => 'get'
      , _nbr_layouts     => 'count'
      , _get_layouts     => 'keys'
      }
    , init_arg          => undef
    , default           => sub{ return {}; }
    );

has _previousMsg =>
    ( is                => 'rw'
    , isa               => 'Str'
    , default           => ''
    , init_arg          => undef
    );

has _previousTime =>
    ( is                => 'rw'
    , isa               => 'Str'
    , default           => ''
    , init_arg          => undef
    );

has _previousDate =>
    ( is                => 'rw'
    , isa               => 'Str'
    , default           => ''
    , init_arg          => undef
    );

has _previousMsgEq =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 0
    , init_arg          => undef
    );

has _lastError =>
    ( is                => 'rw'
    , isa               => 'Maybe[AppState::Ext::Status]'
    , default           => sub { AppState::Ext::Status->new; }
    , init_arg          => undef
    , handles           =>
      { clear_last_error        => 'clear_error'
      , is_last_success         => 'is_success'
      , is_last_fail            => 'is_fail'
      , is_last_forced          => 'is_forced'
      , get_last_message        => 'get_message'
      , get_last_error          => 'get_error'
      , get_last_severity       => 'get_severity'
      , get_last_eventcode      => 'get_eventcode'
      , get_sender_line_no      => 'get_line'
      , get_sender_file         => 'get_file'
      , get_sender_package      => 'get_package'
      }
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;

  # Overwrite the sub at _test_levels. It is used for testing the subtype
  # 'AppState::Plugins::Feature::Log::Types::Log_level'. At that point we do
  # not know the constant values to test against.
  #
  $_test_levels = sub
  {
    # Codes are dualvars. doesn't matter if code is compared as string
    # or as number. But using a number might compare quicker.
    #
    return 0 + $_[0] ~~ [ $self->M_TRACE, $self->M_DEBUG, $self->M_INFO
                        , $self->M_WARN, $self->M_WARNING, $self->M_ERROR
                        , $self->M_FATAL
                        ];
  };
}

#-------------------------------------------------------------------------------
#
sub DEMOLISH
{
  my($self) = @_;
  $self->stop_logging;
  $self->delete_all_subscribers;
}

#-------------------------------------------------------------------------------
#
sub plugin_cleanup
{
  my($self) = @_;
  $self->stop_logging;
  $self->delete_all_subscribers;
}

#-------------------------------------------------------------------------------
#
sub start_logging
{
  my( $self) = @_;

  # Reset some values used to compare values from a previous log entry.
  #
  $self->_previousMsg('');
  $self->_previousMsgEq(0);
  $self->_previousDate('');
  $self->_previousTime('');

  $self->_make_logger_objects unless $self->_logger_initialized;
  $self->_logging_on;

  # Write first entry to log file
  #
  my $level_str = $self->_get_log_level_name($self->log_level);
  $self->log( $self->C_LOG_LOGSTARTED
            , [ $level_str
              , ( $self->do_append_log
                  ? "Appending to old log"
                  : "Starting new log"
                )
              ]
            );
}

#-------------------------------------------------------------------------------
# Stop logging to the file.
#
sub stop_logging
{
  my($self) = @_;
  $self->log($self->C_LOG_LOGSTOPPED);
  $self->_logging_off;
}

#-------------------------------------------------------------------------------
# Setup logger
#
sub _make_logger_objects
{
  my($self) = @_;

  my $config_dir = AppState->instance->config_dir;
  my $log_file = $config_dir . '/' . $self->log_file;


  # Devise several layouts for the used appender and logger
  # First to be used as a starting message of the log
  #
  my $layout = Log::Log4perl::Layout::PatternLayout->new('%m%n');
  $self->_set_layout('log.startmsg' => $layout);

  # Then a layout for the date
  #
  $layout = Log::Log4perl::Layout::PatternLayout->new('%n----------%n%d{yyyy-MM-dd}%n----------%n');
  $self->_set_layout('log.date' => $layout);

  # A layout for the time
  #
  $layout = Log::Log4perl::Layout::PatternLayout->new('%d{HH:mm:ss} %m%n');
  $self->_set_layout('log.time' => $layout);

  # And a layout for the milliseconds and message
  #
  $layout = Log::Log4perl::Layout::PatternLayout->new('     %d{SSS} %m{chomp}%n');
  $self->_set_layout('log.millisec' => $layout);


  # Create logger
  #
  my $logger = Log::Log4perl->get_logger('' . $self->C_LOG_LOGGERNAME);
  $self->_set_logger('' . $self->C_LOG_LOGGERNAME => $logger);

  my %init_appender =
     ( name             => '' . $self->C_LOG_LOGGERNAME
     , filename         => $log_file
     , syswrite         => 1
     , mode             => $self->do_append_log ? 'append' : 'write'
     , autoflush        => $self->do_flush_log ? 1 : 0
     );

  my $appender = Log::Log4perl::Appender->new
                 ( "Log::Log4perl::Appender::File"
                 , %init_appender
                 );

  $logger->add_appender($appender);
  $logger->level('ALL');
  $appender->layout($self->_get_layout('log.millisec'));

  # Finish setup,
  #
  $self->_logging_on;
  $self->_set_logger_initialized(1);
  $self->log($self->C_LOG_LOGINIT);
  $self->log_level($self->M_ERROR);
}

#-------------------------------------------------------------------------------
# Create first message for logfile. Will also be done when starting a new day.
#
sub _log_data_line
{
  my( $self) = @_;

  return unless $self->_is_logging;

  $self->_force_log;
  my $logger = $self->_get_logger('' . $self->C_LOG_LOGGERNAME);
  my $appender = Log::Log4perl->appenders->{'' . $self->C_LOG_LOGGERNAME};

  if( $self->write_start_message )
  {
    $appender->layout($self->_get_layout('log.startmsg'));
    $logger->trace($self->_get_start_msg);
  }

  $appender->layout($self->_get_layout('log.date'));
  $logger->trace('undisplayed message');

  $appender->layout($self->_get_layout('log.millisec'));
  $self->_normal_log;
}

#-------------------------------------------------------------------------------
# Create message for logfile to show the time
#
sub _log_time_line
{
  my( $self, $msg, $forced) = @_;

  return unless $self->_is_logging;

  $self->_force_log;
  my $logger = $self->_get_logger('' . $self->C_LOG_LOGGERNAME);
  my $appender = Log::Log4perl->appenders->{'' . $self->C_LOG_LOGGERNAME};

  $appender->layout($self->_get_layout('log.time'));
#  $logger->trace($msg);
  $self->_log_message( $msg, $forced);

  $appender->layout($self->_get_layout('log.millisec'));
  $self->_normal_log;
}

#-------------------------------------------------------------------------------
# Log message.
#
sub _log_message
{
  my( $self, $msg, $forced) = @_;

  return unless $self->_is_logging;

  $forced //= 0;

  # Get the logger and the function name from the error message. Then
  # log the message with that function.
  #
  $self->_force_log if $forced;
  my $logger = $self->_get_logger('' . $self->C_LOG_LOGGERNAME);
#  my $appender = Log::Log4perl->appenders->{'' . $self->C_LOG_LOGGERNAME};
#  $appender->layout($self->_get_layout('log.millisec'));
  my $l4p_fnc_name = $self->_get_log_level_function_name;
  $logger->$l4p_fnc_name($msg);

  $self->_normal_log if $forced;
}

#-------------------------------------------------------------------------------
# Find log level from severity mask
#
sub _get_log_level_name
{
  my( $self, $mask) = @_;
  my $log_level_name;

  if( is_trace($mask) )
  {
    $log_level_name = 'TRACE';
  }

  elsif( is_debug($mask) )
  {
    $log_level_name = 'DEBUG';
  }

  elsif( is_info($mask) )
  {
    $log_level_name = 'INFO';
  }

  elsif( is_warning($mask) )
  {
    $log_level_name = 'WARN';
  }

  elsif( is_error($mask) )
  {
    $log_level_name = 'ERROR';
  }

  elsif( is_fatal($mask) )
  {
    $log_level_name = 'FATAL';
  }

  else
  {
    $log_level_name = 'TRACE';
  }
}

#-------------------------------------------------------------------------------
# Find l4p log level function name from severity code in status object
#
sub _get_log_level_function_name
{
  my( $self) = @_;
  my $log_level_name;
  my $sts = $self->_lastError;
  if( $sts->is_trace )
  {
    $log_level_name = 'trace';
  }

  elsif( $sts->is_debug )
  {
    $log_level_name = 'debug';
  }

  elsif( $sts->is_info )
  {
    $log_level_name = 'info';
  }

  elsif( $sts->is_warning )
  {
    $log_level_name = 'warn';
  }

  elsif( $sts->is_error )
  {
    $log_level_name = 'error';
  }

  elsif( $sts->is_fatal )
  {
    $log_level_name = 'fatal';
  }

  else
  {
    $log_level_name = 'trace';
  }

#say "Log level function: $log_level_name";
  return $log_level_name;
}

#-------------------------------------------------------------------------------
#
sub _get_start_msg
{
#  my( $self, $dateTxt) = @_;
  my( $self) = @_;

  my $line = '-' x 80;
  return <<EOLEGEND;
$line
Logging format can be one of the following 3 possibilities;
1) date
2) time tag line_number severity_code wrapped_message
3) msec tag line_number severity_code wrapped_message

Milliseconds are shown when date and time are not changing between logs

A tag is a 3 letter code representing the logging module. This is set when
calling add_tag().

Severity code is a 2 letter code.
First is i, w, e, t, d and f for info, warning, error, trace, debug or fatal
respectively. The second letter is s and f for success or failure respectively.

Uppercase letters mean that the log will be forced while otherwise the setting
of loglevel would prevent it.
$line
EOLEGEND
}

#-------------------------------------------------------------------------------
# Write message to log. This handles the code as a dualvar. Furthermore the
# incorporated message cannot be an array reference. The message can also have
# sprintf markup which is substituted with values from message_values,
# an optional array reference. If the call_level must be used and no values
# are needed use an empty array ref [].
#
sub log
{
  my( $self, $error, $message_values, $call_level) = @_;

  # Get the message from the dualvar;
  #
  $call_level //= 0;
  $message_values //= [];
  my $message = '' . $error;
  $message = sprintf( $message, @$message_values) if scalar(@$message_values);

  return $self->write_log( $message, $error, $call_level + 1);
}

#-------------------------------------------------------------------------------
# Write message to log.
#
sub write_log
{
  my( $self, $messages, $error, $call_level) = @_;

  # Don't do a thing when the log level is set higher than the error level.
  # When logging is not yet started, there is no default. Use lowest level
  # in that case.
  #
  my $log_level = $self->log_level // $self->M_TRACE;
  return unless cmp_levels( $error, $log_level) >= 0 or is_forced($error);

  # The message can be a series of messages in an ARRAY ref. Make one message.
  #
  my $message = ref $messages eq 'ARRAY' ? join( ' ', @$messages) : $messages;

  # Check if error has both an event code and a severity.
  #
  if( !(($error & $self->M_EVNTCODE) and ($error & $self->M_SEVERITY)) )
  {
    $error = $self->C_LOG_NOERRCODE;
    $message = '' . $self->C_LOG_NOERRCODE;
  }

  # Rewrite message if there is no message.
  #
  elsif( !defined $message or !$message )
  {
    $message = '' . $self->C_LOG_NOMSG;
    $error = $self->C_LOG_NOMSG;
  }

  # Get the line number from where the call to write_log() was made. Default
  # caller stack level is 0. Get the log_tag when the call level packagename
  # is found. Save the log_tag in the lastError.
  #
  $call_level //= 0;
  my( $package, $f, $l) = caller($call_level);
  my $log_tag = $self->get_log_tag($package);
  $log_tag //= '';
  $log_tag = substr( "$log_tag---", 0, 3);

  # Make the status object to be returned later.
  #
  my $status = AppState::Ext::Status->new;
  $status->set_status( error     => $error
                     , message   => $message
                     , line      => $l
                     , file      => $f
                     , package   => $package
                     );
  # Notification to subscribed users only when status is worse than M_INFO
  #
  $self->notify_subscribers( $log_tag, $status)
    if cmp_levels( $error, $self->M_INFO) > 0;

  # Set new status
  #
  $self->_lastError($status);

  # The message, stackdump and so forth will only be done when
  # error is worse than info or when logging is started.
  #
  if( $self->_is_logging or cmp_levels( $error, $self->M_INFO) > 0 )
  {
    # Create the message for the log
    #
    my( $dateTxt, $timeTxt, $msgTxt) =
       $self->_create_message( $log_tag, $call_level + 1);

    $self->_log_data_line if $dateTxt;

    if( $timeTxt )
    {
      $self->_log_time_line( Text::Wrap::wrap( '', ' ' x 12, $msgTxt)
                           , is_forced($error)
                           );
    }

    else
    {
      $self->_log_message( Text::Wrap::wrap( '', ' ' x 12, $msgTxt)
                         , is_forced($error)
                         ) if $msgTxt;

      $self->_log_message( join( ''
                               , map { ' ' x 13 . "$_\n"}
                                     $self->_get_stack($call_level + 1)
                               )
                         , is_forced($error)
                         )
         if cmp_levels( $error, $self->M_ERROR) >= 0;
    }

    if( is_error($error) and $self->show_on_error
        or is_warning($error) and $self->show_on_warning
        or is_fatal($error) and $self->show_on_fatal
      )
    {
      say STDERR Text::Wrap::wrap( '', ' ' x 12, $msgTxt);
      print STDERR map {' ' x 4 . $_ . "\n"} $self->_get_stack($call_level + 1);
    }

    if( is_error($error) and $self->die_on_error
        or is_fatal($error) and $self->die_on_fatal
      )
    {
      $self->stop_logging;
      $self->leave(1);
    }
  }

  # Return status object if worse than M_INFO
  #
  return cmp_levels( $error, $self->M_INFO) > 0 ? $status : undef;
}

#-------------------------------------------------------------------------------
#
sub _create_message
{
  my( $self, $log_tag, $call_level) = @_;

  # Keep values between calls
  #
  my $previousMsg = $self->_previousMsg;
  my $previousTime = $self->_previousTime;
  my $previousDate = $self->_previousDate;
  my $pMsgEq = $self->_previousMsgEq;

#  my $eventCode = $self->get_last_eventcode;
#  my $severity = $self->get_last_severity;

  # Check the severity of the message set in the mask
  #
  my $sts = $self->_lastError;
  my $severitySymbol = '-';
  $severitySymbol = 'i' if $sts->is_info;
  $severitySymbol = 'w' if $sts->is_warning;
  $severitySymbol = 'e' if $sts->is_error;
  $severitySymbol = 't' if $sts->is_trace;
  $severitySymbol = 'd' if $sts->is_debug;
  $severitySymbol = 'f' if $sts->is_fatal;

  my $stsSymbol = '-';
  $stsSymbol = 's' if $sts->is_success;
  $stsSymbol = 'f' if $sts->is_fail;

  $severitySymbol .= $stsSymbol;

  # If the messages should have been filtered, the forced bit should have
  # been set if we ended up here
  #
  $severitySymbol = uc($severitySymbol) if $sts->is_forced;

  my $error = $sts->get_error;
  my $message = $sts->get_message;

#say "Error: ", Scalar::Util::isdual $error ? 'Dual' : 'Normal';
#say "Message: ", $message;

  my $msgTxt = sprintf "%3.3s %4.4d %2.2s %s"
             , $log_tag
             , $sts->get_line
             , $severitySymbol
             , $message
             ;

  if( $previousMsg eq $msgTxt )
  {
    if( $pMsgEq )
    {
      return ( '', '', '');
    }

    else
    {
      $pMsgEq = 1;
      $msgTxt = "            --[Message repeated]--";
    }
  }

  else
  {
    $pMsgEq = 0;
    $previousMsg = $msgTxt;
  }

  $msgTxt =~ s/[\n]+/ /gm;

  my $date = DateTime->now;
  my $timeTxt = $date->hms;
  if( $previousTime eq $timeTxt )
  {
    $timeTxt = '';
  }

  else
  {
    $previousTime = $timeTxt;
  }

  # When time is changed, maybe date is changed too
  #
  my $dateTxt = '';
  if( $timeTxt )
  {
    my $ymd = $date->ymd;
    $previousDate = $dateTxt = $ymd if $previousDate ne $ymd;
  }

  $self->_previousMsg($previousMsg);
  $self->_previousTime($previousTime);
  $self->_previousMsgEq($pMsgEq);
  $self->_previousDate($previousDate);

  return ( $dateTxt, $timeTxt, $msgTxt);
}

#-------------------------------------------------------------------------------
#
sub _get_stack
{
  my( $self, $call_level) = @_;

  $call_level //= 1;
  my @stack;
  while( my( $package, $f, $l) = caller($call_level++) )
  {
    my $log_tag = $self->get_log_tag($package);
    $log_tag //= '---';
    push @stack, sprintf( "%04d %s", $l, $package);
  }

  return ("Stack dump;", @stack);
}

#-------------------------------------------------------------------------------
# Add a 3 letter tag and couple it to the callers package name. Will be used
# by write_log to show where the message comes from.
#
sub add_tag
{
  my( $self, $log_tag, $call_level, $package) = @_;

  $call_level //= 0;
  $log_tag //= '   ';
#  my( $p, $f, $l);

  # Ignore call level to find package name when package was given
  #
  if( !defined $package )
  {
    # Check if call_level is a number into the stack.
    #
    $call_level = 0 unless $call_level =~ m/^\d+$/;
    ($package) = caller($call_level);
  }

  my @tagLabels = $self->get_tag_names;
#say "AT: $log_tag, $call_level, $package, ", join( ', ', @tagLabels);
#say "-- ", join( '', map { ' ' x 13 . "$_\n"}
#                     $self->_get_stack($call_level + 1)
#               );
  if( $log_tag ~~ \@tagLabels )
  {
    $self->log( $self->C_LOG_TAGLBLINUSE, [$log_tag]);
  }

  elsif( !$self->has_log_tag($package) )
  {
    $log_tag = substr( $log_tag, 0, 3);
    $self->_set_log_tag( $package => $log_tag);
    $self->log( $self->C_LOG_TAGADDED, [ $log_tag, $package]);
  }

  else
  {
    $self->log( $self->C_LOG_TAGALRDYSET
              , [ $package, $self->get_log_tag($package)]
              );
  }
}

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;
1;

__END__
