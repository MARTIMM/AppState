# Testing module Documents.pm for 'no autovivification'
#
use Modern::Perl;
use Test::Most;
use Test::Deep;

require File::Path;
require Data::Dumper;

use AppState;
use AppState::Plugins::ConfigManager::Documents;
#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/Documents', check_directories => 1);

my $log = $app->get_app_object('Log');
$log->do_append_log(0);
$log->start_file_logging;
$log->file_log_level( { level => $app->M_INFO, package => 'root'});
#$log->stderr_log_level($app->M_TRACE);
$log->add_tag('320');

#-------------------------------------------------------------------------------
my $d = AppState::Plugins::ConfigManager::Documents->new;

$d->add_documents({});
$d->select_document(0);
my $doc = $d->get_document(0);

# Set a path in the doc for startRef tests and set $hook to the
# second value in the array.
#
$d->set_value( '/hook', [ 'a', {}]);
my $hook = $d->get_item_value( '/hook', 1);
cmp_deeply( $doc->{hook}, [ 'a', {}], 'Test hook start data');

#-------------------------------------------------------------------------------
subtest getx_value =>
sub
{
  my $v = $d->get_value('/a/b/c/d');
  is( ref $v, 'AppState::Plugins::Log::Status', 'return status for errors');
  ok( $v->get_error == $d->C_DOC_NOVALUE, 'value at /a/b/c/d not defined');
  ok( !exists $doc->{a}, 'a does not exist');

  $v = $d->get_kvalue( '/p', 'a 1/5');
  ok( $v->get_error == $d->C_DOC_NOVALUE, "value at /p/'a 1/5' not defined");
  ok( !exists $doc->{p}, 'p does not exist');

  $v = $d->get_value( '/a/b/c/d', $hook);
  ok( $v->get_error == $d->C_DOC_NOVALUE, 'value /a/b/c/d at hook not defined');
  ok( !exists $doc->{hook}[1]{a}, 'hooked a does not exist');

  $v = $d->get_kvalue( '/p', 'a 1/5', $hook);
  ok( $v->get_error == $d->C_DOC_NOVALUE, "value /p/'a 1/5' at hook not defined");
  ok( !exists $doc->{hook}[1]{p}, 'p does not exist');
};

#-------------------------------------------------------------------------------
subtest setx_value =>
sub
{
  my $hr = $d->set_value( '/a/b/c/d', 10);
  cmp_deeply( $hr, \10, 'Test $hr = \10');
  is( $d->get_value('/a/b/c/d'), 10, 'value at /a/b/c/d is set to 10');

  $d->set_kvalue( '/p', 'a 1/5', 10);
  is( $d->get_kvalue( '/p', 'a 1/5'), 10, "value at /p/'a 1/5' is set to 10");
  $d->set_kvalue( '/p', 'a 1/6', 11);
  is( $d->get_kvalue( '/p', 'a 1/5'), 10, "value at /p/'a 1/5' still set to 10");
  is( $d->get_kvalue( '/p', 'a 1/6'), 11, "value at /p/'a 1/6' is set to 11");

  $hr = $d->set_value( '/a/b/c/d', 11, $hook);
  cmp_deeply( $hr, \11, 'Test $hr = \11');
  is( $d->get_value( '/a/b/c/d', $hook), 11, 'value /a/b/c/d at hook is set to 11');
  cmp_deeply( $doc->{hook}[1]{a}, {b=>{c=>{d=>11}}}, 'hook = 11');

#my $dd = Data::Dumper->new( [$d->get_value('/')], [qw(root)]);
#say $dd->Dump;
#exit(0);

  $d->set_kvalue( '/p', 'a 1/5', 11, $hook);
  is( $d->get_kvalue( '/p', 'a 1/5', $hook), 11, "value at /p/'a 1/5' is set to 11");
  cmp_deeply( $doc->{hook}[1]{p}, {'a 1/5' => 11}, 'keyed hook = 11');
};

