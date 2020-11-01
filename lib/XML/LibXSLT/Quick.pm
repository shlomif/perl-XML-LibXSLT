package XML::LibXSLT::Quick;

use strict;
use warnings;

use XML::LibXML  ();
use XML::LibXSLT ();

my $xslt = XML::LibXSLT->new;

sub new
{
    my $class = shift;
    my $args  = +{@_};

    my $style_doc = XML::LibXML->load_xml(
        location => $args->{location},
        no_cdata => ( $args->{no_cdata} // 0 ),
    );
    my $stylesheet = $xslt->parse_stylesheet($style_doc);
    return $stylesheet;
}

1;

__END__

=head1 NAME

XML::LibXSLT::Quick - a quicker interface to XML::LibXSLT

=head1 SYNOPSIS

work-in-progress

=head1 METHODS

=head2 XML::LibXSLT::Quick->new(location=>"./xslt/my.xslt");

TBD.

=cut
