package AppState::Plugins::Feature::CommandLine;

use Modern::Perl;
use version; our $VERSION = version->parse('v0.2.2');
use 5.010001;

#use namespace::autoclean -also => qr/^_/;
use namespace::autoclean;

use Moose;
extends qw(AppState::Ext::Constants);

use AppState;
use File::Basename ();

use Getopt::Long ();
Getopt::Long::Configure(qw(bundling_override auto_abbrev no_getopt_compat));
use Text::Wrap ('$columns');
local $columns = 80;

use AppState::Ext::Meta_Constants;

#-------------------------------------------------------------------------------
# Error codes
#
const( 'C_CMD_OPTPROCESSED', 'M_INFO', 'Options processed');
const( 'C_CMD_OPTCHANGED',   'M_INFO', 'Option processing changed: %s');
const( 'C_CMD_OPTPROCFAIL',  'M_F_WARNING', 'There are errors processing commandline options');
const( 'C_CMD_NODESCRIPTION','M_F_WARNING', 'Description of command not defined');

#-------------------------------------------------------------------------------

has _arguments =>
    ( is                => 'ro'
    , isa               => 'ArrayRef'
    , default           => sub { return []; }
    , init_arg          => undef
    , writer            => '_set_arguments'
    , traits            => ['Array']
    , handles           =>
      { get_arguments   => 'elements'
      }
    );

has _options =>
    ( is                => 'ro'
    , isa               => 'HashRef'
    , traits            => ['Hash']
    , default           => sub { return {}; }
    , handles           =>
      { get_option      => 'get'    
      , set_option      => 'set'    
      , option_exists   => 'exists' 
      , get_options     => 'keys'
      }
    , writer            => '_set_options'
    , init_arg          => undef
    );

has usage =>
    ( is                => 'ro'
    , isa               => 'Str'
    , writer            => '_set_usage'
    , default           => ''
    , init_arg          => undef
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;

  $self->log_init('=CL');
}

#-------------------------------------------------------------------------------
#
sub plugin_cleanup
{
  my($self) = @_;
}

#-------------------------------------------------------------------------------
# Modify processing of options
#
sub config_getopt_long
{
  my( $self, @processingOptions) = @_;

  Getopt::Long::Configure(@processingOptions);
  $self->log( $self->C_CMD_OPTCHANGED, [join( ' ', @processingOptions)]);
}

#-------------------------------------------------------------------------------
# Get all information from the arguments to setup text to display help text
# with usage(). Also modify options and set arguments.
#
sub initialize
{
  my( $self, $description, $argumentSet, $optionSet, $usersUsage, $examples) = @_;

  return $self->log($self->C_CMD_NODESCRIPTION) unless defined $description;

  # Initialize arguments.
  #
  $argumentSet //= [];
  $optionSet //= [];
  $examples //= [];

  # Remove spaces etc from description
  #
  $description =~ s/\n/ /g;
  $description =~ s/\s+/ /g;

  my $indent = '    ';

  # Get the filename of the currently running program(= $0)
  #
  my( $progname, $path, $suffix) = File::Basename::fileparse($0);

  # Write the first part showing the description and program usage
  #
  my $usage = (defined $usersUsage and ref $usersUsage eq 'ARRAY')
                    ? join( "\n    ", @$usersUsage)
                    : $progname
                      . (scalar @$optionSet ? ' <options>' : '')
                      . ( scalar @$argumentSet
                          ? ' ' . join( ' ', map {"<$_->[0]>"} @$argumentSet)
                          : ''
                        )
                    ;
  $usage = "\n  Description\n"
         . Text::Wrap::wrap( $indent, $indent, $description)
         . "\n\n  Usage\n    $usage\n"
         ;

  # Describe the arguments
  #
  $usage .= "\n  Arguments\n" if scalar @$argumentSet;
  foreach my $a (@$argumentSet)
  {
    my( $aDescr, $aHelp) = @$a;
    $aHelp =~ s/\n/ /g;
    $aHelp =~ s/\s+/ /g;

    $usage .= Text::Wrap::wrap( '', ' ' x 20
                              , sprintf( "%-18s  ", "$indent$aDescr")
                              , $aHelp
                              )
           . "\n\n";
  }

  # Describe the options
  #
  my @getOptions;
  $usage .= "\n  Options\n" if scalar @$optionSet;
  foreach my $o (@$optionSet)
  {
    my $otxt = $indent;

    my( $oDescr, $oHelp) = @$o;
    push @getOptions, $oDescr;

    $oHelp =~ s/\n/ /g;
    $oHelp =~ s/\s+/ /g;

    my( $tspec, $type, $tdest, $trep) =
       $oDescr =~ m/([\!\+\=\:])([siof])?([%@])?(\{\d*(,\d*)\})?$/;
    $oDescr =~ s///;

    my( $name, @aliases) = split( /\|/, $oDescr);
    foreach my $o ( $name, @aliases)
    {
      $otxt .= ( length($o) == 1 ? '-' : '--' ) . $o . ' ';
    }

    $tspec //= '';
    $type //= '';
    $tdest //= '';
    $trep //= '';

    $type = 'string' if $type eq 's';
    $type = 'integer' if $type eq 'i';
    $type = 'extended' if $type eq 'o';
    $type = 'real' if $type eq 'f';
    $otxt .= $type;

    $otxt .= ($tspec eq '+' ? ' repeatable' : '');
    $otxt .= ($tspec eq '!' ? ' negatable' : '');
    $otxt .= ($tspec eq ':' ? ' optional' : '');

    $otxt .= ($tdest eq '@' ? ' list' : '');
    $otxt .= ($tdest eq '%' ? ' hash' : '');

    $otxt .= ($trep  ? " needs $trep values" : '');

    my $ltxt = length($otxt);
    if( $ltxt > 18 )
    {
      $usage .= sprintf( "%-20s\n", "$otxt")
             . Text::Wrap::wrap( ' ' x 20, ' ' x 20, $oHelp)
             . "\n\n";
    }

    else
    {
      $usage .= Text::Wrap::wrap( '', ' ' x 20
                                , sprintf( "%-18s  ", "$otxt")
                                , $oHelp
                                )
             . "\n\n";
    }
  }

  # Describe the examples if any
  #
  $usage .= "\n  Examples\n" if scalar @$examples;
  foreach my $e (@$examples)
  {
    my( $eCmd, $eDescr) = @$e;

    $eDescr =~ s/\n/ /g;
    $eDescr =~ s/\s+/ /g;

    my $eIndentComment = "    # ";
    $usage .= Text::Wrap::wrap( $eIndentComment, $eIndentComment
                              , $eDescr
                              )
           . "\n    #\n    $eCmd\n\n";
  }



  $usage .= "\n";
  $self->_set_usage($usage);

  my $options = $self->_options;
  my $sts = Getopt::Long::GetOptions( $options, @getOptions);
  if( $sts )
  {
    $self->_set_options($options);
    $self->_set_arguments([@ARGV]);

    $self->log($self->C_CMD_OPTPROCESSED);
  }

  else
  {
    $self->_set_options({});
    $self->_set_arguments([]);

    $self->log($self->C_CMD_OPTPROCFAIL);
  }
}

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;
1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState::CommandLine - Perl extension to control commandline arguments and
options

=head1 SYNOPSIS


=head1 DESCRIPTION



=head2 EXPORT

None by default.



=head1 SEE ALSO


=head1 AUTHOR

Marcel Timmerman, E<lt>mt1957@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Marcel Timmerman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.3 or,
at your option, any later version of Perl 5 you may have available.


=cut