#-------------------------------------------------------------------------------
subtest dropx_value =>
sub
{
  my $v = $d->drop_value('/a/b/c/d');
  is( $v, 10, 'value saved from /a/b/c/d is 10');
  ok( !exists $doc->{a}{b}{c}{d}, '/a/b/c/d does not exist anymore');
  ok( exists $doc->{a}{b}{c}, '/a/b/c still exist');

  $v = $d->drop_value('/a/b/c/d');
  is( ref $v, 'AppState::Plugins::Log::Status', 'not possible to remove /a/b/c/d again');
  ok( $v->get_error == $d->C_DOC_KEYNOTEXIST, 'key d not existent');

  $v = $d->drop_value('a');
  ok( !exists $doc->{a}, '/a does not exist anymore');

  $v = $d->drop_kvalue( '/p', 'a 1/5');
  is( $v, 10, "value at /p/'a 1/5' was 10");
  cmp_deeply( $doc->{p}, {'a 1/6' => 11}, 'a 1/5 gone');
  $v = $d->drop_kvalue( '/p', 'a 1/6');
  is( $v, 11, "value at /p/'a 1/6' was 11");
  cmp_deeply( $doc->{p}, {}, 'a 1/6 also gone');

  $v = $d->drop_kvalue( '/p', 'a 1/5');
  ok( !defined $v, "No value found at /p', 'a 1/5'");


  $v = $d->drop_value( '/a/b/c/d', $hook);
  is( $v, 11, 'value saved from /a/b/c/d is 11');
  ok( !exists $doc->{a}{b}{c}{d}, '/a/b/c/d does not exist anymore at hook');
  ok( exists $doc->{a}{b}{c}, '/a/b/c still exist at hook');

  $v = $d->drop_value( 'a', $hook);
  ok( !exists $doc->{hook}->[1]{a}, '/a does not exist anymore at hook');

  $v = $d->drop_kvalue( '/p', 'a 1/5', $hook);
  is( $v, 11, "value at /p/'a 1/5' was 11 at hook");
  $v = $d->get_kvalue( '/p', 'a 1/5', $hook);
  ok( $v->get_error == $d->C_DOC_NOVALUE, "value at /p/'a 1/5' dropped at hook");

  $v = $d->drop_kvalue( '/p', 'a 1/5', $hook);
  ok( !defined $v, "No value found at hook");
};

#-------------------------------------------------------------------------------
subtest popx_value =>
sub
{
  my $hr = $d->set_value( '/a/b/c/d', [5..10]);
  is( ref $hr, 'REF', '$hr is a reference to a reference');
  is( ref $$hr, 'ARRAY', '$$hr is a reference to an ARRAY');
  is( $d->pop_value('/a/b/c/d'), 10, "Value at the end of the array was 10");
  is( $d->pop_value('/a/b/c/d'), 9, "Value at the end of the array was 9");

  $hr = $d->set_kvalue( '/p', 'a 1/5', [8..13]);
  is( ref $hr, 'REF', '$hr is a reference to a reference');
  is( ref $$hr, 'ARRAY', '$$hr is a reference to an ARRAY');
  is( $d->pop_kvalue( '/p', 'a 1/5'), 13, "Value at the end of the array was 13");
  is( $d->pop_kvalue( '/p', 'a 1/5'), 12, "Value at the end of the array was 12");
};

#-------------------------------------------------------------------------------
subtest pushx_value =>
sub
{
  my $hr = $d->push_value( '/a/b/c/d', [ 1, 2]);
  is( ref $hr, 'REF', '$hr is a reference to a reference');
  is( ref $$hr, 'ARRAY', '$$hr is a reference to an ARRAY');
  is( $d->pop_value('/a/b/c/d'), 2, "Value at the end of the array was 2");

  $hr = $d->push_kvalue( '/p', 'a 1/5', [ 3, 4]);
  is( ref $hr, 'REF', '$hr is a reference to a reference');
  is( ref $$hr, 'ARRAY', '$$hr is a reference to an ARRAY');
  is( $d->pop_kvalue( '/p', 'a 1/5'), 4, "Value at the end of the array was 4");
};

