# Log::Log4perl links to info
#
# http://www.perl.com/pub/2002/09/11/log4perl.html
# http://www.netlinxinc.com/netlinx-blog/52-perl/126-eight-loglog4perl-recipes.html
#
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
$columns = 71; # Number of columns left for message See logger patterns.

#-------------------------------------------------------------------------------
# Error codes
#
def_sts( 'C_LOG_LOGINIT',     'M_TRACE', 'Logger initialized');
def_sts( 'C_LOG_LOGSTARTED',  'M_TRACE', "Logging started. File log level set to '%s' and stderr log level set to '%s'. %s");
def_sts( 'C_LOG_LOGSTOPPED',  'M_TRACE', 'Logging stopped');
def_sts( 'C_LOG_TAGLBLINUSE', 'M_FATAL', "Tag label '%s' already in use");
def_sts( 'C_LOG_TAGALRDYSET', 'M_FATAL', "Package '%s' already has a tag '%s'");
def_sts( 'C_LOG_LOGGERLVL',   'M_TRACE', '%s log level changed to %s');
def_sts( 'C_LOG_TAGADDED',    'M_INFO', "Tag '%s' added for module '%s'");
def_sts( 'C_LOG_NOERRCODE',   'M_F_ERROR', 'Error does not have an error code and/or severity code');
def_sts( 'C_LOG_NOMSG',       'M_F_ERROR', 'No message given to write_log');
def_sts( 'C_LOG_LOGALRINIT',  'M_F_WARNING', 'Not changed, logger already initialized');
def_sts( 'C_LOG_ILLLEVELCD',  'M_F_ERROR', 'Illegal logger level %s');

# Constant codes
#
def_sts( 'ROOT_STDERR','M_CODE', 'A_Stderr');
def_sts( 'ROOT_FILE',  'M_CODE', 'A_File');
def_sts( 'ROOT_EMAIL', 'M_CODE', 'A_Email');

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

# File size
#
has log_file_size =>
    ( is                => 'rw'
    , isa               => 'Int'
    , default           => 10485760
    );

