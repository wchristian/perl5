#!/usr/bin/perl


$VERSION = '1.00';

BEGIN {
  push @INC, './lib';
}
use strict ;

sub DEFAULT_ON  () { 1 }
sub DEFAULT_OFF () { 2 }

my $tree = {

'all' => {
       	'io'  		=> { 	'pipe' 		=> DEFAULT_OFF,
       				'unopened'	=> DEFAULT_OFF,
       				'closed'	=> DEFAULT_OFF,
       				'newline'	=> DEFAULT_OFF,
       				'exec'		=> DEFAULT_OFF,
			   },
       	'syntax'	=> { 	'ambiguous'	=> DEFAULT_OFF,
			     	'semicolon'	=> DEFAULT_OFF,
			     	'precedence'	=> DEFAULT_OFF,
			     	'bareword'	=> DEFAULT_OFF,
			     	'reserved'	=> DEFAULT_OFF,
				'digit'		=> DEFAULT_OFF,
			     	'parenthesis'	=> DEFAULT_OFF,
       	 			'deprecated'	=> DEFAULT_OFF,
       	 			'printf'	=> DEFAULT_OFF,
       	 			'prototype'	=> DEFAULT_OFF,
       	 			'qw'		=> DEFAULT_OFF,
			   },
       	'severe'	=> { 	'inplace'	=> DEFAULT_ON,
	 			'internal'	=> DEFAULT_ON,
         			'debugging'	=> DEFAULT_ON,
         			'malloc'	=> DEFAULT_ON,
	 		   },
       	'void'		=> DEFAULT_OFF,
       	'recursion'	=> DEFAULT_OFF,
       	'redefine'	=> DEFAULT_OFF,
       	'numeric'	=> DEFAULT_OFF,
        'uninitialized'	=> DEFAULT_OFF,
       	'once'		=> DEFAULT_OFF,
       	'misc'		=> DEFAULT_OFF,
       	'regexp'	=> DEFAULT_OFF,
       	'glob'		=> DEFAULT_OFF,
       	'y2k'		=> DEFAULT_OFF,
       	'chmod'		=> DEFAULT_OFF,
       	'umask'		=> DEFAULT_OFF,
       	'untie'		=> DEFAULT_OFF,
	'substr'	=> DEFAULT_OFF,
	'taint'		=> DEFAULT_OFF,
	'signal'	=> DEFAULT_OFF,
	'closure'	=> DEFAULT_OFF,
	'overflow'	=> DEFAULT_OFF,
	'portable'	=> DEFAULT_OFF,
	'utf8'		=> DEFAULT_OFF,
       	'exiting'	=> DEFAULT_OFF,
       	'pack'		=> DEFAULT_OFF,
       	'unpack'	=> DEFAULT_OFF,
       	 #'default'	=> DEFAULT_ON,
  	}
} ;


###########################################################################
sub tab {
    my($l, $t) = @_;
    $t .= "\t" x ($l - (length($t) + 1) / 8);
    $t;
}

###########################################################################

my %list ;
my %Value ;
my $index ;

sub walk
{
    my $tre = shift ;
    my @list = () ;
    my ($k, $v) ;

    foreach $k (sort keys %$tre) {
	$v = $tre->{$k};
	die "duplicate key $k\n" if defined $list{$k} ;
	$Value{$index} = uc $k ;
        push @{ $list{$k} }, $index ++ ;
	if (ref $v)
	  { push (@{ $list{$k} }, walk ($v)) }
	push @list, @{ $list{$k} } ;
    }

   return @list ;
}

###########################################################################

sub mkRange
{
    my @a = @_ ;
    my @out = @a ;
    my $i ;


    for ($i = 1 ; $i < @a; ++ $i) {
      	$out[$i] = ".."
          if $a[$i] == $a[$i - 1] + 1 && $a[$i] + 1 == $a[$i + 1] ;
    }

    my $out = join(",",@out);

    $out =~ s/,(\.\.,)+/../g ;
    return $out;
}

###########################################################################
sub printTree
{
    my $tre = shift ;
    my $prefix = shift ;
    my $indent = shift ;
    my ($k, $v) ;

    my $max = (sort {$a <=> $b} map { length $_ } keys %$tre)[-1] ;

    $prefix .= " " x $indent ;
    foreach $k (sort keys %$tre) {
	$v = $tre->{$k};
	print $prefix . "|\n" ;
	print $prefix . "+- $k" ;
	if (ref $v)
	{
	    print " " . "-" x ($max - length $k ) . "+\n" ;
	    printTree ($v, $prefix . "|" , $max + $indent - 1)
	}
	else
	  { print "\n" }
    }

}

