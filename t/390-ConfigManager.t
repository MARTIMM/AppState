# Testing module ConfigManager.pm
#
use Modern::Perl;
use Test::More;
require File::Path;

use AppState;

#-------------------------------------------------------------------------------
# Init
#
my $config_dir = 't/ConfigManager';
my $app = AppState->instance;
$app->initialize( config_dir => $config_dir
                , use_work_dir => 1
                , use_temp_dir => 1
                , check_directories => 1
                );

my $log = $app->get_app_object('Log');
$log->do_append_log(0);
$log->start_logging;

# Some tests are dealing with success stories
#
$log->log_level($app->M_TRACE);
$log->add_tag('390');

#-------------------------------------------------------------------------------
$log->write_log( "Tests of default config object", $log->M_INFO);

my $cfm = $app->get_app_object('ConfigManager');
isa_ok( $cfm, 'AppState::Plugins::Feature::ConfigManager'
      , 'Check config object type');

$cfm->request_file('configManager');

is( $cfm->current_config_object_name, 'defaultConfigObject', "Check default name");
is( $cfm->store_type, 'Yaml', "Check default store type");
is( $cfm->location, $cfm->C_CFF_CONFIGDIR, "Check default location");

is( $cfm->request_file, 'configManager', "Check request file");
unlink $cfm->config_file;

$cfm->load;
$cfm->save;

my $f = $cfm->config_file;
$f =~ s@.*?([^/]+)$@$1@;
ok( -e $cfm->config_file, "Test(1) $f now exists");

#-------------------------------------------------------------------------------
$log->write_log( "Modify default config object", 1|$log->M_INFO);

# When dieonerr == 1
#eval("\$cfm->select_config_object('ddump');");
#my $err = $@;
#ok( $err =~ m/CFG \d+ \* Config 'ddump' not existent/, "Check $err");

# When dieonerr == 0
$cfm->select_config_object('someConfigObject');
is( $log->get_last_error
  , $cfm->C_CFM_CFGNOTEXIST
  , "config object name 'someConfigObject' should not exist"
  );

#-------------------------------------------------------------------------------
$log->write_log( "Add config object", 1|$log->M_INFO);
$cfm->add_config_object( 'ddump', { store_type  => 'DataDumper'
                                  , location    => $cfm->C_CFF_WORKDIR
                                  , request_file => 'myConfig'
                                  }
                       );
$cfm->load;
$cfm->save;

$f = $cfm->config_file;
$f =~ s@.*?([^/]+)$@$1@;
ok( -e $cfm->config_file, "Test(2) $f exists");

my $configObjList = join( ' ', sort $cfm->get_config_object_names);
is( $configObjList, 'ddump defaultConfigObject', "Check list of object names");

$cfm->select_config_object('defaultConfigObject');
is( $log->get_last_error
  , $cfm->C_CFM_CFGSELECTED
  , "config object name 'defaultConfigObject' selected"
  );

#-------------------------------------------------------------------------------
$log->write_log( "Testing load and save", $log->M_INFO);
$cfm->load;
is( $cfm->nbr_documents, 0, "No documents");

$log->write_log( "Add two documents", 1|$log->M_INFO);
$cfm->add_documents( {}
                  , [ qw(a b c d)
                    , { abc => 'def', p => {def => 223}}
                    ]
                  );

$log->write_log( "Overwrite first document", 1|$log->M_INFO);
$cfm->set_document( undef, { pqr => 'xyz', def => 390});

is( $cfm->nbr_documents, 2, "Two documents");
$log->write_log( "Number of documents:" . $cfm->nbr_documents, $log->M_INFO);

$log->write_log( "Save it and load", 1|$log->M_INFO);
$cfm->save;
$cfm->load;

$log->write_log( "Check data again", 1|$log->M_INFO);
is( $cfm->nbr_documents, 2, "Still two documents");

#-------------------------------------------------------------------------------
$log->write_log( "Access functions", 1|$log->M_INFO);
$cfm->select_document(1);
my $rootDoc = $cfm->get_document;
is( join( ', ', sort @{$cfm->get_keys( '/', $rootDoc->[4])})
  , 'abc, p'
  , "Check get_keys with hook"
  );

is( $cfm->get_value( '/abc', $rootDoc->[4]), 'def', "Check get_value with hook");


$cfm->add_documents([{}]);
$cfm->select_document(2);
ok( $cfm->nbr_documents == 3, "Three documents");

$rootDoc = $cfm->get_document;
$cfm->set_value( '/pi', {abc => 1, def => 2, ghi => []}, $rootDoc->[0]);
is( $cfm->get_value( '/pi/abc', $rootDoc->[0]), '1', "Check set_value with hook");

