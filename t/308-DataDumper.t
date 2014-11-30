# Testing module DataDumper.pm
#
use Modern::Perl;
use Test::More;
require File::Path;

use AppState;
use AppState::Plugins::ConfigManager::ConfigFile::Plugins::DataDumper;

#-------------------------------------------------------------------------------
# Init
#
my $as = AppState->instance;
$as->initialize( config_dir => 't/DataDumper', use_work_dir => 1);
$as->check_directories;

my $log = $as->get_app_object('Log');
$log->start_file_logging;
$log->file_log_level($as->M_TRACE);
$log->add_tag('308');

#-------------------------------------------------------------------------------
# Setup config using DataDumper type
#
my $cf = AppState::Plugins::ConfigManager::ConfigFile::Plugins::DataDumper->new;
$cf->options( { Indent => 1, Purity => 1, Deparse => 1});

is( $cf->file_ext, 'dd', 'Check extension');
is( $cf->get_option('Indent'), 1, 'Check an option');

#-------------------------------------------------------------------------------
my $filename = "t/DataDumper/Work/testConfigFile." . $cf->file_ext;
$cf->_configFile($filename);
unlink $filename;
my $docs = $cf->load;
is( ref $docs, 'ARRAY', 'Check type of docs');
is( @$docs, 0, 'No documents');

#-------------------------------------------------------------------------------
$docs->[0] = { x => 'abc'};
$docs->[1] = { y => 'pqr'};
$docs->[2] = { z => sub {return 1999 + $_[0];}};
$cf->save($docs);

#-------------------------------------------------------------------------------
my $docs2 = $cf->load;
is( @$docs2, 3, 'Two documents');
is( $docs2->[0]{x}, 'abc', 'x -> abc');
is( $docs2->[1]{y}, 'pqr', 'y -> pqr');
is( ref $docs2->[2]{z}, 'CODE', 'Check code');
is( &{$docs2->[2]{z}}(1), 2000, 'Check run of code');

#-------------------------------------------------------------------------------

done_testing();
$as->cleanup;

File::Path::remove_tree('t/DataDumper');

