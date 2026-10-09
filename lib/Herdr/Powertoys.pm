package Herdr::Powertoys;

# Pure layout arithmetic over a Herdr portable layout tree (the `root` of a
# `layout.export` reply): a BSP tree whose nodes are
#   { type => "pane", pane_id => ... }
#   { type => "split", direction => "right"|"down", ratio => 0..1,
#     first => NODE, second => NODE }
# A split's `ratio` is the share of the first child. A path names a split by
# the turns from the root: 0 = first child, 1 = second child (the socket API
# takes the same turns as JSON booleans, false/true). No I/O here.

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw(units equal_ratios path_to node_at cycle_share);

# How many equal slots a node needs along `dir`: panes side by side along the
# split direction add up, panes stacked across it share the widest count.
sub units {
    my ($node, $dir) = @_;
    return 1 if $node->{type} eq 'pane';
    my $a = units($node->{first},  $dir);
    my $b = units($node->{second}, $dir);
    return $node->{direction} eq $dir ? $a + $b : ($a > $b ? $a : $b);
}

# Every split with the ratio that gives all panes in a row (or column) the
# same size: [[path, ratio], ...], root first.
sub equal_ratios {
    my ($node, $path, $out) = @_;
    $path //= [];
    $out  //= [];
    return $out if $node->{type} eq 'pane';
    my $dir = $node->{direction};
    my $a = units($node->{first},  $dir);
    my $b = units($node->{second}, $dir);
    push @$out, [[@$path], $a / ($a + $b)];
    equal_ratios($node->{first},  [@$path, 0], $out);
    equal_ratios($node->{second}, [@$path, 1], $out);
    return $out;
}

# The path to the pane `id`, or undef when the tree does not hold it.
sub path_to {
    my ($node, $id, $path) = @_;
    $path //= [];
    if ($node->{type} eq 'pane') {
        return (defined $node->{pane_id} && $node->{pane_id} eq $id) ? $path : undef;
    }
    return path_to($node->{first},  $id, [@$path, 0])
        // path_to($node->{second}, $id, [@$path, 1]);
}

sub node_at {
    my ($node, $path) = @_;
    for my $turn (@$path) {
        return undef unless $node->{type} eq 'split';
        $node = $turn ? $node->{second} : $node->{first};
    }
    return $node;
}

# The next share in the 1/2 -> 2/3 -> 1/3 -> 1/2 cycle. A share that is not
# near one of the three stops starts the cycle at 1/2.
sub cycle_share {
    my ($share) = @_;
    my $near = sub { abs($share - $_[0]) < 0.02 };
    return 2 / 3 if $near->(1 / 2);
    return 1 / 3 if $near->(2 / 3);
    return 1 / 2;
}

1;
