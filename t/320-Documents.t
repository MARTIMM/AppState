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
my $as = AppState->instance;
$as->initialize( config_dir => 't/Documents');
$as->check_directories;

my $log = $as->get_app_object('Log');
$log->show_on_error(0);
#$log->show_on_warning(1);
$log->do_append_log(0);

$log->start_logging;

$log->do_flush_log(1);
$log->log_mask($as->M_SEVERITY);

$log->add_tag('320');

#-------------------------------------------------------------------------------
my $d = AppState::Ext::Documents->new;

is( $d->get_current_document, undef, 'Current document number = undef');
is( $d->get_document(0), undef, 'Document 0 = undef');
is( $d->get_document, undef, 'Document(Current document) = undef');
is( scalar(@{$d->get_documents}), 0, 'Nbr of docs = 0');

#$d->select_document(1);

#-------------------------------------------------------------------------------
$d->set_documents( [ {a => 10, b => 11}, [qw( 1 2 3 4 a b c d)]]);
$d->select_document(1);

is( $d->get_current_document, 1, 'Current document = 1');
is( ref $d->get_document(0), 'HASH', 'Document 0 = HASH');
is( ref $d->get_document(1), 'ARRAY', 'Document 1 = ARRAY');
is( ref $d->get_document, 'ARRAY', 'Document(Current document) = ARRAY');
is( scalar(@{$d->get_documents}), 2, 'Get docs = 2');

is( ref $d->get_document(2), '', 'Document 2 = undef');
$d->select_document(2);
is( $log->get_last_error, $d->C_DOC_SELOUTRANGE, 'Check select failure');
is( $d->get_current_document, 0, 'Current document = 0');
is( ref $d->get_document, 'HASH', 'Document 0 = HASH');

$d->set_documents( [ 1, [qw( bc ab de)]]);
is( $d->get_current_document, undef, 'Current document = undef');
is( ref $d->get_document(1), 'ARRAY', 'Document 1 = ARRAY');

#-------------------------------------------------------------------------------
done_testing();
$as->cleanup;

File::Path::remove_tree('t/Documents');




__END__