$cfm->drop_value( '/pi/abc', $rootDoc->[0]);
is( $cfm->get_value( '/pi/abc', $rootDoc->[0])
  , undef, "Check drop_value with hook"
  );

$cfm->set_kvalue( '/pi/abc', '/path/to/something', 'Test1', $rootDoc->[0]);
is( $cfm->get_kvalue( '/pi/abc', '/path/to/something', $rootDoc->[0])
  , 'Test1', "Check set_kvalue and get_kvalue with hook"
  );

$cfm->set_kvalue( '/pi/abc', '/path/to/something/else', 'Test2', $rootDoc->[0]);
is( $cfm->get_kvalue( '/pi/abc', '/path/to/something/else', $rootDoc->[0])
  , 'Test2', "Prepare drop_kvalue with hook"
  );
$cfm->drop_kvalue( '/pi/abc', '/path/to/something/else', $rootDoc->[0]);
is( $cfm->get_kvalue( '/pi/abc', '/path/to/something/else', $rootDoc->[0])
  , undef, "Check drop_kvalue with hook"
  );

$cfm->push_value( '/pi/ghi', [qw(b d jh e r t)], $rootDoc->[0]);
is( $cfm->pop_value( '/pi/ghi', $rootDoc->[0])
  , 't', "Check push_value and pop_value with hook"
  );

$cfm->unshift_value( '/pi/f', [qw(b d jh e r t)], $rootDoc->[0]);
is( $cfm->shift_value( '/pi/f', $rootDoc->[0])
  , 'b', "Check unshift_value and shift_value with hook"
  );

$cfm->save;

#-------------------------------------------------------------------------------
$log->write_log( "Testing drop config object", 1|$log->M_INFO);
$cfm->select_config_object('ddump');
my $ddumpFilename = $cfm->config_file;

$cfm->drop_config_object('ddump');
is( $log->get_last_error, $cfm->C_CFM_CFGDROPPED, "Drop op ok");

ok( $cfm->has_config_object('ddump') == 0, "Config object ddump dropped");
ok( -e $ddumpFilename, "File for config ddump still exist");

$cfm->add_config_object( 'ddump', { store_type     => 'DataDumper'
                                , location      => $cfm->C_CFF_WORKDIR
                                , request_file   => 'myConfig'
                                }
                     );
$cfm->store_type('Yaml');
unlink $cfm->config_file;

$f = $cfm->config_file;
$f =~ s@.*?([^/]+)$@$1@;
ok( !-e $cfm->config_file, "Yaml config '$f' does not exist");
$cfm->save;
ok( -e $cfm->config_file, "Yaml config does now");

#-------------------------------------------------------------------------------
# Copy is not limited to same storage type! Here done to get same size result
#
$log->write_log( "Testing copy documents from one file to the other", 1|$log->M_INFO);

$cfm->select_config_object('defaultConfigObject');
is( $log->get_last_error
  , $cfm->C_CFM_CFGSELECTED
  , "config object name 'defaultConfigObject' selected"
  );
my $sizefn1 = -s $cfm->config_file;
$cfm->load;
my $documents = $cfm->get_documents;

$cfm->select_config_object('ddump');
is( $log->get_last_error
  , $cfm->C_CFM_CFGSELECTED
  , "config object name 'defaultConfigObject' selected"
  );
$cfm->set_documents($documents);
$cfm->save;
my $sizefn2 = -s $cfm->config_file;
ok( $sizefn1 == $sizefn2, "Sizes should be the same");

#-------------------------------------------------------------------------------
$log->write_log( "Testing modify object", 1|$log->M_INFO);
$cfm->modify_config_object( 'ddump', { store_type => 'Json'
                                     , location => $cfm->C_CFF_TEMPDIR
                                     }
                          );
unlink $cfm->config_file;

$f = $cfm->config_file;
$f =~ s@.*?([^/]+)$@$1@;
ok( !-e $cfm->config_file, "Json config '$f' does not exist yet");
$cfm->save;
ok( -e $cfm->config_file, "Json config exists");

#-------------------------------------------------------------------------------
$log->write_log( "Testing remove config object", 1|$log->M_INFO);

$cfm->modify_config_object( 'ddump', { store_type => 'Storable'
                                     , location => $cfm->C_CFF_WORKDIR
                                     }
                          );
#unlink $cfm->config_file;

$cfm->save;
my $filename = $f = $cfm->config_file;
$f =~ s@.*?([^/]+)$@$1@;
ok( -e $filename, "Storable config $f created");
$cfm->remove_config_object('ddump');
is( $log->get_last_error, $cfm->C_CFM_CFGFLREMOVED, "Remove op ok");
ok( !-e $filename, "Storable config will not exist anymore");

#-------------------------------------------------------------------------------
done_testing();
$app->cleanup;

File::Path::remove_tree( $config_dir);



