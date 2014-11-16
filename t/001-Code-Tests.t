# Testing all modules for syntax errors
#
use Modern::Perl;
use Test::Most;

use_ok('AppState');

use_ok('AppState::Plugins::Feature::CommandLine');
use_ok('AppState::Plugins::Feature::ConfigManager');
use_ok('AppState::Plugins::Feature::Log');
use_ok('AppState::Plugins::Feature::NodeTree');
use_ok('AppState::Plugins::Feature::PluginManager');

use_ok('AppState::Plugins::ConfigDriver::DataDumper');
use_ok('AppState::Plugins::ConfigDriver::FreezeThaw');
use_ok('AppState::Plugins::ConfigDriver::Json');
use_ok('AppState::Plugins::ConfigDriver::Memcached');
use_ok('AppState::Plugins::ConfigDriver::Storable');
use_ok('AppState::Plugins::ConfigDriver::Yaml');

use_ok('AppState::Ext::ConfigFile');
use_ok('AppState::Ext::ConfigIO');
use_ok('AppState::Ext::Constants');
use_ok('AppState::Ext::Documents');
use_ok('AppState::Ext::Meta_Constants');
use_ok('AppState::Ext::Status');

use_ok('AppState::Plugins::Feature::NodeTree::Node');
use_ok('AppState::Plugins::Feature::NodeTree::NodeAttr');
use_ok('AppState::Plugins::Feature::NodeTree::NodeDOM');
use_ok('AppState::Plugins::Feature::NodeTree::NodeGlobal');
use_ok('AppState::Plugins::Feature::NodeTree::NodeRoot');
use_ok('AppState::Plugins::Feature::NodeTree::NodeText');


done_testing();
exit(0);
