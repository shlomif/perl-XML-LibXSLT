# base class.
package Driver::Sablotron;

use Driver::BaseClass;
@ISA = qw(Driver::BaseClass);

use XML::Sablotron;
use IO::File;

use vars qw(
        $xslt
        $stylesheet
        $input
        );

sub init {
    $xslt = XML::Sablotron->new();
}

sub load_stylesheet {
    my ($filename) = @_;
    my $fh = new IO::File;
    if ($fh->open("< $filename")) {
        local $/;        
        $stylesheet = <$fh>;
        $fh->close;
    }
}

sub load_input {
    my ($filename) = @_;
    my $fh = new IO::File;   
    if ($fh->open("< $filename")) { 
        local $/; 
        $input = <$fh>;   
        $fh->close;       
    }    
}

sub run_transform {
    my ($output, $iterations) = @_;
    for (my $i = 0; $i < $iterations; $i++) {
        my $outfile = IO::File->new(">$output")
                || die "Can't write $output : $!";
 
        my $result = '';
        my $args = ['template', "$stylesheet", 'xml_resource', "$input"];

        my $retcode = $xslt->RunProcessor("arg:/template", "arg:/xml_resource", "arg:/result",
                                                [], $args);
        $result = $xslt->GetResultArg("result");

        print $outfile $result;
        $outfile->close;
    }
}

1;
