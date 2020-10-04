#!./perl

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';	# for which_perl() etc
    set_up_inc('../lib');
}

use strict;
use warnings;
use Config;

my ($Null, $Curdir);
if(eval {require File::Spec; 1}) {
    $Null = File::Spec->devnull;
    $Curdir = File::Spec->curdir;
} else {
    die $@ unless is_miniperl();
    $Curdir = '.';
    diag("miniperl failed to load File::Spec, error is:\n$@");
    diag("\ncontinuing, assuming '.' for current directory. Some tests will be skipped.");
}

if ($^O eq 'MSWin32') {
    # under minitest, buildcustomize sets this to 1, which means
    # nlinks isn't populated properly, allow nlinks tests to pass
    ${^WIN32_SLOPPY_STAT} = 0;
}

plan tests => 110;

my $Perl = which_perl();

$ENV{LC_ALL}   = 'C';		# Forge English error messages.
$ENV{LANGUAGE} = 'C';		# Ditto in GNU.

my $Is_Amiga   = $^O eq 'amigaos';
my $Is_Cygwin  = $^O eq 'cygwin';
my $Is_Darwin  = $^O eq 'darwin';
my $Is_Dos     = $^O eq 'dos';
my $Is_MSWin32 = $^O eq 'MSWin32';
my $Is_NetWare = $^O eq 'NetWare';
my $Is_OS2     = $^O eq 'os2';
my $Is_Solaris = $^O eq 'solaris';
my $Is_VMS     = $^O eq 'VMS';
my $Is_MPRAS   = $^O =~ /svr4/ && -f '/etc/.relid';
my $Is_Android = $^O =~ /android/;
my $Is_Dfly    = $^O eq 'dragonfly';

my $Is_Dosish  = $Is_Dos || $Is_OS2 || $Is_MSWin32 || $Is_NetWare;

my $ufs_no_ctime = ($Is_Dfly || $Is_Darwin) && (() = `df -t ufs . 2>/dev/null`) == 2;

my $Is_linux_container = is_linux_container();

if ($Is_Cygwin && !is_miniperl) {
  require Win32;
  Win32->import;
}

my($DEV, $INO, $MODE, $NLINK, $UID, $GID, $RDEV, $SIZE,
   $ATIME, $MTIME, $CTIME, $BLKSIZE, $BLOCKS) = (0..12);

my $tmpfile = tempfile();
my $tmpfile_link = tempfile();

chmod 0666, $tmpfile;
unlink_all $tmpfile;
open(FOO, ">$tmpfile") || DIE("Can't open temp test file: $!");
close FOO;

open(FOO, ">$tmpfile") || DIE("Can't open temp test file: $!");

my($nlink, $mtime, $ctime) = (stat(FOO))[$NLINK, $MTIME, $CTIME];

# The clock on a network filesystem might be different from the
# system clock.
my $Filesystem_Time_Offset = abs($mtime - time); 

#nlink should if link support configured in Perl.
SKIP: {
    skip "No link count - Hard link support not built in.", 1
	unless $Config{d_link};

    is($nlink, 1, 'nlink on regular file');
}

SKIP: {
  skip "mtime and ctime not reliable", 2
    if $Is_MSWin32 or $Is_NetWare or $Is_Cygwin or $Is_Dos or $Is_Darwin;

  ok( $mtime,           'mtime' );
  is( $mtime, $ctime,   'mtime == ctime' );
}


# Cygwin seems to have a 3 second granularity on its timestamps.
my $funky_FAT_timestamps = $Is_Cygwin;
sleep 3 if $funky_FAT_timestamps;

print FOO "Now is the time for all good men to come to.\n";
close(FOO);

sleep 2;

my $has_link = 1;
my $inaccurate_atime = 0;
if (defined &Win32::IsWinNT && Win32::IsWinNT()) {
    if (Win32::FsType() ne 'NTFS') {
        $has_link            = 0;
	$inaccurate_atime    = 1;
    }
}