# Number of logfiles
#
has nbr_log_files =>
    ( is                => 'rw'
    , isa               => 'Int'
    , default           => 5
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

# Subtype to be used to test *_log_level against. Function will be defined
# in BUILD.
#
my $_test_levels = sub {return 0;};
subtype 'AppState::Plugins::Feature::Log::Types::Log_level'
    => as 'Int'
    => where { $_test_levels->($_); }
    => message { "The store type '$_' is not correct" };

# Setting the log level can only be done when Log::Log4perl is initialized by
# _make_logger_objects().
#
has _log_levels =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , traits            => ['Hash']
    , handles           =>
      { _set_log_lvl    => 'set'
      , _get_log_lvl    => 'get'
      , _get_log_lvls   => 'keys'
      , _clr_log_lvls   => 'clear'
      , _nbr_log_lvls   => 'count'
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
          my $logger = Log::Log4perl->get_logger('' . $self->ROOT_FILE);
          $curr_level = $logger->level;
          $logger->level('ALL');
        }

        # When resetting forced logging, get the previously saved log level
        # and restore the old level
        #
        elsif( $n == 0 and $o )
        {
          my $logger = Log::Log4perl->get_logger('' . $self->ROOT_FILE);
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
          my $logger = Log::Log4perl->get_logger('' . $self->ROOT_FILE);
          $curr_level = $logger->level;
          $logger->level('OFF');
        }

        # When turning logging on, get the previously saved log level
        # and restore it
        #
        elsif( $o == 0 and $n )
        {
          my $logger = Log::Log4perl->get_logger('' . $self->ROOT_FILE);
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

# Do we wrap messages over multiple lines or not
#
has message_wrapping =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 1
    );

# Do we show a start message before logging and on change of date.
#
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
  
  # Make sub to define a logging level for a Log4perl logger. Root loggers are
  # defined by $logger_prefix. The calls will set a level for any logger created
  # by adding the adjusted package name to the $logger_prefix.
  #
  my $level_sub =
  sub
  {
    my( $self, $logger_prefix, $type_text, $level) = @_;
    my( $package, $f, $l, $logger_name);

    # Setter or getter ?
    #
    if( defined $level )
    {
      # When $package is not the proper level to set, it is possible to use
      # a structure where this can be set to the proper value. The special value
      # 'root' is used to set level of the root logger in $logger_prefix.
      #
      $logger_name = '';
      if( ref $level eq 'HASH' )
      {
        $package = $level->{package} if defined $level->{package};
        $level = $level->{level} = $level->{level} // $self->M_FATAL;

        $logger_name .= $self->$logger_prefix
                      . ($package eq 'root' ? '' : "::$package")
                      ;
      }

      else
      {
        ( $package, $f, $l) = caller(1);
        $logger_name .= $self->$logger_prefix . "::$package";
      }

      # Check level code
      #
      if( !$_test_levels->($level) )
      {
        $self->log( $self->C_LOG_ILLLEVELCD, [$level]);
        return;
      }

      # Save level for this package
      #
      $self->_set_log_lvl($logger_name => $level);

      my $logger = Log::Log4perl->get_logger($logger_name);
      my $log_level_name = $self->_get_log_level_name($level);
      $logger->level($log_level_name);

      $self->log( $self->C_LOG_LOGGERLVL, [ $logger_name, $log_level_name]);
    }

    else
    {
      # Getter function, so return proper level.
      #
      if( ref $level eq 'HASH' )
      {
        $package = $level->{package} if defined $level->{package};
        $logger_name .= $self->$logger_prefix
                      . ($package eq 'root' ? '' : "::$package")
                      ;
      }

      else
      {
        ( $package, $f, $l) = caller(1);
        $logger_name .= $self->$logger_prefix . "::$package";
      }

      $level = $self->get_log_lvl($logger_name);
    }

    return $level;
  };

  # Add three methods to modify logger levels using defined sub above
  #
  my $meta = Class::MOP::Class->initialize(__PACKAGE__);
  $meta->make_mutable;
  $meta->add_method
         ( file_log_level => sub
           { return &$level_sub ( shift @_, qw( ROOT_FILE File), @_)
           }
         );

  $meta->add_method
         ( stderr_log_level => sub
           { return &$level_sub ( shift @_, qw( ROOT_STDERR Stderr), @_)
           }
         );

  $meta->add_method
         ( email_log_level => sub
           { return &$level_sub ( shift @_, qw( ROOT_EMAIL Email), @_)
           }
         );
  $meta->make_immutable;

  # Now we have initialized the sub above we can set the defaults for the
  # log level and stderr log.
  #
  $self->file_log_level( { level => $self->M_TRACE, package => 'root'});
  $self->stderr_log_level( { level => $self->M_FATAL, package => 'root'});
  $self->email_log_level( { level => $self->M_FATAL, package => 'root'});
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
  
  # Set logging levels explicitly
  #
  my $level_str = $self->_get_log_level_name($self->file_log_level);
  my $stderr_level_str = $self->_get_log_level_name($self->stderr_log_level);
  Log::Log4perl->get_logger('' . $self->ROOT_FILE)->level($level_str);
  Log::Log4perl->get_logger('' . $self->ROOT_STDERR)->level($stderr_level_str);

  # Write first entry to log file
  #
  $self->wlog( $self->C_LOG_LOGSTARTED
             , [ $level_str
               , $stderr_level_str
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
# Setup loggers
#
sub _make_logger_objects
{
  my($self) = @_;

  $self->_create_file_root_logger;
  $self->_create_stderr_root_logger;

  # Finish setup,
  #
  $self->_logging_on;
  $self->_set_logger_initialized(1);
  $self->log($self->C_LOG_LOGINIT);
}

#-------------------------------------------------------------------------------
# Create file root logger setup
#
sub _create_file_root_logger
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
  $layout = Log::Log4perl::Layout::PatternLayout->new('%d{HH:mm:ss} %p{1}%m{chomp}%n');
  $self->_set_layout('log.time' => $layout);

  # And a layout for the milliseconds and message
  #
  $layout = Log::Log4perl::Layout::PatternLayout->new('     %d{SSS} %p{1}%m{chomp}%n');
  $self->_set_layout('log.millisec' => $layout);


  # Create root logger for file logging
  #
  my $logger_file = Log::Log4perl->get_logger('' . $self->ROOT_FILE);

  my $appender_attr =
     { name           => '' . $self->ROOT_FILE
     , filename       => $log_file
     , syswrite       => 1
     , mode           => $self->do_append_log ? 'append' : 'write'
     , autoflush      => $self->do_flush_log ? 1 : 0
     };

  my $dispatch_name = 'Log::Dispatch::File';
  if( $self->do_append_log
  and $self->log_file_size > 0
  and $self->nbr_log_files > 0
    )
  {
    $dispatch_name = 'Log::Dispatch::FileRotate';
    $appender_attr->{size} = $self->log_file_size;
    $appender_attr->{max} = $self->nbr_log_files;
  }

  my $appender_file = Log::Log4perl::Appender->new
                      ( $dispatch_name
                      , %$appender_attr
                      );

  $appender_file->layout($self->_get_layout('log.millisec'));
  $logger_file->add_appender($appender_file);
  $logger_file->level($self->_get_log_level_name($self->file_log_level));
}

#-------------------------------------------------------------------------------
# Create stderr root logger setup
#
sub _create_stderr_root_logger
{
  my($self) = @_;

  # Create logger for stderr logging with its own output pattern
  #
  my $layout = Log::Log4perl::Layout::PatternLayout->new('%p{1}%m{chomp}%n');
  $self->_set_layout('log.stderr' => $layout);

  my $logger_stderr = Log::Log4perl->get_logger('' . $self->ROOT_STDERR);

  my $appender_stderr = Log::Log4perl::Appender->new
                        ( "Log::Log4perl::Appender::ScreenColoredLevels"
                        , name          => '' . $self->ROOT_STDERR
                        , stderr        => 1
#                        , layout        => $layout
                        );

  $appender_stderr->layout($layout);
  $logger_stderr->add_appender($appender_stderr);
#  $logger_stderr->level($self->_get_log_level_name($self->stderr_log_level));
#say STDERR 'STDERR: ', $self->stderr_log_level, ' == ', $self->_get_log_level_name($self->stderr_log_level);
#  $logger_stderr->level('TRACE');
}

#-------------------------------------------------------------------------------
# Create first message for logfile. Will also be done when starting a new day.
#
sub _log_data_line
{
  my( $self) = @_;

  return unless $self->_is_logging;

  # For the data line the output is forced.
  #
  $self->_force_log;
  
  # Only log to file needs another pattern layout
  #
  my $logger = Log::Log4perl->get_logger('' . $self->ROOT_FILE);
  my $appender = Log::Log4perl->appenders->{'' . $self->ROOT_FILE};

  # Check if the story at the start needs to be (re)printed
  #
  if( $self->write_start_message )
  {
    $appender->layout($self->_get_layout('log.startmsg'));
    $logger->trace($self->_get_start_msg);
  }

  # Change pattern again to log the date string
  #
  $appender->layout($self->_get_layout('log.date'));
  $logger->trace('undisplayed message');

  # And again to log the message
  #
  $appender->layout($self->_get_layout('log.millisec'));
  $self->_normal_log;
}

#-------------------------------------------------------------------------------
# Create message for logfile to show the time
#
sub _log_time_line
{
  my( $self, $msg, $log_attr) = @_;

  return unless $self->_is_logging;

  # Change pattern again to log the date string
  #
  my $logger = Log::Log4perl->get_logger('' . $self->ROOT_FILE);
  my $appender = Log::Log4perl->appenders->{'' . $self->ROOT_FILE};
  $appender->layout($self->_get_layout('log.time'));

  # Log and change the pattern back.
  #
  $self->_log_message( $msg, $log_attr);
  $appender->layout($self->_get_layout('log.millisec'));
}

#-------------------------------------------------------------------------------
# Log message.
#
sub _log_message
{
  my( $self, $msg, $log_attr) = @_;

  return unless $self->_is_logging;

  # Force the message if needed
  #
  my $force_message = $log_attr->{force_message} // 0;
  $self->_force_log if $force_message;

  # Get the logger and the function name from the error message. Then
  # log the message with that function.
  #
  my $logger_name = '' . $self->ROOT_FILE . "::$log_attr->{package}";
  my $logger = Log::Log4perl->get_logger($logger_name);
  my $l4p_fnc_name = $self->_get_log_level_function_name;
  my $msgTxt = $self->message_wrapping
               ? Text::Wrap::wrap( '', ' ' x 21, $msg)
               : $msg
               ;
  $logger->$l4p_fnc_name($msgTxt);

  # Turn back to normal logging if the message was forced to be printed
  #
  $self->_normal_log if $force_message;

  # Send message to stderr if stderr_log_level is set to the proper level.
  # This logger does not need change of layout patterns like the file logger
  # because date and time is not printed.
  #
  $logger_name = '' . $self->ROOT_STDERR . "::$log_attr->{package}";
  Log::Log4perl->get_logger($logger_name)->$l4p_fnc_name($msg);
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

  return $log_level_name;
}

#-------------------------------------------------------------------------------
#
sub _get_start_msg
{
  my( $self) = @_;

  my $line = '-' x 80;
  return <<EOLEGEND;
$line
Logging format can be one of the following 3 possibilities;
1) date
2) time tag line_number severity_code message
3) msec tag line_number severity_code message

