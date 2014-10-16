package AppState::Ext::Status;

use Modern::Perl;

use version; our $VERSION = version->parse('v0.0.4');
use 5.010001;

use namespace::autoclean;

use Moose;
extends qw(AppState::Ext::Constants);

use AppState::Ext::Meta_Constants ('def_sts');
use Types::Standard qw(Dict Optional Int Str);

#-------------------------------------------------------------------------------
# Error codes
#
def_sts( 'C_STS_UNKNKEY', 'M_ERROR', 'Unknown/insufficient status information');

#-------------------------------------------------------------------------------
# Error codes for Constants module. The error code can be a dualvar which if so
# will be a code together with its error message. In that case message wouldn't
# have to be used.
#
has status =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , writer            => '_status'
    , default           =>
      sub
      { my( $self) = @_;
        return
        { message       => ''
        , error         => 0
        , line          => 0
        , file          => ''
        , package       => ''
        };
      }
    , traits            => ['Hash']
    , handles           =>
      { _clear_status   => 'clear'
      }
    );

# Type::Tiny structure to check the status attribute with using Type::Standard
#
has _status_types =>
    ( is                => 'ro'
    , isa               => 'Type::Tiny'
    , default           =>
      sub
      {
        return Dict
        ( [ message       => Str
          , error         => Int
          , line          => Optional[Int]
          , file          => Optional[Str]
          , package       => Optional[Str]
          ]
        )
      }
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my( $self) = @_;

  # Set some trace status
  #
  $self->status->{error} = $self->M_TRACE | 1;
  $self->status->{message} = 'State object initialized ok';
  $self->status->{line} = __LINE__;
  $self->status->{file} = __FILE__;
  $self->status->{package} = __PACKAGE__;
}

#-------------------------------------------------------------------------------
#
sub is_success
{
  my($self) = @_;
  return !!($self->status->{error} & $self->M_SUCCESS);
}

#-------------------------------------------------------------------------------
#
sub is_fail
{
  my($self) = @_;
  return !!($self->status->{error} & $self->M_FAIL);
}

#-------------------------------------------------------------------------------
#
sub is_forced
{
  my( $self, $error) = @_;
  return !!($self->status->{error} & $self->M_FORCED);
}

#-------------------------------------------------------------------------------
#
sub is_info
{
  my($self) = @_;
  return !!($self->status->{error} & $self->M_NOTMSFF & $self->M_INFO);
}

#-------------------------------------------------------------------------------
#
sub is_warning
{
  my( $self, $error) = @_;
  return !!($self->status->{error} & $self->M_NOTMSFF & $self->M_WARNING);
}

#-------------------------------------------------------------------------------
#
sub is_error
{
  my($self) = @_;
  return !!($self->status->{error} & $self->M_NOTMSFF & $self->M_ERROR);
}

#-------------------------------------------------------------------------------
#
sub is_trace
{
  my($self) = @_;
  return !!($self->status->{error} & $self->M_NOTMSFF & $self->M_TRACE);
}

#-------------------------------------------------------------------------------
#
sub is_debug
{
  my($self) = @_;
  return !!($self->status->{error} & $self->M_NOTMSFF & $self->M_DEBUG);
}

#-------------------------------------------------------------------------------
# Same as warning because M_WARN == M_WARNING
#
sub is_warn
{
  my($self) = @_;
  return !!($self->status->{error} & $self->M_NOTMSFF & $self->M_WARN);
}

#-------------------------------------------------------------------------------
#
sub is_fatal
{
  my($self) = @_;
  return !!($self->status->{error} & $self->M_NOTMSFF & $self->M_FATAL);
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
  my($self) = @_;

  return $self->status->{line} // 0;
}

#-------------------------------------------------------------------------------
#
sub get_file
{
  my($self) = @_;

  return $self->status->{file} // '';
}

#-------------------------------------------------------------------------------
#
sub get_package
{
  my($self) = @_;

  return $self->status->{package} // '';
}

#-------------------------------------------------------------------------------
# Set the status fields in one go.
#
sub set_status
{
  my( $self, $status_fields, $call_level) = @_;

  my $sts = 0;
  $self->_clear_status;

  # If everything was set right then set the data. If a field call_level was
  # used then ignore the line, file and package info and get that info from
  # set_caller_info().
  #
  if( $self->_status_types()->check($status_fields) )
  {
    $self->_status($status_fields);
    $self->set_caller_info($call_level+1) if defined $call_level;
  }

  else
  {
#say STDERR "X: ", join( ', ', map { "$_ => '$status_fields->{$_}'"} (sort keys %$status_fields));
    # If anything goes wrong set the object with our own message and error
    #
    $self->set_error(0 + $self->C_STS_UNKNKEY);
    $self->set_message('' . $self->C_STS_UNKNKEY);
    $self->set_caller_info(1);
    $sts = $self;
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
  $self->_status( { error         => $self->M_TRACE | 1
                  , message       => 'State object initialized ok'
                  , line          => __LINE__
                  , file          => __FILE__
                  , package       => __PACKAGE__
                  }
                );
}

#-------------------------------------------------------------------------------
#
__PACKAGE__->meta->make_immutable;
1;


