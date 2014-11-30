# Testing module FreezeThaw.pm
#
use Modern::Perl;
use Test::More;
require File::Path;

use AppState;
use AppState::Plugins::ConfigManager::ConfigFile::Plugins::FreezeThaw;

#-------------------------------------------------------------------------------
# Init
#
my $as = AppState->instance;
$as->initialize( config_dir => 't/FreezeThaw', use_work_dir => 1);
$as->check_directories;

my $log = $as->get_app_object('Log');
$log->start_file_logging;
$log->file_log_level($as->M_TRACE);
$log->add_tag('310');

#-------------------------------------------------------------------------------
# Setup config using Yaml type
#
my $cf = AppState::Plugins::ConfigManager::ConfigFile::Plugins::FreezeThaw->new;

is( $cf->file_ext, 'fth', 'Check extension');

#-------------------------------------------------------------------------------
my $filename = "t/FreezeThaw/Work/testConfigFile." . $cf->file_ext;
$cf->_configFile($filename);
unlink $filename;
my $docs = $cf->load;
is( ref $docs, 'ARRAY', 'Check type of docs');
is( @$docs, 0, 'No documents');

#-------------------------------------------------------------------------------
$docs->[0] = { x => 'abc'};
$docs->[1] = { y => 'pqr'};
$cf->save($docs);

#-------------------------------------------------------------------------------
my $docs2 = $cf->load;
is( @$docs2, 2, 'Two documents');
is( $docs2->[0]{x}, 'abc', 'x -> abc');
is( $docs2->[1]{y}, 'pqr', 'y -> pqr');

#-------------------------------------------------------------------------------
done_testing();
$as->cleanup;

File::Path::remove_tree('t/FreezeThaw');


#-------------------------------------------------------------------------------
__END__

##########
done_testing();
exit(0);
##########


#-------------------------------------------------------------------------------

$cf->set_documents([[{}],{a => {b => 100}}]);
my $rootDoc = $cf->get_document;
my $v = [qw(b d jh e r t)];

$cf->set_value( '/pi/g', $v, $rootDoc->[0], $rootDoc->[1]);
$cf->set_value( '/pi/h', $v, $rootDoc->[0]);

is( $cf->get_value('/pi/g', $rootDoc->[0])
  , $cf->get_value('/pi/h', $rootDoc->[0])
  , "Same addresses"
  );

#-------------------------------------------------------------------------------
$log->write_log( ["Store code"], $a->M_INFO );

my $code = sub { return "Hello World"; };
$cf->set_value( '/my/code/tree/point', $code, $rootDoc->[0]);
my $c = $cf->get_value( '/my/code/tree/point', $rootDoc->[0]);
is( &$c, "Hello World", "Code from config runs");
$cf->save;

#-------------------------------------------------------------------------------
$log->write_log( ["Check after save and load"], $a->M_INFO );

$cf->load;

$rootDoc = $cf->get_document;
is( $cf->get_value('/pi/g', $rootDoc->[0])
  , $cf->get_value('/pi/h', $rootDoc->[0])
  , "Still same addresses"
  );

$code = $cf->get_value( '/my/code/tree/point', $rootDoc->[0]);
#say "Code: $code = ", &$code;
is( &$code, "Hello World", "Code reloaded and runs");

#-------------------------------------------------------------------------------
$log->write_log( ["Check after deep cloning"], $a->M_INFO );

my $clonedData = $cf->clone;
is( ref $clonedData->[0], 'ARRAY', "Test first cloned document");
is( ref $clonedData->[1], 'HASH', "Test second cloned document");
is( $cf->get_value( '/pi/g', $clonedData->[0][0])->[0], 'b'
  , "Test value in cloned documents"
  );
$cf->set_value( '/pi/i', $clonedData, $rootDoc->[0]);
$cf->save;

isnt( $rootDoc, $clonedData->[0], "Roots not the same");
my $clonedCode = $cf->get_value( '/my/code/tree/point', $clonedData->[0][0]);
isnt( $code, $clonedCode, "Code address not the same");
is( ref $clonedCode, 'CODE', "Test code ref");
is( &$clonedCode, "Hello World", "Code code runs the same");

