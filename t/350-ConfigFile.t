# Testing module AppState::Ext::ConfigFile
#
use Modern::Perl;
use Test::More;
require File::Path;
require Cwd;

use AppState;
use AppState::Ext::ConfigFile;

#-------------------------------------------------------------------------------
# Init
#
my $config_dir = 't/ConfigFile';
my $as = AppState->instance;
$as->initialize( config_dir => $config_dir);
$as->check_directories;

my $log = $as->get_app_object('Log');
#$log->show_on_error(0);
$log->show_on_warning(1);
$log->do_append_log(0);

$log->start_logging;

$log->do_flush_log(1);
$log->log_mask($as->M_SEVERITY);

$log->add_tag('350');


$log->write_log( "Create tempfile $config_dir/Temp/abc.tmp", $log->M_INFO);
system( "touch $config_dir/Temp/abc.tmp");

#-------------------------------------------------------------------------------
BEGIN { use_ok('AppState::Ext::ConfigFile') };

$log->write_log( "Test new()", $log->M_INFO);
my $cf = AppState::Ext::ConfigFile->new;
is( ref $cf, 'AppState::Ext::ConfigFile', "Test new()");

done_testing();
File::Path::remove_tree( $config_dir, {verbose => 1});
exit(0);
__END__

#-------------------------------------------------------------------------------
# Test storage type setting
#
$l->write_log( ["Testing storage type handling"], $m->M_INFO);

#diag( 'Storage plugins: ', (join ', ', $cf->get_plugin_names));
#diag( "PList 0: ", $cf->nbr_plugins);
#diag( "PList 1: ", $cf->list_plugin_names);

ok( $cf->nbr_plugins >= 5, "At least 5 plugins as of 2013-08-17");

$cf->store_type('Json');
is( $cf->store_type(), 'Json', 'Check if storage type is set to Json');

eval("\$cf->store_type('YYY')");
ok( $@ =~ m/Attribute \(store_type\) does not pass the type constraint because/
  , "Test wrong storage type"
  );

#-------------------------------------------------------------------------------
# Location code testing
#
$l->write_log( ["Testing location code handling"], $m->M_INFO);

$cf->location($m->C_CFG_FILEPATH);
ok( $cf->location == $m->C_CFG_FILEPATH, "Test location C_CFG_FILEPATH");

eval("\$cf->location(0x4ae167)");
ok( $@ =~ m/Attribute \(location\) does not pass the type constraint because/
  , "Test wrong location code"
  );

#-------------------------------------------------------------------------------
# Request input filename
#
$l->write_log( ["Testing filename setting"], $m->M_INFO);

$cf->store_type('Yaml');
$cf->location($m->C_CFG_CONFIGDIR);
my $filename = "/home/marcel/Temp/abc.xyz";
$cf->requestFile($filename);

is( $cf->requestFile(), $filename, "Check request filename $filename");
is( $cf->configFile(), Cwd::cwd() . "/$config_dir/abc.yml"
  , "Check result config filename"
  );

#$cf->location($m->C_CFG_FILEPATH);

#-------------------------------------------------------------------------------

done_testing();
$app->cleanup;

File::Path::remove_tree( $config_dir, {verbose => 1});


#-------------------------------------------------------------------------------
__END__

