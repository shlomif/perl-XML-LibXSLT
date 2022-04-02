
use strict;
use warnings;
use autodie;

use Test::More tests => 15;

use XML::LibXML         ();
use XML::LibXSLT        ();
use XML::LibXSLT::Quick ();

{
    my $stylesheet = XML::LibXSLT::Quick->new( {location => 'example/1.xsl',} );
    my $parser     = XML::LibXML->new();

    # TEST
    ok( $parser, 'parser was initialized' );
    my $source = $parser->parse_file('example/1.xml');

    # TEST
    ok( $source, '$source' );
    my $results = $stylesheet->transform($source);
    my $out1    = $stylesheet->output_as_chars($results);

    # TEST
    ok( $out1, 'output' );
}

my $out_exp;
{
    my $xslt_parser = XML::LibXSLT->new();
    my $stylesheet  = XML::LibXSLT::Quick->new(
        {
        xslt_parser => $xslt_parser,
        location    => 'example/1.xsl',
    }
    );
    my $parser = XML::LibXML->new();

    # TEST
    ok( $parser, 'parser was initialized' );
    my $source = $parser->parse_file('example/1.xml');

    # TEST
    ok( $source, '$source' );
    my $results = $stylesheet->transform($source);
    my $out1    = $stylesheet->output_as_chars($results);

    $out_exp = $out1;

    # TEST
    ok( $out1, 'output' );
}

{
    my $stylesheet = XML::LibXSLT::Quick->new( {location => 'example/1.xsl',} );
    my $parser     = XML::LibXML->new();

    # TEST
    ok( $parser, 'parser was initialized' );
    my $source = $parser->parse_file('example/1.xml');

    # TEST
    ok( $source, '$source' );
    my $out2 = $stylesheet->transform_into_chars($source);

    # TEST
    is( $out2, $out_exp, 'transform_into_chars' );
}

{
    my $stylesheet = XML::LibXSLT::Quick->new( {location => 'example/1.xsl',} );
    my $parser     = XML::LibXML->new();

    # TEST
    ok( $parser, 'parser was initialized' );
    my $source = $parser->parse_file('example/1.xml');

    # TEST
    ok( $source, '$source' );
    my $out_str = '';
    open my $fh, '>', \$out_str;
    $stylesheet->generic_transform( $fh, $source, );

    $fh->flush();

    # TEST
    is( $out_str, $out_exp, 'transform_into_chars' );
}

{
    my $stylesheet = XML::LibXSLT::Quick->new( {location => 'example/1.xsl',} );
    my $parser     = XML::LibXML->new();

    # TEST
    ok( $parser, 'parser was initialized' );
    my $source = $parser->parse_file('example/1.xml');

    # TEST
    ok( $source, '$source' );
    my $out_str = '';
    $stylesheet->generic_transform( ( \$out_str ), $source, );

    # TEST
    is( $out_str, $out_exp, 'transform_into_chars' );
}
