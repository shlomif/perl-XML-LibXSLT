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
        $handler
        );

sub init {
    my %options = @_;
    $xslt = XML::Sablotron->new();
    $handler = Driver::Sablotron::Handler->new(%options);
    $xslt->RegHandler(0, $handler);
}

sub shutdown {
    $xslt->ClearError();
    $xslt->UnregHandler(0, $handler);
    undef $handler;
    undef $xslt;
    undef $input;
    undef $stylesheet;
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

        my $retcode = $xslt->RunProcessor("arg:/template", "arg:/xml_resource", "arg:/result",                                                [], $args);
        $result = $xslt->GetResultArg("result");
        
        print $outfile $result;
        $outfile->close;
    }
}

package Driver::Sablotron::Handler;

sub new {
    my $class = shift;
    my %options = @_;
    bless \%options, $class;
}

sub MHMakeCode {
    my $self = shift;
    my $processor = shift;

    my ($severity, $facility, $code) = @_;
    return $code;
}

sub MHLog {
    my $self = shift;
    my $processor = shift;
    
    warn "Sablotron [Log]: ", join(' :: ', @fields), "\n" if $self->{verbose};
    return 1;
}

sub MHError {
    my $self = shift;
    my $processor = shift;
    
    warn "Sablotron [Error]: ", join(' :: ', @fields), "\n" if $self->{verbose};
    return 1;
}

1;
