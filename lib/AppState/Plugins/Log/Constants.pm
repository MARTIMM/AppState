package AppState::Plugins::Log::Constants;

use Modern::Perl;
use version; our $VERSION = version->parse('v0.2.8');
use 5.010001;

use namespace::autoclean;
require Scalar::Util;
use Moose;

#-------------------------------------------------------------------------------
# Error codes for Constants module
#
has _code_count =>
    ( is         => 'ro'
    , isa        => 'Num'
    , init_arg   => undef
    , traits     => ['Counter']
    , default    => 10
    , reader     => '_get_code_count'
#    , writer     => '_set_code_count'
    , handles    =>
      { _code_increment => 'inc'
#      , _code_reset     => 'reset'
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

has M_EVNTCODE  => ( default => 0x000007FF, %_c_Attr); # 2046 codes (no 0)
has M_SEVERITY  => ( default => 0xFFFE0000, %_c_Attr); # 12 bits for severity
has M_MSGMASK   => ( default => 0xFFFE07FF, %_c_Attr); # Severity and code
has M_NOTMSFF   => ( default => 0x0FF00000, %_c_Attr); # Not Success failed etc
has M_ISMSFF    => ( default => 0xF0000000, %_c_Attr); # Is Success failed etc
has M_LEVELMSK  => ( default => 0x000E0000, %_c_Attr); # Level count field

has M_RESERVED  => ( default => 0x0001F800, %_c_Attr); # Reserved

# Severity codes are bitmasks
#
has M_SUCCESS   => ( default => 0x10000000, %_c_Attr);
has M_FAIL      => ( default => 0x20000000, %_c_Attr);
has M_CODE      => ( default => 0x80000000, %_c_Attr);  # Used to define codes

has M_TRACE     => ( default => 0x10120000, %_c_Attr);  # is success
has M_DEBUG     => ( default => 0x10240000, %_c_Attr);
has M_INFO      => ( default => 0x11060000, %_c_Attr);
has M_WARN      => ( default => 0x02080000, %_c_Attr);  # no success/fail
has M_WARNING   => ( default => 0x02080000, %_c_Attr);  # same as M_WARNING
has M_ERROR     => ( default => 0x240A0000, %_c_Attr);  # is fail
has M_FATAL     => ( default => 0x204C0000, %_c_Attr);

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
# 0x204C0000 == M_FATAL
has C_MODIMMUT  =>
    ( default => Scalar::Util::dualvar( 1 | 0x604C0000, 'Module is immutable')
    , %_c_Attr
    );

# Convenience codes C_LOG_TRACE and C_LOG_DEBUG
#
# 0x1012000 == M_TRACE
has C_LOG_TRACE =>
    ( default => Scalar::Util::dualvar( 2 | 0x10120000, 'TRACE - %s')
    , %_c_Attr
    );

# 0x10240000 == M_DEBUG
has C_LOG_DEBUG =>
    ( default => Scalar::Util::dualvar( 3 | 0x10240000, 'DEBUG - %s')
    , %_c_Attr
    );

# 0x11060000 == M_INFO
has C_LOG_INFO =>
    ( default => Scalar::Util::dualvar( 4 | 0x11060000, 'INFO - %s')
    , %_c_Attr
    );
#
# !! Error start count at 10. increase when codes here gets there. !!
#

#-------------------------------------------------------------------------------
# Do not make a BUILD subroutine because of init sequence and has no further
# use.
#
#sub BUILD
#{
#  say "Cnst: " . __PACKAGE__, join( ', ', caller());
#}

#-------------------------------------------------------------------------------
# Make a Moose constant in the callers namespace. First strip down some of
# the stack because Moose can insert extra steps before reaching this call.
# This has something to do with the 'extends' keyword of Moose and other Build
# operations. The calculated default can be anything but zero. When zero, the
# constant is not created.
#
# Obsolete
sub XXdef_sts       ## no critic (RequireArgUnpacking)
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
  my( $self, $name, $modifier, $message) = @_[$stackPtr..$#_];
  my $const_code = $self->_get_code_count;
  $self->_code_increment;

#say "MM: ", ref $self
#  , ", ", ($self->meta->is_mutable ? 'RW' : 'RO')
#  , ", $name = $const_code";

  # Check if caller class is mutable, if so add the constant.
  #
  my $meta = $self->meta;
  if( $meta->is_mutable )
  {
    # 1) Make sure that message is defined
    # 2) Make sure that users error code is not larger than allowed.
    # 3) Make sure that the users severity code is not larger than allowed.
    #
    $message //= '';
    $const_code = $self->M_EVNTCODE & $const_code;
    $const_code |= $self->M_SEVERITY & $self->$modifier;

    # Make the code for the user. It boils down to moose's
    # has $name => ( default => ..., ...);
    # The result is not overwritable, not settable when initializing the
    # callers module and is lazy so only comes into view when using. The
    # value of the variable is a dualvar holding a constant and its message.
    #
    if( $const_code )
    {
      $meta->add_attribute
             ( $name
             , default => Scalar::Util::dualvar( $const_code, $message)
             , init_arg => undef
             , lazy => 1
             , is => 'ro'
             , isa => 'Any'
             );
    }
  }

  else
  {
    $self->log($self->C_MODIMMUT);
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

  if( ref $log eq 'AppState::Plugins::Log' )
  {
    # Only add a tag when packagae doesn't have any
    #
    $log->add_tag( $prefix, $call_level + 1) unless $log->has_log_tag($package);
  }

  else
  {
    $app->add_subscriber
    ( 'AppState::Plugins::Log'
    , sub
      { my( $observed, $event, %parameters) = @_;
        my $log = $parameters{object};

        # Only add a tag when packagae doesn't have any
        #
        $log->add_tag( $prefix, 0, $package) unless $log->get_log_tag($package);
      }
    );
  }

  return;
}

#-------------------------------------------------------------------------------
# Only write to the log file when there is already a log object created by
# the user. There may be only 2 arguments.
#
sub XXX_log
{
  my( $self, $messages, $error_code, $call_level) = @_;

  $call_level //= 0;
  my $sts = 0;

  my $app = AppState->instance;
  my $log = $app->check_plugin('Log');

  $sts = $log->write_log( $messages, $error_code, $call_level + 1)
    if ref $log eq 'AppState::Plugins::Log';

  return $sts;
}

#-------------------------------------------------------------------------------
# Only write to the log file when there is already a log object created by
# the user. There may be only 2 arguments.
#
sub log
{
  my( $self, $error_code, $msg_values, $call_level) = @_;

  $call_level //= 0;
  my $sts = 0;

  # It is possible that the log module is not yet instantiated. When $log = 1
  # the module exists but there is no object (yet)
  #
  my $app = AppState->instance;
  my $log = $app->check_plugin('Log');
  $sts = $log->wlog( $error_code, $msg_values, $call_level + 1) if ref $log;

  return $sts;
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
