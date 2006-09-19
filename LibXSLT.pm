# $Id$
package XML::LibXSLT;

use strict;
use vars qw($VERSION @ISA $USE_LIBXML_DATA_TYPES $MatchCB $ReadCB $OpenCB $CloseCB);

use XML::LibXML 1.60;
use XML::LibXML::Literal;
use XML::LibXML::Boolean;
use XML::LibXML::Number;
use XML::LibXML::NodeList;

use Carp;

require Exporter;

$VERSION = "1.61";

require DynaLoader;

@ISA = qw(DynaLoader);

bootstrap XML::LibXSLT $VERSION;

$USE_LIBXML_DATA_TYPES = 0;

sub new {
    my $class = shift;
    my %options = @_;
    my $self = bless \%options, $class;
    return $self;
}

# ido - perl dispatcher
sub perl_dispatcher {
    my $func = shift;
    my @params = @_;
    my @perlParams;
    
    my $i = 0;
    while (@params) {
        my $type = shift(@params);
        if ($type eq 'XML::LibXML::Literal' or 
            $type eq 'XML::LibXML::Number' or
            $type eq 'XML::LibXML::Boolean')
        {
            my $val = shift(@params);
            unshift(@perlParams, $USE_LIBXML_DATA_TYPES ? $type->new($val) : $val);
        }
        elsif ($type eq 'XML::LibXML::NodeList') {
            my $node_count = shift(@params);
            my @nodes = splice(@params, 0, $node_count);
            # warn($_->getName) for @nodes;
            unshift(@perlParams, $type->new(@nodes));
        }
    }
    
    $func = "main::$func" unless ref($func) || $func =~ /(.+)::/;
    no strict 'refs';
    my $res = $func->(@perlParams);
    return $res;
}


sub xpath_to_string {
    my @results;
    while (@_) {
        my $value = shift(@_); $value = '' unless defined $value;
        push @results, $value;
        if (@results % 2) {
            # key
            $results[-1] =~ s/:/_/g; # XSLT doesn't like names with colons
        }
        else {
            if ($value =~ s/'/', "'", '/g) {
	        $results[-1] = "concat('$value')";
            }
            else {
                $results[-1] = "'$results[-1]'";
            }
        }
    }
    return @results;
}

#-------------------------------------------------------------------------#
# callback functions                                                      #
#-------------------------------------------------------------------------#

sub input_callbacks {
    my $self = shift;
    my $icbclass = shift;

    if ( defined $icbclass ) {
        $self->{XML_LIBXSLT_CALLBACK_STACK} = $icbclass;
    }
    return $self->{XML_LIBXSLT_CALLBACK_STACK};
}

sub match_callback {
    my $self = shift;
    if ( ref $self ) {
        if ( scalar @_ ) {
            $self->{XML_LIBXSLT_MATCH_CB} = shift;
            $self->{XML_LIBXSLT_CALLBACK_STACK} = undef;
        }
        return $self->{XML_LIBXSLT_MATCH_CB};
    }
    else {
        $MatchCB = shift if scalar @_;
        return $MatchCB;
    }
}

sub read_callback {
    my $self = shift;
    if ( ref $self ) {
        if ( scalar @_ ) {
            $self->{XML_LIBXSLT_READ_CB} = shift;
            $self->{XML_LIBXSLT_CALLBACK_STACK} = undef;
        }
        return $self->{XML_LIBXSLT_READ_CB};
    }
    else {
        $ReadCB = shift if scalar @_;
        return $ReadCB;
    }
}

sub close_callback {
    my $self = shift;
    if ( ref $self ) {
        if ( scalar @_ ) {
            $self->{XML_LIBXSLT_CLOSE_CB} = shift;
            $self->{XML_LIBXSLT_CALLBACK_STACK} = undef;
        }
        return $self->{XML_LIBXSLT_CLOSE_CB};
    }
    else {
        $CloseCB = shift if scalar @_;
        return $CloseCB;
    }
}

sub open_callback {
    my $self = shift;
    if ( ref $self ) {
        if ( scalar @_ ) {
            $self->{XML_LIBXSLT_OPEN_CB} = shift;
            $self->{XML_LIBXSLT_CALLBACK_STACK} = undef;
        }
        return $self->{XML_LIBXSLT_OPEN_CB};
    }
    else {
        $OpenCB = shift if scalar @_;
        return $OpenCB;
    }
}

