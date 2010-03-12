#!/usr/bin/perl

# Copyright (c) 2010 Oracle and/or its affiliates. All rights reserved.
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

#################### FOR THE MOMENT THIS SCRIPT IS FOR TESTING PURPOSES

use lib 'lib';
use lib "$ENV{RQG_HOME}/lib";
use Carp;
use strict;
use GenTest;
use GenTest::Server::MySQLd;
use GenTest::Server::ReplMySQLd;

$| = 1;
if (windows()) {
	$SIG{CHLD} = "IGNORE";
}

if (defined $ENV{RQG_HOME}) {
    if (windows()) {
        $ENV{RQG_HOME} = $ENV{RQG_HOME}.'\\';
    } else {
        $ENV{RQG_HOME} = $ENV{RQG_HOME}.'/';
    }
}

use Getopt::Long;
use GenTest::Constants;
use DBI;
use Cwd;

my $database = 'test';
my @dsns;

my ($gendata, @basedirs, @mysqld_options, @vardirs, $rpl_mode,
    $engine, $help, $debug, $validators, $reporters, $grammar_file,
    $redefine_file, $seed, $mask, $mask_level, $mem, $rows,
    $varchar_len, $xml_output, $valgrind, @valgrind_options, $views,
    $start_dirty, $filter, $build_thread);

my $threads = my $default_threads = 10;
my $queries = my $default_queries = 1000;
my $duration = my $default_duration = 3600;

my @ARGV_saved = @ARGV;

my $opt_result = GetOptions(
	'mysqld=s@' => \$mysqld_options[0],
	'mysqld1=s@' => \$mysqld_options[0],
	'mysqld2=s@' => \$mysqld_options[1],
	'basedir=s@' => \@basedirs,
	'vardir=s@' => \@vardirs,
	'rpl_mode=s' => \$rpl_mode,
	'engine=s' => \$engine,
	'grammar=s' => \$grammar_file,
	'redefine=s' => \$redefine_file,
	'threads=i' => \$threads,
	'queries=s' => \$queries,
	'duration=i' => \$duration,
	'help' => \$help,
	'debug' => \$debug,
	'validators:s' => \$validators,
	'reporters:s' => \$reporters,
	'gendata:s' => \$gendata,
	'seed=s' => \$seed,
	'mask=i' => \$mask,
    'mask-level=i' => \$mask_level,
	'mem' => \$mem,
	'rows=i' => \$rows,
	'varchar-length=i' => \$varchar_len,
	'xml-output=s'	=> \$xml_output,
	'valgrind!'	=> \$valgrind,
	'valgrind_options=s@'	=> \@valgrind_options,
	'views'		=> \$views,
	'start-dirty'	=> \$start_dirty,
	'filter=s'	=> \$filter,
    'mtr-build-thread=i' => \$build_thread
    );

if (!$opt_result || $help || $basedirs[0] eq '' || not defined $grammar_file) {
	help();
	exit($help ? 0 : 1);
}

say("Copyright (c) 2010, Oracle and/or its affiliates. All rights reserved. Use is subject to license terms.");
say("Please see http://forge.mysql.com/wiki/Category:RandomQueryGenerator for more information on this test framework.");
say("Starting \n# $0 \\ \n# ".join(" \\ \n# ", @ARGV_saved));

#
# Calculate master and slave ports based on MTR_BUILD_THREAD (MTR
# Version 1 behaviour)
#

if (not defined $build_thread) {
    if (defined $ENV{MTR_BUILD_THREAD}) {
        $build_thread = $ENV{MTR_BUILD_THREAD}
    } else {
        $build_thread = DEFAULT_MTR_BUILD_THREAD;
    }
}

if ( $build_thread eq 'auto' ) {
    say ("Please set the environment variable MTR_BUILD_THREAD to a value <> 'auto' (recommended) or unset it (will take the value ".DEFAULT_MTR_BUILD_THREAD.") ");
    exit (STATUS_ENVIRONMENT_FAILURE);
}

my @ports = (10000 + 10 * $build_thread, 10000 + 10 * $build_thread + 2);

say("master_port : $ports[0] slave_port : $ports[1] ports : @ports MTR_BUILD_THREAD : $build_thread ");

#
# If the user has provided two vardirs and one basedir, start second
# server using the same basedir
#


if (
	($vardirs[1] ne '') && 
	($basedirs[1] eq '')
    ) {
	$basedirs[1] = $basedirs[0];	
}


if (
	($mysqld_options[1] ne '') && 
	($basedirs[1] eq '')
    ) {
	$basedirs[1] = $basedirs[0];	
}

#
# If the user has provided identical basedirs and vardirs, warn of a
# potential overlap.
#

if (
	($basedirs[0] eq $basedirs[1]) &&
	($vardirs[0] eq $vardirs[1]) &&
	($rpl_mode eq '')
    ) {
	croak("Please specify either different --basedir[12] or different --vardir[12] in order to start two MySQL servers");
}

