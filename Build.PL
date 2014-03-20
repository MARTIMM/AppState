#!/usr/bin/perl
#
use 5.014003;
require Modern::Perl;
require Module::Build;
require Module::Build::ConfigData;

my $build = Module::Build->new
( module_name		=> 'AppState'
, license		=> 'perl'
, create_licence	=> 1
, dist_author		=> 'Marcel Timmerman <mt1957@gmail.com>'
, release_status	=> 'stable'
, abstract_from		=> 'lib/AppState.pm'

, tap_harness_args	=> { timer => 1
#			   , verbosity => 1
			   , failures => 1
			   , show_count => 1
			   }

, requires		=> { 'perl'			=> 'v5.14.3'
			   , 'Moose'                    => '2.0603'
                           , 'MooseX::NonMoose'         => '0.22'
			   , 'MooseX::Singleton'	=> 0
			   , 'Tree::XPathEngine'	=> 0
                           , 'Modern::Perl'             => '1.20121103'
                           , 'File::Spec'               => '3.33' #'3.40'
                           , 'YAML'                     => '0.84'
                           , 'Storable'                 => '2.27' #'2.39'
                           , 'FreezeThaw'               => '0.5001'
                           , 'Data::Dumper'             => '2.135'
                           , 'IPC::Msg'                 => '2.03'
#                          , 'Digest::MD5'              => '2.52'
#                          , 'Module::Load'             => '0.22'
                           , 'File::Path'               => '2.08'
			   }

, configure_requires	=> { 'Modern::Perl'		=> '1.20121103'
			   , 'Module::Build'		=> '0.4005'
			   , 'Software::License'	=> 0
			   , 'Test::Most'		=> 0
			   , 'Test::File::Content'	=> 0
			   , 'Devel::Size'		=> 0
			   , 'File::Path'		=> 0
			   , 'Test::Perl::Critic'	=> 0
			   , 'Perl::Critic'		=> 0
			   }
);


$build->create_build_script();