sub callbacks {
    my $self = shift;
    if ( ref $self ) {
        if (@_) {
            my ($match, $open, $read, $close) = @_;
            @{$self}{qw(XML_LIBXSLT_MATCH_CB XML_LIBXSLT_OPEN_CB XML_LIBXSLT_READ_CB XML_LIBXSLT_CLOSE_CB)} = ($match, $open, $read, $close);
            $self->{XML_LIBXSLT_CALLBACK_STACK} = undef;
        }
        else {
            return @{$self}{qw(XML_LIBXSLT_MATCH_CB XML_LIBXSLT_OPEN_CB XML_LIBXSLT_READ_CB XML_LIBXSLT_CLOSE_CB)};
        }
    }
    else {
        if (@_) {
            ( $MatchCB, $OpenCB, $ReadCB, $CloseCB ) = @_;
        }
        else {
            return ( $MatchCB, $OpenCB, $ReadCB, $CloseCB );
        }
    }
}

sub _init_callbacks{
    my $self = shift;
    my $icb = $self->{XML_LIBXSLT_CALLBACK_STACK};

    unless ( defined $icb ) {
        $self->{XML_LIBXSLT_CALLBACK_STACK} = XML::LibXML::InputCallback->new();
        $icb = $self->{XML_LIBXSLT_CALLBACK_STACK};
    }

    my $mcb = $self->match_callback();
    my $ocb = $self->open_callback();
    my $rcb = $self->read_callback();
    my $ccb = $self->close_callback();

    if ( defined $mcb and defined $ocb and defined $rcb and defined $ccb ) {
        $icb->register_callbacks( [$mcb, $ocb, $rcb, $ccb] );
    }

    $self->lib_init_callbacks();
    $icb->init_callbacks();
}

sub _cleanup_callbacks {
    my $self = shift;
    $self->{XML_LIBXSLT_CALLBACK_STACK}->cleanup_callbacks();
    my $mcb = $self->match_callback();
    if ( defined $mcb ) {
        $self->{XML_LIBXSLT_CALLBACK_STACK}->unregister_callbacks( [$mcb] );
    }
}

sub parse_stylesheet {
    my $self = shift;

    $self->_init_callbacks();

    my $stylesheet;
    eval { $stylesheet = $self->_parse_stylesheet(@_); };

    $self->_cleanup_callbacks();

    my $err = $@;
    if ($err) {
        croak $err;
    }

    my $rv = {
               XML_LIBXSLT_STYLESHEET => $stylesheet,
               XML_LIBXSLT_CALLBACK_STACK => $self->{XML_LIBXSLT_CALLBACK_STACK},
               XML_LIBXSLT_MATCH_CB => $self->{XML_LIBXSLT_MATCH_CB},
               XML_LIBXSLT_OPEN_CB => $self->{XML_LIBXSLT_OPEN_CB},
               XML_LIBXSLT_READ_CB => $self->{XML_LIBXSLT_READ_CB},
               XML_LIBXSLT_CLOSE_CB => $self->{XML_LIBXSLT_CLOSE_CB},
             };

    return bless $rv, "XML::LibXSLT::StylesheetWrapper";
}

sub parse_stylesheet_file {
    my $self = shift;

    $self->_init_callbacks();

    my $stylesheet;
    eval { $stylesheet = $self->_parse_stylesheet_file(@_); };

    $self->_cleanup_callbacks();

    my $err = $@;
    if ($err) {
        croak $err;
    }

    my $rv = {
               XML_LIBXSLT_STYLESHEET => $stylesheet,
               XML_LIBXSLT_CALLBACK_STACK => $self->{XML_LIBXSLT_CALLBACK_STACK},
               XML_LIBXSLT_MATCH_CB => $self->{XML_LIBXSLT_MATCH_CB},
               XML_LIBXSLT_OPEN_CB => $self->{XML_LIBXSLT_OPEN_CB},
               XML_LIBXSLT_READ_CB => $self->{XML_LIBXSLT_READ_CB},
               XML_LIBXSLT_CLOSE_CB => $self->{XML_LIBXSLT_CLOSE_CB},
             };

    return bless $rv, "XML::LibXSLT::StylesheetWrapper";
}