SKIP: {
    skip "No link on this filesystem", 6 unless $has_link;
    unlink $tmpfile_link;
    my $lnk_result = eval { link $tmpfile, $tmpfile_link };
    skip "link() unimplemented", 6 if $@ =~ /unimplemented/;

    is( $@, '',         'link() implemented' );
    ok( $lnk_result,    'linked tmp testfile' );
    ok( chmod(0644, $tmpfile),             'chmoded tmp testfile' );

    my($nlink, $mtime, $ctime) = (stat($tmpfile))[$NLINK, $MTIME, $CTIME];

    SKIP: {
        skip "No link count", 1 if $Config{dont_use_nlink};
        skip "Cygwin9X fakes hard links by copying", 1
          if $Config{myuname} =~ /^cygwin_(?:9\d|me)\b/i;

        is($nlink, 2,     'Link count on hard linked file' );
    }

    SKIP: {
	skip_if_miniperl("File::Spec not built for minitest", 2);
        my $cwd = File::Spec->rel2abs($Curdir);
        skip "Solaris tmpfs has different mtime/ctime link semantics", 2
                                     if $Is_Solaris and $cwd =~ m#^/tmp# and
                                        $mtime && $mtime == $ctime;
        skip "AFS has different mtime/ctime link semantics", 2
                                     if $cwd =~ m#$Config{'afsroot'}/#;
        skip "AmigaOS has different mtime/ctime link semantics", 2
                                     if $Is_Amiga;
        # Win32 could pass $mtime test but as FAT and NTFS have
        # no ctime concept $ctime is ALWAYS == $mtime
        # expect netware to be the same ...
        skip "No ctime concept on this OS", 2
                                     if $Is_MSWin32 || $ufs_no_ctime;

        if( !ok($mtime, 'hard link mtime') ||
            !isnt($mtime, $ctime, 'hard link ctime != mtime') ) {
            print STDERR <<DIAG;
# Check if you are on a tmpfs of some sort.  Building in /tmp sometimes
# has this problem.  Building on the ClearCase VOBS filesystem may also
# cause this failure.
#
# Some UFS implementations don't have a ctime concept, and thus are
# expected to fail this test.
DIAG
        }
    }

}

# truncate and touch $tmpfile.
open(F, ">$tmpfile") || DIE("Can't open temp test file: $!");
ok(-z \*F,     '-z on empty filehandle');
ok(! -s \*F,   '   and -s');
close F;

ok(-z $tmpfile,     '-z on empty file');
ok(! -s $tmpfile,   '   and -s');

open(F, ">$tmpfile") || DIE("Can't open temp test file: $!");
print F "hi\n";
close F;

open(F, "<$tmpfile") || DIE("Can't open temp test file: $!");
ok(!-z *F,     '-z on empty filehandle');
ok( -s *F,   '   and -s');
close F;

ok(! -z $tmpfile,   '-z on non-empty file');
ok(-s $tmpfile,     '   and -s');


# Strip all access rights from the file.
ok( chmod(0000, $tmpfile),     'chmod 0000' );

SKIP: {
    skip "-r, -w and -x have different meanings on VMS", 3 if $Is_VMS;

    SKIP: {
        # Going to try to switch away from root.  Might not work.
        my $olduid = $>;
        eval { $> = 1; };
        skip "Can't test -r or -w meaningfully if you're superuser", 2
          if ($Is_Cygwin ? _ingroup(544, 1) : $> == 0);

        SKIP: {
            skip "Can't test -r meaningfully?", 1 if $Is_Dos;
            ok(!-r $tmpfile,    "   -r");
        }

        ok(!-w $tmpfile,    "   -w");

        # switch uid back (may not be implemented)
        eval { $> = $olduid; };
    }

    ok(! -x $tmpfile,   '   -x');
}



ok(chmod(0700,$tmpfile),    'chmod 0700');
ok(-r $tmpfile,     '   -r');
ok(-w $tmpfile,     '   -w');

SKIP: {
    skip "-x simply determines if a file ends in an executable suffix", 1
      if $Is_Dosish;

    ok(-x $tmpfile,     '   -x');
}

ok(  -f $tmpfile,   '   -f');
ok(! -d $tmpfile,   '   !-d');

# Is this portable?
ok(  -d '.',          '-d cwd' );
ok(! -f '.',          '!-f cwd' );


SKIP: {
    unlink($tmpfile_link);
    my $symlink_rslt = eval { symlink $tmpfile, $tmpfile_link };
    skip "symlink not implemented", 3 if $@ =~ /unimplemented/;

    is( $@, '',     'symlink() implemented' );
    ok( $symlink_rslt,      'symlink() ok' );
    ok(-l $tmpfile_link,    '-l');
}

