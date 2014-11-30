# Tests of text node
#
use Modern::Perl;
use Test::Most;

use AppState;
use AppState::Plugins::NodeTree::NodeDOM;
use AppState::Plugins::Log::Meta_Constants;

#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/NodeDOM');
$app->check_directories;

my $log = $app->get_app_object('Log');
$log->start_file_logging;

$log->file_log_level($log->M_ERROR);
$app->log_init('701');

#-------------------------------------------------------------------------------
my $nt0 = AppState::Plugins::NodeTree::NodeDOM->new;
isa_ok( $nt0, 'AppState::Plugins::NodeTree::NodeDOM');

my $nt1 = AppState::Plugins::NodeTree::NodeDOM->new;
$nt0->link_with_node($nt1);
ok( $log->get_last_error == $nt0->E_NODENOTROOT, "Link went wrong");


$nt0->search_nodes( { type => $nt0->C_CMP_NAME
                    , strings => [ 'a']
                    }
                  );

is( $nt0->nbr_found_nodes, 0, 'Searching for a name shouldn\'t give any results');

$nt0->search_nodes( { type => $nt0->C_CMP_ATTR
                    , strings => [ 'a']
                    }
                  );

is( $nt0->nbr_found_nodes, 0, 'Searching for attributes shouldn\'t give any results');


$nt0->search_nodes( { type => $nt0->C_CMP_DATA
                    , strings => [ 'a']
                    }
                  );

is( $nt0->nbr_found_nodes, 0, 'Searching for data shouldn\'t give any results');

#-------------------------------------------------------------------------------
# Drop the instance and remove directories
#
done_testing();
$app->cleanup;
File::Path::remove_tree('t/NodeDOM');
exit(0);
