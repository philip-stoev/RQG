# Copyright (c) 2008, 2012 Oracle and/or its affiliates. All rights reserved.
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

package GenTest::Transform::ExecuteAsTrigger;

require Exporter;
@ISA = qw(GenTest GenTest::Transform);

use strict;
use lib 'lib';

use GenTest;
use GenTest::Transform;
use GenTest::Constants;

sub transform {
	my ($class, $orig_query, $executor) = @_;
	
	# We skip: - [OUTFILE | INFILE] queries because these are not data producing and fail (STATUS_ENVIRONMENT_FAILURE)
	return STATUS_WONT_HANDLE if $orig_query =~ m{(OUTFILE|INFILE)}sio
		|| $orig_query !~ m{\s*SELECT}sio
		|| $orig_query =~ m{LIMIT}sio;

	return [
		"CREATE DATABASE IF NOT EXISTS transforms",
		"DROP TABLE IF EXISTS trigger1".$$.",  transforms.trigger2".$$,
		"CREATE TABLE IF NOT EXISTS trigger1".$$." (f1 INTEGER)",
		"CREATE TABLE IF NOT EXISTS transforms.trigger2".$$." $orig_query LIMIT 0",
		"CREATE TRIGGER trigger1".$$." BEFORE INSERT ON trigger1".$$." FOR EACH ROW INSERT INTO transforms.trigger2".$$." $orig_query;",
		"INSERT INTO trigger1".$$." VALUES (1)",
		"SELECT * FROM transforms.trigger2".$$." /* TRANSFORM_OUTCOME_UNORDERED_MATCH */",
		"DROP TABLE IF EXISTS trigger1".$$.",  transforms.trigger2".$$,
		"DROP DATABASE IF EXISTS transforms"
	];
}

1;