Milliseconds are shown when date and time are not changing between log
entriess

Severity code is a 2 letter code. First is I, W, E, T, D and F for info,
warning, error, trace, debug or fatal respectively. The second letter is
s and f for success or failure respectively.

Uppercase letters s and f mean that the log entry would be forced while
otherwise the setting of loglevel would prevent it.

A tag is a 3 letter code representing the logging module. This must be
set by the module by calling add_tag(). The tag is followed by a four
digit line number.
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
sub wlog
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

  # Create the message for the log
  #
  my( $dateTxt, $timeTxt, $msgTxt) = $self->_create_message( $log_tag, $package);

  $self->_log_data_line if $dateTxt;

  my $log_attr = {package => $package};
  $log_attr->{force_message} = 1 if is_forced($error);

  # Stackdump attached to message when error level is higher than warning
  #
  $msgTxt .= "\n"
           . join( ''
                 , map { ' ' x 13 . "$_\n"}
                       $self->_get_stack($call_level + 1)
                 ) if cmp_levels( $error, $self->M_WARNING) > 0;

  if( $timeTxt and $msgTxt )
  {
    $self->_log_time_line( $msgTxt, $log_attr);
  }

  elsif( $msgTxt )
  {
    $self->_log_message( $msgTxt, $log_attr);
  }

  if(    is_error($error) and $self->die_on_error
      or is_fatal($error) and $self->die_on_fatal
    )
  {
    $self->stop_logging;
    my $app = AppState->instance;
    $app->cleanup;
    die $msgTxt;
  }

  # Return status object if worse than M_INFO
  #
  return cmp_levels( $error, $self->M_INFO) > 0 ? $status : undef;
}

