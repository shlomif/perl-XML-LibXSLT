
use strict;
use warnings;

# Should be 3
use Test::More tests => 3;

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
