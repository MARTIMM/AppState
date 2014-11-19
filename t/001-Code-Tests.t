# Testing all modules for syntax errors
#
use Modern::Perl;
use Test::Most;

use_ok('AppState');

use_ok('AppState::Plugins::CommandLine');

use_ok('AppState::Plugins::ConfigManager');
use_ok('AppState::Plugins::ConfigManager::ConfigFile');
use_ok('AppState::Plugins::ConfigManager::ConfigIO');
use_ok('AppState::Plugins::ConfigManager::Documents');
use_ok('AppState::Plugins::ConfigManager::ConfigFile::Plugins::DataDumper');
use_ok('AppState::Plugins::ConfigManager::ConfigFile::Plugins::FreezeThaw');
use_ok('AppState::Plugins::ConfigManager::ConfigFile::Plugins::Json');
use_ok('AppState::Plugins::ConfigManager::ConfigFile::Plugins::Memcached');
use_ok('AppState::Plugins::ConfigManager::ConfigFile::Plugins::Storable');
use_ok('AppState::Plugins::ConfigManager::ConfigFile::Plugins::Yaml');

use_ok('AppState::Plugins::Log');
use_ok('AppState::Plugins::Log::Constants');
use_ok('AppState::Plugins::Log::Meta_Constants');
use_ok('AppState::Plugins::Log::Status');

use_ok('AppState::Plugins::NodeTree');
use_ok('AppState::Plugins::NodeTree::Node');
use_ok('AppState::Plugins::NodeTree::NodeAttr');
use_ok('AppState::Plugins::NodeTree::NodeDOM');
use_ok('AppState::Plugins::NodeTree::NodeGlobal');
use_ok('AppState::Plugins::NodeTree::NodeRoot');
use_ok('AppState::Plugins::NodeTree::NodeText');

use_ok('AppState::Plugins::PluginManager');

done_testing();
exit(0);
