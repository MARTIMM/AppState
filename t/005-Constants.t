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
isa_ok( $self, 'main');

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

is( $log->getLogTag(ref $self), '005', 'Check log tag');
$log->write_log( "Message 1", 1|$log->M_INFO);
$self->wlog( "Message 2", 1|$log->M_INFO);

#-------------------------------------------------------------------------------
subtest 'Constants test and set constant' =>
sub
{
  is( $self->M_SUCCESS, 0x01000000, 'Check constant success = 0x01000000');
  is( $self->N, 0x1100007b, 'Check new constant value N = 0x1100007b');

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

  is( $self->M_SUCCESS, 0x01000000, 'Check constant success = 0x01000000');
  is( $self->N, 0x1100007b, 'Check new constant value N = 0x1100007b');
};

#-------------------------------------------------------------------------------
subtest 'Drop main and test again' =>
sub
{
  $self = undef;
  $self = main->new;

  is( $self->M_SUCCESS, 0x01000000, 'Check constant success = 0x01000000');
  is( $self->N, 0x1100007b, 'Check new constant value N = 0x1100007b');
};

#-------------------------------------------------------------------------------
subtest 'Test all codes' =>
sub
{
  $self->t_code( M_ALL => 0xFFFFFFFF);
  $self->t_code( M_NONE => 0);

  $self->t_code( M_EVNTCODE => 0xFF);
  $self->t_code( M_SEVERITY => 0xFF000000);
  $self->t_code( M_MSGMASK => 0xFF0000FF);
  $self->t_code( M_RESERVED => 0x00FFFF00);

  $self->t_code( M_SUCCESS => 0x01000000);
  $self->t_code( M_FAIL => 0x02000000);

  $self->t_code( M_INFO => 0x10000000);
  $self->t_code( M_WARNING => 0x20000000);
  $self->t_code( M_ERROR => 0x40000000);
  $self->t_code( M_FORCED => 0x80000000);

  $self->t_code( M_F_INFO => 0x90000000);
  $self->t_code( M_F_WARNING => 0xA0000000);
  $self->t_code( M_F_ERROR => 0xB0000000);

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


