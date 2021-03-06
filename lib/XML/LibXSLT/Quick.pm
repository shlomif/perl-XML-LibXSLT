package XML::LibXSLT::Quick;

use strict;
use warnings;
use 5.010;

use XML::LibXML  ();
use XML::LibXSLT ();

sub new
{
    my $class = shift;
    my $args  = +{@_};

    my $xslt = ( $args->{xslt_parser} // XML::LibXSLT->new() );

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

=head1 SEE ALSO

L<XML::LibXSLT::Easy> by Yuval Kogman - requires some MooseX modules.

L<XML::LibXSLT> - used as the backend of this module.

=cut
