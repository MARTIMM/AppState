#-------------------------------------------------------------------------------
# Module to interact on process level. This means that it can help to daemonize
# the calling process, or to find out if there is a server, to kill that server
# etc. The server process id will be stored in a file in the config directory
# maintained by AppState. Furthermore some interprocess communication is
# possible by using a message queue.
#-------------------------------------------------------------------------------
package AppState::Plugins::Feature::Process;

use Modern::Perl;
use version; our $VERSION = qv('v0.1.7');
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

#-------------------------------------------------------------------------------

has pidFile =>
    ( is                => 'ro'
    , isa               => 'Str'
    , default           =>
      sub
      { my $basename = File::Basename::fileparse( $0, qr/\.[^.]*/);
        return "$basename.pid";
      }
    );

has cmmType =>
    ( is                => 'rw'
    , isa               => 'Str'
    , default           => 'MsgQueue'
    );

has plugin_manager =>
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

        # Number of separators in the path is the depth of the base
        #
        my(@lseps) = $path =~ m@(/)@g;

        # Search for any modules
        #
        $pm->search_plugins( { base => $path
                            , depthSearch => 2 + @lseps
                            , searchRegex => qr@/AppState/Process/[A-Z][\w]+.pm$@
                            , apiTest => [ qw( send receive)]
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

  if( $self->meta->is_mutable )
  {
    $self->log_init('PRC');

    # Error codes
    #
    $self->code_reset;
    $self->const( 'C_PRC_PIDFILEREMOVED',qw(M_INFO M_SUCCESS));
    $self->const( 'C_PRC_CLEANCOMM',qw(M_INFO M_SUCCESS));
    $self->const( 'C_PRC_PIDFILECREATED',qw(M_INFO M_SUCCESS));
    $self->const( 'C_PRC_PARENTSTOPPED',qw(M_INFO M_SUCCESS));
    $self->const( 'C_PRC_SERVERSTARTED',qw(M_INFO M_SUCCESS));
    $self->const( 'C_PRC_SIGNALSENT',qw(M_INFO M_SUCCESS));
    $self->const( 'C_PRC_SERVERINTERRUPT',qw(M_WARNING M_FORCED));
    $self->const( 'C_PRC_PIDOK',qw(M_INFO M_SUCCESS));
    $self->const( 'C_PRC_PIDNOTFOUND',qw(M_WARNING M_FORCED));
    $self->const( 'C_PRC_RECEIVE',qw(M_INFO M_SUCCESS));
    $self->const( 'C_PRC_NOPLUGIN',qw(M_ERROR M_FAIL));
    $self->const( 'C_PRC_RECEIVE',qw(M_INFO M_SUCCESS));
#    $self->const( '',qw());
#    $self->const( '',qw());
#    $self->const( '',qw());

    # Server status codes
    #
    $self->const('C_PRC_SRVROK');
    $self->const('C_PRC_SRVRNOK');
    $self->const('C_PRC_SRVRASTRTD');

    __PACKAGE__->meta->make_immutable;
  }
}

#--[ Any ]----------------------------------------------------------------------
# Cleanup
#
sub cleanup
{
  my($self) = @_;

  # Check if server runs and if this process's id is the same as the
  # one returned by the checkServer function.
  #
  my $pidServer = $self->checkServer;
  if( $$ == $pidServer )
  {
    my $config_dir = AppState->instance->config_dir;
    my $pidFile = $config_dir . '/' . $self->pidFile;
    unlink $pidFile;
    $self->wlog( "Pid file " . $self->pidFile . " removed"
               , $self->C_PRC_PIDFILEREMOVED
               );

    # Remove communication only when server stops
    #
    $self->wlog( "Cleanup communication", $self->C_PRC_CLEANCOMM);
    $self->plugin_manager->cleanup;
  }
}

#--[ Client ]-------------------------------------------------------------------
# Start as a server
#
sub startServer
{
  my($self) = @_;

  # Check if server exists we don't need a second one
  #
  return $self->C_PRC_SRVRASTRTD if $self->checkServer;

  my $config_dir = AppState->instance->config_dir;
  my $pidFile = $config_dir . '/' . $self->pidFile;

  # First do fork.
  # If $pid is set then the process is the parent process and we need to exit
  # but before the process exits it stores the pid in a file. Otherwise we are
  # the child process and do the work.
  #
  my $pid = fork;
  if( defined $pid and $pid )
  {
    open( PIDF, "> $pidFile");
    print PIDF "$pid\n";
    close(PIDF);

    $self->wlog( "Pid file " . $self->pidFile
               . " created for server with pid $pid"
               , $self->C_PRC_PIDFILECREATED
               );

    my $log = AppState->instance->checkAppPlugin('Log');
    if( ref $log eq 'AppState::Plugins::Feature::Log' )
    {
      $log->wlog( "Parent process stopped", $self->C_PRC_PARENTSTOPPED);
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
  $self->wlog( "Server process started with pid $$", $self->C_PRC_SERVERSTARTED);

  # Setup kill signals TERM and INT to call stopServer()
  #
  $SIG{TERM} = sub { $self->stopServer; };
  $SIG{INT} = sub { $self->stopServer; };

  return $self->C_PRC_SRVROK;
}

#--[ Client ]-------------------------------------------------------------------
# Kill server process. Is called from non-server process.
#
sub killServer
{
  my($self) = @_;

  my $pid = $self->checkServer;
  kill 'TERM', $pid if $pid;
  $self->wlog( "Sent signal to server", $self->C_PRC_SIGNALSENT);
}

#--[ Server ]-------------------------------------------------------------------
# End of the spiderServer. This function is triggerd after a TERM or INT signal.
#
sub stopServer
{
  my($self) = @_;

  # Kill this server
  #
  $self->wlog( "Server interrupted.", $self->C_PRC_SERVERINTERRUPT);

  # Clear the appstate object which will trigger the demolition of
  # the other objects in the set.
  #
  AppState->instance->cleanup;
  exit(0);
}

#--[ Any ]----------------------------------------------------------------------
# Check if a server runs already. Return 0 (an unused pid number) if no
# server is running. Otherwise return pid of server process.
#
sub checkServer
{
  my($self) = @_;

  my $config_dir = AppState->instance->config_dir;
  my $pid = 0;
  my $pidFile = $config_dir . '/' . $self->pidFile;
  if( -r $pidFile )
  {
    open( PIDF, "< $pidFile");
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
      $self->wlog( "Pid $pid checked and is ok.", $self->C_PRC_PIDOK);
    }

    else
    {
      $self->wlog( "Pid $pid checked and is not found, server crashed?"
                 , $self->C_PRC_PIDNOTFOUND
                 );
      $pid = 0;
      unlink $pidFile;
    }
  }

#say "CS: $pidFile, $pid";
  return $pid;
}

#-------------------------------------------------------------------------------
#
sub receive
{
  my( $self, $arguments) = @_;

  my $cmmType = $self->cmmType;
  if( defined $self->plugin_manager->check_plugin($cmmType) )
  {
    $self->wlog( "Receive using $cmmType type config", $self->C_PRC_RECEIVE);
    $self->plugin_manager->get_object({name => $cmmType})->receive($arguments);
  }

  else
  {
    $self->wlog( "Method $cmmType plugin not loaded for receiving"
               , $self->C_PRC_NOPLUGIN
               );
  }
}

#-------------------------------------------------------------------------------
#
sub send
{
  my( $self, $arguments) = @_;

  my $cmmType = $self->cmmType;
  my $pmgr = $self->plugin_manager;
  if( defined $pmgr->check_plugin($cmmType) )
  {
    $self->wlog( "Send using $cmmType type config", $self->C_PRC_RECEIVE);
    $pmgr->get_object({name => $cmmType})->send($arguments);
  }

  else
  {
    $self->wlog( "Method $cmmType plugin not loaded for sending"
               , $self->C_PRC_NOPLUGIN
               );
  }
}

#-------------------------------------------------------------------------------

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
