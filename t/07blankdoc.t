use Test;
BEGIN { plan tests => 0 }
use XML::LibXSLT;

if (0) {
# for some reason this doesnt work on latest libxslt.
my $parser = XML::LibXML->new();
my $xslt = XML::LibXSLT->new();
ok($parser); ok($xslt);

my $source = $parser->parse_string(<<'EOT');
<?xml version="1.0" encoding="ISO-8859-1"?>
<document></document>
EOT

my $style = $parser->parse_string(<<'EOT');
<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
<xsl:output encoding="ISO-8859-1" method="text"/>

<data>data in stylesheet</data>

<xsl:template match="document">

Data: <xsl:value-of select="document('')/xsl:stylesheet/data"/><xsl:text>
</xsl:text>

</xsl:template>

</xsl:stylesheet>
EOT

ok($style);
my $stylesheet = $xslt->parse_stylesheet($style);

my $results = $stylesheet->transform($source);
ok($results);

ok($results->toString =~ /data in stylesheet/);
}
