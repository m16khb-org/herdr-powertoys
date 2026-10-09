use strict;
use warnings;
use Test::More;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Herdr::Powertoys qw(units equal_ratios path_to node_at cycle_share);

sub pane  { { type => 'pane', pane_id => $_[0] } }
sub sp { { type => 'split', direction => $_[0], ratio => $_[1], first => $_[2], second => $_[3] } }

sub ratios_of {
    my ($root) = @_;
    return { map { (join('', @{ $_->[0] }) => sprintf('%.4f', $_->[1])) } @{ equal_ratios($root) } };
}

# Two panes side by side: exactly half.
is_deeply ratios_of(sp('right', 0.31, pane('a'), pane('b'))), { '' => '0.5000' },
    'two panes split in half';

# Three columns made of nested right splits: every column a third.
is_deeply ratios_of(sp('right', 0.5, pane('a'), sp('right', 0.5, pane('b'), pane('c')))),
    { '' => '0.3333', '1' => '0.5000' },
    'nested same-direction splits give equal columns';

# A column stacked into two rows still counts as one column.
is_deeply ratios_of(sp('right', 0.7, pane('a'), sp('down', 0.2, pane('b'), pane('c')))),
    { '' => '0.5000', '1' => '0.5000' },
    'a stacked column counts as one column';

# Left: two rows; right: two columns. The root splits 1 : 2 columns.
is_deeply ratios_of(sp('right', 0.5,
        sp('down', 0.9, pane('a'), pane('b')),
        sp('right', 0.1, pane('c'), pane('d')))),
    { '' => '0.3333', '0' => '0.5000', '1' => '0.5000' },
    'mixed tree weighs each side by its column count';

is units(pane('a'), 'right'), 1, 'a pane is one slot';

my $tree = sp('right', 0.5, pane('a'), sp('down', 0.5, pane('b'), pane('c')));
is_deeply path_to($tree, 'c'), [1, 1], 'path to a nested pane';
is_deeply path_to($tree, 'a'), [0], 'path to the first child';
is path_to($tree, 'missing'), undef, 'unknown pane has no path';
is node_at($tree, [1])->{direction}, 'down', 'node_at follows the turns';

is sprintf('%.4f', cycle_share(0.5)),   '0.6667', 'cycle: 1/2 -> 2/3';
is sprintf('%.4f', cycle_share(2 / 3)), '0.3333', 'cycle: 2/3 -> 1/3';
is sprintf('%.4f', cycle_share(1 / 3)), '0.5000', 'cycle: 1/3 -> 1/2';
is sprintf('%.4f', cycle_share(0.42)),  '0.5000', 'cycle: an odd share restarts at 1/2';

done_testing;