#-------------------------------------------------------------------------------
subtest shiftx_value =>
sub
{
  is( $d->shift_value('/a/b/c/d'), 5, "Value at the start of the array was 5");
  is( $d->shift_value('/a/b/c/d'), 6, "Value at the start of the array was 6");

  is( $d->shift_kvalue( '/p', 'a 1/5'), 8, "Value at the start of the array was 8");
};

#-------------------------------------------------------------------------------
subtest shiftx_value =>
sub
{
  my $hr = $d->unshift_value( '/a/b/c/d', [22..26]);
  is( ref $hr, 'REF', '$hr is a reference to a reference');
  is( ref $$hr, 'ARRAY', '$$hr is a reference to an ARRAY');
  is( $d->shift_value('/a/b/c/d'), 22, "Value at the start of the array was 22");

  $hr = $d->unshift_kvalue( '/p', 'a 1/5', [3..5]);
  is( ref $hr, 'REF', '$hr is a reference to a reference');
  is( ref $$hr, 'ARRAY', '$$hr is a reference to an ARRAY');
  is( $d->shift_kvalue( '/p', 'a 1/5'), 3, "Value at the start of the array was 3");
};

#-------------------------------------------------------------------------------
subtest splicex_value =>
sub
{
  # At "/a/b/c/d":  [ 23, 24, 25, 26, 7, 8, 1]
  # Splice off + len + list
  #
  my $hr = $d->splice_value( '/a/b/c/d', [ 2, 2, 122..125]);
  cmp_deeply( $hr
            , \[ 23, 24, 122..125, 7, 8, 1]
            , 'Return spliced: off + len + list'
            );

  cmp_deeply( $doc->{a}
            , {b => {c => {d => [ 23, 24, 122..125, 7, 8, 1]}}}
            , 'Doc spliced: off + len + list'
            );

  # Splice off + len
  #
  $d->splice_value( '/a/b/c/d', [ 2, 2]);
  cmp_deeply( $doc->{a}
            , {b => {c => {d => [ 23, 24, 124, 125, 7, 8, 1]}}}
            , 'Doc spliced: off + len'
            );

  # Splice off
  #
  $d->splice_value( '/a/b/c/d', [ 3]);
  cmp_deeply( $doc->{a}
            , {b => {c => {d => [ 23, 24, 124]}}}
            , 'Array correctly spliced: off'
            );

  # At "p/'a 1/5'"  [ 4, 5, 9, 10, 11, 3]
  # -> []
  #
  $hr = $d->splice_kvalue( '/p', 'a 1/5', [ 2, 2, 33..36]);
  cmp_deeply( $doc->{p}
            , {'a 1/5' => [ 4, 5, 33..36, 11, 3]}
            , 'Doc kspliced: off + len + list'
            );

  $hr = $d->splice_kvalue( '/p', 'a 1/5', [ 2, 2]);
  cmp_deeply( $doc->{p}
            , {'a 1/5' => [ 4, 5, 35, 36, 11, 3]}
            , 'Doc kspliced: off + len'
            );
};

#-------------------------------------------------------------------------------
subtest itemx_value =>
sub
{
  # Get 'a/b/c/d'->[2]
  #
  is( $d->get_item_value( '/a/b/c/d', 2), 124, "3rd item is 124");

  # Get "p/'a 1/5'"->[3]
  #
  is( $d->get_item_kvalue( '/p', 'a 1/5', 3), 36, "4th item is 36");

#my $dd = Data::Dumper->new( [$doc], [qw(doc)]);
#say $dd->Dump;
};

#-------------------------------------------------------------------------------

done_testing();
$app->cleanup;

File::Path::remove_tree('t/Documents');





__END__
#my $dd = Data::Dumper->new( [$doc], [qw(doc)]);
#say $dd->Dump;










