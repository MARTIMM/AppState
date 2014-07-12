package AppState::Plugins::Feature::PluginManager;

use Modern::Perl;
use version; our $VERSION = '' . version->parse("v0.1.6");
use 5.010001;

use namespace::autoclean;

use Modern::Perl;
use Moose;
use MooseX::NonMoose;

extends qw( Class::Publisher AppState::Ext::Constants);

use AppState;

require File::Find;
require Cwd;

#-------------------------------------------------------------------------------
# Structure with all objects
#
has plugged_objects =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , default           => sub { return {}; }
    , init_arg          => undef
    , traits            => ['Hash']
    , handles           =>
      { add_plugin              => 'set'
      , get_plugin              => 'get'
      , delete_plugin            => 'delete'
      , get_plugin_names        => 'keys'
      , plugin_exists           => 'exists'
      , plugin_defined           => 'defined'
      , clear_plugins            => 'clear'
      , nbr_plugins             => 'count'
      }
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;

  # Cannot use methods here which use an instance of AppState because
  # plugin_manager is created when the AppState is in its instantiation phase
  # and when executing a line such as 'AppState->instance()' the program will
  # get into deep recursion loop.
  #
  #$self->log_init('=PM');

  if( $self->meta->is_mutable )
  {
    # Error codes
    #
#    $self->code_reset;
    $self->const( 'C_PLG_PLGDELETED',   'M_INFO', 'Plugin object %s deleted (undefined)');
    $self->const( 'C_PLG_PLGREMOVED',   'M_INFO', 'Plugin entry %s removed');
    $self->const( 'C_PLG_PLGNOTDEF',    'M_FATAL', 'Plugin entry %s not defined');
    $self->const( 'C_PLG_PLGDEFINED',   'M_INFO', 'Plugin entry %s defined');
    $self->const( 'C_PLG_PLGKEYNOTDEF', 'M_FATAL', 'Key %s not defined');
    $self->const( 'C_PLG_PLGCREATED',   'M_INFO', 'Object %s created');
    $self->const( 'C_PLG_PLGRETRVED',   'M_INFO', 'Object %s retrieved');
    $self->const( 'C_PLG_UNRECCREATE',  'M_INFO', 'Unrecognized create flag');
    $self->const( 'C_PLG_APIFAIL',      'M_FATAL', 'Object %s cannot do %s()');
    $self->const( 'C_PLG_APISTUB',      'M_F_WARNING', 'Called generated stub %s::%s()');
    $self->const( 'C_PLG_PLGCODEFAIL',  'M_FATAL', 'Error evaluating code');
    $self->const( 'C_PLG_PLGEXISTS',    'M_F_ERROR', 'Plugin exists, not added');
#    $self->const( 'C_PLG_', '');

    # Object creation codes
    #
    $self->const( 'C_PLG_NOCREATE',     'M_CODE', 'Do not create plugin if not exists');
    $self->const( 'C_PLG_CREATEIF',     'M_CODE', 'Create plugin if not exists');
    $self->const( 'C_PLG_CREATEALW',    'M_CODE', 'Create plugin always');

    __PACKAGE__->meta->make_immutable;
  }
}

#-------------------------------------------------------------------------------
sub initialize
{
  my ( $self) = @_;
  $self->log_init('=PM');
}

#-------------------------------------------------------------------------------
sub DEMOLISH
{
  my ( $self) = @_;
  $self->delete_all_subscribers;
}

#-------------------------------------------------------------------------------
# Run cleanup() on every plugin object if 1) the object exists and 2) that
# object has a cleanup function.
#
sub cleanup
{
  my( $self, $list, @arguments) = @_;

  foreach my $pluginName (ref $list eq 'ARRAY' ? @$list : $self->get_plugin_names)
  {
    # Get object. If there is one, call cleanup() if there followed by
    # the destruction of the object.
    #
    my $c = $self->check_plugin($pluginName);
    if( ref $c )
    {
      $self->log( $self->C_PLG_PLGDELETED, [$pluginName]);
      $c->cleanup(@arguments) if $c->can('cleanup');
      $self->get_plugin($pluginName)->{object} = undef;
    }
  }
}

