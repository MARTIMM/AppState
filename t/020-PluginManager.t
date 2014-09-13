# Testing module AppState::Ext::Constants
#
use Modern::Perl;

use Test::Most;
use Moose;

use AppState::Plugins::Feature::PluginManager;

#-------------------------------------------------------------------------------
# Make object
#
my $pm = AppState::Plugins::Feature::PluginManager->new;
isa_ok( $pm, 'AppState::Plugins::Feature::PluginManager');

#-------------------------------------------------------------------------------
subtest 'Test some constants' =>
sub
{
  t_code( C_PLG_PLGDELETED => $pm->C_PLG_PLGDELETED);
  t_code( C_PLG_UNRECCREATE => $pm->C_PLG_UNRECCREATE);
  t_code( C_PLG_APISTUB => $pm->C_PLG_APISTUB);
};

#-------------------------------------------------------------------------------
subtest 'Search plugins' =>
sub
{
  $pm->search_plugins( { base => 'lib'
                       , max_depth => 4
                       , search_regex => qr@/AppState/Plugins/Feature/[A-Z][\w]+.pm$@
                       , api_test => [ qw(cleanup initialize)]
                       }
                     );
  my $pnames = [$pm->get_plugin_names];
  ok( 'Log' ~~ $pnames, 'Plugin Log found');
#  ok( 'Process' ~~ $pnames, 'Plugin Process found');
  ok( 'CommandLine' ~~ $pnames,  'Plugin CommandLine found');
  ok( 'NodeTree' ~~ $pnames,'Plugin NodeTree found');
  ok( 'PluginManager' ~~ $pnames, 'Plugin PluginManager found');
  ok( 'ConfigManager' ~~ $pnames, 'Plugin ConfigManager found');
};

#-------------------------------------------------------------------------------
done_testing();

File::Path::remove_tree('t/Pm');
exit(0);

#-------------------------------------------------------------------------------
#
sub t_code
{
  my( $name, $code) = @_;

#say sprintf( "$name=%08x == %08x & %08x"
#           , $self->$name
#           , $code
#           , ~$self->M_LEVELMSK
#           );
  ok( $pm->$name, sprintf( "Code %s = 0x%08X", $name, 0+$code));
}