my $client_basedir;

foreach my $path ("$basedirs[0]/client/RelWithDebInfo", "$basedirs[0]/client", "$basedirs[0]/bin") {
	if (-e $path) {
		$client_basedir = $path;
		last;
	}
}

#
# Start servers. Use rpl_alter if replication is needed.
#

my @server;
my $rplsrv;
	
if ($rpl_mode ne '') {
    my @options;
    push @options, lc("--$engine") if defined $engine && lc($engine) ne lc('myisam');
    
    push @options, "--sql-mode=no_engine_substitution" if join(' ', @ARGV_saved) !~ m{sql-mode}io;
    
    if (defined $mysqld_options[0]) {
        push @options, @{$mysqld_options[0]};
    }
    
    $rplsrv = GenTest::Server::ReplMySQLd->new(basedir => $basedirs[0],
                                               master_vardir => $vardirs[0],
                                               master_port => $ports[0],
                                               slave_vardir => $vardirs[1],
                                               slave_port => $ports[1],
                                               mode => $rpl_mode,
                                               server_options => \@options,
                                               valgrind => $valgrind,
                                               valgrind_options => \@valgrind_options,
                                               start_dirty => $start_dirty);
    
    my $status = $rplsrv->startServer();
    
    if ($status > STATUS_OK) {
        stopServers();
        say(system("ls -l ".$rplsrv->master->datadir));
        say(system("ls -l ".$rplsrv->slave->datadir));
        croak("Could not start replicating server pair");
    }
    
    $dsns[0] = $rplsrv->master->dsn($database);
    $dsns[1] = undef; ## passed to gentest. No dsn for slave!
    $server[0] = $rplsrv->master;
    $server[1] = $rplsrv->slave;
    
} else {
    foreach my $server_id (0..1) {
        next if $basedirs[$server_id] eq '';
        
        my @options;
        push @options, lc("--$engine") if defined $engine && lc($engine) ne lc('myisam');
        
        push @options, "--sql-mode=no_engine_substitution" if join(' ', @ARGV_saved) !~ m{sql-mode}io;
        
        if (defined $mysqld_options[$server_id]) {
            push @options, @{$mysqld_options[$server_id]};
        }
        
        $server[$server_id] = GenTest::Server::MySQLd->new(basedir => $basedirs[$server_id],
                                                           vardir => $vardirs[$server_id],
                                                           port => $ports[$server_id],
                                                           start_dirty => $start_dirty,
                                                           valgrind => $valgrind,
                                                           valgrind_options => \@valgrind_options,
                                                           server_options => \@options);
        
        my $status = $server[$server_id]->startServer;
        
        if ($status > STATUS_OK) {
            stopServers();
            say(system("ls -l ".$server[$server_id]->datadir));
            croak("Could not start all servers");
        }
        
        if (
            ($server_id == 0) ||
            ($rpl_mode eq '') 
            ) {
            $dsns[$server_id] = $server[$server_id]->dsn($database);
        }
    
        if ((defined $dsns[$server_id]) && (defined $engine)) {
            my $dbh = DBI->connect($dsns[$server_id], undef, undef, { RaiseError => 1 } );
            $dbh->do("SET GLOBAL storage_engine = '$engine'");
        }
    }
}

#
# Run actual queries
#

my @gentest_options;

push @gentest_options, "--start-dirty" if defined $start_dirty;
push @gentest_options, "--gendata=$gendata";
push @gentest_options, "--engine=$engine" if defined $engine;
push @gentest_options, "--rpl_mode=$rpl_mode" if defined $rpl_mode;
push @gentest_options, map {'--validator='.$_} split(/,/,$validators) if defined $validators;
push @gentest_options, map {'--reporter='.$_} split(/,/,$reporters) if defined $reporters;
push @gentest_options, "--threads=$threads" if defined $threads;
push @gentest_options, "--queries=$queries" if defined $queries;
push @gentest_options, "--duration=$duration" if defined $duration;
push @gentest_options, "--dsn=$dsns[0]" if defined $dsns[0];
push @gentest_options, "--dsn=$dsns[1]" if defined $dsns[1];
push @gentest_options, "--grammar=$grammar_file";
push @gentest_options, "--redefine=$redefine_file" if defined $redefine_file;
push @gentest_options, "--seed=$seed" if defined $seed;
push @gentest_options, "--mask=$mask" if defined $mask;
push @gentest_options, "--mask-level=$mask_level" if defined $mask_level;
push @gentest_options, "--rows=$rows" if defined $rows;
push @gentest_options, "--views" if defined $views;
push @gentest_options, "--varchar-length=$varchar_len" if defined $varchar_len;
push @gentest_options, "--xml-output=$xml_output" if defined $xml_output;
push @gentest_options, "--debug" if defined $debug;
push @gentest_options, "--filter=$filter" if defined $filter;
push @gentest_options, "--valgrind" if $valgrind;