sub register_xslt_module {
    my $self = shift;
    my $module = shift;
    # Not implemented
}

1;

package XML::LibXSLT::StylesheetWrapper;

use strict;
use vars qw($MatchCB $ReadCB $OpenCB $CloseCB);

use XML::LibXML;
use Carp;

sub input_callbacks {
    my $self     = shift;
    my $icbclass = shift;

    if ( defined $icbclass ) {
        $self->{XML_LIBXSLT_CALLBACK_STACK} = $icbclass;
    }
    return $self->{XML_LIBXSLT_CALLBACK_STACK};
}

sub match_callback {
    my $self = shift;
    if ( ref $self ) {
        if ( scalar @_ ) {
            $self->{XML_LIBXSLT_MATCH_CB} = shift;
            $self->{XML_LIBXSLT_CALLBACK_STACK} = undef;
        }
        return $self->{XML_LIBXSLT_MATCH_CB};
    }
    else {
        $MatchCB = shift if scalar @_;
        return $MatchCB;
    }
}

sub read_callback {
    my $self = shift;
    if ( ref $self ) {
        if ( scalar @_ ) {
            $self->{XML_LIBXSLT_READ_CB} = shift;
            $self->{XML_LIBXSLT_CALLBACK_STACK} = undef;
        }
        return $self->{XML_LIBXSLT_READ_CB};
    }
    else {
        $ReadCB = shift if scalar @_;
        return $ReadCB;
    }
}

sub close_callback {
    my $self = shift;
    if ( ref $self ) {
        if ( scalar @_ ) {
            $self->{XML_LIBXSLT_CLOSE_CB} = shift;
            $self->{XML_LIBXSLT_CALLBACK_STACK} = undef;
        }
        return $self->{XML_LIBXSLT_CLOSE_CB};
    }
    else {
        $CloseCB = shift if scalar @_;
        return $CloseCB;
    }
}

sub open_callback {
    my $self = shift;
    if ( ref $self ) {
        if ( scalar @_ ) {
            $self->{XML_LIBXSLT_OPEN_CB} = shift;
            $self->{XML_LIBXSLT_CALLBACK_STACK} = undef;
        }
        return $self->{XML_LIBXSLT_OPEN_CB};
    }
    else {
        $OpenCB = shift if scalar @_;
        return $OpenCB;
    }
}

sub callbacks {
    my $self = shift;
    if ( ref $self ) {
        if (@_) {
            my ($match, $open, $read, $close) = @_;
            @{$self}{qw(XML_LIBXSLT_MATCH_CB XML_LIBXSLT_OPEN_CB XML_LIBXSLT_READ_CB XML_LIBXSLT_CLOSE_CB)} = ($match, $open, $read, $close);
            $self->{XML_LIBXSLT_CALLBACK_STACK} = undef;
        }
        else {
            return @{$self}{qw(XML_LIBXSLT_MATCH_CB XML_LIBXSLT_OPEN_CB XML_LIBXSLT_READ_CB XML_LIBXSLT_CLOSE_CB)};
        }
    }
    else {
        if (@_) {
            ( $MatchCB, $OpenCB, $ReadCB, $CloseCB ) = @_;
        }
        else {
            return ( $MatchCB, $OpenCB, $ReadCB, $CloseCB );
        }
    }
}

sub _init_callbacks {
    my $self = shift;
    my $icb = $self->{XML_LIBXSLT_CALLBACK_STACK};

    unless ( defined $icb ) {
        $self->{XML_LIBXSLT_CALLBACK_STACK} = XML::LibXML::InputCallback->new();
        $icb = $self->{XML_LIBXSLT_CALLBACK_STACK};
    }

    my $mcb = $self->match_callback();
    my $ocb = $self->open_callback();
    my $rcb = $self->read_callback();
    my $ccb = $self->close_callback();

    if ( defined $mcb and defined $ocb and defined $rcb and defined $ccb ) {
        $icb->register_callbacks( [$mcb, $ocb, $rcb, $ccb] );
    }
    $self->XML::LibXSLT::lib_init_callbacks();
    $icb->init_callbacks();
}

