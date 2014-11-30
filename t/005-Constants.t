# Testing module AppState::Plugins::Log::Constants
#
use Modern::Perl;

use Test::Most;
use Moose;
extends 'AppState::Plugins::Log::Constants';

use AppState;
use AppState::Plugins::Log::Meta_Constants;

#-------------------------------------------------------------------------------
def_sts( 'CONST_1', 'M_WARNING', 'Constant warning');
def_sts( 'N'      , 'M_INFO', 'Message for constant N');
def_sts( 'M'      , 'M_INFO', 'Message for constant M');

#-------------------------------------------------------------------------------
# Make object
#
my $self = main->new;
isa_ok( $self, 'main');

$self->meta->make_immutable;
$self->log_init('005');

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
$log->die_on_fatal(0);
$log->do_append_log(0);
$log->start_file_logging;
$log->do_flush_log(1);
$log->file_log_level($as->M_TRACE);

is( $log->get_log_tag(ref $self), '005', 'Check log tag');

#-------------------------------------------------------------------------------
subtest 'Test to set a constant' =>
sub
{
  eval('$self->N(11);');

  is( $@ =~ m/Cannot assign a value to a read-only accessor/
    , 1
    , 'Cannot change constant N'
    );
};

#-------------------------------------------------------------------------------
subtest 'Test DC type constants' =>
sub
{
  $self->t_all_code( CONST_1 => $self->M_WARNING | 10);
  $self->t_all_code( N => $self->M_INFO | 10);
  $self->t_all_code( M => $self->M_INFO | 10);
};

#-------------------------------------------------------------------------------
done_testing();
$as->cleanup;

File::Path::remove_tree('t/Constants');
exit(0);

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
  ok( $self->$name >= $code
    , sprintf( "Syscode 0x%08X: Code %s >= 0x%08X"
             , 0 + $self->$name
             , $name
             , $code
             )
    );
}


