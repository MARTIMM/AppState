package AppState::Plugins::Feature::Log;

use Modern::Perl '2010';
use 5.010001;
use version; our $VERSION = '' . version->parse("v0.3.11");

use namespace::autoclean;

use Moose;
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
require Scalar::Util;

use Text::Wrap ('$columns');
$columns = 80;

#-------------------------------------------------------------------------------
# Switch to append to an existing log or to start a fresh one
#
has do_append_log =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 1
    , traits            => ['Bool']
    , handles           =>
      { append          => 'set'
      , fresh           => 'unset'
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
      , get_log_tags      => 'keys'
      , get_tag_labels    => 'values'
      }
    );

# Log bitmask is a verbosity mask. The more bits are set the more noise is
# shown. Write gets a message mask with the message and is tested with this
# mask before logging.
#
has log_mask =>
    ( is                => 'rw'
    , isa               => 'Int'
    , lazy              => 1
    , default           => sub { return $_[0]->M_ERROR; }
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;

        $o //= 0;
        return if $n == $o;
        
        my $n_str = $self->_get_log_level_name($n);
        my $o_str = $self->_get_log_level_name($o);
        $self->log( $self->C_LOG_BMCHANGED, [ $o_str, $n_str]);

        my $log_level_name = $self->_get_log_level_name($n);
        my $logger = $self->get_logger('AppState::Plugins::Feature::Log');
        $logger->level($log_level_name) if defined $logger;
      }
    );

has _toggle_forced =>
    ( is                => 'ro'
    , isa               => 'Bool'
    , default           => 0
    , lazy              => 1
    , traits            => ['Bool']
    , handles           =>
      { _forced_log => 'set'
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
          my $logger = $self->get_logger('' . $self->C_LOG_LOGGERNAME);
          $curr_level = $logger->level;
          $logger->level('ALL');
        }
        
        # When resetting forced logging, get the previously saved log level
        # and restore the old level
        #
        elsif( $n == 0 and $o )
        {
          my $logger = $self->get_logger('' . $self->C_LOG_LOGGERNAME);
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

has log_is_started =>
    ( is                => 'ro'
    , isa               => 'Bool'
    , default           => 0
    , writer            => '_set_started'
    );

has logger_initialized =>
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
      { set_logger     => 'set'
      , get_logger     => 'get'
      }
    , init_arg          => undef
    , default           => sub{ return {}; }
    );

has _logger_layouts =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , traits            => ['Hash']
    , handles           =>
      { _set_layout     => 'set'
      , _get_layout     => 'get'
      }
    , init_arg          => undef
    , default           => sub{ return {}; }
    );

has do_flush_log =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 0
    , trigger           =>
      sub
      {
return;
        my( $self, $n, $o) = @_;

        $o //= 0;
        return if $n == $o;
        return unless $self->isLogFileOpen;

        if( $n )
        {
#          $self->_logFileHandle->autoflush(1);
          $self->log($self->C_LOG_AUTOFLUSHON);
        }

        else
        {
#          $self->_logFileHandle->autoflush(0);
          $self->log($self->C_LOG_AUTOFLUSHOFF);
        }
      }
    );

