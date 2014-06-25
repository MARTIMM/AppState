# Testing module Memcached.pm
#
use Modern::Perl;
use Test::More;
require File::Path;

use AppState;
use AppState::Plugins::ConfigDriver::Memcached;

#-------------------------------------------------------------------------------
# Init
#
my $as = AppState->instance;
$as->initialize( config_dir => 't/Memcached');
$as->check_directories;


my $log = $as->get_app_object('Log');
#$log->show_on_error(0);
#$log->show_on_warning(1);
#$log->do_append_log(0);
#$log->do_flush_log(1);

$log->start_logging;

$log->log_level($as->M_ERROR);

$log->add_tag('306');

#pass('Initialized');

#-------------------------------------------------------------------------------
# Setup config using Memcached type
#
my $cf = AppState::Plugins::ConfigDriver::Memcached->new;
$cf->options( { Deparse => 1, Eval => 1});
$cf->control( { servers => [qw( localhost:11211)]
              , debug => 0
              , compress_threshold => 10_000
              , namespace => '306_Memcached'
              }
            );

SKIP:
{
  my $hr = $cf->stats([qw(misc)]);
  $log->get_last_error != $cf->C_CIO_NOSERVER or skip('No server available');
#  say join( ', ', map {"$_ = $hr->{$_}"} keys %$hr);

  #-----------------------------------------------------------------------------
  is( $cf->fileExt, 'memcached', 'Check extension');
  is( $cf->getControl('servers')->[0], 'localhost:11211', 'Check a control item');

  #-----------------------------------------------------------------------------
  my $filename = "t/Memcached/Work/some-file-dont-care-what." . $cf->fileExt;
  $cf->_configFile($filename);
  $cf->delete;

  my $docs = $cf->load;
  is( ref $docs, 'ARRAY', 'Check type of docs');
  is( @$docs, 0, 'No documents');

  #-----------------------------------------------------------------------------
  $docs->[0] = { x => 'abc'};
  $docs->[1] = { y => 'pqr'};
  $docs->[2] = { z => sub {return 1999 + $_[0];}};
  $cf->save($docs);

  #-----------------------------------------------------------------------------
  my $docs2 = $cf->load;
  is( @$docs2, 3, 'Three documents');
  is( $docs2->[0]{x}, 'abc', 'x -> abc');
  is( $docs2->[1]{y}, 'pqr', 'y -> pqr');
  is( ref $docs2->[2]{z}, 'CODE', 'Check code');
  is( &{$docs2->[2]{z}}(1), 2000, 'Check run of code');
}

#-------------------------------------------------------------------------------
$cf->delete;
done_testing();
$as->cleanup;

File::Path::remove_tree('t/Memcached');




__END__



#-------------------------------------------------------------------------------
# Init
#
my $as = AppState->instance;
my $m = $as->get_app_object('Constants');
$as->initialize( config_dir => 't/Memcached');
$as->check_directories;

my $log = $as->get_app_object('Log');
#$log->die_on_error(1);
#$log->show_on_error(0);
#$log->show_on_warning(1);
#$log->do_append_log(0);
#$log->do_flush_log(1);

$log->start_logging;

$log->log_level($m->M_ERROR);

#pass('Initialized');

$as->log_init('301');

#-------------------------------------------------------------------------------
# Setup config using Memcached type
#
my $filename = "t/Memcached/Work/testConfigFile";
my $cf = $as->get_app_object('ConfigManager');
$cf->store_type('Memcached');
$cf->location($m->C_CFG_FILEPATH);
$cf->requestFile($filename);
$cf->init( { Deparse => 1, Eval => 1}
         , { servers => [qw( localhost:11211)]
#        , { servers => [qw( 192.168.0.11:11211)]
           , debug => 0
           , compress_threshold => 10_000
           }
         );

#-------------------------------------------------------------------------------
$log->write_log( ["Generate anchors. Should give same addresses"], $m->M_INFO);

#$cf->add_documents([{}],{a => {b => 100}});
$cf->set_documents([[{}],{a => {b => 100}}]);
my $rootDoc = $cf->get_document;
my $v = [qw(b d jh e r t)];

$cf->set_value( '/pi/g', $v, $rootDoc->[0]);
$cf->set_value( '/pi/h', $v, $rootDoc->[0]);

is( $cf->get_value('/pi/g', $rootDoc->[0])
  , $cf->get_value('/pi/h', $rootDoc->[0])
  , "Same addresses"
  );

#-------------------------------------------------------------------------------
$log->write_log( ["Store code"], $m->M_INFO );

my $code = sub { return "Hello World"; };
$cf->set_value( '/my/code/tree/point', $code, $rootDoc->[0]);
$cf->save;

#-------------------------------------------------------------------------------
$log->write_log( ["Check after save and load"], $m->M_INFO);

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
$log->write_log( ["Check after deep cloning"], $m->M_INFO);

my $clonedData = $cf->clone;

is( ref $clonedData->[0], 'ARRAY', "Test first cloned document");
is( ref $clonedData->[1], 'HASH', "Test second cloned document");
is( $cf->get_value( '/pi/g'
  , $clonedData->[0][0])->[0], 'b'
  , "Test value in cloned documents"
  );
$cf->set_value( '/pi/i', $clonedData, $rootDoc->[0]);
$cf->save;

isnt( $rootDoc, $clonedData->[0], "Roots not the same");
my $clonedCode = $cf->get_value( '/my/code/tree/point', $clonedData->[0][0]);
isnt( $code, $clonedCode, "Code address not the same");
is( ref $clonedCode, 'CODE', "Test code ref");
is( &$clonedCode, "Hello World", "Code code runs the same");

#-------------------------------------------------------------------------------

done_testing();
$as->cleanup;

File::Path::remove_tree('t/Memcached');


#-------------------------------------------------------------------------------
__END__

