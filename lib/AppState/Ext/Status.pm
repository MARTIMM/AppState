package AppState::Ext::Status;

use Modern::Perl;
 
use version; our $VERSION = version->parse('v0.0.1');
use 5.010001;

use namespace::autoclean;

use Moose;
extends qw(AppState::Ext::Constants);

#-------------------------------------------------------------------------------
# Error codes for Constants module
#
has status =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , writer            => '_status'
    , default           =>
      sub
      { my( $self) = @_;
      
        # Must be done later if not set yet
        #
        my $error = 0;
        $error = $self->C_STS_INITOK unless $self->meta->is_mutable;

        return
        { error         => $error
        , message       => ''
        , line          => 0
        , file          => ''
        , package       => ''
        };
      }
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my( $self) = @_;
  
  if( $self->meta->is_mutable )
  {
    # Error codes
    #
#    $self->code_reset;
    $self->const( 'C_STS_INITOK',       qw(M_INFO));
    $self->const( 'C_STS_UNKNKEY',      qw(M_WARN));

    # Codes
    #
#    $self->const( 'C_STS_', 0);

    # Fill in the status value
    #
    $self->status->{error} = $self->C_STS_INITOK;

    __PACKAGE__->meta->make_immutable;
  }
}

#-------------------------------------------------------------------------------
#
sub is_success
{
  my( $self) = @_;
  
  my $is = !!($self->status->{error} & $self->M_SUCCESS);
  return $is;
}

#-------------------------------------------------------------------------------
#
sub is_fail
{
  my( $self) = @_;

  my $ie = !!($self->status->{error} & $self->M_FAIL);
  return $ie;
}

#-------------------------------------------------------------------------------
#
sub is_forced
{
  my( $self) = @_;

  my $ie = !!($self->status->{error} & $self->M_FORCED);
  return $ie;
}

#-------------------------------------------------------------------------------
#
sub is_info
{
  my( $self) = @_;

  my $ie = !!($self->status->{error} & $self->M_NOTMSFF & $self->M_INFO);
  return $ie;
}

#-------------------------------------------------------------------------------
#
sub is_warning
{
  my( $self) = @_;

  my $iw = !!($self->status->{error} & $self->M_NOTMSFF & $self->M_WARNING);
  return $iw;
}

#-------------------------------------------------------------------------------
#
sub is_error
{
  my( $self) = @_;

  my $ie = !!($self->status->{error} & $self->M_NOTMSFF & $self->M_ERROR);
  return $ie;
}

#-------------------------------------------------------------------------------
#
sub is_trace
{
  my( $self) = @_;

  my $ie = !!($self->status->{error} & $self->M_NOTMSFF & $self->M_TRACE);
  return $ie;
}

#-------------------------------------------------------------------------------
#
sub is_debug
{
  my( $self) = @_;

  my $ie = !!($self->status->{error} & $self->M_NOTMSFF & $self->M_DEBUG);
  return $ie;
}

#-------------------------------------------------------------------------------
# Same as warning because M_WARN == M_WARNING
#
sub is_warn
{
  my( $self) = @_;

  my $iw = !!($self->status->{error} & $self->M_NOTMSFF & $self->M_WARN);
  return $iw;
}

#-------------------------------------------------------------------------------
#
sub is_fatal
{
  my( $self) = @_;

  my $ie = !!($self->status->{error} & $self->M_NOTMSFF & $self->M_FATAL);
  return $ie;
}

#-------------------------------------------------------------------------------
#
sub set_message
{
  my( $self, @msgs) = @_;
  $self->status->{message} = join( ' ', @msgs);
  
  return '';
}

#-------------------------------------------------------------------------------
#
sub get_message
{
  return $_[0]->status->{message};
}

#-------------------------------------------------------------------------------
#
sub set_error
{
  my( $self, $error) = @_;
  $self->status->{error} = $error;
  
  return '';
}

#-------------------------------------------------------------------------------
#
sub get_error
{
  return $_[0]->status->{error};
}

#-------------------------------------------------------------------------------
#
sub get_severity
{
  my($self) = @_;
  return $self->status->{error} & $self->M_SEVERITY;
}

#-------------------------------------------------------------------------------
#
sub get_eventcode
{
  my($self) = @_;
  return $self->status->{error} & $self->M_EVNTCODE;
}

#-------------------------------------------------------------------------------
#
sub set_caller_info
{
  my( $self, $call_level) = @_;

  $call_level //= 0;
  my( $p, $f, $l) = caller($call_level);
#say "Caller: $p, $f, $l";
  $self->status->{line} = $l;
  $self->status->{file} = $f;
  $self->status->{package} = $p;

  return '';
}

#-------------------------------------------------------------------------------
#
sub get_caller_info
{
  my( $self, $item) = @_;

  my $it = $self->status->{$item} if $item =~ m/^(line|file|package)$/;
  return $it // '';
}

#-------------------------------------------------------------------------------
#
sub get_line
{
  my( $self, $item) = @_;

  return $self->status->{line} // 0;
}

#-------------------------------------------------------------------------------
#
sub get_file
{
  my( $self, $item) = @_;

  return $self->status->{file} // '';
}

#-------------------------------------------------------------------------------
#
sub get_package
{
  my( $self, $item) = @_;

  return $self->status->{package} // '';
}

#-------------------------------------------------------------------------------
#
sub set_status
{
  my( $self, %status_fields) = @_;
  my $sts = 0;

  foreach my $sts_key (keys %status_fields)
  {
    if( $sts_key !~ m/^(error|message|line|file|package|call_level)$/ )
    {
      # If anything goes wrong set the object with our own message and error
      #
      $self->set_error($self->C_STS_UNKNKEY);
      $self->set_message("Unknown key '$sts_key' to set status fields");
      $self->set_caller_info(0);
      $sts = 1;
      last;
    }
  }

  if( !$sts )
  {
    my $cl = delete $status_fields{call_level};
    $self->_status(\%status_fields);
    $self->set_caller_info($cl+1) if defined $cl;
  }

  # Return 0 on success
  #
  return $sts;
}

#-------------------------------------------------------------------------------
#
sub clear_error
{
  my( $self, $item) = @_;

  # Must be done later if not set yet
  #
  my $error = 0;
  $error = $self->C_STS_INITOK unless $self->meta->is_mutable;

  $self->_status( { error         => $error
                  , message       => ''
                  , line          => 0
                  , file          => ''
                  , package       => ''
                  }
                );
}

#-------------------------------------------------------------------------------
#
1;


