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

package GenTest::Validator::SimpleExecutionTimeComparator;

require Exporter;
@ISA = qw(GenTest GenTest::Validator);

use strict;

use GenTest;
use GenTest::Constants;
use GenTest::Comparator;
use GenTest::Result;

use constant THRESHOLD => 2;
use constant MIN_TIME => 0.2;

sub validate {
	my ($comparator, $executors, $results) = @_;
	my $query = $results->[0]->query();

	if ($query !~ m{EXPLAIN}sgio) {
		say("Query $query could not be benchmarked. Generate EXPLAIN SELECT queries instead.");
		return STATUS_WONT_HANDLE;

	}

	my @explains = map { $results->[$_]->data()->[0]->[0] } (0..1);
	if ($explains[0] eq $explains[1]) {
#		say("Query $query has identical EXPLAIN plans");
#                print(".");
#		return STATUS_WONT_HANDLE;
	}

#	print("*");
#	say("$query;");

	my $select_query = $query;
	$select_query =~ s{EXPLAIN}{}sgio;
	my @durations = map { $executors->[$_]->execute($select_query)->duration() } (0..1);


	my $ratio = $durations[0] / $durations[1];

        if (
		(($durations[0] > MIN_TIME) || ($durations[1] > MIN_TIME)) &&
 		(($ratio > THRESHOLD) || ($ratio < 1/THRESHOLD))
	) {
		say(sprintf("%5.3f %5.3f %5.3f: %s", $ratio, $durations[0], $durations[1], $query));
	}

	return STATUS_OK;
}

1;
