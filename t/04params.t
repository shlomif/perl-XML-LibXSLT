use Test;
BEGIN { plan tests => 6 }

use XML::LibXSLT;
use XML::LibXML;
ok(1);

my ($xml_file, $xsl_file) = @_;


my $parser = XML::LibXML->new();
my $xslt = XML::LibXSLT->new();

my $source = $parser->parse_string(<<'EOF');
<?xml version="1.0" encoding="UTF-8" ?>
<top>
<next myid="next">NEXT</next>
<bottom myid="last">LAST</bottom>
</top>
EOF
        
ok($source);

my $style_doc = $parser->parse_string(<<'EOF');
<?xml version="1.0"?>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    version="1.0"
>

<xsl:output method="xml" indent="yes"/>
<xsl:param name="incoming"/>

<xsl:template match="*">
<xsl:value-of select="$incoming"/>
<xsl:text>&#xa;</xsl:text>
      <xsl:copy>
        <xsl:apply-templates select="*"/>
        </xsl:copy>
</xsl:template>

</xsl:stylesheet>
EOF

ok($style_doc);

my $stylesheet = $xslt->parse_stylesheet($style_doc);

ok($stylesheet);

my $results = $stylesheet->transform($source,
        'incoming' => 'INCOMINGTEXT',
        'incoming' => 'INCOMINGTEXT2',
        'outgoing' => 'OUTGOINGTEXT',
        );

ok($results);

ok($stylesheet->output_string($results));
