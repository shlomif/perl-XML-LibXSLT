# $Id$

package XML::LibXML;

use strict;
use vars qw($VERSION @ISA);

$VERSION = "0.90";

require DynaLoader;

@ISA = qw(DynaLoader);

bootstrap XML::LibXML $VERSION;

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

XML::LibXML - Perl extension for blah blah blah

=head1 SYNOPSIS

  use XML::LibXML;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for XML::LibXML was created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head1 AUTHOR

A. U. Thor, a.u.thor@a.galaxy.far.far.away

=head1 SEE ALSO

perl(1).

=cut