#-------------------------------------------------------------------------------
# Search for plugins in directories.
#
sub search_plugins
{
  my( $self, $search) = @_;

  my $baseDir = $search->{base};
  my $depthSearch = $search->{depthSearch};
  my $searchRegex = $search->{searchRegex};
  my $apiTest = $search->{apiTest};

  my @modulePathList;

  my $spl = File::Find::find
  ( { bydepth => 1
    , follow => 0
    , wanted =>
      sub
      { my $path = $File::Find::dir;
        my $fname = $_;

        # The depth of a path is measured by the number of separators (/)
        #
        my $lseps = $path =~ m@(/)@g;
        my $pathOk = ( $depthSearch >= 0 + $lseps
                       and "$path/$fname" =~ $searchRegex
                       and ! -d "$path/$fname"
                     );

        push @modulePathList, "$path/$fname" if $pathOk;
      }
    }
  , $baseDir
  );

  # Initialize the plugin objects
  #
  foreach my $mp (@modulePathList)
  {
    my $namespace = $mp;
    $namespace =~ s/$baseDir\/?//;
    my $name = $namespace;
    $name =~ s@[^/]+/@@g;
    $name =~ s/\.[^.]+$//;

    $namespace =~ s/\.[^.]+$//;
    $namespace =~ s@/@::@g;

    if( $self->plugin_exists($name) )
    {
      $self->log($self->C_PLG_PLGEXISTS);
    }

    else
    {
      $self->add_plugin( $name => { object => undef
                                  , class => $namespace
                                  , libdir => $baseDir
                                  , apiTest => $apiTest
                                  }
                       );
    }
  }
}

#-------------------------------------------------------------------------------
# Instead of search give the specific path names of the modules.
#
sub set_plugins
{
  my( $self, $set) = @_;

  my $baseDir = $set->{base};
  my $apiTest = $set->{apiTest};
  my $modules = $set->{modules};

  # When path doesn't exist, realpath() will return undef.
  #
  my @modulePathList = map {Cwd::realpath($_)} @$modules;

  # Initialize the plugin objects
  #
  foreach my $mp (@modulePathList)
  {
    next unless defined $mp;

    my $namespace = $mp;
    $namespace =~ s/$baseDir\/?//;
    my $name = $namespace;
    $name =~ s@[^/]+/@@g;
    $name =~ s/\.[^.]+$//;

    $namespace =~ s/\.[^.]+$//;
    $namespace =~ s@/@::@g;


    if( $self->plugin_exists($name) )
    {
      $self->log($self->C_PLG_PLGEXISTS);
    }

    else
    {
      $self->add_plugin( $name => { object => undef
                                  , class => $namespace
                                  , libdir => $baseDir
                                  , apiTest => $apiTest
                                  }
                       );
    }
  }
}

#-------------------------------------------------------------------------------
# Bit of debug purpose
#
sub list_plugin_names
{
  my($self) = @_;
  foreach my $name (sort $self->get_plugin_names)
  {
    say STDERR " $name, ", $self->get_plugin($name)->{class};
  }
}

#-------------------------------------------------------------------------------
# Check state of a plugin
# Returns
#   undef       if no entry is found by that name
#   1           if entry is found but no object is created
#   object ref  entry found and object is created.
#
sub check_plugin
{
  my( $self, $name) = @_;

  return undef unless $self->plugin_defined($name);
  my $plObj = $self->get_plugin($name)->{object};
  return 1 unless ref $plObj;
  return $plObj;

# -old-
#  return undef unless exists $self->plugged_objects->{$name};
#  return 1 unless ref $self->plugged_objects->{$name}{object};
#  return $self->plugged_objects->{$name}{object};
}

#-------------------------------------------------------------------------------
# Undefine the plugin object
#
sub cleanup_plugin
{
  my( $self, $name) = @_;

  if( $self->plugin_exists($name) )
  {
    if( ref $self->plugged_objects->{$name}{object} )
    {
      $self->get_plugin($name)->{object} = undef;
      $self->log( $self->C_PLG_PLGDELETED, [$name]);
    }
  }
}

#-------------------------------------------------------------------------------
# Undefine and remove entry of the plugin object
#
sub drop_plugin
{
  my( $self, $name) = @_;

  if( $self->plugin_exists($name) )
  {
    $self->get_plugin($name)->{object} = undef;
    $self->delete_plugin($name);
    $self->log( $self->C_PLG_PLGREMOVED, $name);
  }
}

#-------------------------------------------------------------------------------
# Test if config given by name has an object defined or not. Return undef if
# there is no plugin config given by name .
#
sub has_object
{
  my( $self, $name) = @_;
  my $has_object;

  if( $self->plugin_defined($name) )
  {
    my $plugin = $self->get_plugin($name);
    my $object = $plugin->{object};
    $has_object = ref $object ? 1 : 0;
  }

  else
  {
    $self->log( $self->C_PLG_PLGNOTDEF, [$name]);
  }

  return $has_object
}

