# Testing module AppState.pm
#
use Modern::Perl;

use Test::Most;
use Moose;
extends 'AppState::Ext::Constants';

use AppState;

#-------------------------------------------------------------------------------
sub BUILD
{
  my($self) = @_;

  # Create a constant. Cannot be done after first instanciation but is tested.
  #
  $self->set_code_count(hex('7b'));
  $self->const( 'N', qw( M_SUCCESS M_INFO));
  is( ref $self->can('N'), 'CODE', 'Constant N available');

  $self->meta->make_immutable;

  # Create another constant, should not be possible.
  #
  $self->set_code_count(hex('8b'));
  $self->const( 'M', qw( M_SUCCESS M_INFO));
  is( ref $self->can('M'), '', 'Constant M not available');

  $self->log_init('005');
}

#-------------------------------------------------------------------------------
# Make object
#
my $self = main->new;

#-------------------------------------------------------------------------------
# Init
#
my $as = AppState->instance;
$as->initialize( config_dir => 't/Constants');
$as->check_directories;

my $log = $as->get_app_object('Log');
$log->show_on_error(0);
#$log->show_on_warning(1);
$log->do_append_log(0);

$log->start_logging;

$log->do_flush_log(1);
$log->log_mask($as->M_SEVERITY);

is( $log->getLogTag(ref $self), '005', 'Check log_init');
$log->write_log( "Mededeling 1", 1|$log->M_INFO);
$self->_log( "Mededeling 2", 1|$log->M_INFO);

#-------------------------------------------------------------------------------
is( $self->M_SUCCESS, 0x01000000, 'Check constant success = 0x01000000');
is( $self->N, 0x1100007b, 'Check new constant value N = 0x1100007b');

eval('$self->N(11);');

is( $@ =~ m/Cannot assign a value to a read-only accessor/
  , 1
  , 'Cannot change a constant N'
  );

#-------------------------------------------------------------------------------
$self = undef;
$self = main->new;

is( $self->M_SUCCESS, 0x01000000, 'Check constant success = 0x01000000');
is( $self->N, 0x1100007b, 'Check new constant value N = 0x1100007b');

#-------------------------------------------------------------------------------
done_testing();
$as->cleanup;

File::Path::remove_tree('t/Constants');




__END__
use constant
{ M_ALL                 => 0xFFFFFFFF
  M_NONE                => 0x00000000

  M_EVNTCODE            => 0x00000FFF # 4095 codes/module (no 0)
  M_SEVERITY            => 0xFF000000 # 8 bits for severity
  M_MSGMASK             => 0xFF000FFF # Severity and code
  M_RESERVED            => 0x00FFF000 # Reserved

  # Severity codes ar
  #
  M_SUCCESS             => 0x01000000
  M_FAIL                => 0x02000000

  M_INFO                => 0x10000000  # INFO always SUCCESS
  M_WARNING             => 0x20000000
  M_ERROR               => 0x40000000  # ERROR always FAIL
  M_FORCED              => 0x80000000  # Force logging

  # Following are combinations with FORCED -> log always when log is opened
  #
  M_F_INFO              => 0x90000000  # INFO always SUCCESS
  M_F_WARNING           => 0xA0000000
  M_F_ERROR             => 0xB0000000  # ERROR always FAIL
};

#-------------------------------------------------------------------------------
*c_Attr = *AppState::Ext::Constants::c_Attr;
say join( ', ', c_Attr());

sub c_Attr
{
  my( $defCode, @defSeverity) = shift;
  my %attr = ( is => 'ro', init_arg => undef, lazy => 1);
  $attr{default} = $defCode if defined $defCode;
  return %attr;
}

#-------------------------------------------------------------------------------
*$full_name = sub () { $scalar };
