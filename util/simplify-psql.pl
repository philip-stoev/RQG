#!/usr/bin/perl
$| = 1;

use strict;
use lib 'lib';
use lib '../lib';

use Getopt::Long;
use Time::HiRes;

use GenTest;
use GenTest::Constants;
use GenTest::Simplifier::Mysqltest;

my $psql_options = "-p 6875 -h 127.0.0.1 -U materialize";
my $input_file;
my $expected_output;

my $o = GetOptions( 
    'psql-options=s' => \$psql_options,
    'input-file=s' => \$input_file,
    'expected-output=s' => \$expected_output
);

die "Usage: perl simplify-psql.pl --psql-options='...' --input-file= --expected-output=...\n" if not defined $input_file or not defined $expected_output;

my $run_id = time();
my $iteration = 0;

say("run_id = $run_id.");

my $simplifier = GenTest::Simplifier::Mysqltest->new(
    oracle => sub {
        my $oracle_psql = shift;
        $iteration++;
        
        my $testfile = "/tmp/".$run_id.'-'.$iteration.'.sql';
        
        open (ORACLE_PSQL, ">$testfile") or die "Unable to open $testfile: $!";

        print ORACLE_PSQL "DROP SCHEMA public CASCADE;\n";
        print ORACLE_PSQL "CREATE SCHEMA public;\n";
        print ORACLE_PSQL $oracle_psql;
        close ORACLE_PSQL;

        my $psql_start_time = Time::HiRes::time();
        my $psql_cmd = "psql --file $testfile --echo-all $psql_options 2>&1";
        my $psql_output = `$psql_cmd`;
        my $psql_duration = Time::HiRes::time() - $psql_start_time;

        open(ORACLE_PSQL_OUT, ">$testfile.out") or die "Unable to open $testfile.out: $!";
        print ORACLE_PSQL_OUT $psql_output;
        close(ORACLE_PSQL);

        if ($psql_output =~ m{$expected_output}sgio) {
            say("Issue repeatable with $testfile.");
            return ORACLE_ISSUE_STILL_REPEATABLE;
        } else {
            say("Issue not repeatable with $testfile.");
            return ORACLE_ISSUE_NO_LONGER_REPEATABLE;
        }
    }
);

open(PSQL_FILE, $input_file) or die "Unable to open $input_file";
read (PSQL_FILE, my $initial_psql, -s $input_file);
close(PSQL_FILE);

my $simplified_psql = $simplifier->simplify($initial_psql);

if (defined $simplified_psql) {
    say("Simplified psql:");
    print $simplified_psql;
    exit (STATUS_OK);
} else {
    say("Unable to simplify $input_file\n");
    exit (STATUS_ENVIRONMENT_FAILURE);
}
