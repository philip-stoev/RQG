package GenTest::Executor;

require Exporter;
@ISA = qw(GenTest Exporter);

@EXPORT = qw(
        EXECUTOR_ROW_COUNTS
	EXECUTOR_EXPLAIN_COUNTS
	EXECUTOR_EXPLAIN_QUERIES
	EXECUTOR_ERROR_COUNTS
);

use strict;
use GenTest;
use GenTest::Constants;

use constant EXECUTOR_DSN		=> 0;
use constant EXECUTOR_DBH		=> 1;
use constant EXECUTOR_ID		=> 2;
use constant EXECUTOR_ROW_COUNTS	=> 3;
use constant EXECUTOR_EXPLAIN_COUNTS	=> 4;
use constant EXECUTOR_EXPLAIN_QUERIES	=> 5;
use constant EXECUTOR_ERROR_COUNTS	=> 6;
use constant EXECUTOR_DEFAULT_SCHEMA => 7;

1;

sub new {
    my $class = shift;
	
	my $executor = $class->SUPER::new({
		'dsn'	=> EXECUTOR_DSN,
		'dbh'	=> EXECUTOR_DBH,
	}, @_);
    
    return $executor;
}

sub newFromDSN {
	my ($self,$dsn) = @_;
	
	if ($dsn =~ m/^dbi:mysql:/i) {
		require GenTest::Executor::MySQL;
		return GenTest::Executor::MySQL->new(dsn => $dsn);
	} elsif ($dsn =~ m/^dbi:drizzle:/i) {
		require GenTest::Executor::Drizzle;
		return GenTest::Executor::Drizzle->new(dsn => $dsn);
	} elsif ($dsn =~ m/^dbi:JDBC:.*url=jdbc:derby:/i) {
		require GenTest::Executor::JavaDB;
		return GenTest::Executor::JavaDB->new(dsn => $dsn);
	} elsif ($dsn =~ m/^dbi:Pg:/i) {
		require GenTest::Executor::Postgres;
		return GenTest::Executor::Postgres->new(dsn => $dsn);
    } elsif ($dsn =~ m/^dummy/) {
		require GenTest::Executor::Dummy;
		return GenTest::Executor::Dummy->new(dsn => $dsn);
	} else {
		say("Unsupported dsn: $dsn");
		exit(STATUS_ENVIRONMENT_FAILURE);
	}
}

sub dbh {
	return $_[0]->[EXECUTOR_DBH];
}

sub setDbh {
	$_[0]->[EXECUTOR_DBH] = $_[1];
}

sub dsn {
	return $_[0]->[EXECUTOR_DSN];
}

sub setDsn {
	$_[0]->[EXECUTOR_DSN] = $_[1];
}

sub id {
	return $_[0]->[EXECUTOR_ID];
}

sub setId {
	$_[0]->[EXECUTOR_ID] = $_[1];
}

sub type {
	my ($self) = @_;
	
	if (ref($self) eq "GenTest::Executor::JavaDB") {
		return DB_JAVADB;
	} elsif (ref($self) eq "GenTest::Executor::MySQL") {
		return DB_MYSQL;
	} elsif (ref($self) eq "GenTest::Executor::Drizzle") {
		return DB_DRIZZLE;
	} elsif (ref($self) eq "GenTest::Executor::Postgres") {
		return DB_POSTGRES;
    } elsif (ref($self) eq "GenTest::Executor::Dummy") {
        if ($self->dsn =~ m/mysql/) {
            return DB_MYSQL;
        } elsif ($self->dsn =~ m/postgres/) {
            return DB_POSTGRES;
        } if ($self->dsn =~ m/javadb/) {
            return DB_JAVADB;
        } else {
            return DB_DUMMY;
        }
	} else {
		return DB_UNKNOWN;
	}
}

my @dbid = ("Unknown","Dummy", "MySQL","Postgres","JavaDB","Drizzle");

sub getName {
    my ($self) = @_;
    return $dbid[$self->type()];
}

sub preprocess {
    my ($self, $query) = @_;

    my $id = $dbid[$self->type()];
    
    # Keep if match (+)

    # print "... $id before: $query \n";
    
    $query =~ s/\/\*\+[a-z:]*$id[a-z:]*:([^*]*)\*\//\1/gi;

    # print "... after: $query \n";

    return $query;
}

## This array maps SQL State class (2 first letters) to a status. This
## list needs to be extended
my %class2status = (
    "07" => STATUS_SEMANTIC_ERROR, # dynamic SQL error
    "08" => STATUS_SEMANTIC_ERROR, # connection exception
    "22" => STATUS_SEMANTIC_ERROR, # data exception
    "23" => STATUS_SEMANTIC_ERROR, # integrity constraint violation
    "25" => STATUS_TRANSACTION_ERROR, # invalid transaction state
    "42" => STATUS_SYNTAX_ERROR    # syntax error or access rule
                                   # violation
    
    );

sub findStatus {
    my ($self, $state) = @_;

    my $class = substr($state, 0, 2);
    if (defined $class2status{$class}) {
        return $class2status{$class};
    } else {
        return STATUS_UNKNOWN_ERROR;
    }
}

sub defaultSchema {
    my ($self, $schema) = @_;
    if (defined $schema) {
        $self->[EXECUTOR_DEFAULT_SCHEMA] = $schema;
    }
    return $self->[EXECUTOR_DEFAULT_SCHEMA];
}

sub currentSchema {
    return undef;
}

1;
