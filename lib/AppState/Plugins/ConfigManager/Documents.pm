package AppState::Plugins::ConfigManager::Documents;

use Modern::Perl;
use version; our $VERSION = version->parse('v0.0.4');
use 5.010001;

use namespace::autoclean;
no autovivification qw(fetch exists delete);

use Moose;
use Moose::Util::TypeConstraints;
extends 'AppState::Plugins::Log::Constants';

use AppState;
use AppState::Plugins::Log::Meta_Constants;

#-------------------------------------------------------------------------------
# Error codes. These codes must also be handled by ConfigManager.
#
def_sts( 'C_DOC_SELOUTRANGE',  'M_ERROR', 'Document number %s out of range, document not %s');
def_sts( 'C_DOC_DOCRETRIEVED', 'M_TRACE', 'Document %s retrieved');
def_sts( 'C_DOC_NODOCUMENTS',  'M_F_WARNING', 'No documents available');
def_sts( 'C_DOC_NOHASHREF',    'M_ERROR', 'Config root nor config hook into data is a hash reference. Returned an empty hash reference, perhaps no document selected');
def_sts( 'C_DOC_NOARRAYREF',   'M_ERROR', 'No array reference at %s');
def_sts( 'C_DOC_EVALERROR',    'M_ERROR', 'Error eval path %s: %s');
def_sts( 'C_DOC_NOVALUE',      'M_WARNING', 'No value found at %s');
def_sts( 'C_DOC_NOKEY',        'M_ERROR', 'Key not defined');
def_sts( 'C_DOC_KEYNOTEXIST',  'M_WARNING', 'Key %s does not exist');
def_sts( 'C_DOC_MODTRACE',     'M_TRACE', "%s p='%s' '%s'");
def_sts( 'C_DOC_MODKTRACE',    'M_TRACE', "%s p='%s' k='%s' %s");
def_sts( 'C_DOC_MODERR',       'M_ERROR', "%s %s");

#-------------------------------------------------------------------------------
# Documents is an array reference, each entry in the array is a document. For
# almost all but yaml this separation of content in documents does not really
# exist.
#
has _documents =>
    ( is                => 'ro'
    , isa               => 'ArrayRef'
    , default           => sub { return []; }
    , trigger           => sub { $_[0]->_clear_current_document;}
    , init_arg          => undef
    , reader            => 'get_documents'
    , writer            => 'set_documents'
    , traits            => ['Array']
    , handles           =>
      { add_documents    => 'push'
      , nbr_documents    => 'count'
      , _get_document    => 'get'
      , _set_document    => 'set'
      }
    );

# Current document
#
has _current_document =>
    ( is                => 'ro'
    , isa               => 'Maybe[Int]'
    , default           => undef
    , reader            => 'get_current_document'
    , writer            => '_select_document'
    , clearer           => '_clear_current_document'
    );

#-------------------------------------------------------------------------------
#
sub BUILD
{
  my($self) = @_;
  $self->log_init('=DC');
}

#-------------------------------------------------------------------------------
# Get a document. If doc nbr is not defined select the current document.
# An error is thrown if doc nbr is out of range and undef is returned.
#
sub get_document
{
  my( $self, $document) = @_;

  $document //= $self->get_current_document;
  return undef unless defined $document;

  my $docs;
  my $nbrDocs = $self->nbr_documents;
  if( $nbrDocs )
  {
    if( $document >= 0 and $document < $nbrDocs )
    {
      $self->log( $self->C_DOC_DOCRETRIEVED, [$document]);
      $docs = $self->_get_document($document);
    }

    else
    {
      $self->log( $self->C_DOC_SELOUTRANGE, [ $document, 'retrieved']);
    }
  }

  else
  {
    $self->log($self->C_DOC_NODOCUMENTS);
  }

  return $docs;
}

#-------------------------------------------------------------------------------
# Select a document.
#
sub select_document
{
  my( $self, $document) = @_;

  my $nbrDocs = $self->nbr_documents;
  if( $nbrDocs and $document >= 0 and $document < $nbrDocs )
  {
    $self->_select_document($document);
  }

  else
  {
    $self->_select_document( $nbrDocs ? 0 : undef);
    $self->log( $self->C_DOC_SELOUTRANGE, [ $document, 'selected']);
  }
}

