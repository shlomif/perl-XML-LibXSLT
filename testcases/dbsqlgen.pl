#!/usr/bin/perl

$size = shift;

if ($size eq "") 
{
    die "usage:  dbsqlgen.pl [size]\n";
}

print "<xsl:stylesheet xmlns:xsl=\"http://www.w3.org/1999/XSL/Transform\" version=\"1.0\">\n\n";

print "<xsl:template match=\"table\">\n";
print "  <document>\n";
print "    <!-- select * from table where id = ... -->\n";
for ($i=0; $i<$size; $i+=10)
{
    printf "    <xsl:apply-templates select=\"row[id=%d]\"/>\n", $i+3;
}

print "    <!-- select * from table where id > ... and id < ... -->\n";
for ($i=0; $i<$size; $i+=10)
{
    printf "    <xsl:apply-templates select=\"row[id&gt;%d and id&lt;%d]\"/>\n", $i+4, $i+8;
}

print "    <!-- select * from table where firstname = 'Bob' -->\n";
print "    <xsl:apply-templates select=\"row[firstname='Bob']\"/>\n";

print "    <!-- select firstname, lastname from table where id=... -->\n";
print "    <xsl:for-each select=\"row[id mod 10 = 9]\">\n";
print "       <xsl:apply-templates select=\"firstname\"/>\n";
print "       <xsl:apply-templates select=\"lastname\"/>\n";
print "    </xsl:for-each>\n";
print "  </document>\n";
print "</xsl:template>\n\n";

print "<xsl:template match=\"row\">\n";
print "  <xsl:apply-templates select=\"id\"/>\n";
print "  <xsl:apply-templates select=\"firstname\"/>\n";
print "  <xsl:apply-templates select=\"lastname\"/>\n";
print "  <xsl:apply-templates select=\"street\"/>\n";
print "  <xsl:apply-templates select=\"city\"/>\n";
print "  <xsl:apply-templates select=\"state\"/>\n";
print "  <xsl:apply-templates select=\"zip\"/>\n";
print "  <xsl:text>&#x0A;</xsl:text>\n";
print "</xsl:template>\n\n";

print "<xsl:template match=\"id|firstname|lastname|street|city|state|zip\">\n";
print "  <xsl:value-of select=\"name(.)\"/>\n";
print "  <xsl:text>=</xsl:text>\n";
print "  <xsl:value-of select=\".\"/>\n";
print "  <xsl:text>&#x0A;</xsl:text>\n";
print "</xsl:template>\n\n";

print "</xsl:stylesheet>\n";
