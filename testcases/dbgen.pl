#!/usr/bin/perl

use strict;
use warnings;

my $size = shift;

if ($size eq "")
{
    die "usage:  dbgen.pl [size]\n";
}

@firstnames = ("Al", "Bob", "Charles", "David", "Egon", "Farbood",
               "George", "Hank", "Inki", "James");
@lastnames = ("Aranow", "Barker", "Corsetti", "Dershowitz", "Engleman",
              "Franklin", "Grice", "Haverford", "Ilvedson", "Jones");
@states = ("AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
           "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
           "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
           "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
           "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY");

print "<?xml version=\"1.0\"?>\n";
print "\n";
print "<table>\n";

for my $i (0 .. $size-1)
{
    $first = $firstnames [$i % 10];
    $last = $lastnames [($i / 10) % 10];
    $state = $states [($i / 100) % 50];
    $zip = 22000 + $i / 5000;

    printf "  <row>\n";
    printf "    <id>%04d</id>\n", $i;
    printf "    <firstname>$first</firstname>\n", $i;
    printf "    <lastname>$last</lastname>\n", $i;
    printf "    <street>%d Any St.</street>\n", ($i % 100) + 1;
    printf "    <city>Anytown</city>\n";
    printf "    <state>$state</state>\n";
    printf "    <zip>%d</zip>\n", $zip;
    printf "  </row>\n";
}

print "</table>\n";

