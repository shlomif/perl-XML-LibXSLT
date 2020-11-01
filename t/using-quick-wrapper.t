
use strict;
use warnings;

use Test::More tests => 6;

use XML::LibXSLT::Quick ();

{
    my $stylesheet = XML::LibXSLT::Quick->new( location => 'example/1.xsl' );
    my $parser     = XML::LibXML->new();

    # TEST
    ok( $parser, 'parser was initialized' );
    my $source = $parser->parse_file('example/1.xml');

    # TEST
    ok( $source, '$source' );
    my $results = $stylesheet->transform($source);
    my $out1    = $stylesheet->output_string($results);

    # TEST
    ok( $out1, 'output' );
}

{
    my $xslt_parser = XML::LibXSLT->new();
    my $stylesheet  = XML::LibXSLT::Quick->new(
        xslt_parser => $xslt_parser,
        location    => 'example/1.xsl'
    );
    my $parser = XML::LibXML->new();

    # TEST
    ok( $parser, 'parser was initialized' );
    my $source = $parser->parse_file('example/1.xml');

    # TEST
    ok( $source, '$source' );
    my $results = $stylesheet->transform($source);
    my $out1    = $stylesheet->output_string($results);

    # TEST
    ok( $out1, 'output' );
}
