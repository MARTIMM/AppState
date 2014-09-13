# Testing module AppState::Ext::Constants
#
use Modern::Perl;

use Test::Most;
use Moose;
extends 'AppState::Ext::Constants';

use AppState;
use AppState::Ext::Meta_Constants;

# Create a constant. Cannot be done after first instanciation but is tested.
#
def_sts( 'N',  'M_INFO', 'Message for constant N');

# Create another constant.
#
def_sts( 'M', 'M_INFO', 'Message for constant M');


#-------------------------------------------------------------------------------
sub BUILD
{
  my($self) = @_;

  is( ref $self->can('N'), 'CODE', 'Constant N available');
  is( ref $self->can('M'), 'CODE', 'Constant M available');
  is( ref $self->can('O'), '', 'Constant O not available');

  $self->log_init('005');
}

#-------------------------------------------------------------------------------
# Make object
#
__PACKAGE__->meta->make_immutable;
my $self = main->new;
isa_ok( $self, 'main');

#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize(config_dir => 't/Constants', check_directories => 1);

my $log = $app->get_app_object('Log');
$log->die_on_fatal(0);
$log->do_append_log(0);
$log->do_flush_log(1);
$log->start_logging;
$log->log_level($app->M_TRACE);

#-------------------------------------------------------------------------------
subtest 'Constants test and set constant' =>
sub
{
  ok( $self->M_SUCCESS == 0x10000000, 'Check constant success = 0x10000000');
  ok( $self->N & $self->M_EVNTCODE, 'Check eventcode of value N');
  is( $self->N, 'N - Message for constant N', 'Check text constant value N');

  eval('$self->N(11);');

  is( $@ =~ m/Cannot assign a value to a read-only accessor/
    , 1
    , 'Cannot change a constant N'
    );
};

#-------------------------------------------------------------------------------
subtest 'Drop main and test again 1' =>
sub
{
  $self = undef;
  $self = main->new;

  ok( $self->M_FAIL == 0x20000000, 'Check constant fail = 0x20000000');
  ok( $self->N & $self->M_EVNTCODE, 'Check evencode of value N');
  is( $self->N, 'N - Message for constant N', 'Check text constant value N');
};

#-------------------------------------------------------------------------------
subtest 'Drop main and test again 2' =>
sub
{
  $self = undef;
  $self = main->new;

  ok( $self->M_SUCCESS == 0x10000000, 'Check constant success = 0x10000000');
  ok( $self->M & $self->M_EVNTCODE, 'Check evencode of value M');
  is( $self->M, 'M - Message for constant M', 'Check text constant value M');
};

#-------------------------------------------------------------------------------
subtest 'Test all codes' =>
sub
{
  $self->t_all_code( M_ALL          => 0xFFFFFFFF);
  $self->t_all_code( M_NONE         => 0x00000000);

  $self->t_all_code( M_EVNTCODE     => 0x000007FF);
  $self->t_all_code( M_SEVERITY     => 0xFFFE0000);
  $self->t_all_code( M_MSGMASK      => 0xFFFE07FF);
  $self->t_all_code( M_NOTMSFF      => 0x0FF00000);
  $self->t_all_code( M_ISMSFF       => 0xF0000000);
  $self->t_all_code( M_LEVELMSK     => 0x000E0000);

  $self->t_all_code( M_RESERVED     => 0x0001F800);

  $self->t_code( M_SUCCESS      => 0x10000000);
  $self->t_code( M_FAIL         => 0x20000000);
  $self->t_code( M_FORCED       => 0x40000000);
  $self->t_code( M_CODE         => 0x80000000);

  $self->t_code( M_INFO         => 0x11000000);
  $self->t_code( M_WARNING      => 0x02000000);
  $self->t_code( M_ERROR        => 0x24000000);

  $self->t_code( M_TRACE        => 0x10100000);
  $self->t_code( M_DEBUG        => 0x10200000);
  $self->t_code( M_WARN         => 0x02000000);
  $self->t_code( M_FATAL        => 0x20400000);

  $self->t_code( M_F_INFO       => 0x51000000);
  $self->t_code( M_F_WARNING    => 0x42000000);
  $self->t_code( M_F_ERROR      => 0x64000000);
  $self->t_code( M_F_TRACE      => 0x50100000);
  $self->t_code( M_F_DEBUG      => 0x50200000);
  $self->t_code( M_F_WARN       => 0x42000000);
  $self->t_code( M_F_FATAL      => 0x60400000);

#  $self->t_code(  => 0x);
};

#-------------------------------------------------------------------------------
done_testing();
$app->cleanup;

File::Path::remove_tree('t/Constants');
exit(0);

################################################################################
#
sub t_code
{
  my( $self, $name, $code) = @_;

#say sprintf( "$name=%08x == %08x & %08x"
#           , $self->$name
#           , $code
#           , ~$self->M_LEVELMSK
#           );
  is( $self->$name & ~$self->M_LEVELMSK
    , $code
    , sprintf( "Code %s = 0x%08X", $name, $code)
    );
}

################################################################################
#
sub t_all_code
{
  my( $self, $name, $code) = @_;

#say sprintf( "$name=%08x == %08x & %08x"
#           , $self->$name
#           , $code
#           , ~$self->M_LEVELMSK
#           );
  is( $self->$name
    , $code
    , sprintf( "Code %s = 0x%08X", $name, $code)
    );
}


