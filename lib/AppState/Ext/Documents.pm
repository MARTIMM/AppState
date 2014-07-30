package AppState::Ext::Documents;

use Modern::Perl;
use version; our $VERSION = version->parse('v0.0.2');
use 5.010001;

use namespace::autoclean;

use Moose;
use Moose::Util::TypeConstraints;
extends 'AppState::Ext::Constants';

use AppState;
use AppState::Ext::Meta_Constants;

#-------------------------------------------------------------------------------
# Error codes. These codes must also be handled by ConfigManager.
#
const( 'C_DOC_SELOUTRANGE'  , 'M_ERROR', 'Document number %s out of range, document not %s');
const( 'C_DOC_DOCRETRIEVED' , 'M_INFO', 'Document %s retrieved');      
const( 'C_DOC_NODOCUMENTS'  , 'M_F_WARNING', 'No documents available'); 
const( 'C_DOC_NOHASHREF'    , 'M_ERROR', 'Config root nor config hook into data is a hash reference. Returned an empty hash reference, perhaps no document selected');
const( 'C_DOC_EVALERROR'    , 'M_ERROR', 'Error eval path %s: %s');     
const( 'C_DOC_NOVALUE'      , 'M_WARNING', 'No value found at %s');
const( 'C_DOC_NOKEY'        , 'M_ERROR', 'Key not defined');

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
#say "DN: $document > $nbrDocs";
    if( $document >= 0 and $document < $nbrDocs )
    {
      $self->log( $self->C_DOC_DOCRETRIEVED, [$document]);
      $docs = $self->_get_document($document);
    }

    else
    {
      $self->log( $self->C_DOC_SELOUTRANGE, [ $document, 'retrieved']);
#      $document = 0;
#      $docs = $self->_get_document($document);
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
say "Set doc: $document, $newData";
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
  my( $self, $path, $startRef) = @_;

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
    $cfg = {};
    $self->log($self->C_DOC_NOHASHREF);
  }

  $path =~ s@/{2,}@/@g;         # Remove any repetition of slashes
  $path =~ s@^/@@;              # Remove first slash
  $path =~ s@/$@@;              # Remove last slash

  # If the path is not empty, evaluate it
  #
  if( $path )
  {
    # Split line on the slashes and wrap each resulting array entry
    # in braces ({}) and concatenate each result. Then evaluate resulting
    # in an address which will be referenced to give methods the opportunity
    # to set values on the result.
    #
    my $l = '$cfg->' . join( '', map { "{'$_'}" } split( '/', $path));
    eval("\$ref = \\$l;");
    if( my $err = $@ )
    {
      $self->log( $self->C_DOC_EVALERROR, [$path, $err]);
    }
  }

  # If empty, return the root of the data
  #
  else
  {
    $ref = \$cfg;
  }

  return $ref;
}

#-------------------------------------------------------------------------------
#
sub get_keys
{
  my( $self, $path, $startRef) = @_;

  my $keys = [];
  my $hashref = $self->_path2hashref( $path, $startRef);
  $keys = [keys %{$$hashref}] if ref $$hashref eq 'HASH';

  $self->write_log( $self->C_LOG_TRACE, "get_keys from '$path'");
  return $keys;
}

#-------------------------------------------------------------------------------
#
sub get_value
{
  my( $self, $path, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef);
  my $v;
  $v = $$hashref if ref $hashref;# =~ m/^(REF|SCALAR|ARRAY|HASH)$/;
  $self->log( $self->C_DOC_NOVALUE, [$path]) unless ref $hashref;
  $self->write_log( $self->C_LOG_TRACE
                  , "get_value from '$path' "
                  . ref $startRef eq 'HASH' ? 'with hook' : ''
                  );
  return $v;
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

  my $hashref = $self->_path2hashref( $path, $startRef);
  $$hashref = $value;
  $self->write_log( $self->C_LOG_TRACE
                  , "set_value, $path, '$value' "
                  . ref $startRef eq 'HASH' ? 'with hook' : ''
                  );
}

