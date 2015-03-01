#!perl

use strict;
use warnings;
use Test::More;
use POSIX qw( EPERM ESRCH );

unless ( $^O eq "MSWin32" ) {
    print "1..0 # skipped: windows specific test\n";
    exit 0;
}

run();
done_testing();

sub run {
    my %live_procs = processes();
    my @live_pids = sort { $a <=> $b } keys %live_procs;

    # check all live processes
    {
        for my $pid ( @live_pids ) {
            undef $!;
            my ( $ret, $err ) = ( kill( 0, $pid ), $! );
            my $errno = $err + 0;
            my $alive = $ret || ( $errno == EPERM );
            if ( !$alive ) {
                my %live_procs = processes();
                if ( !$live_procs{$pid} ) {
                    is $errno, ESRCH, "$pid - processes that vanished after first sample return 0 and ESRCH";
                    next;
                }
            }
            ok $alive, "$pid - living processes result in 1 or EPERM";
        }
    }

    # check process ids with lower two bits set
    {
        my $accessible_done;
        my $forbidden_done;
        for my $pid ( keys %live_procs ) {
            last if $accessible_done and $forbidden_done;
            undef $!;
            my ( $ret, $err ) = ( kill( 0, $pid ), $! );
            my $errno = $err + 0;
            next if ( $ret and $accessible_done++ ) or ( !$ret and $errno == EPERM and $forbidden_done++ );
            check_next_three( $pid, 0, ESRCH );
        }
    }

    # check dead pids
    {
        my %dead_seeds = map { $_ => 1 } ( 1 .. $live_pids[-1] / 4 );
        delete $dead_seeds{ $$ / 4 };
        delete $dead_seeds{ $_ / 4 } for @live_pids;
        my @dead_seeds = map $_ * 4, keys %dead_seeds;
        my %search_deads = map { $_ => 1 } @dead_seeds[ 0 .. 999 ], ( sort { $a <=> $b } @dead_seeds )[ 0 .. 249 ];
        for my $pid ( sort { $a <=> $b } keys %search_deads ) {
            undef $!;
            my ( $ret, $err ) = ( kill( 0, $pid ), $! );
            if ( $ret ) {
                my %live_procs = processes();
                next if $live_procs{$pid};
            }
            my $errno = $err + 0;
            is $ret, 0, "$pid - dead procs return 0";
            is $errno, ESRCH, "$pid - dead procs produce ESRCH";
        }
    }

    return;
}

sub check_next_three {
    my ( $pid ) = @_;
    for my $delta ( 1 .. 3 ) {
        my $new_pid = $pid + $delta;
        undef $!;
        my ( $ret, $err ) = ( kill( 0, $new_pid ), $! );
        my $errno = $err + 0;
        is $ret, 0, "$new_pid - non-aligned pids return 0";
        is $errno, ESRCH, "$new_pid - non-aligned pids produce ESRCH";
    }
}

sub processes {
    my @processes = split /\n/, `tasklist /FO CSV /NH`;    # processes in csv with no header line
    @processes = map parse_process_line( $_ ), @processes;
    my %processes = map { $_->[1] => 1 } @processes;
    delete $processes{0};                                  # fake process, handled manually
    delete $processes{$$};                                 # skip self
    return %processes;
}

sub parse_process_line {
    my ( $line ) = @_;
    my @parts = split /,/, $line;
    $_ =~ s/^"|"$//g for @parts;
    return \@parts;
}
