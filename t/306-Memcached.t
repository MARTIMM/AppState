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
$as->initialize( config_dir => 't/Memcached'
               , use_work_dir => 0
               , use_temp_dir => 0
               );
$as->check_directories;

my $log = $as->get_app_object('Log');
$log->start_logging;
$log->log_level($as->M_TRACE);
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
  is( $cf->file_ext, 'memcached', 'Check extension');
  is( $cf->get_control('servers')->[0], 'localhost:11211', 'Check a control item');

  #-----------------------------------------------------------------------------
  my $filename = "t/Memcached/Work/some-file-dont-care-what." . $cf->file_ext;
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