#-------------------------------------------------------------------------------
# Create plugin depending on the following values of the create option
#       0 Don't create if it isn't there
#       1 Create only once, next call gets same object, default
#       2 Create always. Address in not stored
#
sub get_object
{
  my( $self, $select) = @_;

  my $name = $select->{name};
  unless( defined $name )
  {
    $self->log( $self->C_PLG_PLGKEYNOTDEF, [$name]);
    return undef;
  }

  my $object;
  my $classCreated = 0;

  my $create = $select->{create};
  $create //= $self->C_PLG_CREATEIF;

  my %iOptions = ref $select->{initOptions} eq 'HASH'
                 ? %{$select->{initOptions}}
                 : ();
  my %mOptions = ref $select->{modifyOptions} eq 'HASH'
                 ? %{$select->{modifyOptions}}
                 : ();
  my $apiTest;

#say "GO: $name, $create, $self";

  # Check if there is a plugin by that name
  #
  if( $self->plugin_defined($name) )
  {
    my $plugin = $self->get_plugin($name);
    if( $create == $self->C_PLG_NOCREATE )
    {
      $object = $plugin->{object};
      if( defined $object )
      {
        $self->log( $self->C_PLG_PLGNOTDEF, [$name]);
      }
      
      else
      {
        $self->log( $self->C_PLG_PLGDEFINED, [$name]);
      }
    }

    # Create only when there is no object. If it is there return that one
    #
    elsif( $create == $self->C_PLG_CREATEIF )
    {
      if( !defined $plugin->{object} )
      {
        my $class = $plugin->{class};
        my $lib = $plugin->{libdir};

        eval(<<EOEVAL);
push \@INC, '$lib';
require $class;
EOEVAL
        die "\nModule $class has problems\n\n$@" if $@;

        # Create new object with init options
        #
        $plugin->{object} = $class->new( %iOptions, %mOptions);
        $classCreated = 1;
      }

      $object = $self->plugged_objects->{$name}{object};
      if( $classCreated )
      {
        $self->log( $self->C_PLG_PLGCREATED, [$name]);
      }
      
      else
      {
        $self->log( $self->C_PLG_PLGRETRVED, [$name]);
      }
    }

    # Create always. This object will not be stored
    #
    elsif( $create == $self->C_PLG_CREATEALW )
    {
      my $class = $plugin->{class};
      my $lib = $plugin->{libdir};
      eval(<<EOEVAL);
push \@INC, '$lib';
require $class;
EOEVAL
      die "\nModule '$class' has problems\n\n$@" if $@;

      # Create new object with init options
      #
      $object = $class->new( %iOptions, %mOptions);
      $classCreated = 1;

      $self->log( $self->C_PLG_PLGCREATED, [$name]);
    }

    else
    {
      $self->log($self->C_PLG_UNRECCREATE);
      $object = undef;
    }
  }

  else
  {
    my( $p, $f, $l, $s) = caller;
    $self->log( $self->C_PLG_PLGNOTDEF, [$name]);
    $object = undef;
  }

  if( ref $object )
  {
    # If object is created make this fact known to the world.
    #
    if( $classCreated )
    {
      $object->initialize if $object->can('initialize');
      $self->notify_subscribers( ref $object, object => $object);
    }

    else
    {
      # Modify object with modifiable options if not created anew
      #
      foreach my $o (keys %mOptions)
      {
        $object->$o($mOptions{$o});
      }
    }

    # Check object for obligatory functions
    #
    my $plugin = $self->get_plugin($name);
    $apiTest = $plugin->{apiTest};
    if( ref $apiTest eq 'ARRAY' )
    {
      for my $f (@$apiTest)
      {
        my $class = $plugin->{class};
        if( !$object->can($f) )
        {
          $self->log($self->C_PLG_APIFAIL, [ $class, $f]);

          # Create function to prevent crashes
          #
          my $cmd =<<EOCODE;
sub ${class}::$f
{
  say "Called generated stub ${class}::$f()";
  \$self->log( $self->C_PLG_APISTUB, [ $class, $f]);
}
EOCODE
          eval($cmd);
          $self->log( "Error evaluating code", $self->C_PLG_PLGCODEFAIL) if $@;
        }
      }
    }
  }

  return $object;
}

#-------------------------------------------------------------------------------
no Moose;
#__PACKAGE__->meta->make_immutable;

1;
#-------------------------------------------------------------------------------
__END__
#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState::PluginManager - Perl extension to

=head1 SYNOPSIS


=head1 DESCRIPTION

=head1 METHODS

=item * get_app_object( $name, $options)

Get the object of a specific plugin. Use C<$name> to select the proper plugin. Use
get_plugin_names() of the plugin_manager to check for the proper names.
C<$options> is a hashreference with the following keys;

=over 2

=item * B<name> => name of plugin entry.

This name is generated automatically from the plugin module found from which
the end '.pm' is stripped.

=item * B<create> => create code

Code which specifies the way

=back






=head1 SEE ALSO


=head1 AUTHOR

Marcel Timmerman, E<lt>mt1957@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Marcel Timmerman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.3 or,
at your option, any later version of Perl 5 you may have available.



=cut