# Push the number of "worker" threads into the environment.
# lib/GenTest/Generator/FromGrammar.pm will generate a corresponding grammar element.
$ENV{RQG_THREADS}= $threads;

my $gentest_result = system("perl $ENV{RQG_HOME}gentest.pl ".join(' ', @gentest_options));
say("gentest.pl exited with exit status ".($gentest_result >> 8));
exit_test($gentest_result >> 8) if $gentest_result > 0;

#
# Compare master and slave, or two masters
#

if ($rpl_mode || (defined $basedirs[1])) {
    if ($rpl_mode ne '') {
        $rplsrv->waitForSlaveSync;
    }
	my @dump_ports = ($ports[0]);
	if ($rpl_mode) {
		push @dump_ports, $ports[1];
	} elsif (defined $basedirs[1]) {
		push @dump_ports, $ports[1];
	}
    
	my @dump_files;
    
	foreach my $i (0..$#dump_ports) {
		say("Dumping server on port $dump_ports[$i]...");
		$dump_files[$i] = tmpdir()."/server_".$$."_".$i.".dump";
        
		my $dump_result = system("\"$client_basedir/mysqldump\" --hex-blob --no-tablespaces --skip-triggers --compact --order-by-primary --skip-extended-insert --no-create-info --host=127.0.0.1 --port=$dump_ports[$i] --user=root $database | sort > $dump_files[$i]");
		exit_test($dump_result >> 8) if $dump_result > 0;
	}
    
	say("Comparing SQL dumps...");
	my $diff_result = system("diff -u $dump_files[0] $dump_files[1]");
	$diff_result = $diff_result >> 8;
    
	if ($diff_result == 0) {
		say("No differences were found between servers.");
	}
    
	foreach my $dump_file (@dump_files) {
		unlink($dump_file);
	}
    
	exit_test($diff_result);
}


stopServers();

sub stopServers {
    if ($rpl_mode ne '') {
        $rplsrv->stopServer();
    } else {
        foreach my $srv (@server) {
            if ($srv) {
                $srv->stopServer;
            }
        }
    }
}


sub help {
    
	print <<EOF
Copyright (c) 2010 Oracle and/or its affiliates. All rights reserved. Use is subject to license terms.

$0 - Run a complete random query generation test, including server start with replication and master/slave verification
    
    Options related to one standalone MySQL server:

    --basedir   : Specifies the base directory of the stand-alone MySQL installation;
    --mysqld    : Options passed to the MySQL server
    --vardir    : Optional. (default \$basedir/mysql-test/var);

    Options related to two MySQL servers

    --basedir1  : Specifies the base directory of the first MySQL installation;
    --basedir2  : Specifies the base directory of the second MySQL installation;
    --mysqld1   : Options passed to the first MySQL server
    --mysqld2   : Options passed to the second MySQL server
    --vardir1   : Optional. (default \$basedir1/mysql-test/var);
    --vardir2   : Optional. (default \$basedir2/mysql-test/var);

    General options

    --grammar   : Grammar file to use when generating queries (REQUIRED);
    --redefine  : Grammar file to redefine and/or add rules to the given grammar
    --rpl_mode  : Replication type to use (statement|row|mixed) (default: no replication);
    --vardir1   : Optional.
    --vardir2   : Optional. 
    --engine    : Table engine to use when creating tables with gendata (default no ENGINE in CREATE TABLE);
    --threads   : Number of threads to spawn (default $default_threads);
    --queries   : Number of queries to execute per thread (default $default_queries);
    --duration  : Duration of the test in seconds (default $default_duration seconds);
    --validator : The validators to use
    --reporter  : The reporters to use
    --gendata   : Generate data option. Passed to gentest.pl
    --seed      : PRNG seed. Passed to gentest.pl
    --mask      : Grammar mask. Passed to gentest.pl
    --mask-level: Grammar mask level. Passed to gentest.pl
    --rows      : No of rows. Passed to gentest.pl
    --varchar-length: length of strings. passed to gentest.pl
    --xml-outputs: Passed to gentest.pl
    --views     : Generate views. Passed to gentest.pl
    --valgrind  : Passed to gentest.pl
    --filter    : Passed to gentest.pl
    --mem       : Passed to mtr.
    --mtr-build-thread: 
                  Value used for MTR_BUILD_THREAD when servers are started and accessed.
    --debug     : Debug mode
    --help      : This help message

    If you specify --basedir1 and --basedir2 or --vardir1 and --vardir2, two servers will be started and the results from the queries
    will be compared between them.
EOF
	;
	print "$0 arguments were: ".join(' ', @ARGV_saved)."\n";
	exit_test(STATUS_UNKNOWN_ERROR);
}

sub exit_test {
	my $status = shift;
    stopServers();
	say("[$$] $0 will exit with exit status $status");
	safe_exit($status);
}