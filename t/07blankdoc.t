use Test;
BEGIN { plan tests => 5 }
use XML::LibXSLT;

my $parser = XML::LibXML->new();
my $xslt = XML::LibXSLT->new();
ok($parser); ok($xslt);

my $source = $parser->parse_string(<<'EOT');
<?xml version="1.0" encoding="ISO-8859-1"?>
<document></document>
EOT

my $style = $parser->parse_string(<<'EOT');
<?xml version="1.0" encoding="ISO-8859-1"?>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
xmlns:data="data.uri" version="1.0">
<xsl:output encoding="ISO-8859-1" method="text"/>

<data:type>typed data in stylesheet</data:type>

<xsl:template match="/*">

Data: <xsl:value-of select="document('')/xsl:stylesheet/data:type"/><xsl:text>
</xsl:text>

</xsl:template>

</xsl:stylesheet>
EOT

ok($style);
my $stylesheet = $xslt->parse_stylesheet($style);
# my $stylesheet = $xslt->parse_stylesheet_file("example/document.xsl");

my $results = $stylesheet->transform($source);
ok($results);

ok($results->toString, qr/typed data in stylesheet/);