###########################################################################

sub mkHex
{
    my ($max, @a) = @_ ;
    my $mask = "\x00" x $max ;
    my $string = "" ;

    foreach (@a) {
	vec($mask, $_, 1) = 1 ;
    }

    #$string = unpack("H$max", $mask) ;
    #$string =~ s/(..)/\x$1/g;
    foreach (unpack("C*", $mask)) {
	$string .= '\x' . sprintf("%2.2x", $_) ;
    }
    return $string ;
}

###########################################################################

if (@ARGV && $ARGV[0] eq "tree")
{
    #print "  all -+\n" ;
    printTree($tree, "   ", 4) ;
    exit ;
}

#unlink "warnings.h";
#unlink "lib/warnings.pm";
open(WARN, ">warnings.h") || die "Can't create warnings.h: $!\n";
open(PM, ">lib/warnings.pm") || die "Can't create lib/warnings.pm: $!\n";

print WARN <<'EOM' ;
/* !!!!!!!   DO NOT EDIT THIS FILE   !!!!!!!
   This file is built by warnings.pl
   Any changes made here will be lost!
*/


#define Off(x)			((x) / 8)
#define Bit(x)			(1 << ((x) % 8))
#define IsSet(a, x)		((a)[Off(x)] & Bit(x))


#define G_WARN_OFF		0 	/* $^W == 0 */
#define G_WARN_ON		1	/* -w flag and $^W != 0 */
#define G_WARN_ALL_ON		2	/* -W flag */
#define G_WARN_ALL_OFF		4	/* -X flag */
#define G_WARN_ONCE		8	/* set if 'once' ever enabled */
#define G_WARN_ALL_MASK		(G_WARN_ALL_ON|G_WARN_ALL_OFF)

#define pWARN_STD		Nullsv
#define pWARN_ALL		(Nullsv+1)	/* use warnings 'all' */
#define pWARN_NONE		(Nullsv+2)	/* no  warnings 'all' */

#define specialWARN(x)		((x) == pWARN_STD || (x) == pWARN_ALL ||	\
				 (x) == pWARN_NONE)
EOM

my $offset = 0 ;

$index = $offset ;
#@{ $list{"all"} } = walk ($tree) ;
walk ($tree) ;


$index *= 2 ;
my $warn_size = int($index / 8) + ($index % 8 != 0) ;

my $k ;
foreach $k (sort { $a <=> $b } keys %Value) {
    print WARN tab(5, "#define WARN_$Value{$k}"), "$k\n" ;
}
print WARN "\n" ;

print WARN tab(5, '#define WARNsize'),	"$warn_size\n" ;
#print WARN tab(5, '#define WARN_ALLstring'), '"', ('\377' x $warn_size) , "\"\n" ;
print WARN tab(5, '#define WARN_ALLstring'), '"', ('\125' x $warn_size) , "\"\n" ;
print WARN tab(5, '#define WARN_NONEstring'), '"', ('\0' x $warn_size) , "\"\n" ;

print WARN <<'EOM';

#define isLEXWARN_on 	(PL_curcop->cop_warnings != pWARN_STD)
#define isLEXWARN_off	(PL_curcop->cop_warnings == pWARN_STD)
#define isWARN_ONCE	(PL_dowarn & (G_WARN_ON|G_WARN_ONCE))
#define isWARN_on(c,x)	(IsSet(SvPVX(c), 2*(x)))
#define isWARNf_on(c,x)	(IsSet(SvPVX(c), 2*(x)+1))

#define ckDEAD(x)							\
	   ( ! specialWARN(PL_curcop->cop_warnings) &&			\
	    ( isWARNf_on(PL_curcop->cop_warnings, WARN_ALL) || 		\
	      isWARNf_on(PL_curcop->cop_warnings, x)))

#define ckWARN(x)							\
	( (isLEXWARN_on && PL_curcop->cop_warnings != pWARN_NONE &&	\
	      (PL_curcop->cop_warnings == pWARN_ALL ||			\
	       isWARN_on(PL_curcop->cop_warnings, x) ) )		\
	  || (isLEXWARN_off && PL_dowarn & G_WARN_ON) )

#define ckWARN2(x,y)							\
	  ( (isLEXWARN_on && PL_curcop->cop_warnings != pWARN_NONE &&	\
	      (PL_curcop->cop_warnings == pWARN_ALL ||			\
	        isWARN_on(PL_curcop->cop_warnings, x)  ||		\
	        isWARN_on(PL_curcop->cop_warnings, y) ) ) 		\
	    ||	(isLEXWARN_off && PL_dowarn & G_WARN_ON) )

