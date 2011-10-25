use strict;
use warnings;

# Should be 5.
use Test::More tests => 5;
use XML::LibXSLT;

my $parser = XML::LibXML->new();
my $xslt = XML::LibXSLT->new();
# TEST
ok ($parser, '$parser was initted.');
# TEST
ok ($xslt, '$xslt was initted.');

my $source = $parser->parse_string(<<'EOT');
<?xml version="1.0" encoding="ISO-8859-1"?>
<document></document>
EOT

my $style = $parser->parse_string(<<'EOT');
<html
    xsl:version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
>
<head>
</head>
</html>
EOT

# TEST
ok ($style, '$style is true.');
my $stylesheet = $xslt->parse_stylesheet($style);

my $results = $stylesheet->transform($source);
# TEST
ok ($results, '$results are true.');

# TEST
is ($stylesheet->media_type, 'text/html', 'media_type is text/html');
