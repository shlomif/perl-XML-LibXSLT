# $Id$

package XML::LibXML;

use strict;
use vars qw($VERSION @ISA);

$VERSION = "0.90";

require DynaLoader;

@ISA = qw(DynaLoader);

bootstrap XML::LibXML $VERSION;

sub new {
    my $class = shift;
    my %options = @_;
    my $self = bless \%options, $class;
    return $self;
}

1;
__END__

=head1 NAME

XML::LibXML - Interface to the gnome libxml2 library

=head1 SYNOPSIS

  use XML::LibXML;
  my $parser = XML::LibXML->new();

  my $doc = $parser->parse_string(<<'EOT');
  <xml/>
  EOT

=head1 DESCRIPTION

Currently this module doesn't actually do much but parse files and give
you back a document (DOM) handle. You can't actually call DOM methods on
that document though (because I haven't written the code to do it yet!).

=head1 OPTIONS

When calling C<new()>, you can pass in several options:

=over

=item no_entities

Do not process external parsed entities.

=item validate

Validate the document against the DTD specified in the DOCTYPE of the
XML file.

=item ext_ent_handler

Set this to a subroutine reference (or function name) to have it be
called to load external parsed entities.

=item lose_blanks

Kill whitespace in the document. See the libxml docs on 
xmlKeepBlanksDefault() for more details

=item input_callbacks

This is a hash reference containing some methods to call to load other
"things" - for example when this parser is used with XML::LibXSLT these
input_callbacks will be used for document() and xsl:import.

The sub-keys are all sub refs (or the fully qualified name of a function):

=over

=item match

Called to check whether to actually use these
input callbacks, or let libxml use it's default handlers. The sub is called
with one parameter - a URI or filename. Return a true value if you want the 
methods below to be called for this URI/filename.

=item open

Called to open the resource associated with the URI/filename passed in as
a parameter. The return value my be any scalar, perhaps an open filehandle,
or an object that can retrieve the resource.

=item read

Called with two parameters, the first being the scalar returned by open,
and the second being how many bytes to read from the resource. Return
a string up to the length passed in as a param.

=item close

Close recieves one parameter - the scalar returned from open above. Use this
to close and free up any resources.

=back

=item error_handler

Another subref (or function name), called when a parsing error occurs. The
function is called with one argument - a string containing the error.

=back

=head1 API

=head2 C<$parser->parse_string($string)>

Parse the XMl in C<$string> and return a XML::LibXML::Document object.

=head2 C<$parser->parse_file($filename)>

Parse the file in C<$filename> and return a XML::LibXML::Document object.

=head2 C<$parser->parse_fh($fh)>

Parse the filehandle in C<$fh> and return a XML::LibXML::Document object.

=head1 XML::LibXML::Document

The objects returned above have a few methods available to them:

=head2 C<$doc->toString>

Convert the document to a string.

=head2 C<$doc->is_valid>

Post parse validation. Cannot currently take any sort of DTD as a parameter
(which would allow validation of any XML document against arbitrary DTD's),
but expect this to change in time.

=head2 C<$doc->process_xinclude>

Process any xinclude tags in the file.

=head1 AUTHOR

Matt Sergeant, matt@sergeant.org

Copyright 2001, AxKit.com Ltd. All rights reserved.

=head1 SEE ALSO

XML::LibXSLT

=cut
