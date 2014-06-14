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
    , writer            => 'set_status'
    , default           =>
      sub
      { return
        { error_type    => 0
        , message       => ''
#        , stack         => []
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
    $self->const( 'C_STS_INITOK', qw(M_L4P_INFO));

    # Codes
    #
#    $self->const( 'C_STS_', 0);

    # Fill in the status value
    #
    $self->status->{error_type} = $self->C_STS_INITOK;

    __PACKAGE__->meta->make_immutable;
  }
}

#-------------------------------------------------------------------------------
#
sub is_success
{
  my( $self) = @_;
  
  my $is = !!($self->status->{error_type} & $self->M_SUCCESS);
  return $is;
}

#-------------------------------------------------------------------------------
#
sub is_warning
{
  my( $self) = @_;

  my $iw = !!($self->status->{error_type} & $self->M_L4P_WARN);
  return $iw;
}

#-------------------------------------------------------------------------------
#
sub is_error
{
  my( $self) = @_;

  my $ie = !!($self->status->{error_type} & $self->M_FAIL);
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
sub set_error_type
{
  my( $self, $type) = @_;
  $self->status->{error_type} = $type;
  
  return '';
}

#-------------------------------------------------------------------------------
#
sub get_error_type
{
  return $_[0]->status->{error_type};
}

#-------------------------------------------------------------------------------
#
sub set_stack
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
sub get_stack
{
  my( $self, $item) = @_;

  my $it = $self->status->{$item} if $item =~ m/^(line|file|package)$/;
  return $it // '';
}

#-------------------------------------------------------------------------------
#
1;


