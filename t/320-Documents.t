# Testing module Documents.pm, document handling
#
use Modern::Perl;
use Test::Most;
use Test::Deep;
require File::Path;

use AppState;
use AppState::Ext::Documents;
#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/Documents');
$app->check_directories;

my $log = $app->get_app_object('Log');
$log->start_logging;
$log->log_level($app->M_TRACE);
#$log->stderr_log_level($app->M_TRACE);

$log->add_tag('320');

#-------------------------------------------------------------------------------
my $d = AppState::Ext::Documents->new;
isa_ok( $d, 'AppState::Ext::Documents');

subtest empty_document =>
sub
{
  is( $d->get_current_document, undef, 'Current document number = undef');
  is( $d->get_document(0), undef, 'Document 0 = undef');
  is( $d->get_document, undef, 'Document(Current document) = undef');
  is( scalar(@{$d->get_documents}), 0, 'Nbr of docs = 0');
};

#-------------------------------------------------------------------------------
subtest set_documents =>
sub
{
  $d->set_documents( [ {a => 10, b => 11}, [qw( 1 2 3 4 a b c d)]]);

  $d->select_document(1);
  is( $d->get_current_document, 1, 'Current document = 1');

  cmp_deeply( $d->get_document(0), {a => 10, b => 11}, 'Check document 0');
  is( $d->get_current_document, 1, 'Current document still 1');
  cmp_deeply( $d->get_document(1), [ 1..4, qw( a b c d)], 'Check document 1');

  is( ref $d->get_document, 'ARRAY', 'Document(Current document) = ARRAY');
  is( scalar( @{$d->get_documents}), 2, 'Get 2 docs');
  is( $d->nbr_documents, 2, 'Nbr docs = 2');

  is( ref $d->get_document(2), '', 'Document 2 = undef');
  $d->select_document(2);
  is( $log->get_last_error, $d->C_DOC_SELOUTRANGE, 'Check select failure');
  is( $d->get_current_document, 0, 'Current document = 0');
  is( ref $d->get_document, 'HASH', 'Document 0 = HASH');

  $d->set_documents( [ 1, [qw( bc ab de)]]);
  is( $d->get_current_document, undef, 'Current document = undef');
  is( ref $d->get_document(1), 'ARRAY', 'Document 1 = ARRAY');
};

#-------------------------------------------------------------------------------
done_testing();
$app->cleanup;

File::Path::remove_tree('t/Documents');




__END__
