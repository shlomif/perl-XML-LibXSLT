# $Id$

package XML::LibXSLT;

use strict;
use vars qw($VERSION @ISA);

use XML::LibXML;

require Exporter;

$VERSION = "0.92";

require DynaLoader;

@ISA = qw(DynaLoader);

bootstrap XML::LibXSLT $VERSION;

sub new {
    my $class = shift;
    my %options = @_;
    my $self = bless \%options, $class;
    return $self;
}

1;
__END__
# Below is the stub of documentation for your module. You better edit it!

=head1 NAME

XML::LibXSLT - Perl extension for blah blah blah

=head1 SYNOPSIS

  use XML::LibXSLT;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for XML::LibXSLT was created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut
