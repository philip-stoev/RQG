# Copyright (c) 2008, 2011 Oracle and/or its affiliates. All rights reserved.
# Copyright (c) 2013, Monty Program Ab.
# Use is subject to license terms.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301
# USA

package GenTest::Validator::MzQueryPlanLengthComparator;

require Exporter;
@ISA = qw(GenTest GenTest::Validator);

use strict;

use GenTest;
use GenTest::Constants;
use GenTest::Comparator;
use GenTest::Result;
use GenTest::Validator;

sub validate {
	my ($comparator, $executors, $results) = @_;

        return STATUS_WONT_HANDLE if $results->[0]->status() == STATUS_SEMANTIC_ERROR || $results->[1]->status() == STATUS_SEMANTIC_ERROR;
        return STATUS_WONT_HANDLE if $results->[0]->status() == STATUS_SYNTAX_ERROR || $results->[1]->status() == STATUS_SYNTAX_ERROR;
        return STATUS_WONT_HANDLE if not defined $results->[0]->data();

	my $query = $results->[0]->query();
	my @explains = map { $results->[$_]->data()->[0]->[0] } (0..1);

	foreach my $explain (@explains) {
		if ($explain =~ m{Constant}sgio) {
			return STATUS_WONT_HANDLE;
		}
	}

	my @lengths = map { my @matches = $_ =~ m{%\d+ =}gio; $#matches + 1} @explains;
	my $len_diff = $lengths[1] - $lengths[0];

	if ($len_diff < 0) {
                say("Query: $query plan length difference of $len_diff ($lengths[0] vs. $lengths[1])");
		say(GenTest::Comparator::dumpDiff($results->[0], $results->[1]));
	}
}

1;
