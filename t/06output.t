use Test;
BEGIN { plan tests => 6 }

use XML::LibXSLT;
use XML::LibXML;
ok(1);

my $parser = XML::LibXML->new();
my $xslt = XML::LibXSLT->new();

my $source = $parser->parse_string(<<'EOF');
<?xml version="1.0"?>
<top/>
EOF
        
ok($source);

my $style_doc = $parser->parse_string(<<'EOF');
<?xml version="1.0"?>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="1.0"
>

<xsl:output method="xml"/>

<xsl:template match="*|@*">
<xsl:copy-of select="."/>
</xsl:template>

</xsl:stylesheet>
EOF

ok($style_doc);

my $stylesheet = $xslt->parse_stylesheet($style_doc);

ok($stylesheet);

ok($stylesheet->output_encoding, 'UTF-8');

ok($stylesheet->media_type, 'text/xml');
