# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

use Test;
# BEGIN { plan tests=>6; }
BEGIN { plan tests=>4; }
END {ok(0) unless $loaded;}
use XML::LibXML;
$loaded = 1;
ok($loaded);

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

# this performs general dom tests
my $file    = "example/dromeds.xml";

# init the file parser
my $parser = XML::LibXML->new();
$dom    = $parser->parse_file( $file );

if ( defined $dom ) {
  # get the root document
  $elem   = $dom->getDocumentElement(); 
  ok( defined $elem && $elem->getName() eq "dromedaries" );
  if( defined $elem ) {
    my @nodelist = $elem->getElementsByTagName( "species" );
    ok( scalar(@nodelist) == 3 );
    return unless scalar(@nodelist) == 3;
    my $lama = $nodelist[1];
    ok( defined $lama && $lama->getAttribute( "name" ) eq "Llama" );
#    $nodelist->delNode( $lama );
#    my $alpaca = $nodelist->getNode( 1 );
#    ok( defined $alpaca && $alpaca->getAttribute( "name" ) eq "Alpaca" );
#    $nodelist->addNode( $lama );
#    $lama = $nodelist->getNode( 2 );
#    ok( defined $lama && $lama->getAttribute( "name" ) eq "Llama" );
  }	
}
