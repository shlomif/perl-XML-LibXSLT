use Test;
BEGIN { plan tests => 3 };
use XML::LibXML;
ok(1);

my $parser = XML::LibXML->new();
ok($parser);

my $doc = $parser->parse_string(<<'EOT');
<xml/>
EOT

ok($doc);

my $doc2 = $parser->parse_string(<<'EOT');
<foo/>
EOT

# warn "doc is: ", $doc2->toString, "\n";
