
use strict;
use warnings;
use autodie;

use Test::More tests => 8;

use XML::LibXML         ();
use XML::LibXSLT        ();
use XML::LibXSLT::Quick ();

my $parser = XML::LibXML->new();

# TEST
ok( $parser, 'parser was initialized' );

my $xml1_dom = $parser->parse_file('example/1.xml');

# TEST
ok( $xml1_dom, '$xml1_dom' );

{
    my $stylesheet =
        XML::LibXSLT::Quick->new( { location => 'example/1.xsl', } );
    my $results = $stylesheet->transform($xml1_dom);
    my $out1    = $stylesheet->output_as_chars($results);

    # TEST
    ok( $out1, 'output' );
}

my $expected_output;
{
    my $xslt_parser = XML::LibXSLT->new();
    my $stylesheet  = XML::LibXSLT::Quick->new(
        {
            xslt_parser => $xslt_parser,
            location    => 'example/1.xsl',
        }
    );
    my $results = $stylesheet->transform($xml1_dom);
    my $out1    = $stylesheet->output_as_chars($results);

    $expected_output = $out1;

    # TEST
    ok( $out1, 'output' );
}

{
    my $stylesheet =
        XML::LibXSLT::Quick->new( { location => 'example/1.xsl', } );
    my $out2 = $stylesheet->transform_into_chars($xml1_dom);

    # TEST
    is( $out2, $expected_output, 'transform_into_chars' );
}

{
    my $stylesheet =
        XML::LibXSLT::Quick->new( { location => 'example/1.xsl', } );
    my $out_str = '';
    open my $fh, '>', \$out_str;
    $stylesheet->generic_transform( $fh, $xml1_dom, );

    $fh->flush();

    # TEST
    is( $out_str, $expected_output, 'transform_into_chars' );
}

{
    my $stylesheet =
        XML::LibXSLT::Quick->new( { location => 'example/1.xsl', } );
    my $out_str = '';
    $stylesheet->generic_transform( ( \$out_str ), $xml1_dom, );

    # TEST
    is( $out_str, $expected_output, 'transform_into_chars' );
}

sub _raw_slurp
{
    my $filename = shift;

    open my $in, '<:raw', $filename
        or die "Cannot open '$filename' for slurping - $!";

    local $/;
    my $contents = <$in>;

    close($in);

    return $contents;
}

sub _utf8_slurp
{
    my $filename = shift;

    open my $in, '<:encoding(utf8)', $filename
        or die "Cannot open '$filename' for slurping - $!";

    local $/;
    my $contents = <$in>;

    close($in);

    return $contents;
}

{
    my $stylesheet =
        XML::LibXSLT::Quick->new( { location => 'example/1.xsl', } );
    my $out_fn = 'foo.xml';
    $stylesheet->generic_transform(
        +{
            type => 'file',
            path => $out_fn,

        },
        $xml1_dom,
    );

    my $out_str = _utf8_slurp($out_fn);

    # TEST
    is( $out_str, $expected_output, 'transform_into_chars' );
    unlink($out_fn);
}
