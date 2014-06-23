# Tests of text node
#
use Modern::Perl;
use Test::Most;

use AppState;
use AppState::NodeTree::NodeDOM;

#-------------------------------------------------------------------------------
# Init
#
my $app = AppState->instance;
$app->initialize( config_dir => 't/NodeDOM');
$app->check_directories;

my $log = $app->get_app_object('Log');
$log->show_on_error(0);
#$log->show_on_warning(1);
#$log->do_append_log(0);
#$log->do_flush_log(1);

$log->start_logging;

$log->log_mask($log->M_ERROR);
$app->log_init('701');

#-------------------------------------------------------------------------------
my $nt0 = AppState::NodeTree::NodeDOM->new;
isa_ok( $nt0, 'AppState::NodeTree::NodeDOM');

my $nt1 = AppState::NodeTree::NodeDOM->new;
$nt0->link_with_node($nt1);
is( $log->get_last_error, $nt0->C_NDM_NODENOTROOT, "Link went wrong");


$nt0->search_nodes( { type => $nt0->C_NDM_CMP_NAME
                    , strings => [ 'a']
                    }
                  );

is( $nt0->nbr_found_nodes, 0, 'Searching for a name shouldn\'t give any results');

$nt0->search_nodes( { type => $nt0->C_NDM_CMP_ATTR
                    , strings => [ 'a']
                    }
                  );

is( $nt0->nbr_found_nodes, 0, 'Searching for attributes shouldn\'t give any results');


$nt0->search_nodes( { type => $nt0->C_NDM_CMP_DATA
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