#-------------------------------------------------------------------------------
# Set a document to $newData. If doc nbr is not defined select the current
# document.
#
sub set_document
{
  my( $self, $document, $newData) = @_;
  $document //= $self->get_current_document // 0;
  if( $document >= 0 and $document < $self->nbr_documents )
  {
    $self->_set_document( $document, $newData);
  }

  else
  {
    $self->log( $self->C_DOC_SELOUTRANGE, [ $document, 'set']);
  }
}

#-------------------------------------------------------------------------------
# Return a hash reference into the configuration data using the given path. When
# for example a path like '/document/menu/color' is used it will mean
# $data->{document}{menu}{color}. The function then returns a reference to it
# for the methods who need to set values.
#
sub _path2hashref
{
  my( $self, $path, $startRef, $value, $key) = @_;

  my( $cfg, $ref);
  my $docRoot = $self->get_document($self->get_current_document);

  # If startref is found and is a hash reference, use that as a starting point
  # for path.
  #
  if( ref $startRef eq 'HASH' )
  {
    $cfg = $startRef;
  }

  # If not, check if the root of the current document is a hash reference
  #
  elsif( ref $docRoot eq 'HASH' )
  {
    $cfg = $docRoot;
  }

  else
  {
    return $self->log($self->C_DOC_NOHASHREF);
  }

  # Cleanup the path a bit.
  #
  $path =~ s@/{2,}@/@g;         # Remove any repetition of slashes
  $path =~ s@^/@@;              # Remove first slash if any
  $path =~ s@/$@@;              # Remove last slash

  # If the resulting path is not empty, evaluate it
  #
  if( $path )
  {
    # Split line on the slashes and wrap each resulting array entry
    # in braces ({}) and concatenate each result. Then evaluate result
    # in an address which will be referenced to give methods the opportunity
    # to set values on the result.
    #
    my $c;
    my $l = '$cfg->' . join( '', map { "{'$_'}" } split( '/', $path));

    # When assigning a value we need differend code to do so despite the
    # no autovivification settings above at the start.
    #
    if( defined $value and defined $key )
    {
      $c =<<EOC;
$l = {} unless ref $l eq 'HASH';
$l\{'$key'\} = \$value;
\$ref = \\$l\{'$key'};
EOC
#say STDERR "C v+k:\n", $c;
    }

    elsif( defined $value)
    {
      $c =<<EOC;
$l = \$value;
\$ref = \\$l;
EOC
#say STDERR "C v:\n", $c;
    }

    elsif( defined $key)
    {
      $c =<<EOC;
my \$va = $l\{\$key\};
\$ref = \\\$va;
EOC
#say STDERR "C k:\n", $c;
    }

    else
    {
      $c =<<EOC;
my \$va = $l;
\$ref = \\\$va;
EOC
#say STDERR "C -:\n", $c;
    }

    eval($c);
    if( my $err = $@ )
    {
      return $self->log( $self->C_DOC_EVALERROR, [$path, $err]);
    }
  }

  # If empty, return the root of the data
  #
  else
  {
    $ref = \$cfg;
  }

#$doc = $self->get_document(0);
#$dd = Data::Dumper->new( [$doc], [qw(doc2)]);
#say $dd->Dump;

#say "Ref \$ref = ", ref $ref;

  # Be sure to return a reference or a status object
  #
  return ref $ref ? $ref : $self->log($self->C_DOC_NOVALUE);
}

#-------------------------------------------------------------------------------
#
sub get_keys
{
  my( $self, $path, $startRef) = @_;

  my $keys = [];
  my $hashref = $self->_path2hashref( $path, $startRef);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  $keys = [keys %{$$hashref}];
  $self->log( $self->C_LOG_TRACE, ["get_keys from '$path'"]);
  return $keys;
}

