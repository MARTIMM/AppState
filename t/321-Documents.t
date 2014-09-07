# Testing module Documents.pm
#
use Modern::Perl;
use Test::Most;
require File::Path;

use AppState;
use AppState::Ext::Documents;
#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/Documents', check_directories => 1);

my $log = $app->get_app_object('Log');
$log->do_append_log(0);
$log->start_logging;
$log->log_level($app->M_TRACE);
$log->stderr_log_level($app->M_ERROR);
$log->add_tag('320');

#-------------------------------------------------------------------------------
my $d = AppState::Ext::Documents->new;

$d->add_documents({});
$d->select_document(0);

#-------------------------------------------------------------------------------
subtest get_value =>
sub
{
  ok( !defined $d->get_value('/a/b/c'), '/a/b/c not defined');
  my $doc = $d->get_document(0);
#  ok( !exists $doc->{a}, 'a does not exist');

$log->log($d->C_DOC_NOHASHREF);
};

#-------------------------------------------------------------------------------
#$d->save;

done_testing();
$app->cleanup;

#File::Path::remove_tree('t/Documents');

