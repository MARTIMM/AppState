package AppState::Process::MsgQueue;

use Modern::Perl;
use version; our $VERSION = '' . version->parse("v0.0.5");
use 5.010001;

use namespace::autoclean;

use Moose;
use AppState;
require POSIX;
use IPC::Msg (qw(MSG_NOERROR));
use IPC::SysV (qw( ftok IPC_CREAT IPC_NOWAIT S_IRUSR S_IWUSR));
#require Digest::MD5;

#-------------------------------------------------------------------------------
#use AppState::Ext::Constants;
#my $m = AppState::Ext::Constants->new;

#-------------------------------------------------------------------------------
has msg_queue =>
    ( is                => 'ro'
    , isa               => 'IPC::Msg'
    , writer            => '_msgQueue'
    , predicate         => 'has_queue'
    , clearer           => '_clearMsgQueue'
    );

has queue_key =>
    ( is                => 'rw'
    , isa               => 'Str'
    , predicate         => 'has_queue_key'
    , writer            => '_queueKey'
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;
  AppState->instance->log_init('=MQ');
}

#-------------------------------------------------------------------------------
#
sub plugin_initialize
{
  my($self) = @_;
  $self->_queueKey($self->gen_queue_key) unless $self->has_queue_key;
}

#-------------------------------------------------------------------------------
#
sub plugin_cleanup
{
  my($self) = @_;

  if( $self->has_queue )
  {
    $self->msg_queue->remove;
    $self->_clearMsgQueue;
  }
}

#-------------------------------------------------------------------------------
#
sub send
{
  my( $self, $arguments) = @_;
  my $type = $arguments->{type};
  my $msg = $arguments->{message};

  if( !$self->has_queue )
  {
    # Server needs to read from the queue to read the urls from it.
    #
    my $mq = IPC::Msg->new( $self->queue_key
                          , IPC_CREAT | S_IRUSR | S_IWUSR
                          );

    if( ref $mq eq 'IPC::Msg' )
    {
      $self->_msgQueue($mq);

      $self->wlog( "Message queue created for reading and writing"
                 , $m->M_INFO
                 );
    }

    else
    {
      $self->wlog( "Message queue not created, $mq", $m->M_ERROR);
    }
  }

  if( $self->has_queue )
  {
    $self->msg_queue->snd( $type, $msg);
    $self->wlog( "Message '$msg' of type '$type' sent.", $m->M_INFO);
  }

  else
  {
    $self->wlog( "Message not sent.", $m->M_ERROR);
  }
}

#-------------------------------------------------------------------------------
#
sub receive
{
  my( $self, $arguments) = @_;

  if( !$self->has_queue )
  {
    my $mq = IPC::Msg->new( $self->queue_key
                          , IPC_CREAT | S_IRUSR | S_IWUSR
                          );
    if( ref $mq eq 'IPC::Msg' )
    {
      $self->_msgQueue($mq);

      $self->wlog( "Message queue created for reading and writing:"
                 , $m->M_INFO
                 );
    }

    else
    {
      $self->wlog( "Message queue not created", $m->M_ERROR);
    }
  }

  if( $self->has_queue )
  {
    $arguments->{msg} = '';
    $arguments->{async} //= 0;
    $arguments->{size} //= 256;
    $arguments->{flags} = $m->MSG_NOERROR;
    $arguments->{flags} |= $arguments->{async} ? IPC_NOWAIT : 0;

    $arguments->{type} = $self->msg_queue->rcv
                         ( $arguments->{msg}
                         , $arguments->{size}
                         , undef
                         , $arguments->{flags}
                         );
    $arguments->{type} //= '';
    $self->wlog( "Message of type '$arguments->{type}' received.", $m->M_INFO);
  }

  else
  {
    $arguments->{type} = '';
    $self->wlog( "Cannot receive messages", $m->M_ERROR);
  }

  # Only return data when synchronized.
  #
  my @returnData = $arguments->{async}
                 ? ()
                 : ( $arguments->{type}, $arguments->{msg});
  return @returnData;
}

#-------------------------------------------------------------------------------
# In this system the ftok from the Sysv module wouldn't give any key. So,
# we need to write our own. It is some mapping of the path and key to a
# 4 byte number.
#
sub gen_queue_key
{
  my( $self) = @_;

  # Sometimes there is an overflow
  #
  my $nbr;# = Digest::MD5::md5_hex(AppState->instance->config_dir);
#say "Nbr: $nbr";
#  $nbr = '0x' . substr( $nbr, 0, 8);
#say "Nbr: $nbr";
#  $nbr = hex $nbr;
#say "Nbr: $nbr";

  # Take some random number until better times arrive
  #
#  $nbr = 0x4FE0A260;
#say "Nbr: $nbr";
  $nbr = ftok( AppState->instance->config_dir, 'C');
say "Nbr: $nbr";

  $self->wlog( "Generated message queue key key: $nbr", $m->M_INFO);
  return $nbr;
}

#-------------------------------------------------------------------------------
no Moose;
__PACKAGE__->meta->make_immutable;
1;
