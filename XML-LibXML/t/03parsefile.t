use Test;
BEGIN { plan tests => 3 };
use XML::LibXML;
ok(1);

my $parser = XML::LibXML->new();
ok($parser);

my $doc = $parser->parse_file("example/dromeds.xml");

ok($doc);

# warn "doc is: ", $doc->toString, "\n";
