#-------------------------------------------------------------------------------
# Module to interact on process level. This means that it can help to daemonize
# the calling process, or to find out if there is a server, to kill that server
# etc. The server process id will be stored in a file in the config directory
# maintained by AppState. Furthermore some interprocess communication is
# possible by using a message queue.
#-------------------------------------------------------------------------------
package AppState::Plugins::Feature::Process;

use Modern::Perl;
use version; our $VERSION = qv('v0.1.8');
use 5.010001;

use namespace::autoclean;

use Moose;
extends qw(AppState::Ext::Constants);

use AppState;
use AppState::Plugins::Feature::PluginManager;
require POSIX;
require IPC::Msg;
require Digest::MD5;
require Proc::ProcessTable;

use AppState::Ext::Meta_Constants;

#-------------------------------------------------------------------------------
# Error codes
#
const( 'C_PRC_PIDFILEREMOVED',  'M_INFO', 'Pid file %s removed');
const( 'C_PRC_CLEANCOMM',       'M_INFO', 'Cleanup communication');
const( 'C_PRC_PIDFILECREATED',  'M_INFO', 'Pid file %s created for server with pid %s');
const( 'C_PRC_PARENTSTOPPED',   'M_INFO', 'Parent process stopped');
const( 'C_PRC_SERVERSTARTED',   'M_INFO', 'Server process started with pid %s');
const( 'C_PRC_SIGNALSENT',      'M_INFO', 'Sent signal to server');
const( 'C_PRC_SERVERINTERRUPT', 'M_F_WARNING', 'Server interrupted');
const( 'C_PRC_PIDOK',           'M_INFO', 'Pid %s checked and is ok');
const( 'C_PRC_PIDNOTFOUND',     'M_F_WARNING', 'Pid %s checked but not found');
const( 'C_PRC_RECEIVE',         'M_INFO', 'Receive using %s type config');
const( 'C_PRC_NOPLUGIN',        'M_ERROR', 'Method %s plugin not loaded for receiving');

# Server status codes
#
const( 'C_PRC_SRVROK',          'M_CODE', 'Server started ok');
const( 'C_PRC_SRVRASTRTD',      'M_CODE', 'Server already started');


#-------------------------------------------------------------------------------

has pid_file =>
    ( is                => 'ro'
    , isa               => 'Str'
    , default           =>
      sub
      { my $basename = File::Basename::fileparse( $0, qr/\.[^.]*/);
        return "$basename.pid";
      }
    );

has cmm_type =>
    ( is                => 'rw'
    , isa               => 'Str'
    , default           => 'MsgQueue'
    );

has _plugin_manager =>
    ( is                => 'ro'
    , isa               => 'AppState::Plugins::Feature::PluginManager'
    , init_arg          => undef
    , default           =>
      sub
      {
        # Don't use "AppState->instance->getAppObj('PluginManager');" because
        # this will interfere wis the users plugin managers if used.
        # Get the path to the base module AppState.
        #
        my $pm = AppState::Plugins::Feature::PluginManager->new;
        my $path = Cwd::realpath($INC{"AppState.pm"});
        $path =~ s@/AppState.pm@@;

        # Search for any modules
        #
        $pm->search_plugins( { base => $path
                             , max_depth => 3
                             , search_regex => qr@/AppState/Process/[A-Z][\w]+.pm$@
                             , api_test => [ qw( send receive)]
                             }
                           );
#$pm->list_plugin_names;

        return $pm;
      }
    );

# AppState object to get some general information from and to get to
# other modules.
#
#has appStateObj =>
#    ( is               => 'ro'
#    , isa              => 'AppState'
#    , init_arg         => 'appState'
#    , clearer          => '_clearAppState'
#    );

#--[ Client ]-------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;
  $self->log_init('PRC');
}

#--[ Any ]----------------------------------------------------------------------
# Cleanup
#
sub plugin_cleanup
{
  my($self) = @_;

  # Check if server runs and if this process's id is the same as the
  # one returned by the check_server function.
  #
  my $pidServer = $self->check_server;
  if( $$ == $pidServer )
  {
    my $config_dir = AppState->instance->config_dir;
    my $pid_file = $config_dir . '/' . $self->pid_file;
    unlink $pid_file;
    $self->log( $self->C_PRC_PIDFILEREMOVED, [$self->pid_file]);

    # Remove communication only when server stops. The program needs to cleanup
    # its own used plugins.
    #
    $self->log($self->C_PRC_CLEANCOMM);
    $self->_plugin_manager->cleanup;
  }
}