#define ckWARN_d(x)							\
	  (isLEXWARN_off || PL_curcop->cop_warnings == pWARN_ALL ||	\
	     (PL_curcop->cop_warnings != pWARN_NONE &&			\
	      isWARN_on(PL_curcop->cop_warnings, x) ) )

#define ckWARN2_d(x,y)							\
	  (isLEXWARN_off || PL_curcop->cop_warnings == pWARN_ALL ||	\
	     (PL_curcop->cop_warnings != pWARN_NONE &&			\
	        (isWARN_on(PL_curcop->cop_warnings, x)  ||		\
	         isWARN_on(PL_curcop->cop_warnings, y) ) ) )

/* end of file warnings.h */

EOM

close WARN ;

while (<DATA>) {
    last if /^KEYWORDS$/ ;
    print PM $_ ;
}

#$list{'all'} = [ $offset .. 8 * ($warn_size/2) - 1 ] ;

#my %Keys = map {lc $Value{$_}, $_} keys %Value ;

print PM "%Offsets = (\n" ;
foreach my $k (sort { $a <=> $b } keys %Value) {
    my $v = lc $Value{$k} ;
    $k *= 2 ;
    print PM tab(4, "    '$v'"), "=> $k,\n" ;
}

print PM "  );\n\n" ;

print PM "%Bits = (\n" ;
foreach $k (sort keys  %list) {

    my $v = $list{$k} ;
    my @list = sort { $a <=> $b } @$v ;

    print PM tab(4, "    '$k'"), '=> "',
		# mkHex($warn_size, @list),
		mkHex($warn_size, map $_ * 2 , @list),
		'", # [', mkRange(@list), "]\n" ;
}

print PM "  );\n\n" ;

print PM "%DeadBits = (\n" ;
foreach $k (sort keys  %list) {

    my $v = $list{$k} ;
    my @list = sort { $a <=> $b } @$v ;

    print PM tab(4, "    '$k'"), '=> "',
		# mkHex($warn_size, @list),
		mkHex($warn_size, map $_ * 2 + 1 , @list),
		'", # [', mkRange(@list), "]\n" ;
}

print PM "  );\n\n" ;
print PM '$NONE     = "', ('\0' x $warn_size) , "\";\n" ;
print PM '$LAST_BIT = ' . "$index ;\n" ;
print PM '$BYTES    = ' . "$warn_size ;\n" ;
while (<DATA>) {
    print PM $_ ;
}

close PM ;

__END__

# This file was created by warnings.pl
# Any changes made here will be lost.
#

package warnings;

our $VERSION = '1.00';

=head1 NAME

warnings - Perl pragma to control optional warnings

=head1 SYNOPSIS

    use warnings;
    no warnings;

    use warnings "all";
    no warnings "all";

    use warnings::register;
    if (warnings::enabled()) {
        warnings::warn("some warning");
    }

    if (warnings::enabled("void")) {
        warnings::warn("void", "some warning");
    }

    if (warnings::enabled($object)) {
        warnings::warn($object, "some warning");
    }

    warnif("some warning");
    warnif("void", "some warning");
    warnif($object, "some warning");

=head1 DESCRIPTION

If no import list is supplied, all possible warnings are either enabled
or disabled.

A number of functions are provided to assist module authors.

=over 4

=item use warnings::register

Creates a new warnings category with the same name as the package where
the call to the pragma is used.

=item warnings::enabled()

Use the warnings category with the same name as the current package.

Return TRUE if that warnings category is enabled in the calling module.
Otherwise returns FALSE.

=item warnings::enabled($category)

Return TRUE if the warnings category, C<$category>, is enabled in the
calling module.
Otherwise returns FALSE.

=item warnings::enabled($object)

Use the name of the class for the object reference, C<$object>, as the
warnings category.

Return TRUE if that warnings category is enabled in the first scope
where the object is used.
Otherwise returns FALSE.

=item warnings::warn($message)

Print C<$message> to STDERR.

Use the warnings category with the same name as the current package.

If that warnings category has been set to "FATAL" in the calling module
then die. Otherwise return.

=item warnings::warn($category, $message)

Print C<$message> to STDERR.

If the warnings category, C<$category>, has been set to "FATAL" in the
calling module then die. Otherwise return.

=item warnings::warn($object, $message)

Print C<$message> to STDERR.

Use the name of the class for the object reference, C<$object>, as the
warnings category.

If that warnings category has been set to "FATAL" in the scope where C<$object>
is first used then die. Otherwise return.


=item warnings::warnif($message)

Equivalent to:

    if (warnings::enabled())
      { warnings::warn($message) }