#-------------------------------------------------------------------------------
#
sub _create_message
{
  my( $self, $log_tag, $package) = @_;

  # Keep values between calls
  #
  my $previousMsg = $self->_previousMsg;
  my $previousTime = $self->_previousTime;
  my $previousDate = $self->_previousDate;
  my $pMsgEq = $self->_previousMsgEq;

  # Check the severity of the message set in the mask
  #
  my $sts = $self->_lastError;
  my $severitySymbol = '';

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

  my $msgTxt = sprintf "%s %3.3s %4.4d %s"
             , $severitySymbol
             , $log_tag
             , $sts->get_line
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
    # Only save it when it would be logged otherwise we might still have msec
    # shown in an other second. This can happen when there are messages below
    # the current level which are not logged. We only need to compare with
    # file_log_level() because stderr does not show time/date output.
    #
    my $logger_name = '';
    $logger_name .= $self->ROOT_FILE . "::$package";

#my $lvl_msk = $self->M_LEVELMSK;
#say STDERR sprintf "cmp: %08X <=> %08X = %d"
#  , $error & $lvl_msk
#  , $self->get_log_lvl($logger_name) & $lvl_msk
#  , ($error & $lvl_msk) <=> ($self->get_log_lvl($logger_name) & $lvl_msk)
#  ;

    $previousTime = $timeTxt
       if cmp_levels( $error, $self->get_log_lvl($logger_name)) >= 0;
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
# Logger levels can be set on any level and will default to higher catagories
# when not defined until the root logger is found or a level. 
#
sub get_log_lvl
{
  my( $self, $logger_name) = @_;

  my $log_level;
  while( !defined $log_level )
  {
#say STDERR "GLVL: $logger_name, ll = ", (defined $log_level ? $log_level : 'Not defined' );
    $log_level = $self->_get_log_lvl($logger_name);
    last if $logger_name !~ m/::/;
    $logger_name =~ s/::[^:]+$//;
  }

  # Last try on root logger 
  #
  $log_level = $self->_get_log_lvl($logger_name) unless defined $log_level;
#say STDERR sprintf( "GLVL: $logger_name, ll -> %08X", $log_level);

  return $log_level;
}


#-------------------------------------------------------------------------------
# Return logger name.
#
sub get_logger_name
{
  my( $self, $root_logger) = @_;
  return '' . $root_logger . '::' . (caller(0))[0];
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
