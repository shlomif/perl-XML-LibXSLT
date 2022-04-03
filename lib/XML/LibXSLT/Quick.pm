package XML::LibXSLT::Quick;

use strict;
use warnings;
use 5.010;
use autodie;

use Carp ();

use XML::LibXML  ();
use XML::LibXSLT ();

sub new
{
    my $class = shift;
    my $args  = shift;

    my $xslt = ( $args->{xslt_parser} // XML::LibXSLT->new() );
    my $xml  = ( $args->{xml_parser}  // XML::LibXML->new() );

    my $style_doc = XML::LibXML->load_xml(
        location => $args->{location},
        no_cdata => ( $args->{no_cdata} // 0 ),
    );
    my $stylesheet = $xslt->parse_stylesheet($style_doc);
    my $obj        = bless( +{}, $class );
    $obj->{_xml_parser} = $xml;
    $obj->{_stylesheet} = $stylesheet;
    return $obj;
}

sub _write_utf8_file
{
    my ( $out_path, $contents ) = @_;

    open my $out_fh, '>:encoding(utf8)', $out_path;

    print {$out_fh} $contents;

    close($out_fh);

    return;
}

sub _write_raw_file
{
    my ( $out_path, $contents ) = @_;

    open my $out_fh, '>:raw', $out_path;

    print {$out_fh} $contents;

    close($out_fh);

    return;
}

sub generic_transform
{
    my $self = shift;

    my ( $dest, $source, ) = @_;
    my $parser     = $self->{_xml_parser};
    my $stylesheet = $self->{_stylesheet};

    my $ret;
    if ( ref($source) eq '' )
    {
        $source = $parser->parse_string($source);
    }
    my $results = $stylesheet->transform( $source, );
    $ret = $stylesheet->output_as_chars( $results, );
    my $destref = ref($dest);
    if ( $destref eq "SCALAR" )
    {
        if ( ref($$dest) eq "" )
        {
            $$dest .= $ret;
        }
        else
        {
            Carp::confess(
                "\$dest as a reference to a non-string scalar is not supported!"
            );
        }
    }
    elsif ( $destref eq "HASH" )
    {
        my $type = $dest->{type};
        if ( $type eq "file" )
        {
            my $path = $dest->{path};
            _write_utf8_file( $path, $ret );
        }
        else
        {
            Carp::confess("unknown dest type");
        }
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