#-------------------------------------------------------------------------------
#
sub drop_value
{
  my( $self, $path, $startRef) = @_;

  my( $vpath, $spath) = $path =~ m@(.*)/([^/]+)$@;
  return unless defined $spath;

  my $hashref = $self->_path2hashref( $vpath, $startRef);
  my $value;
  if( defined $$hashref->{$spath} )
  {
    $value = $$hashref->{$spath};
    delete $$hashref->{$spath} if ref $$hashref eq 'HASH';
  }

  $self->write_log( $self->C_LOG_TRACE
                  , "drop_value, '$path' "
                  . ref $startRef eq 'HASH' ? 'with hook' : ''
                  );

  return $value;
}

#-------------------------------------------------------------------------------
#
sub get_kvalue
{
  my( $self, $path, $key, $startRef) = @_;

  $self->log($self->C_DOC_NOKEY) unless defined $key;
  $key //= '';

  my $hashref = $self->_path2hashref( $path, $startRef);

  $self->write_log( $self->C_LOG_TRACE
                  , "get_kvalue from '$path' and '$key' "
                  . ref $startRef eq 'HASH' ? 'with hook' : ''
                  );
  return $$hashref->{$key};
}

#-------------------------------------------------------------------------------
#
sub set_kvalue
{
  my( $self, $path, $key, $value, $startRef) = @_;

  $self->log($self->C_DOC_NOKEY) unless defined $key;
  $self->log( $self->C_DOC_NOVALUE, [$path]) unless defined $value;

  $key //= '';
  $value //= '';

  my $hashref = $self->_path2hashref( $path, $startRef);
  $$hashref //= {};
  $$hashref->{$key} = $value;
  $self->write_log( $self->C_LOG_TRACE
                  , "set_kvalue, '$path', '$key', '$value' "
                  . ref $startRef eq 'HASH' ? 'with hook' : ''
                  );
}

#-------------------------------------------------------------------------------
#
sub drop_kvalue
{
  my( $self, $path, $key, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef);

  my $value = $$hashref->{$key};
#say "DV: $value, $hashref";
  delete $$hashref->{$key} if ref $$hashref eq 'HASH';

  $self->write_log( $self->C_LOG_TRACE
                  , "drop_kvalue from '$path' and '$key' "
                  . ref $startRef eq 'HASH' ? 'with hook' : ''
                  );
  return $value;
}

#-------------------------------------------------------------------------------
#
sub pop_value
{
  my( $self, $path, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef);

  $self->write_log( $self->C_LOG_TRACE
                  , "pop_value from '$path' "
                  . ref $startRef eq 'HASH' ? 'with hook' : ''
                  );
  return pop @{$$hashref};
}

#-------------------------------------------------------------------------------
# Push values on the end of an array
#
sub push_value
{
  my( $self, $path, $values, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef);
  push @{$$hashref}, @$values;

  $self->write_log( $self->C_LOG_TRACE
                  , "push_value, '$path', @$values "
                  . ref $startRef eq 'HASH' ? 'with hook' : ''
                  );
}

#-------------------------------------------------------------------------------
#
sub shift_value
{
  my( $self, $path, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef);

  $self->write_log( $self->C_LOG_TRACE
                  , "shift_value from '$path' "
                  . ref $startRef eq 'HASH' ? 'with hook' : ''
                  );
  return shift @{$$hashref};
}

#-------------------------------------------------------------------------------
#
sub unshift_value
{
  my( $self, $path, $values, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef);
  unshift @{$$hashref}, @$values;

  $self->write_log( $self->C_LOG_TRACE
                  , "unshift_value, '$path', @$values "
                  . ref $startRef eq 'HASH' ? 'with hook' : ''
                  );
}

#-------------------------------------------------------------------------------
# Push values on the end of an array
#
sub splice_value
{
  my( $self, $path, $spliceArgs, $startRef) = @_;

  my $hashref = $self->_path2hashref( $path, $startRef);
  splice @{$$hashref}, @$spliceArgs;

  $self->write_log( $self->C_LOG_TRACE
                  , "push_value, '$path', @$spliceArgs "
                  . ref $startRef eq 'HASH' ? 'with hook' : ''
                  );
}

#-------------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable;
1;

__END__

#-------------------------------------------------------------------------------
# Documentation
#

=head1 NAME

AppState::Ext::Documents - Module to control documents for AppState::Config

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
