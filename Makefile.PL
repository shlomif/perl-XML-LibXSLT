# $Id$

use ExtUtils::MakeMaker;
use Config;
use Symbol;
use File::Spec;

$|=0;

my %config;

while($_ = shift) {
    my ($key, $val) = split(/=/, $_, 2);
    $config{$key} = $val;
}

my $DEBUG = delete $config{DEBUG};

# get libs and inc from gnome-config
eval {
    print "running xslt-config... ";
    my $ver = backtick('xslt-config --version');
    my ($major, $minor) = $ver =~ /(\d+)\.(\d+)/g;
    die "VERSION" unless $major > 0 || $minor >= 7;
    $config{LIBS} ||= backtick('xslt-config --libs');
    $config{INC} ||= backtick('xslt-config --cflags');
    print "ok\n";
};
if ($@) {
    print "failed\n";
    if ($@ =~ /^VERSION/) { 
        die "XML::LibXSLT needs libxslt version 0.7.0 or higher\n";
    }
    warn "*** ", $@ if $DEBUG;
    warn "using fallback values for LIBS and INC\n";
    # backtick fails if gnome-config didn't exist...
    $config{LIBS} = '-L/usr/local/lib -L/usr/lib -lxslt -lxml2 -lz -lm';
    $config{INC} = '-I/usr/local/include -I/usr/include';
    
    print <<OPT;
options:
  LIBS='$config{LIBS}'
  INC='$config{INC}'
If this is wrong, Re-run as:
  \$ $^X Makefile.PL LIBS='-L/path/to/lib' INC='-I/path/to/include'

OPT

}

if ($config{LIBS} !~ /\-lxslt/) {
    $config{LIBS} .= ' -lxslt -lxml2 -lz -lm';
}

if (!have_library("xslt")) {
    die <<DEATH;
libxslt not found
Try setting LIBS and INC values on the command line
Or get libxslt and libxml2 from 
  http://www.libxml.org/
If you install via RPMs, make sure you also install the -devel
RPMs, as this is where the headers (.h files) are.
DEATH
}

WriteMakefile(
    'NAME'	=> 'XML::LibXSLT',
    'VERSION_FROM' => 'LibXSLT.pm', # finds $VERSION
    'AUTHOR'    => 'Matt Sergeant',
    'ABSTRACT'  => 'Interface to Gnome libxslt library',
    'PREREQ_PM' => { 'XML::LibXML' => "0.94", },
    %config,
);

###################################################################
# Functions
#  - these should really be in MakeMaker... But &shrug;
###################################################################

use Config;
use Symbol;
use File::Spec;

use vars qw/$LINK $DEVNULL $CC $is_Win32/;

BEGIN {
  $is_Win32 = ($^O =~ /Win32/);
  if ($is_Win32) {
      $CC = "$Config{cc} -c $Config{ccflags} -I$Config{incpath} %s conftest.c ";
      $LINK = "LINK $Config{ccdlflags} $Config{ldflags} conftest.obj $Config{libs} %s %s ";
      $DEVNULL = 'DEVNULL';
  }
  else {
      $LINK = "$Config{cc} $Config{ccdlflags} -o conftest $Config{ccflags} -I$Config{incpath} $Config{ldflags} %s %s conftest.c $Config{libs} %s";
      $DEVNULL = eval { File::Spec->devnull };
      if ($@) { $DEVNULL = '/dev/null' }
  }
}

sub rm_f {
    my @files = @_;
    my @realfiles;
    foreach (@files) {
        push @realfiles, glob($_);
    }
    if (@realfiles) {
        chmod(0777, @realfiles);
        unlink(@realfiles);
    }
}

sub xsystem {
    my $command = shift;
    if ($DEBUG) {
        print $command, "\n";
        if (system($command) != 0) {
            die "system call to '$command' failed";
        }
        return 1;
    }
    open(OLDOUT, ">&STDOUT");
    open(OLDERR, ">&STDERR");
    open(STDOUT, ">$DEVNULL");
    open(STDERR, ">$DEVNULL");
    my $retval = system($command);
    open(STDOUT, ">&OLDOUT");
    open(STDERR, ">&OLDERR");
    if ($retval != 0) {
        die "system call to '$command' failed";
    }
    return 1;
}

sub backtick {
    my $command = shift;
    if ($DEBUG) {
        print $command, "\n";
        my $results = `$command`;
        chomp $results;
        if ($? != 0) {
            die "backticks call to '$command' failed";
        }
        return $results;
    }
    open(OLDOUT, ">&STDOUT");
    open(OLDERR, ">&STDERR");
    open(STDOUT, ">$DEVNULL");
    open(STDERR, ">$DEVNULL");
    my $results = `$command`;
    my $retval = $?;
    open(STDOUT, ">&OLDOUT");
    open(STDERR, ">&OLDERR");
    if ($retval != 0) {
        die "backticks call to '$command' failed";
    }
    chomp $results;
    return $results;
}

sub try_link0 {
    my ($src, $opt) = @_;
    my $cfile = gensym();
    open($cfile, ">conftest.c") || die "Cannot write to file conftest.c";
    print $cfile $src;
    close($cfile);
    if ($is_Win32) {
        xsystem(sprintf($CC, $config{INC}));
        xsystem(sprintf($LINK, $config{LIBS}, $opt));
    }
    else {
        xsystem(sprintf($LINK, $config{INC}, $config{LIBS}, $opt));      
    }
}

sub try_link {
    my $result = eval {
        try_link0(@_);
    };
    warn $@ if $DEBUG && $@;
    rm_f("conftest*");
    return $result;
}

sub have_library {
    my ($lib, $func) = (@_, "main");
    printf("checking for %s() in -l%s... ", $func, $lib);

    my $result;
    if ($func) {
        my $libs = $is_Win32 ? " $lib.lib  " : "-l$lib";
        if ($is_Win32) {
            $result = try_link(<<"SRC", $libs);
#include <windows.h>
#include <winsock.h>
int main() { return 0; }
int t() { ${func}(); return 0; }
SRC
            unless ($result) {
                $result = try_link(<<"SRC", $libs);
#include <windows.h>
#include <winsock.h>
int main() { return 0; }
int t() { void ((*p)()); p = (void ((*)()))${func}; return 0; }
SRC
            }
        }
        else {

            $result = try_link(<<"SRC", $libs);
int main() { return 0; }
int t() { ${func}(); return 0; }
SRC
        }
    }

    unless ($result) {
        print "no\n";
        return 0;
    }

    if ($func ne "main") {
        $config{DEFINE} .= uc(" -Dhave_$func");
    }

    print "yes\n";
    return 1;
}
