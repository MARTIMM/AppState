# Testing module AppState::Ext::Constants
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
  $self->const( 'N',  'M_INFO', 'Message for constant N');
  is( ref $self->can('N'), 'CODE', 'Constant N available');

  # Create another constant.
  #
  $self->set_code_count(hex('8b'));
  $self->const( 'M', 'M_INFO', 'Message for constant M');
  is( ref $self->can('M'), 'CODE', 'Constant M available');

  $self->meta->make_immutable;

  # Create another constant, should not be possible.
  #
  $self->const( 'O', 'M_INFO');
  is( ref $self->can('O'), '', 'Constant O not available');

  $self->log_init('005');
}

#-------------------------------------------------------------------------------
# Make object
#
my $self = main->new;
isa_ok( $self, 'main');

#-------------------------------------------------------------------------------
# Init
#
my $as = AppState->instance;
$as->initialize( config_dir => 't/Constants'
               , use_work_dir => 0
               , use_temp_dir => 0
               );
$as->check_directories;

my $log = $as->get_app_object('Log');
$log->show_on_error(0);
$log->show_on_fatal(0);
$log->die_on_fatal(0);
#$log->show_on_warning(1);
$log->do_append_log(0);

$log->start_logging;

$log->do_flush_log(1);
$log->log_mask($as->M_TRACE);

is( $log->get_log_tag(ref $self), '005', 'Check log tag');

#-------------------------------------------------------------------------------
subtest 'Constants test and set constant' =>
sub
{
  ok( $self->M_SUCCESS == 0x01000000, 'Check constant success = 0x01000000');
  ok( $self->N == $self->M_INFO | hex('7b'), 'Check number constant value N');
  is( $self->N, 'Message for constant N', 'Check text constant value N');

  eval('$self->N(11);');

  is( $@ =~ m/Cannot assign a value to a read-only accessor/
    , 1
    , 'Cannot change a constant N'
    );
};

#-------------------------------------------------------------------------------
subtest 'Drop main and test again' =>
sub
{
  $self = undef;
  $self = main->new;

  ok( $self->M_FAIL == 0x02000000, 'Check constant fail = 0x02000000');
  ok( $self->N == ($self->M_INFO | hex('7b')), 'Check new constant value N');
  is( $self->N, 'Message for constant N', 'Check text constant value N');
};

#-------------------------------------------------------------------------------
subtest 'Drop main and test again' =>
sub
{
  $self = undef;
  $self = main->new;

  ok( $self->M_SUCCESS == 0x01000000, 'Check constant success = 0x01000000');
  ok( $self->M == ($self->M_INFO | hex('8b')), 'Check new constant value M');
  is( $self->M, 'Message for constant M', 'Check text constant value M');
};

#-------------------------------------------------------------------------------
subtest 'Test all codes' =>
sub
{
  $self->t_code( M_ALL          => 0xFFFFFFFF);
  $self->t_code( M_NONE         => 0x00000000);

  $self->t_code( M_EVNTCODE     => 0x000003FF);
  $self->t_code( M_SEVERITY     => 0xFFF00000);
  $self->t_code( M_MSGMASK      => 0xFFF003FF);
  $self->t_code( M_NOTMSFF      => 0xF0F00000);

  $self->t_code( M_RESERVED     => 0x000FFC00);

  $self->t_code( M_SUCCESS      => 0x01000000);
  $self->t_code( M_FAIL         => 0x02000000);
  $self->t_code( M_FORCED       => 0x04000000);

  $self->t_code( M_INFO         => 0x11000000);
  $self->t_code( M_WARNING      => 0x20000000);
  $self->t_code( M_ERROR        => 0x42000000);

  $self->t_code( M_TRACE        => 0x01100000);
  $self->t_code( M_DEBUG        => 0x01200000);
  $self->t_code( M_WARN         => 0x20000000);
  $self->t_code( M_FATAL        => 0x02400000);

  $self->t_code( M_F_INFO       => 0x15000000);
  $self->t_code( M_F_WARNING    => 0x24000000);
  $self->t_code( M_F_ERROR      => 0x46000000);
  $self->t_code( M_F_TRACE      => 0x05100000);
  $self->t_code( M_F_DEBUG      => 0x05200000);
  $self->t_code( M_F_WARN       => 0x24000000);
  $self->t_code( M_F_FATAL      => 0x06400000);

#  $self->t_code(  => 0x);
};

#-------------------------------------------------------------------------------
done_testing();
$as->cleanup;

File::Path::remove_tree('t/Constants');
exit(0);

################################################################################
#
sub t_code
{
  my( $self, $name, $code) = @_;

  is( $self->$name, $code, sprintf( "Code %s = 0x%08X", $name, $code));
}