=item warnings::warnif($category, $message)

Equivalent to:

    if (warnings::enabled($category))
      { warnings::warn($category, $message) }

=item warnings::warnif($object, $message)

Equivalent to:

    if (warnings::enabled($object))
      { warnings::warn($object, $message) }

=back

See L<perlmodlib/Pragmatic Modules> and L<perllexwarn>.

=cut

use Carp ;

KEYWORDS

$All = "" ; vec($All, $Offsets{'all'}, 2) = 3 ;

sub bits {
    my $mask ;
    my $catmask ;
    my $fatal = 0 ;
    foreach my $word (@_) {
	if  ($word eq 'FATAL') {
	    $fatal = 1;
	}
	elsif ($catmask = $Bits{$word}) {
	    $mask |= $catmask ;
	    $mask |= $DeadBits{$word} if $fatal ;
	}
	else
          { croak("unknown warnings category '$word'")}
    }

    return $mask ;
}

sub import {
    shift;
    my $mask = ${^WARNING_BITS} ;
    if (vec($mask, $Offsets{'all'}, 1)) {
        $mask |= $Bits{'all'} ;
        $mask |= $DeadBits{'all'} if vec($mask, $Offsets{'all'}+1, 1);
    }
    ${^WARNING_BITS} = $mask | bits(@_ ? @_ : 'all') ;
}

sub unimport {
    shift;
    my $mask = ${^WARNING_BITS} ;
    if (vec($mask, $Offsets{'all'}, 1)) {
        $mask |= $Bits{'all'} ;
        $mask |= $DeadBits{'all'} if vec($mask, $Offsets{'all'}+1, 1);
    }
    ${^WARNING_BITS} = $mask & ~ (bits(@_ ? @_ : 'all') | $All) ;
}

sub __chk
{
    my $category ;
    my $offset ;
    my $isobj = 0 ;

    if (@_) {
        # check the category supplied.
        $category = shift ;
        if (ref $category) {
            croak ("not an object")
                if $category !~ /^([^=]+)=/ ;+
	    $category = $1 ;
            $isobj = 1 ;
        }
        $offset = $Offsets{$category};
        croak("unknown warnings category '$category'")
	    unless defined $offset;
    }
    else {
        $category = (caller(1))[0] ;
        $offset = $Offsets{$category};
        croak("package '$category' not registered for warnings")
	    unless defined $offset ;
    }

    my $this_pkg = (caller(1))[0] ;
    my $i = 2 ;
    my $pkg ;

    if ($isobj) {
        while (do { { package DB; $pkg = (caller($i++))[0] } } ) {
            last unless @DB::args && $DB::args[0] =~ /^$category=/ ;
        }
	$i -= 2 ;
    }
    else {
        for ($i = 2 ; $pkg = (caller($i))[0] ; ++ $i) {
            last if $pkg ne $this_pkg ;
        }
        $i = 2
            if !$pkg || $pkg eq $this_pkg ;
    }

    my $callers_bitmask = (caller($i))[9] ;
    return ($callers_bitmask, $offset, $i) ;
}

sub enabled
{
    croak("Usage: warnings::enabled([category])")
	unless @_ == 1 || @_ == 0 ;

    my ($callers_bitmask, $offset, $i) = __chk(@_) ;

    return 0 unless defined $callers_bitmask ;
    return vec($callers_bitmask, $offset, 1) ||
           vec($callers_bitmask, $Offsets{'all'}, 1) ;
}


sub warn
{
    croak("Usage: warnings::warn([category,] 'message')")
	unless @_ == 2 || @_ == 1 ;

    my $message = pop ;
    my ($callers_bitmask, $offset, $i) = __chk(@_) ;
    local $Carp::CarpLevel = $i ;
    croak($message)
	if vec($callers_bitmask, $offset+1, 1) ||
	   vec($callers_bitmask, $Offsets{'all'}+1, 1) ;
    carp($message) ;
}

sub warnif
{
    croak("Usage: warnings::warnif([category,] 'message')")
	unless @_ == 2 || @_ == 1 ;

    my $message = pop ;
    my ($callers_bitmask, $offset, $i) = __chk(@_) ;
    local $Carp::CarpLevel = $i ;

    return
        unless defined $callers_bitmask &&
            	(vec($callers_bitmask, $offset, 1) ||
            	vec($callers_bitmask, $Offsets{'all'}, 1)) ;

    croak($message)
	if vec($callers_bitmask, $offset+1, 1) ||
	   vec($callers_bitmask, $Offsets{'all'}+1, 1) ;

    carp($message) ;
}
1;