has _OriginalFileOutputSetting =>
    ( is                => 'rw'
    , isa               => 'Any'
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
    , isa               => 'AppState::Ext::Status'
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

  if( $self->meta->is_mutable )
  {
    # Error codes
    #
#    $self->code_reset;
    $self->const( 'C_LOG_AUTOFLUSHON',  'M_F_INFO', 'Autoflush turned on');
    $self->const( 'C_LOG_AUTOFLUSHOFF', 'M_F_INFO', 'Autoflush turned off');
    $self->const( 'C_LOG_LOGINIT',      'M_F_INFO', 'Logger initialized');
    $self->const( 'C_LOG_LOGOPENED',    'M_F_INFO', 'Log level set to \'%s\'. %s');
    $self->const( 'C_LOG_LOGCLOSED',    'M_F_INFO', 'Logfile closed');
    $self->const( 'C_LOG_TAGLBLINUSE',  'M_F_WARNING', 'Tag label \'%s\' already in use');
    $self->const( 'C_LOG_TAGALRDYSET',  'M_F_WARNING', 'Package \'%s\' already has a tag \'%s\'');
    $self->const( 'C_LOG_BMCHANGED',    'M_F_INFO', "Log level changed from '%s' into '%s'");
    $self->const( 'C_LOG_TAGADDED',     'M_INFO', 'Tag \'%s\' added for module \'%s\'');
    $self->const( 'C_LOG_NOERRCODE',    'M_F_ERROR', 'Error does not have an error code and/or severity code');
    $self->const( 'C_LOG_NOMSG',        'M_F_ERROR', 'No message given to write_log');
#    $self->const( 'C_LOG_', '');

    # Constant codes
    #
#    $self->const( 'C_LOG_'     , '');
    $self->const( 'C_LOG_LOGGERNAME',   'M_CODE', 'AppState::Plugins::Feature::Log');
    __PACKAGE__->meta->make_immutable;
  }
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
sub cleanup
{
  my($self) = @_;
  $self->stop_logging;
}

#-------------------------------------------------------------------------------
# !!!!!! NOT Can hand over your own file handle e.g. $l->start_logging(*STDERR);
#
sub start_logging
{
#  my( $self, $LOG) = @_;
  my( $self) = @_;

  # Reset some values used to compare values from a previous log entry.
  #
  $self->_previousMsg('');
  $self->_previousMsgEq(0);
  $self->_previousDate('');
  $self->_previousTime('');

  $self->_set_started(1);
  $self->_make_logger_objects unless $self->logger_initialized;

  # Check if user has a IO handler of his own. Use that instead.
#  if( defined $LOG )
#  {
#  }

  # Otherwise open a file for logging.
  #
#  else
#  {
#  }

  # Write first entry to log file
  #
  my $level_str = $self->_get_log_level_name($self->log_mask);
  $self->log( $self->C_LOG_LOGOPENED
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
  $self->_set_started(0);
return;

#  return unless $self->isLogFileOpen;

#  $self->log($self->C_LOG_LOGCLOSED);

#  my $log = $self->_logFileHandle;
#  close $log;

#  $self->_clearHandle;
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
  $layout = Log::Log4perl::Layout::PatternLayout->new('%n%d{HH:mm:ss}%n');
  $self->_set_layout('log.time' => $layout);

  # And a layout for the milliseconds and message
  #
  $layout = Log::Log4perl::Layout::PatternLayout->new('%d{SSS} %m{chomp}%n');
  $self->_set_layout('log.millisec' => $layout);


  # Create logger
  #
  my $logger = Log::Log4perl->get_logger('' . $self->C_LOG_LOGGERNAME);
  $self->set_logger('' . $self->C_LOG_LOGGERNAME => $logger);

  my %init_appender =
     ( name         => '' . $self->C_LOG_LOGGERNAME
     , filename     => $log_file
     );
  $init_appender{mode} = 'write' unless $self->do_append_log;
  $init_appender{autoflush} = 1 if $self->do_flush_log;
  my $appender = Log::Log4perl::Appender->new
                 ( "Log::Log4perl::Appender::File"
                 , %init_appender
                 );

  $logger->add_appender($appender);
  $logger->level('ALL');
  $appender->layout($self->_get_layout('log.millisec'));

  # Finish setup, 
  #
  $self->_set_logger_initialized(1);
  $self->log($self->C_LOG_LOGINIT);
  $self->log_mask($self->M_ERROR);
}

#-------------------------------------------------------------------------------
# Create first message for logfile. Will also be done when starting a new day.
#
sub _log_data_line
{
  my( $self) = @_;

  return unless $self->log_is_started;
  
  $self->_forced_log;
  my $logger = $self->get_logger('' . $self->C_LOG_LOGGERNAME);
  my $appender = Log::Log4perl->appenders->{'' . $self->C_LOG_LOGGERNAME};

  $appender->layout($self->_get_layout('log.startmsg'));
  $logger->trace($self->_get_start_msg);
  $appender->layout($self->_get_layout('log.date'));
  $logger->trace('undispl. msg');

  $appender->layout($self->_get_layout('log.millisec'));
  $self->_normal_log;
}

#-------------------------------------------------------------------------------
# Create message for logfile to show the time
#
sub _log_time_line
{
  my( $self) = @_;

  return unless $self->log_is_started;
  
  $self->_forced_log;
  my $logger = $self->get_logger('' . $self->C_LOG_LOGGERNAME);
  my $appender = Log::Log4perl->appenders->{'' . $self->C_LOG_LOGGERNAME};

  $appender->layout($self->_get_layout('log.time'));
  $logger->trace('undispl. msg');

  $appender->layout($self->_get_layout('log.millisec'));
  $self->_normal_log;
}

#-------------------------------------------------------------------------------
# Log message.
#
sub _log_message
{
  my( $self, $msg, $forced) = @_;

  return unless $self->log_is_started;
  
  $forced //= 0;
  
  # Get the logger and the function name from the error message. Then
  # log the message with that function.
  #
  $self->_forced_log if $forced;
  my $logger = $self->get_logger('' . $self->C_LOG_LOGGERNAME);
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

# maybe because of multibit values:
# if( ($mask & $self->M_NOTMSFF) == $self->M_TRACE ) {}

  if( !!($mask & $self->M_NOTMSFF & $self->M_TRACE) )
  {
    $log_level_name = 'TRACE';
  }

  elsif( !!($mask & $self->M_NOTMSFF & $self->M_DEBUG) )
  {
    $log_level_name = 'DEBUG';
  }

  elsif( !!($mask & $self->M_NOTMSFF & $self->M_INFO) )
  {
    $log_level_name = 'INFO';
  }

  elsif( !!($mask & $self->M_NOTMSFF & $self->M_WARNING) )
  {
    $log_level_name = 'WARN';
  }

  elsif( !!($mask & $self->M_NOTMSFF & $self->M_ERROR) )
  {
    $log_level_name = 'ERROR';
  }

  elsif( !!($mask & $self->M_NOTMSFF & $self->M_FATAL) )
  {
    $log_level_name = 'FATAL';
  }

  else
  {
    $log_level_name = 'TRACE';
  }

#say "Log level: $log_level_name";
  return $log_level_name;
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
Format is as follows;
[date][time][msec] tag line_number severity_code wrapped_message

Date and time are shown on a separate line when it repeates
Milliseconds are shown when date and time are not changing between logs

Tag is a 3 letter code representing the logging module

Severity code is a 2 letter code.
First is i, w, e, t, d and f for info, warning, error, trace, debug or fatal resp.
Second is s and f for success or failure resp.

Uppercase letters mean that the log will be forced while otherwise the setting
of loglevel would prevent it.
$line
EOLEGEND
}

#-------------------------------------------------------------------------------
# Write message to log. This handles the code as a dualvar. Furthermore the
# incorporated message cannot be an array reference. The message can now have
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

  my $message = '';
  $message = ref $messages eq 'ARRAY' ? join( ' ', @$messages) : $messages;

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


  # Make the status object to be returned later. When it fails, returns
  # a status object itself and must be returned immediately.
  # Any error logged in set_status comes here again -> deep recursion
  #
  my $status = AppState::Ext::Status->new;
  $status->set_status( error     => $error
                     , message   => $message
                     , line      => $l
                     , file      => $f
                     , package   => $package
                     );
  $self->_lastError($status);

  # Notify subscribed users when error is worse than info
  #
  $self->notify_subscribers( $log_tag, $status)
    if $status->is_warning or $status->is_error or $status->is_fatal;

  # Create the message for the log
  #
  my( $dateTxt, $timeTxt, $msgTxt) =
     $self->_create_message( $log_tag, $call_level + 1);

  
  $self->_log_data_line if $dateTxt;
  $self->_log_time_line if $timeTxt;

  $self->_log_message( Text::Wrap::wrap( '', ' ' x 12, $msgTxt)
                     , $status->is_forced
                     ) if $msgTxt;

  $self->_log_message( join( ''
                           , map { ' ' x 8 . "$_\n"}
                                 $self->_get_stack($call_level + 1)
                           )
                     , $status->is_forced
                     )
     if $status->is_error
     or $status->is_fatal
     ;

  if( $status->is_error and $self->show_on_error
      or $status->is_warning and $self->show_on_warning
      or $status->is_fatal and $self->show_on_fatal
    )
  {
    say STDERR Text::Wrap::wrap( '', ' ' x 12, $msgTxt);
    print STDERR map {' ' x 4 . $_ . "\n"} $self->_get_stack($call_level + 1);
  }

  if( $status->is_error and $self->die_on_error
      or $status->is_fatal and $self->die_on_fatal
    )
  {
    $self->stop_logging;
    exit(1);
  }

  # Return status object
  #
  return $status;
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

  my $tagLabels = join( '|', $self->get_tag_labels);
  if( $log_tag =~ m/^($tagLabels)$/ )
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
# Set bits in the logmask using bitwise or.
#
#sub setMask
#{
#  my( $self, $mask) = @_;
#
#  $mask //= $self->M_SEVERITY;
#  $self->log_mask($self->log_mask | $mask);
#}
#
#-------------------------------------------------------------------------------
# Clear bits in the logmask using bitwise and of negated mask.
#
#sub clrMask
#{
#  my( $self, $mask) = @_;
#
#  $mask //= $self->M_NONE;
#  $self->log_mask($self->log_mask & ~$mask);
#}


#-------------------------------------------------------------------------------

1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState::Log - Module to do message logging and severity status handling

=head1 SYNOPSIS


=head1 DESCRIPTION



=head2 EXPORT

None by default.



=head1 SEE ALSO


=head1 AUTHOR

Marcel Timmerman, E<lt>mt1957@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Marcel Timmerman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
