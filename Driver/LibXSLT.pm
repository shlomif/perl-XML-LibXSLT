# base class.
package Driver::LibXSLT;

use Driver::BaseClass;
@ISA = qw(Driver::BaseClass);

use XML::LibXSLT;
use XML::LibXML;
use IO::File;

use vars qw(
        $parser
        $xslt
        $stylesheet
        $input
        );

sub init {
    $parser = XML::LibXML->new();
    $xslt = XML::LibXSLT->new();
}

sub load_stylesheet {
    my ($filename) = @_;
    my $styledoc = $parser->parse_file($filename);
    $stylesheet = $xslt->parse_stylesheet($styledoc);
}

sub load_input {
    my ($filename) = @_;
    $input = $parser->parse_file($filename);
}

sub run_transform {
    my ($output, $iterations) = @_;
    for (my $i = 0; $i < $iterations; $i++) {
        my $outfile = IO::File->new(">$output")
                || die "Can't write $output : $!";
        my $results = $stylesheet->transform($input);
        $stylesheet->output_fh($results, $outfile);
    }
}

1;
