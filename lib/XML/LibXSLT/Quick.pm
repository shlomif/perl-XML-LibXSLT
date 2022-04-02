package XML::LibXSLT::Quick;

use strict;
use warnings;
use 5.010;

use XML::LibXML  ();
use XML::LibXSLT ();

sub new
{
    my $class = shift;
    my $args  = shift;

    my $xslt = ( $args->{xslt_parser} // XML::LibXSLT->new() );

    my $style_doc = XML::LibXML->load_xml(
        location => $args->{location},
        no_cdata => ( $args->{no_cdata} // 0 ),
    );
    my $stylesheet = $xslt->parse_stylesheet($style_doc);
    my $obj        = bless( +{}, $class );
    $obj->{_stylesheet} = $stylesheet;
    return $obj;
}

sub generic_transform
{
    my $self = shift;

    my ( $dest, $source, ) = @_;
    my $stylesheet = $self->{_stylesheet};

    my $ret;
    my $results = $stylesheet->transform( $source, );
    $ret = $stylesheet->output_as_chars( $results, );
    if ( ref($dest) eq "SCALAR" )
    {
        $$dest .= $ret;
    }
    else
    {
        $dest->print($ret);
    }
    return $ret;
}

sub output_as_chars
{
    my $self = shift;

    return $self->{_stylesheet}->output_as_chars(@_);
}

sub transform
{
    my $self = shift;

    return $self->{_stylesheet}->transform(@_);
}

sub transform_into_chars
{
    my $self = shift;

    return $self->{_stylesheet}->transform_into_chars(@_);
}

1;

__END__

=head1 NAME

XML::LibXSLT::Quick - a quicker interface to XML::LibXSLT

=head1 SYNOPSIS

work-in-progress

=head1 METHODS

=head2 XML::LibXSLT::Quick->new({ location=>"./xslt/my.xslt", });

TBD.

=head1 SEE ALSO

L<XML::LibXSLT::Easy> by Yuval Kogman - requires some MooseX modules.

L<XML::LibXSLT> - used as the backend of this module.

=cut