sub _cleanup_callbacks {
    my $self = shift;
    $self->{XML_LIBXSLT_CALLBACK_STACK}->cleanup_callbacks();
    my $mcb = $self->match_callback();
    if ( defined $mcb ) {
        $self->{XML_LIBXSLT_CALLBACK_STACK}->unregister_callbacks( [$mcb] );
    }
}

sub transform {
    my $self = shift;
    my $doc;

    $self->_init_callbacks();
    eval { $doc = $self->{XML_LIBXSLT_STYLESHEET}->transform(@_); };
    $self->_cleanup_callbacks();

    my $err = $@;
    if ($err) {
        croak $err;
    }

    return $doc;
}

sub transform_file {
    my $self = shift;
    my $doc;

    $self->_init_callbacks();
    eval { $doc = $self->{XML_LIBXSLT_STYLESHEET}->transform_file(@_); };
    $self->_cleanup_callbacks();

    my $err = $@;
    if ($err) {
        croak $err;
    }

    return $doc;
}

sub output_string { shift->{XML_LIBXSLT_STYLESHEET}->output_string(@_) }
sub output_fh { shift->{XML_LIBXSLT_STYLESHEET}->output_fh(@_) }
sub output_file { shift->{XML_LIBXSLT_STYLESHEET}->output_file(@_) }
sub media_type { shift->{XML_LIBXSLT_STYLESHEET}->media_type(@_) }
sub output_encoding { shift->{XML_LIBXSLT_STYLESHEET}->output_encoding(@_) }

1;
__END__

=head1 NAME

XML::LibXSLT - Interface to the gnome libxslt library

=head1 SYNOPSIS

  use XML::LibXSLT;
  use XML::LibXML;
  
  my $parser = XML::LibXML->new();
  my $xslt = XML::LibXSLT->new();
  
  my $source = $parser->parse_file('foo.xml');
  my $style_doc = $parser->parse_file('bar.xsl');
  
  my $stylesheet = $xslt->parse_stylesheet($style_doc);
  
  my $results = $stylesheet->transform($source);
  
  print $stylesheet->output_string($results);

=head1 DESCRIPTION

This module is an interface to the gnome project's libxslt. This is an
extremely good XSLT engine, highly compliant and also very fast. I have
tests showing this to be more than twice as fast as Sablotron.

=head1 OPTIONS

XML::LibXSLT has some global options. Note that these are probably not
thread or even fork safe - so only set them once per process. Each one
of these options can be called either as class methods, or as instance
methods. However either way you call them, it still sets global options.

Each of the option methods returns its previous value, and can be called
without a parameter to retrieve the current value.

=head2 max_depth

  XML::LibXSLT->max_depth(1000);

This option sets the maximum recursion depth for a stylesheet. See the
very end of section 5.4 of the XSLT specification for more details on
recursion and detecting it. If your stylesheet or XML file requires
seriously deep recursion, this is the way to set it. Default value is
250.

=head2 debug_callback

  XML::LibXSLT->debug_callback($subref);

Sets a callback to be used for debug messages. If you don't set this,
debug messages will be ignored.

=head2 register_function

  XML::LibXSLT->register_function($uri, $name, $subref);

Registers an XSLT extension function mapped to the given URI. For example:

  XML::LibXSLT->register_function("urn:foo", "bar",
    sub { scalar localtime });

Will register a C<bar> function in the C<urn:foo> namespace (which you
have to define in your XSLT using C<xmlns:...>) that will return the
current date and time as a string:

  <xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:foo="urn:foo">
  <xsl:template match="/">
    The time is: <xsl:value-of select="foo:bar()"/>
  </xsl:template>
  </xsl:stylesheet>

Parameters can be in whatever format you like. If you pass in a nodelist
it will be a XML::LibXML::NodeList object in your perl code, but ordinary
values (strings, numbers and booleans) will be ordinary perl scalars. If
you wish them to be C<XML::LibXML::Literal>, C<XML::LibXML::Number> and
C<XML::LibXML::Number> values respectively then set the variable
C<$XML::LibXSLT::USE_LIBXML_DATA_TYPES> to a true value. Return values can
be a nodelist or a plain value - the code will just do the right thing.
But only a single return value is supported (a list is not converted to
a nodelist).

