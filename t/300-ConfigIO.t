# Testing module ConfigIO.pm
#
use Modern::Perl;
use Test::More;
require File::Path;

#-------------------------------------------------------------------------------
use Moose;
extends qw(AppState::Ext::ConfigIO);

use AppState;
use AppState::Plugins::ConfigDriver::Yaml;

#-------------------------------------------------------------------------------
# Init
#
my $as = AppState->instance;
$as->initialize( config_dir => 't/ConfigIO'
               , use_work_dir => 1
               , check_directories => 1
               );

my $log = $as->get_app_object('Log');
$log->start_logging;
$log->file_log_level($as->M_ERROR);
$log->add_tag('300');

#-------------------------------------------------------------------------------
# Setup
#
has '+file_ext' => ( default => 'yml');

my $self = main->new;
$self->options( { Indent => 1, SortKeys => 1, UseBlock => 0
                , AnchorPrefix => 'x', UseVersion => 1
                , DumpCode => 1, LoadCode => 1, UseCode => 1
                }
              );
$self->control( { server => 'localhost', port => '99299'});

#-------------------------------------------------------------------------------
# Check setup config
#
is( $self->file_ext, 'yml', 'Check extension');
is( $self->get_option('Indent'), 1, 'Check an option');
is( $self->get_control('port'), 99299, 'Check a control item');

#-------------------------------------------------------------------------------
# File does not exist.
#
my $filename = "t/ConfigIO/WorkX/testConfigFile.yml";
$self->_configFile($filename);
$log->clear_last_error;
my $docs = $self->load;
ok( $log->get_last_error == $self->C_CIO_CFGNOTREAD
  , 'Load error, path is wrong'
  );

# Change and try again
#
$log->clear_last_error;
$filename = "t/ConfigIO/Work/testConfigFile.yml";
$self->_configFile($filename);
unlink $filename;

$docs = $self->load;
is( ref $docs, 'ARRAY', 'Check type of docs');
is( @$docs, 0, 'No documents');

$docs->[0] = 'abc';

#-------------------------------------------------------------------------------
# Modify doc and save, again first with wrong path
#
$filename = "t/ConfigIO/WorkX/testConfigFile.yml";
$self->_configFile($filename);
$log->clear_last_error;
$self->save($docs);

is( $log->get_last_error
  , 0 + $self->C_CIO_CFGNOTWRITTEN
  , 'Save error, path is wrong'
  );

# Change and try again
#
$log->clear_last_error;
$filename = "t/ConfigIO/Work/testConfigFile.yml";
$self->_configFile($filename);

$self->save($docs);
is( -e $filename, 1, 'Check existence of file');


#-------------------------------------------------------------------------------

done_testing();
$as->cleanup;

File::Path::remove_tree('t/ConfigIO');


#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
#
sub serialize
{
  my( $self, $documents) = @_;
  return $documents->[0];
}

#-------------------------------------------------------------------------------
#
sub deserialize
{
  my( $self, $text) = @_;
  return defined $text ? [$text] : undef;
}

#-------------------------------------------------------------------------------
#
sub close
{
  my( $self, $documents) = @_;
}


#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
__END__

##########
done_testing();
exit(0);
##########
