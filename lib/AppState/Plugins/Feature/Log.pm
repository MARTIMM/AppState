package AppState::Plugins::Feature::Log;

use Modern::Perl '2010';
use 5.010001;
use version; our $VERSION = '' . version->parse("v0.2.11");

use namespace::autoclean;

use Moose;
use MooseX::NonMoose;
extends qw( Class::Publisher AppState::Ext::Constants);

use DateTime;
require File::Basename;
use IO::Handle;
use AppState;

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
      { nbrLogTags      => 'count'
      , getLogTag       => 'get'
      , _setLogTag      => 'set'
      , hasLogTag       => 'defined'
      , getLogTags      => 'keys'
      , getTagLabels    => 'values'
#      , tagExists      => 'exists'
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
    , default           => sub { return $_[0]->M_SEVERITY; }
#    , default          => sub { return $_[0]->M_ERROR; }
    , trigger           =>
      sub
      {
        my( $self, $n, $o) = @_;

        $o //= $self->M_SEVERITY;
        return if $n == $o;
        $self->write_log( "Log bitmask changed from"
                        . sprintf( ' 0x%08X into 0x%08X', $o, $n)
                        , $self->C_LOG_BMCHANGED
                        );
      }
    );

has die_on_error =>
    ( is                => 'rw'
    , isa               => 'Bool'
    , default           => 0
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

# When the logfile is opened, save the handle here
#
has _logFileHandle =>
    ( is                => 'rw'
    , predicate         => 'isLogFileOpen'
    , clearer           => '_clearHandle'
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
        return unless $self->isLogFileOpen;

        if( $n )
        {
#         my $o = select($self->_logFileHandle);
#         $|++;
#         select($o);
          $self->_logFileHandle->autoflush(1);
          $self->write_log( "Autoflush turned on", $self->C_LOG_AUTOFLUSHON);
        }

        else
        {
#         my $o = select($self->_logFileHandle);
#         select($self->_logFileHandle);
#         $|--;
#         select($o);
          $self->_logFileHandle->autoflush(0);
          $self->write_log( "Autoflush turned off", $self->C_LOG_AUTOFLUSHOFF);
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

# Questions:
#  - How long has it been that the error was logged?
#  - When there are two of the same, how to process?
#
has _lastError =>
    ( is                => 'rw'
    , isa               => 'HashRef'
#    , writer           => '_lastError'
    , default           => sub {return {};}
    , init_arg          => undef
    , traits            => ['Hash']
    , handles           =>
      { clearLastError  => 'clear'
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
    $self->code_reset;
    $self->const( 'C_LOG_AUTOFLUSHON'   , qw(M_SUCCESS M_F_INFO));
    $self->const( 'C_LOG_AUTOFLUSHOFF'  , qw(M_SUCCESS M_F_INFO));
    $self->const( 'C_LOG_LOGOPENED'     , qw(M_SUCCESS M_F_INFO));
    $self->const( 'C_LOG_LOGCLOSED'     , qw(M_SUCCESS M_F_INFO));
    $self->const( 'C_LOG_TAGLBLINUSE'   , qw(M_F_WARNING));
    $self->const( 'C_LOG_TAGALRDYSET'   , qw(M_F_WARNING));
    $self->const( 'C_LOG_BMCHANGED'     , qw(M_SUCCESS M_F_INFO));
    $self->const( 'C_LOG_TAGADDED'      , qw(M_SUCCESS M_INFO));
#    $self->const( 'C_LOG_', 9, qw());

    # Constant codes
    #
#    $self->const( 'C_LOG_'     , 1);

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
# Can hand over your own file handle e.g. $l->start_logging(*STDERR);
#
sub start_logging
{
  my( $self, $LOG) = @_;

  # If logfile is open then no work is to be done
  #
  return if $self->isLogFileOpen;

  # Reset some values used in write_log()
  #
  $self->_previousMsg('');
  $self->_previousDate('');
  $self->_previousTime('');
  $self->_previousMsgEq(0);

  # Check if user has a IO handler of his own. Use that instead.
  if( defined $LOG )
  {
    $self->_logFileHandle($LOG);
  }

  # Otherwise open a file for logging.
  #
  else
  {
    $LOG = $self->_openLogFile;
  }

  # Write first entry to log file
  #
#  my $date = DateTime->now(time_zone => 'Europe/Amsterdam');

#  say $LOG "\n", '-' x 80;
#  say $LOG $date->ymd, '  I - Info, W - Warning, E - Error, F - Forced';
#  say $LOG $self->_show_start($date->ymd);

  my $flushState;
  if( $self->do_flush_log )
  {
    my $o = select($LOG);
    $|++;
    select($o);
    $flushState = "Autoflush is turned on";
  }

  else
  {
    $flushState = "Autoflush is turned off";
  }

  $self->write_log( sprintf( "Logfile opened. Log bitmask set to 0x%08X'."
                       . " $flushState. %s"
                       , $self->log_mask
                       , ( $self->do_append_log
                         ? "Appending to old log" : "Starting new log"
                         )
                       )
              , $self->C_LOG_LOGOPENED
              );
}

#-------------------------------------------------------------------------------
# Open the logfile
#
sub _openLogFile
{
  my($self) = @_;

  # Get config directory and make path to logfile
  #
  my $config_dir = AppState->instance->config_dir;
  my $log_file = $config_dir . '/' . $self->log_file;

  # Check if log must be appended (>>) or writen from top (>)
  #
  my $appendSymbols = '>';
  $appendSymbols = '>>' if $self->do_append_log;

  my $LOG;
  open( $LOG, $appendSymbols, $log_file);
  $self->_logFileHandle($LOG);

  return $LOG;
}

#-------------------------------------------------------------------------------
# Stop logging to the file.
#
sub stop_logging
{
  my($self) = @_;

  return unless $self->isLogFileOpen;

  $self->write_log( "Logfile closed\n", $self->C_LOG_LOGCLOSED);

  my $log = $self->_logFileHandle;
  close $log;

  $self->_clearHandle;

  # From now append to the log when again startlogging is called
  #
#  $self->append;
}

#-------------------------------------------------------------------------------
# Write message to log.
#
sub write_log
{
  my( $self, $messages, $error, $call_level) = @_;

  # Check if message mask has a proper error.
  #
  return unless $error & $self->M_MSGMASK;

  # Store error and message
  #
  $self->_lastError
         ( { message    => ref $messages eq 'ARRAY'
                           ? join( ' ', @$messages)
                           : $messages
           , error      => $error
           , severity   => $error & $self->M_SEVERITY
           , eventCode  => $error & $self->M_EVNTCODE
           , forced     => $error & $self->M_FORCED     ? 1 : 0
           , fail       => $error & $self->M_FAIL       ? 1 : 0
           , success    => $error & $self->M_SUCCESS    ? 1 : 0
           }
         );

  $self->_lastError->{success} = 0 if $self->_lastError->{fail};

  # Get the line number from where the call to write_log() was made. Default
  # caller stack level is 0. Get the log_tag when the call level packagename
  # is found. Save the log_tag in the lastError.
  #
  $call_level //= 0;
  my( $package, $f, $l) = caller($call_level);
  my $log_tag = $self->getLogTag($package);
  $log_tag //= '';
  $log_tag = substr( "$log_tag---", 0, 3);
  $self->_lastError->{senderTag} = $log_tag;
  $self->_lastError->{senderLineNo} = $l;
  $self->_lastError->{senderFile} = $f;
  $self->_lastError->{senderPackage} = $package;

  # Notify users when something is logged
  #
  $self->notify_subscribers( $log_tag, $self->get_last_error);

  # Return if there is no message or if the logfile has not been opened.
  #
  return unless $self->_lastError->{message}
            and $self->isLogFileOpen
            ;

  # Check if log_mask is set in such a way that the severity bits from the
  # message log mask are not filtered or that the forced bit in the message log
  # mask is turned on.
  #
  my $severity = $self->get_last_severity;
  return unless $self->log_mask & $severity      # Filter log mask on severity
             or $self->is_last_forced             # or forced bit turned on
             ;

  # Create the message for the log
  #
  my( $dateTxt, $timeTxt, $msgTxt) =
     $self->_create_message($call_level + 1);

  if( $self->_logFileHandle )
  {
    say {$self->_logFileHandle} $self->_show_start($dateTxt) if $dateTxt;
    say {$self->_logFileHandle} "\n$timeTxt\n--------" if $timeTxt;
    say {$self->_logFileHandle} Text::Wrap::wrap( '', ' ' x 12, $msgTxt) if $msgTxt;

    print {$self->_logFileHandle} map {' ' x 12 . $_ . "\n"} $self->_get_stack($call_level + 1)
       if $severity == $self->M_ERROR or $severity == $self->M_WARNING;
  }

  if( ($severity & $self->M_ERROR) and $self->die_on_error )
  {
    $self->stop_logging;
    say STDERR Text::Wrap::wrap( '', ' ' x 12, $msgTxt);
    print STDERR map {' ' x 4 . $_ . "\n"} $self->_get_stack($call_level + 1);
    exit(1);
  }

  elsif( ($severity & $self->M_ERROR) and $self->show_on_error )
  {
    say STDERR Text::Wrap::wrap( '', ' ' x 12, $msgTxt);
    print STDERR map {' ' x 4 . $_ . "\n"} $self->_get_stack($call_level + 1);
  }

  elsif( ($severity & $self->M_WARNING) and $self->show_on_warning )
  {
    say STDERR Text::Wrap::wrap( '', ' ' x 12, $msgTxt);
    print STDERR map {' ' x 4 . $_ . "\n"} $self->_get_stack($call_level + 1);
  }
}

#-------------------------------------------------------------------------------
#
sub _create_message
{
  my( $self, $call_level) = @_;

  # Keep values between calls
  #
  my $previousMsg = $self->_previousMsg;
  my $previousTime = $self->_previousTime;
  my $previousDate = $self->_previousDate;
  my $pMsgEq = $self->_previousMsgEq;

  my $eventCode = $self->get_last_eventcode;
  my $severity = $self->get_last_severity;

  # Check the severity of the message set in the mask
  #
  my $severitySymbol = '-';
  $severitySymbol = 'i' if $severity & $self->M_INFO;
  $severitySymbol = 'w' if $severity & $self->M_WARNING;
  $severitySymbol = 'e' if $severity & $self->M_ERROR;

  my $sts = '-';
  $sts = 's' if $severity & $self->M_SUCCESS;
  $sts = 'f' if $severity & $self->M_FAIL;

  $severitySymbol .= $sts;

  # If the messages should have been filtered, the forced bit should have
  # been set if we ended up here
  #
  $severitySymbol = uc($severitySymbol) unless $self->log_mask & $severity;

  my $msgTxt = sprintf "%3.3s %4.4d %2.2s %s"
             , $self->_lastError->{senderTag}
             , $self->get_sender_line_no
             , $severitySymbol
             , $self->_lastError->{message}
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



  my $date = DateTime->now(time_zone => 'Europe/Amsterdam');
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
sub _show_start
{
  my( $self, $dateTxt) = @_;

  my $line = '-' x 80;
  return "\n$line\n$dateTxt"
       . "  iI - Info, wW - Warning, eE - Error (Uppercase is forced)\n"
       . "            sS - Success, fF - Fail (Uppercase is forced)\n"
       . "            - - Unknown severity or state";
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
    my $log_tag = $self->getLogTag($package);
    $log_tag //= '---';
    push @stack, sprintf( "%5d %s", $l, $package);
  }

  return ("Stack;", @stack);
}

#-------------------------------------------------------------------------------
# Info from last message stored in write_log()
#
sub is_last_success     { return $_[0]->_lastError->{success}; }
sub is_last_fail        { return $_[0]->_lastError->{fail}; }
sub is_last_forced      { return $_[0]->_lastError->{forced}; }
sub get_last_message    { return $_[0]->_lastError->{message}; }
sub get_last_error      { return $_[0]->_lastError->{error}; }
sub get_last_severity   { return $_[0]->_lastError->{severity}; }
sub get_last_eventcode  { return $_[0]->_lastError->{eventCode}; }
sub get_sender_tag      { return $_[0]->_lastError->{senderTag}; }
sub get_sender_line_no  { return $_[0]->_lastError->{senderLineNo}; }
sub get_sender_file     { return $_[0]->_lastError->{senderFile}; }
sub get_sender_package  { return $_[0]->_lastError->{senderPackage}; }

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

#say "Ltgs: $call_level, $log_tag => "
#  , join( ', ', map { $self->getLogTag($_)} $self->getLogTags);

  my $tagLabels = join( '|', $self->getTagLabels);
  if( $log_tag =~ m/^($tagLabels)$/ )
  {
#say "Tag in tag list";
    $self->write_log( "Tag label '$log_tag' already in use"
                    , $self->C_LOG_TAGLBLINUSE
                    );
  }

  elsif( !$self->hasLogTag($package) )
  {
    $log_tag = substr( $log_tag, 0, 3);
#say "Tag $log_tag set for $package";
    $self->_setLogTag( $package => $log_tag);
    $self->write_log( "Tag '$log_tag' added for module '$package'", $self->C_LOG_TAGADDED);
  }

  else
  {
#say "$package has tag";
    $self->write_log( "Package '$package' already has a tag '"
                    . $self->getLogTag($package)
                    . "'"
                    , $self->C_LOG_TAGALRDYSET
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
