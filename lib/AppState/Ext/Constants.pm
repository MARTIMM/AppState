package AppState::Ext::Constants;

use Modern::Perl;
use version; our $VERSION = version->parse('v0.2.6');
use 5.010001;

use namespace::autoclean;

use Moose;

#-------------------------------------------------------------------------------
# Error codes for Constants module
#
has _code_count =>
    ( is         => 'ro'
    , isa        => 'Num'
    , init_arg   => undef
    , traits     => ['Counter']
    , default    => 1
    , reader     => 'get_code_count'
    , writer     => 'set_code_count'
    , handles    =>
      { _code_increment  => 'inc'
      , code_reset       => 'reset'
      }
    );

#-------------------------------------------------------------------------------
# Log mask values.
#
my %_c_Attr = (is => 'ro', init_arg => undef, lazy => 1);

# Mask is formatted like so
#
has M_ALL       => ( default => 0xFFFFFFFF, %_c_Attr);
has M_NONE      => ( default => 0x00000000, %_c_Attr);

has M_EVNTCODE  => ( default => 0x000000FF, %_c_Attr); # 255 codes/module (no 0)
has M_SEVERITY  => ( default => 0xFFF00000, %_c_Attr); # 12 bits for severity
has M_OLD_MASK  => ( default => 0xF0000000, %_c_Attr); 
has M_OK_MASK   => ( default => 0x0F000000, %_c_Attr); 
has M_L4P_MASK  => ( default => 0x00F00000, %_c_Attr); 
has M_MSGMASK   => ( default => 0xFFF000FF, %_c_Attr); # Severity and code
has M_RESERVED  => ( default => 0x000FFF00, %_c_Attr); # Reserved

# Severity codes are bitmasks
#
has M_SUCCESS   => ( default => 0x01000000, %_c_Attr);
has M_FAIL      => ( default => 0x02000000, %_c_Attr);
has M_FORCED    => ( default => 0x04000000, %_c_Attr);  # Force logging

has M_INFO      => ( default => 0x11000000, %_c_Attr);  # is success
has M_WARNING   => ( default => 0x20000000, %_c_Attr);  # no success/fail
has M_ERROR     => ( default => 0x42000000, %_c_Attr);  # is fail

has M_L4P_TRACE => ( default => 0x01100000, %_c_Attr);  # Log4perl codes
has M_L4P_DEBUG => ( default => 0x01200000, %_c_Attr);
has M_L4P_INFO  => ( default => 0x11000000, %_c_Attr);  # same as M_INFO
has M_L4P_WARN  => ( default => 0x20000000, %_c_Attr);  # same as M_WARNING
has M_L4P_ERROR => ( default => 0x42000000, %_c_Attr);  # same as M_ERROR
has M_L4P_FATAL => ( default => 0x02400000, %_c_Attr);

# Following are combinations with FORCED -> log always when log is opened
#
has M_F_INFO    => ( default => 0x15000000, %_c_Attr);
has M_F_WARNING => ( default => 0x24000000, %_c_Attr);
has M_F_ERROR   => ( default => 0x46000000, %_c_Attr);

#-------------------------------------------------------------------------------
# POSIX IPC constants
#
#From bits/msq.h
#define MSG_NOERROR     010000  /* no error if message is too big */
has MSG_NOERROR => ( default => oct(10000), %_c_Attr);

#-------------------------------------------------------------------------------
# AppState::Process
#
has C_MSG_WAIT          => ( default => 0, %_c_Attr);
has C_MSG_NOWAIT        => ( default => 1, %_c_Attr);

#-------------------------------------------------------------------------------
# Error codes for Constants module
#
has C_CONST0    => ( default => 1 | 0x40000000 | 0x02000000, %_c_Attr);
has C_MODIMMUT  => ( default => 2 | 0x40000000 | 0x02000000, %_c_Attr);

#-------------------------------------------------------------------------------
# Do not make a BUILD subroutine because of init sequence and has no further
# use.
#
#sub BUILD {}

#-------------------------------------------------------------------------------
# Make a Moose constant in the callers namespace. First strip down some of
# the stack because Moose can insert extra steps before reaching this call.
# This has something to do with the 'extends' keyword of Moose and other Build
# operations. The calculated default can be anything but zero. When zero, the
# constant is not created.
#
sub const       ## no critic (RequireArgUnpacking)
{
  # Stack must be searched first
  #
  my $stackPtr = 0;
  while( ref $_[$stackPtr] eq 'Moose::Meta::Class'
      or ref $_[$stackPtr] eq 'Class::MOP::Class::Immutable::Moose::Meta::Class'
       )
  {
    $stackPtr++ ;
  }

  # Get the rest from the stack
  #
  my( $mutatable, $name, @modifiers) = @_[$stackPtr..$#_];
  my $const_code = $mutatable->get_code_count;
  $mutatable->_code_increment;

#say "MM: ", ref $mutatable
#  , ", ", ($mutatable->meta->is_mutable ? 'RW' : 'RO')
#  , ", $name = $const_code";

  # Check if caller class is mutable, if so add the constant.
  #
  my $meta = $mutatable->meta;
  if( $meta->is_mutable )
  {
    $const_code //= 0;

    $const_code |= $mutatable->M_SEVERITY & $mutatable->$_
      for (@modifiers);

    if( $const_code )
    {
      $meta->add_attribute( $name, default => $const_code
                          , init_arg => undef, lazy => 1
                          , is => 'ro'
                          );
    }

    else
    {
      $mutatable->wlog( "Default is 0, no constant created"
                      , $mutatable->C_CONST0
                      );
    }
  }

  else
  {
    $mutatable->wlog( "Module is immutable", $mutatable->C_MODIMMUT);
  }

  return;
}

#-------------------------------------------------------------------------------
#
sub log_init
{
  my( $self, $prefix, $call_level) = @_;

  $call_level //= 0;

  my( $package, $f, $l) = caller($call_level);

  # We don't want to fire up a log object. Just check if one is already there
  # and if not, add a subscriber to the event that the log object will be
  # created by the plugin manager.
  #
  my $app = AppState->instance;
  my $log = $app->check_plugin('Log');
#say "Set $package($prefix) how ? ", (ref $log ? 'direct' : 'by subscription');

  if( ref $log eq 'AppState::Plugins::Feature::Log' )
  {
#say "Set direct: $package = ", ($log->hasLogTag($package) ? 'Y' : 'N');
    $log->add_tag( $prefix, $call_level + 1)
      unless $log->hasLogTag($package);
  }

  else
  {
    $app->add_subscriber
          ( 'AppState::Plugins::Feature::Log'
          , sub
            { my( $observed, $event, %parameters) = @_;
              my $log = $parameters{object};
              $log->add_tag( $prefix, 0, $package);
#say "Set by subscription: $prefix, $package";
            }
          );
  }

  return;
}

#-------------------------------------------------------------------------------
# Only write to the log file when there is already a log object created by
# the user. There may be only 2 arguments.
#
sub wlog
{
  my( $self, $messages, $msg_log_mask, $call_level) = @_;

  $call_level //= 0;

  my $app = AppState->instance;
  my $log = $app->check_plugin('Log');

  $log->write_log( $messages, $msg_log_mask, $call_level + 1)
    if ref $log eq 'AppState::Plugins::Feature::Log';

  return;
}

#-------------------------------------------------------------------------------
# Cleanup and leave
#
sub leave
{
  my( $self, $exit_value) = @_;

  my $app = AppState->instance;
  $app->cleanup;

  $exit_value //= 0;
  exit($exit_value);
}

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;

1;

__END__