#--[ Client ]-------------------------------------------------------------------
# Start as a server
#
sub start_server
{
  my($self) = @_;

  # Check if server exists we don't need a second one
  #
  return $self->C_PRC_SRVRASTRTD if $self->check_server;

  my $config_dir = AppState->instance->config_dir;
  my $pid_file = $config_dir . '/' . $self->pid_file;

  # First do fork.
  # If $pid is set then the process is the parent process and we need to exit
  # but before the process exits it stores the pid in a file. Otherwise we are
  # the child process and do the work.
  #
  my $pid = fork;
  if( defined $pid and $pid )
  {
    open( PIDF, "> $pid_file");
    print PIDF "$pid\n";
    close(PIDF);

    # Log messsage in client log
    #
    $self->log( $self->C_PRC_PIDFILECREATED, [ $self->pid_file, $pid]);

    # Get a new log file for server log
    #
    my $log = AppState->instance->checkAppPlugin('Log');
    if( ref $log eq 'AppState::Plugins::Feature::Log' )
    {
      $log->log($self->C_PRC_PARENTSTOPPED);
      $log->stop_logging;
    }

    exit(0);
  }

  # Change the name of the logfile to prevent clashes with the clients logfile
  #
  my $log = AppState->instance->checkAppPlugin('Log');
  if( ref $log eq 'AppState::Plugins::Feature::Log' )
  {
    $log->stop_logging;
    my $logfile = $log->log_file;
    $logfile =~ s/(\.log)$/-server.log/;
    $log->log_file($logfile);
    $log->start_logging;
  }

  # Then setsid to ensure that you aren't a process
  # group leader (the setsid() will fail if you are).
  #
  POSIX::setsid() or die "Can't start a new session: $!";

  # Setup log to logfile
  #
  $self->log( $self->C_PRC_SERVERSTARTED, [$$]);

  # Setup kill signals TERM and INT to call stop_server()
  #
  $SIG{TERM} = sub { $self->stop_server; };
  $SIG{INT} = sub { $self->stop_server; };

  return $self->C_PRC_SRVROK;
}

#--[ Client ]-------------------------------------------------------------------
# Kill server process. Is called from non-server process.
#
sub kill_server
{
  my($self) = @_;

  my $pid = $self->check_server;
  kill 'TERM', $pid if $pid;
  $self->log($self->C_PRC_SIGNALSENT);
}

#--[ Server ]-------------------------------------------------------------------
# End of the spiderServer. This function is triggerd after a TERM or INT signal.
#
sub stop_server
{
  my($self) = @_;

  # Kill this server
  #
  $self->log($self->C_PRC_SERVERINTERRUPT);

  # Clear the appstate object which will trigger the demolition of
  # the other objects in the set.
  #
  $self->leave;
  exit(0);
}

#--[ Any ]----------------------------------------------------------------------
# Check if a server runs already. Return 0 (an unused pid number) if no
# server is running. Otherwise return pid of server process.
#
sub check_server
{
  my($self) = @_;

  my $config_dir = AppState->instance->config_dir;
  my $pid = 0;
  my $pid_file = $config_dir . '/' . $self->pid_file;
  if( -r $pid_file )
  {
    open( PIDF, "< $pid_file");
    $pid = <PIDF>;
    close(PIDF);
    chomp($pid);
  }

  # Check pid in process table
  #
  if( $pid )
  {
    my $pidFound = 0;
    my $psTable = new Proc::ProcessTable;
    foreach my $psTEntry (@{$psTable->table})
    {
      # Check pid and server name
      #
      if( $pid == $psTEntry->pid and $psTEntry->cmndline =~ m/spider/ )
      {
        $pidFound = 1;
        last;
      }
    }

    # Reset $pid and remove pid file if server process is not found in table
    #
    if( $pidFound )
    {
      $self->log( $self->C_PRC_PIDOK, [$pid]);
    }

    else
    {
      $self->log( $self->C_PRC_PIDNOTFOUND, [$pid]);
      $pid = 0;
      unlink $pid_file;
    }
  }

#say "CS: $pid_file, $pid";
  return $pid;
}

#-------------------------------------------------------------------------------
#
sub receive
{
  my( $self, $arguments) = @_;

  my $cmm_type = $self->cmm_type;
  if( defined $self->_plugin_manager->check_plugin($cmm_type) )
  {
    $self->log( $self->C_PRC_RECEIVE, [$cmm_type]);
    $self->_plugin_manager->get_object({name => $cmm_type})->receive($arguments);
  }

  else
  {
    $self->log( $self->C_PRC_NOPLUGIN, [$cmm_type]);
  }
}

#-------------------------------------------------------------------------------
#
sub send
{
  my( $self, $arguments) = @_;

  my $cmm_type = $self->cmm_type;
  my $pmgr = $self->_plugin_manager;
  if( defined $pmgr->check_plugin($cmm_type) )
  {
    $self->wlog( $self->C_PRC_RECEIVE, [$cmm_type]);
    $pmgr->get_object({name => $cmm_type})->send($arguments);
  }

  else
  {
    $self->log( $self->C_PRC_NOPLUGIN, [$cmm_type]);
  }
}

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;
1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState::Plugins::Feature::Process - Perl extension to control processes as well as
communication between them

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