#-------------------------------------------------------------------------------
#
sub get_value
{
  my( $self, $path, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  my $value;
  if( defined $$hashref )
  {
    $value = $$hashref;
  }

  else
  {
    return $self->log( $self->C_DOC_NOVALUE, [$path]);
  }

  $self->log( $self->C_LOG_TRACE
            , [ "get_value from '$path' "
              . (ref $startRef eq 'HASH' ? 'with hook' : '')
              ]
            );
  return $value;
}

#-------------------------------------------------------------------------------
#
sub get_kvalue
{
  my( $self, $path, $key, $startRef) = @_;

  return $self->log($self->C_DOC_NOKEY) unless defined $key;
  $key //= '';

  my $hashref = $self->_path2hashref( $path, $startRef, undef, $key);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  my $value;
  if( defined $$hashref )
  {
    $value = $$hashref;
    $self->log( $self->C_LOG_TRACE
              , [ "get_kvalue from '$path' and '$key' "
                . (ref $startRef eq 'HASH' ? 'with hook' : '')
                ]
              );
  }
  
  else
  {
    return $self->log( $self->C_DOC_NOVALUE, [$path]);
  }

  return $value;
}

#-------------------------------------------------------------------------------
# Set a value on a key. The key is a path into the config data. The values can be anything such as scalars,
# arrayrefs and hashrefs to them. In case of hashreferences the following
# actions mean almost the same thing;
#   set_value( '/a/b/c', {d => {e => 1}});
#   set_value( '/a/b/c/d/e', 1);
# The first will add or replace the part starting at 'd' and the last will only
# create or modify 'e'.
#
sub set_value
{
  my( $self, $path, $value, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef, $value);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';
  $self->log( $self->C_LOG_TRACE
            , [ "set_value, $path, '$value' "
              . (ref $startRef eq 'HASH' ? 'with hook' : '')
              ]
            );
  return $hashref;
}

#-------------------------------------------------------------------------------
#
sub set_kvalue
{
  my( $self, $path, $key, $value, $startRef) = @_;

  return $self->log($self->C_DOC_NOKEY) unless defined $key;
  return $self->log( $self->C_DOC_NOVALUE, [$path]) unless defined $value;

  $key //= '';
  $value //= '';

  # Generate a reference. Check for errors first before using.
  #
  my $hashref = $self->_path2hashref( $path, $startRef, $value, $key);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';
  $self->log( $self->C_LOG_TRACE
            , [ "set_kvalue, '$path', '$key', '$value' "
              . (ref $startRef eq 'HASH' ? 'with hook' : '')
              ]
            );
  return $hashref;
}

#-------------------------------------------------------------------------------
#
sub drop_value
{
  my( $self, $path, $startRef) = @_;

  # Split the last part of the path which needs to be removed
  #
  my( $vpath, $spath) = $path =~ m@(.*)/?([^/]+)$@;

  my $hashref = $self->_path2hashref( $vpath, $startRef);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  my $value;
  if( defined ${$hashref}->{$spath} )
  {
    $value = delete ${$hashref}->{$spath};
    $self->log( $self->C_DOC_MODTRACE
              , [ 'drop_value', $path
                , (ref $startRef eq 'HASH' ? 'with hook' : '')
                ]
              );
  }
  
  else
  {
    return $self->log( $self->C_DOC_KEYNOTEXIST, [$spath]);
  }

  return $value;
}

#-------------------------------------------------------------------------------
#
sub drop_kvalue
{
  my( $self, $path, $key, $startRef) = @_;

  return $self->log($self->C_DOC_NOKEY) unless defined $key;

  my $hashref = $self->_path2hashref( $path, $startRef);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  my $value;
  if( ref $$hashref eq 'HASH' )
  {
    $value = delete ${$hashref}->{$key};
    $self->log( $self->C_LOG_TRACE
              , [ "drop_kvalue from '$path' and '$key' "
                . (ref $startRef eq 'HASH' ? 'with hook' : '')
                ]
              );
  }
  
  else
  {
    return $self->log( $self->C_DOC_KEYNOTEXIST, [$key]);
  }
  
  return $value;
}

#-------------------------------------------------------------------------------
#
sub get_item_value
{
  my( $self, $path, $idx, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  my $v;
  if( ref $hashref and ref $$hashref eq 'ARRAY' )
  {
    $v = ${$hashref}->[$idx];
    $self->log( $self->C_DOC_MODTRACE
              , [ 'get_item_value', $path, " i=$idx"
                . (ref $startRef eq 'HASH' ? ' with hook' : '')
                ]
              );
  }
  
  elsif( ref $$hashref )
  {
    return $self->log( $self->C_DOC_NOARRAYREF, ["$path\[$idx\]"]);
  }
  
  else
  {
    return $self->log( $self->C_DOC_NOVALUE, ["$path\[$idx\]"]);
  }

  return $v;
}

#-------------------------------------------------------------------------------
#
sub get_item_kvalue
{
  my( $self, $path, $key, $idx, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef, undef, $key);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  my $v;
  if( ref $$hashref eq 'ARRAY' )
  {
    $v = ${$hashref}->[$idx];
    $self->log( $self->C_DOC_MODTRACE
              , [ 'get_item_kvalue', $path, " i=$idx"
                . (ref $startRef eq 'HASH' ? ' with hook' : '')
                ]
              );
  }

  else
  {
    return $self->log( $self->C_DOC_NOVALUE, ["$path\[$idx\]"]);
  }

  return $v;
}

#-------------------------------------------------------------------------------
#
sub pop_value
{
  my( $self, $path, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  if( ref $$hashref eq 'ARRAY' )
  {
    $self->log( $self->C_LOG_TRACE
              , [ "pop_value from '$path' "
                . (ref $startRef eq 'HASH' ? 'with hook' : '')
                ]
              );
    return pop @{$$hashref};
  }
  
  else
  {
    return $self->log( $self->C_DOC_NOVALUE, ["$path\[\]"]);
  }
}

#-------------------------------------------------------------------------------
#
sub pop_kvalue
{
  my( $self, $path, $key, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef, undef, $key);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  if( ref $$hashref  eq 'ARRAY' )
  {
    $self->log( $self->C_LOG_TRACE
              , [ "pop_value from '$path' "
                . (ref $startRef eq 'HASH' ? 'with hook' : '')
                ]
              );
    return pop @{$$hashref};
  }
  
  else
  {
    return $self->log( $self->C_DOC_NOVALUE, ["$path\[\]"]);
  }
}

#-------------------------------------------------------------------------------
# Push values on the end of an array
#
sub push_value
{
  my( $self, $path, $values, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  if( ref $$hashref eq 'ARRAY' and ref $values eq 'ARRAY' )
  {
    $self->log( $self->C_LOG_TRACE
              , [ "push_value, '$path', @$values "
                . (ref $startRef eq 'HASH' ? 'with hook' : '')
                ]
              );
    push @{$$hashref}, @$values;
  }
  
  else
  {
    return $self->log( $self->C_DOC_NOVALUE, ["$path\[\]"]);
  }

  return $hashref;
}
#-------------------------------------------------------------------------------
# Push values on the end of an array
#
sub push_kvalue
{
  my( $self, $path, $key, $values, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef, undef, $key);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  if( ref $$hashref eq 'ARRAY' and ref $values eq 'ARRAY' )
  {
    $self->log( $self->C_LOG_TRACE
              , [ "push_value, '$path', @$values "
                . (ref $startRef eq 'HASH' ? 'with hook' : '')
                ]
              );
    push @{$$hashref}, @$values;
  }
  
  else
  {
    return $self->log( $self->C_DOC_NOVALUE, ["$path\[\]"]);
  }

  return $hashref;
}

#-------------------------------------------------------------------------------
#
sub shift_value
{
  my( $self, $path, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  if( ref $$hashref eq 'ARRAY' )
  {
    $self->log( $self->C_LOG_TRACE
              , [ "shift_value from '$path' "
                . (ref $startRef eq 'HASH' ? 'with hook' : '')
                ]
              );
    return shift @{$$hashref};
  }

  else
  {
    return $self->log( $self->C_DOC_NOVALUE, ["$path\[\]"]);
  }
}

#-------------------------------------------------------------------------------
#
sub shift_kvalue
{
  my( $self, $path, $key, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef, undef, $key);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  if( ref $$hashref eq 'ARRAY' )
  {
    $self->log( $self->C_LOG_TRACE
              , [ "shift_value from '$path' "
                . (ref $startRef eq 'HASH' ? 'with hook' : '')
                ]
              );
    return shift @{$$hashref};
  }

  else
  {
    return $self->log( $self->C_DOC_NOVALUE, ["$path\[\]"]);
  }
}

#-------------------------------------------------------------------------------
#
sub unshift_value
{
  my( $self, $path, $values, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  if( ref $$hashref eq 'ARRAY' )
  {
    $self->log( $self->C_LOG_TRACE
              , [ "unshift_value, '$path', @$values "
                . (ref $startRef eq 'HASH' ? 'with hook' : '')
                ]
              );
    unshift @{$$hashref}, @$values;
  }

  else
  {
    return $self->log( $self->C_DOC_NOVALUE, ["$path\[\]"]);
  }

  return $hashref;
}

#-------------------------------------------------------------------------------
#
sub unshift_kvalue
{
  my( $self, $path, $key, $values, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef, undef, $key);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  if( ref $$hashref eq 'ARRAY' )
  {
    $self->log( $self->C_LOG_TRACE
              , [ "unshift_kvalue, '$path', @$values "
                . (ref $startRef eq 'HASH' ? 'with hook' : '')
                ]
              );

    unshift @{$$hashref}, @$values;
  }

  else
  {
    return $self->log( $self->C_DOC_NOVALUE, ["$path\[\]"]);
  }

  return $hashref;
}

#-------------------------------------------------------------------------------
# Push values on the end of an array
#
sub splice_value
{
  my( $self, $path, $spliceArgs, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  if( ref $$hashref eq 'ARRAY' and ref $spliceArgs eq 'ARRAY' )
  {
    my $off = shift @$spliceArgs;
    my $len = shift @$spliceArgs;
    if( defined $len )
    {
      splice @$$hashref, $off, $len, @$spliceArgs;
    }
    
    else
    {
      splice @$$hashref, $off;
    }
    
    $self->log( $self->C_DOC_MODTRACE
              , [ 'splice_value', $path
                , '[' . join( ', ', @$spliceArgs) . ']'
                . (ref $startRef eq 'HASH' ? ' with hook' : '')
                ]
              );
  }
  
  else
  {
    $self->log( $self->C_DOC_MODERR
              , [ 'splice_value', "Result is not a reference"]
              ) if !ref $hashref;
  }
  
  return $hashref;
}

#-------------------------------------------------------------------------------
# Push values on the end of an array
#
sub splice_kvalue
{
  my( $self, $path, $key, $spliceArgs, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef, undef, $key);
  return $hashref if ref $hashref eq 'AppState::Plugins::Log::Status';

  if( ref $$hashref eq 'ARRAY' and ref $spliceArgs eq 'ARRAY' )
  {
    my $off = shift @$spliceArgs;
    my $len = shift @$spliceArgs;
    if( defined $len )
    {
      splice @$$hashref, $off, $len, @$spliceArgs;
    }
    
    else
    {
      splice @$$hashref, $off;
    }
    
    $self->log( $self->C_DOC_MODKTRACE
              , [ 'splice_kvalue', $path, $key
                , '[' . join( ', ', @$spliceArgs) . ']'
                . (ref $startRef eq 'HASH' ? ' with hook' : '')
                ]
              );
  }
  
  else
  {
    $self->log( $self->C_DOC_MODERR
              , [ 'splice_kvalue', "Result is not a reference"]
              ) if !ref $hashref;
  }
  
  return $hashref;
}

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;
1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState::Plugins::ConfigManager::Documents - Module to control documents for AppState::Config

=head1 SYNOPSIS


=head1 DESCRIPTION




=head1 SEE ALSO


=head1 AUTHOR

Marcel Timmerman, E<lt>mt1957@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 by Marcel Timmerman

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.3 or,
at your option, any later version of Perl 5 you may have available.


=cut
