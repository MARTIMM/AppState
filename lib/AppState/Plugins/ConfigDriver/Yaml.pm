package AppState::Plugins::ConfigDriver::Yaml;

use Modern::Perl;
use version; our $VERSION = '' . version->parse("v0.2.5");
use 5.010001;

use namespace::autoclean;

use Moose;

extends qw(AppState::Ext::ConfigIO);

require YAML;
use Text::Tabs ();

#-------------------------------------------------------------------------------
#
has '+fileExt' => ( default => 'yml');

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;

  if( $self->meta->is_mutable )
  {
    $self->log_init('==Y');

    __PACKAGE__->meta->make_immutable;
  }
}

#-------------------------------------------------------------------------------
# Serialize to text
#
sub serialize
{
  my( $self, $documents) = @_;
  my( $script, $result);

  $script = '';

  # Get all options and set them locally
  #
  $script .= "local \$YAML::$_ = '" . $self->options->{$_} . "';\n"
    for (keys %{$self->options});

  # Dump data into result
  #
  $script .= '$result = YAML::Dump(@$documents);';

  # Evaluate and check for errors.
  #
  eval $script;
  if( my $e = $@ )
  {
    $self->wlog( "Failed to serialize YAML file:", $e
               , $self->C_CIO_SERIALIZEFAIL
               );
  }

  return $result;
}

#-------------------------------------------------------------------------------
# Deserialize to data
#
sub deserialize
{
  my( $self, $text) = @_;
  my( $script, $result);

  $script = '';
  $text //= '';

  # Get all options and set them locally
  #
  $script .= "local \$YAML::$_ = '" . $self->options->{$_} . "';\n"
    for (keys %{$self->options});

  # Load yaml text and convert into result
  #
  $script .= '$result = $text eq "" ? undef : [YAML::Load(Text::Tabs::expand($text))]';

  # Evaluate and check for errors.
  #
  eval $script;
  if( my $e = $@ )
  {
    $self->wlog( "Failed to deserialize YAML file "
               . $self->configFile . ": $e"
               , $self->C_CIO_DESERIALFAIL
               );
  }

  return $result;
}

#-------------------------------------------------------------------------------
# Deserialize to data
#
sub XYZdeserialize
{
  my( $self, $text) = @_;
  my( $script, $result);

  $script = '';
  $text //= '';

#  eval
  {
    # Get all options and set them locally
    #
    for my $o (keys %{$self->options})
    {
#      eval {local '$YAML::$o = ' . $self->options->{$o};};
    }

    # Load yaml text and convert into result
    #
    $result = $text eq "" ? undef : [YAML::Load(Text::Tabs::expand($text))];
  }

  if( my $e = $@ )
  {
    $self->wlog( "Failed to deserialize YAML file "
               . $self->configFile . ": $e"
               , $self->C_CIO_DESERIALFAIL
               );
  }

  return $result;
}

#-------------------------------------------------------------------------------

1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME
AppState::Config::Yaml - Storage plugin using Yaml

=head1 SYNOPSIS

  use AppState;

  my $cfg = AppState->instance->get_app_object('Config');
  $cfg->store_type('Yaml');
  $cfg->load;

  # Do something with the data ...

  $cfg->save({indent => 2});


=head1 DESCRIPTION

This module is a storage plugin module used by the
L<AppState::Config::ConfigFile> module which is in turm used
byL<AppState::Config>. This module is based on the YAML module of Matt S Trout. The
save() and load() procedures defined in L<AppState::Config::ConfigIO>.

=head1 METHODS

=over 2

=item * serialize($options)

Turn given documents into Yaml formatted text. $options is a hash reference.

=item * deserialize($options)

Turn given Yaml text into documents. The result returned is an array reference.
$options is a hash reference.

=back


=head1 OPTIONS

The following options can be given to load and save for the Yaml module. See
also L<YAML> from where the documentation is taken because this module uses
L<YAML>.

First options to be used with save();

=over 2

=item * DumperClass

You can override which module/class YAML uses for Dumping data.

=item * Indent

Indent is the number of space characters to use for
each indentation level. The default is 2.

=item * SortKeys

Sortkeys tells the underlying module whether or not to sort hash keys when
storing a document. default is 1 (true).

=item * UseHeader

This tells the Yaml module whether to use a separator string for a Dump
operation. This only applies to the first document in a stream. Subsequent
documents must have a YAML header by definition. Default is 1 (true).

=item * UseVersion

Tells Yaml whether to include the YAML version on the separator/header. Default
is 0 (false).

=item * AnchorPrefix

Anchor names are normally numeric. YAML.pm simply starts with '1' and increases
by one for each new anchor. This option allows you to specify a string to be
prepended to each anchor number. Default is the empty string ''.

=item * DumpCode

Determines if and how YAML.pm should serialize Perl code references. By default
YAML.pm will dump code references as dummy placeholders (much like
Data::Dumper). If DumpCode is set to '1' or 'deparse', code references will be
dumped as actual Perl code.

DumpCode can also be set to a subroutine reference so that you can write your
own serializing routine. YAML.pm passes you the code ref. You pass back the
serialization (as a string) and a format indicator. The format indicator is a
simple string like: 'deparse' or 'bytecode'.

=item * UseBlock

YAML.pm uses heuristics to guess which scalar style is best for a given
node. Sometimes you'll want all multiline scalars to use the 'block' style. If
so, set this option to 1.

NOTE: YAML's block style is akin to Perl's here-document.

=item * UseFold

If you want to force YAML to use the 'folded' style for all multiline scalars,
then set $UseFold to 1.

NOTE: YAML's folded style is akin to the way HTML folds text, except smarter.

=item * UseAliases

YAML has an alias mechanism such that any given structure in memory gets
serialized once. Any other references to that structure are serialized only as
alias markers. This is how YAML can serialize duplicate and recursive
structures.

Sometimes, when you KNOW that your data is nonrecursive in nature, you may want
to serialize such that every node is expressed in full. (ie as a copy of the
original). Setting $YAML::UseAliases to 0 will allow you to do this. This also
may result in faster processing because the lookup overhead is by bypassed.

THIS OPTION CAN BE DANGEROUS. *If* your data is recursive, this option *will*
cause Dump() to run in an endless loop, chewing up your computers memory. You
have been warned.

=item * CompressSeries

Compresses the formatting of arrays of hashes. Default is 1 (true).



=back


Now options to be used with load(). Also the documentation here is taken from
the L<YAML> module.

=over 2

=item * LoaderClass

You can override which module/class YAML uses for Loading data.

=item * LoadCode

LoadCode is the opposite of DumpCode. It tells YAML if and how to deserialize
code references. When set to '1' or 'deparse' it will use eval(). Since this is
potentially risky, only use this option if you know where your YAML has been.

LoadCode can also be set to a subroutine reference so that you can write your
own deserializing routine. YAML.pm passes the serialization (as a string) and a
format indicator. You pass back the code reference.

=back



The next few options can be used with both save and load(). Again, the
documentation here is taken from the L<YAML> module.

=over 2


=item * UseCode

Setting the UseCode option is a shortcut to set both the DumpCode and LoadCode
options at once. Setting UseCode to '1' tells YAML.pm to dump Perl code
references as Perl (using B::Deparse) and to load them back into memory using
eval(). The reason this has to be an option is that using eval() to parse
untrusted code is, well, untrustworthy.

=back



=head1 BUGS

No bugs yet.

=head1 AUTHOR

Marcel Timmerman, E<lt>mt1957@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Marcel Timmerman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