ok(-o $tmpfile,     '-o');

ok(-e $tmpfile,     '-e');

unlink($tmpfile_link);
ok(! -e $tmpfile_link,  '   -e on unlinked file');

SKIP: {
    skip "No character, socket or block special files", 6
      if $Is_MSWin32 || $Is_NetWare || $Is_Dos;
    skip "/dev isn't available to test against", 6
      unless -d '/dev' && -r '/dev' && -x '/dev';
    skip "Skipping: unexpected ls output in MP-RAS", 6
      if $Is_MPRAS;

    # VMS problem:  If GNV or other UNIX like tool is installed, then
    # sometimes Perl will find /bin/ls, and will try to run it.
    # But since Perl on VMS does not know to run it under Bash, it will
    # try to run the DCL verb LS.  And if the VMS product Language
    # Sensitive Editor is installed, or some other LS verb, that will
    # be run instead.  So do not do this until we can teach Perl
    # when to use BASH on VMS.
    skip "ls command not available to Perl in OpenVMS right now.", 6
      if $Is_VMS;

    delete $ENV{CLICOLOR_FORCE};
    my $LS  = $Config{d_readlink} && !$Is_Android ? "ls -lL" : "ls -l";
    my $CMD = "$LS /dev 2>/dev/null";
    my $DEV = qx($CMD);

    skip "$CMD failed", 6 if $DEV eq '';

    my @DEV = do { my $dev; opendir($dev, "/dev") ? readdir($dev) : () };

    skip "opendir failed: $!", 6 if @DEV == 0;

    # /dev/stdout might be either character special or a named pipe,
    # or a symlink, or a socket, depending on which OS and how are
    # you running the test, so let's censor that one away.
    # Similar remarks hold for stderr.
    $DEV =~ s{^[cpls].+?\sstdout$}{}m;
    @DEV =  grep { $_ ne 'stdout' } @DEV;
    $DEV =~ s{^[cpls].+?\sstderr$}{}m;
    @DEV =  grep { $_ ne 'stderr' } @DEV;

    # /dev/printer is also naughty: in IRIX it shows up as
    # Srwx-----, not srwx------.
    $DEV =~ s{^.+?\sprinter$}{}m;
    @DEV =  grep { $_ ne 'printer' } @DEV;

    # If running as root, we will see .files in the ls result,
    # and readdir() will see them always.  Potential for conflict,
    # so let's weed them out.
    $DEV =~ s{^.+?\s\..+?$}{}m;
    @DEV =  grep { ! m{^\..+$} } @DEV;

    # sometimes files cannot be stat'd on cygwin, making inspecting pointless
    # remove them from both @DEV and $DEV
    @DEV = grep $DEV =~ s/^.\?{9}.*\s$_(?: -> .*)?$//m ? () : $_, @DEV
      if $Is_Cygwin;

    # Irix ls -l marks sockets with 'S' while 's' is a 'XENIX semaphore'.
    if ($^O eq 'irix') {
        $DEV =~ s{^S(.+?)}{s$1}mg;
    }

    my $try = sub {
	my @c1 = eval qq[\$DEV =~ /^$_[0].*/mg];
	my @c2 = eval qq[grep { $_[1] "/dev/\$_" } \@DEV];
	my $c1 = scalar @c1;
	my $c2 = scalar @c2;
        diag ( "================",$DEV, "--------", @DEV, "================", @c1, "--------", @c2, "================") unless #
	is($c1, $c2, "ls and $_[1] agreeing on /dev ($c1 $c2)");
    };

{
    $try->('b', '-b');
    $try->('c', '-c');
    $try->('s', '-S');
}

ok(! -b $Curdir,    '!-b cwd');
ok(! -c $Curdir,    '!-c cwd');
ok(! -S $Curdir,    '!-S cwd');

}

END {
    chmod 0666, $tmpfile;
    unlink_all $tmpfile;
}

sub _ingroup {
    my ($gid, $eff)   = @_;

    $^O eq "VMS"    and return $_[0] == $);

    my ($egid, @supp) = split " ", $);
    my ($rgid)        = split " ", $(;

    $gid == ($eff ? $egid : $rgid)  and return 1;
    grep $gid == $_, @supp          and return 1;

    return "";
}