=head1 API

The following methods are available on the new XML::LibXSLT object:

=head2 parse_stylesheet($doc)

C<$doc> here is an XML::LibXML::Document object (see L<XML::LibXML>)
representing an XSLT file. This method will return a 
XML::LibXSLT::Stylesheet object, or undef on failure. If the XSLT is
invalid, an exception will be thrown, so wrap the call to 
parse_stylesheet in an eval{} block to trap this.

=head2 parse_stylesheet_file($filename)

Exactly the same as the above, but parses the given filename directly.

=head2 Input Callbacks

To define XML::LibXSLT or XML::LibXSLT::Stylesheet specific input
callbacks, reuse the XML::LibXML input callback API as described in
L<XML::LibXML::InputCallback(3)>.

=head1 XML::LibXSLT::Stylesheet

The main API is on the stylesheet, though it is fairly minimal.

One of the main advantages of XML::LibXSLT is that you have a generic
stylesheet object which you call the transform() method passing in a
document to transform. This allows you to have multiple transformations
happen with one stylesheet without requiring a reparse.

=head2 transform(doc, %params)

  my $results = $stylesheet->transform($doc, foo => "value);

Transforms the passed in XML::LibXML::Document object, and returns a
new XML::LibXML::Document. Extra hash entries are used as parameters.

=head2 transform_file(filename, %params)

  my $results = $stylesheet->transform_file($filename, bar => "value");

=head2 output_string(result)

Returns a scalar that is the XSLT rendering of the
XML::LibXML::Document object using the desired output format
(specified in the xsl:output tag in the stylesheet). Note that you can
also call $result->toString, but that will *always* output the
document in XML format, and in UTF8, which may not be what you asked
for in the xsl:output tag.

Note that the returned scalar is always bytes not characters, i.e. it
is *not* marked with the UTF8 flag even if the desired output encoding
was in fact UTF-8. If the output encoding was UTF-8 and you wish the
scalar to be treated by Perl as characters, apply
Encode::_utf8_on($result) on the returned scalar.

=head2 output_fh(result, fh)

Outputs the result to the filehandle given in C<$fh>.

=head2 output_file(result, filename)

Outputs the result to the file named in C<$filename>.

=head2 output_encoding

Returns the output encoding of the results. Defaults to "UTF-8".

=head2 media_type

Returns the output media_type of the results. Defaults to "text/html".

=head1 Parameters

LibXSLT expects parameters in XPath format. That is, if you wish to pass
a string to the XSLT engine, you actually have to pass it as a quoted
string:

  $stylesheet->transform($doc, param => "'string'");

Note the quotes within quotes there!

Obviously this isn't much fun, so you can make it easy on yourself:

  $stylesheet->transform($doc, XML::LibXSLT::xpath_to_string(
        param => "string"
        ));

The utility function does the right thing with respect to strings in XPath,
including when you have quotes already embedded within your string.

=head1 BENCHMARK

Included in the distribution is a simple benchmark script, which has two
drivers - one for LibXSLT and one for Sablotron. The benchmark requires
the testcases files from the XSLTMark distribution which you can find
at http://www.datapower.com/XSLTMark/

Put the testcases directory in the directory created by this distribution,
and then run:

  perl benchmark.pl -h

to get a list of options.

The benchmark requires XML::XPath at the moment, but I hope to factor that
out of the equation fairly soon. It also requires Time::HiRes, which I
could be persuaded to factor out, replacing it with Benchmark.pm, but I
haven't done so yet.

I would love to get drivers for XML::XSLT and XML::Transformiix, if you
would like to contribute them. Also if you get this running on Win32, I'd
love to get a driver for MSXSLT via OLE, to see what we can do against
those Redmond boys!

=head1 AUTHOR

Matt Sergeant, matt@sergeant.org

Copyright 2001-2006, AxKit.com Ltd. All rights reserved.

=head1 SEE ALSO

XML::LibXML

=cut
