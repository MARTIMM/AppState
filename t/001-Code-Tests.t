# Testing all modules for syntax errors
#
use Modern::Perl;
use Test::Most;

use_ok('AppState');

use_ok('AppState::Plugins::CommandLine');
use_ok('AppState::Plugins::ConfigManager');
use_ok('AppState::Plugins::Log');
use_ok('AppState::Plugins::NodeTree');
use_ok('AppState::Plugins::PluginManager');

use_ok('AppState::Plugins::ConfigDriver::DataDumper');
use_ok('AppState::Plugins::ConfigDriver::FreezeThaw');
use_ok('AppState::Plugins::ConfigDriver::Json');
use_ok('AppState::Plugins::ConfigDriver::Memcached');
use_ok('AppState::Plugins::ConfigDriver::Storable');
use_ok('AppState::Plugins::ConfigDriver::Yaml');

use_ok('AppState::Ext::ConfigFile');
use_ok('AppState::Ext::ConfigIO');
use_ok('AppState::Plugins::Log::Constants');
use_ok('AppState::Ext::Documents');
use_ok('AppState::Plugins::Log::Meta_Constants');
use_ok('AppState::Ext::Status');

use_ok('AppState::Plugins::NodeTree::Node');
use_ok('AppState::Plugins::NodeTree::NodeAttr');
use_ok('AppState::Plugins::NodeTree::NodeDOM');
use_ok('AppState::Plugins::NodeTree::NodeGlobal');
use_ok('AppState::Plugins::NodeTree::NodeRoot');
use_ok('AppState::Plugins::NodeTree::NodeText');


done_testing();
exit(0);
