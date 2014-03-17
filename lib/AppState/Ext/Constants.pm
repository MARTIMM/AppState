package AppState::Ext::Constants;

use Modern::Perl;
use version; our $VERSION = version->parse("v0.2.6");
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
has M_SEVERITY  => ( default => 0xFF000000, %_c_Attr); # 8 bits for severity
has M_MSGMASK   => ( default => 0xFF0000FF, %_c_Attr); # Severity and code
has M_RESERVED  => ( default => 0x00FFFF00, %_c_Attr); # Reserved

# Severity codes are bitmasks
#
has M_SUCCESS   => ( default => 0x01000000, %_c_Attr);
has M_FAIL      => ( default => 0x02000000, %_c_Attr);

has M_INFO      => ( default => 0x10000000, %_c_Attr);
has M_WARNING   => ( default => 0x20000000, %_c_Attr);
has M_ERROR     => ( default => 0x40000000, %_c_Attr);
has M_FORCED    => ( default => 0x80000000, %_c_Attr);  # Force logging

# Following are combinations with FORCED -> log always when log is opened
#
has M_F_INFO    => ( default => 0x90000000, %_c_Attr);
has M_F_WARNING => ( default => 0xA0000000, %_c_Attr);
has M_F_ERROR   => ( default => 0xB0000000, %_c_Attr);

#-------------------------------------------------------------------------------
# POSIX IPC constants
#
#From bits/msq.h
#define MSG_NOERROR     010000  /* no error if message is too big */
has MSG_NOERROR => ( default => oct(10000), %_c_Attr);

#-------------------------------------------------------------------------------
# ConfigFile
#
#has C_CFF_CONFIGDIR    => ( default => 0, %_c_Attr);
#has C_CFF_WORKDIR      => ( default => 1, %_c_Attr);
#has C_CFF_FILEPATH     => ( default => 2, %_c_Attr);
#has C_CFF_TEMPDIR      => ( default => 3, %_c_Attr);

#has C_CFF_NORESETCFG   => ( default => 0, %_c_Attr);
#has C_CFF_RESETCFG     => ( default => 1, %_c_Attr);

#-------------------------------------------------------------------------------
# AppState::Process
#
has C_MSG_WAIT          => ( default => 0, %_c_Attr);
has C_MSG_NOWAIT        => ( default => 1, %_c_Attr);

#has C_PRC_SRVROK        => ( default => 2, %_c_Attr);
#has C_PRC_SRVRNOK       => ( default => 3, %_c_Attr);
#has C_PRC_SRVRASTRTD    => ( default => 4, %_c_Attr);

#-------------------------------------------------------------------------------
# AppState::PluginManager
#
#has C_PLG_NOCREATE     => ( default => 0, %_c_Attr);
#has C_PLG_CREATEIF     => ( default => 1, %_c_Attr);
#has C_PLG_CREATEALW    => ( default => 2, %_c_Attr);

#-------------------------------------------------------------------------------
# AppState::NodeTree
#
#has C_NT_DEPTHFIRST1            => ( default => 0, %_c_Attr);
#has C_NT_DEPTHFIRST2            => ( default => 1, %_c_Attr);
#has C_NT_BREADTHFIRST1          => ( default => 2, %_c_Attr);
#has C_NT_BREADTHFIRST2          => ( default => 3, %_c_Attr);

#has C_NT_NODEMODULE             => ( default => 4, %_c_Attr);
#has C_NT_VALUEDMODULE           => ( default => 5, %_c_Attr);
#has C_NT_ATTRIBUTEMODULE        => ( default => 6, %_c_Attr);

#has C_NT_CMP_NAME              => ( default => 7, %_c_Attr);
#has C_NT_CMP_ATTR              => ( default => 8, %_c_Attr);
#has C_NT_CMP_DATA              => ( default => 9, %_c_Attr);
#has C_NT_CMP_PATH              => ( default => 10, %_c_Attr);

#has C_NT_TYPE_DOCUMENT         => ( default => 11, %_c_Attr);
#has C_NT_TYPE_ELEMENT          => ( default => 12, %_c_Attr);
#has C_NT_TYPE_ATTRIBUTE                => ( default => 13, %_c_Attr);
#has C_NT_TYPE_VALUE            => ( default => 14, %_c_Attr);



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
      $mutatable->_log( "Default is 0, no constant created"
                      , $mutatable->C_CONST0
                      );
    }
  }

  else
  {
    $mutatable->_log( "Module is immutable", $mutatable->C_MODIMMUT);
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
sub _log
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
  my $app = AppState->instance;
  $app->cleanup;
  exit(0);
}

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;

1;

__END__
