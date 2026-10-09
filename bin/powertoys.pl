#!/usr/bin/env perl
# Action command: resize the splits of the focused pane's tab.
#
#   powertoys.pl equalize   every pane in a row or column gets the same size
#   powertoys.pl half       the focused pane's split goes to exactly 1/2
#   powertoys.pl cycle      the focused pane's share steps 1/2 -> 2/3 -> 1/3
#
# The Herdr CLI has no command that sets a split ratio, so this talks to the
# socket API directly (`layout.export`, then `layout.set_split_ratio`). Only
# Perl core modules are used, so nothing has to be installed.

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use IO::Socket::UNIX;
use JSON::PP;
use Herdr::Powertoys qw(equal_ratios path_to node_at cycle_share);

my $json = JSON::PP->new->canonical;
my $herdr = $ENV{HERDR_BIN_PATH} || 'herdr';

# Actions run on the server with no terminal: stdout goes to `herdr plugin
# log`, and a notification is sent for setups that show them.
sub say_user {
    my ($msg) = @_;
    print "$msg\n";
    system($herdr, 'notification', 'show', 'powertoys', '--body', $msg, '--sound', 'none');
}

sub call {
    my ($method, $params) = @_;
    my $path = $ENV{HERDR_SOCKET_PATH}
        or die "HERDR_SOCKET_PATH is not set; run this from a Herdr action.\n";
    my $sock = IO::Socket::UNIX->new(Type => SOCK_STREAM(), Peer => $path)
        or die "cannot connect to the Herdr socket at $path: $!\n";
    print {$sock} $json->encode({ id => "powertoys", method => $method, params => $params }), "\n";
    my $line = <$sock>;
    close $sock;
    die "Herdr closed the socket without answering $method\n" unless defined $line;
    my $reply = $json->decode($line);
    if (my $err = $reply->{error}) {
        die "$method failed: " . ($err->{message} // $err->{code} // 'unknown error') . "\n";
    }
    return $reply->{result};
}

sub focused_pane {
    if (my $ctx = $ENV{HERDR_PLUGIN_CONTEXT_JSON}) {
        my $c = eval { $json->decode($ctx) } || {};
        return $c->{focused_pane_id} if $c->{focused_pane_id};
        return $c->{pane_id} if $c->{pane_id};
    }
    return $ENV{HERDR_PANE_ID};
}

sub set_ratio {
    my ($tab, $path, $ratio) = @_;
    call('layout.set_split_ratio', {
        tab_id => $tab,
        path   => [map { $_ ? JSON::PP::true : JSON::PP::false } @$path],
        ratio  => $ratio + 0,
    });
}

my $cmd = shift @ARGV // '';
die "usage: powertoys.pl equalize|half|cycle\n" unless $cmd =~ /\A(?:equalize|half|cycle)\z/;

my $pane = focused_pane();
my $layout = call('layout.export', $pane ? { pane_id => $pane } : {})->{layout};
my ($tab, $root) = ($layout->{tab_id}, $layout->{root});

if ($root->{type} ne 'split') {
    say_user("This tab has one pane, so there is no split to resize.");
    exit 0;
}

if ($cmd eq 'equalize') {
    my $changed = 0;
    for my $entry (@{ equal_ratios($root) }) {
        my ($path, $ratio) = @$entry;
        next if abs(node_at($root, $path)->{ratio} - $ratio) < 1e-4;
        set_ratio($tab, $path, $ratio);
        $changed++;
    }
    print $changed ? "Equalized $changed split(s) in $tab.\n" : "Every split in $tab is already even.\n";
    exit 0;
}

# half and cycle work on the split that holds the focused pane.
my $path = $pane ? path_to($root, $pane) : undef;
unless ($path && @$path) {
    say_user("No focused pane in a split to resize.");
    exit 0;
}
my @parent = @$path[0 .. $#$path - 1];
my $side = $path->[-1];                  # 0: focused pane is the first child
my $split = node_at($root, \@parent);
my $share = $side ? 1 - $split->{ratio} : $split->{ratio};
my $next = $cmd eq 'half' ? 1 / 2 : cycle_share($share);
set_ratio($tab, \@parent, $side ? 1 - $next : $next);
printf "Focused pane %s now takes %.0f%% of its split.\n", $pane, $next * 100;
