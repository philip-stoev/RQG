# Copyright (C) 2009-2010 Sun Microsystems, Inc. All rights reserved.  # Use is subject to license terms.
# Copyright (c) 2013, Monty Program Ab.
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

###########################################################################
# This is a derivate of conf/replication/replication-ddl_sql.yy
# with additions for
# WL5092 RBR: Options for writing partial or full row images in RBR events
# It is under heavy development and will later replace all
# conf/replication/replication-ddl_* and conf/replication/replication-dml_*
# grammars.
# 2010-05-19 Matthias Leich
###########################################################################

# From the manual:
##################
# Statements which are unsafe when using statement based replication
#    In case of binlog format
#    - MIXED we get an automatic switching from statement-based to row-based replication.
#      Attention: This test does not contain an explicit check if this switching happens.
#    - STATEMENT we get a warning that the statement is unsafe.
#      The "/* QUERY_IS_REPLICATION_SAFE */" which gets added to most generated statements
#      ensures that RQG aborts in case the statement gets a warning about unsafe actions.
# ------------------------------------------------------------------------------------------------------------
# - DML updates an NDBCLUSTER table
#   FIXME: NOT TESTED
# - FOUND_ROWS(), ROW_COUNT(), UUID(), USER(), CURRENT_USER(), LOAD_FILE(), CURRENT_USER, VERSION() ,
#   SYSDATE(), RAND() are used
#   --> "value_unsafe_for_sbr"
# - LIMIT even if we have a preceding ORDER BY which makes the statement safe
#   --> "where" --> "unsafe_condition" (no use of ORDER BY)
# - 2 or more tables with AUTO_INCREMENT columns are updated.
#   --> "update","delete"
# - any INSERT DELAYED is executed.
#   --> "low_priority_delayed_high_priority" but this had to be disabled.
# - When the body of a view requires row-based replication, the statement creating the view also uses it
#   — for example, this occurs when the statement creating a view uses the UUID() function.
#   Observation: When running a statement using a view than the statement will be declared
#                unsafe in case the SELECT within the VIEW is unsafe.
#   --> create_view -> where -> optional use of value_unsafe_for_sbr
# - Call to a UDF      My guess: It is feared that the file might not exist on slave side.
#   FIXME: NOT IMPLEMENTED
# - If a statement is logged by row and the client that executed the statement has any temporary tables,
#   then logging by row is used for all subsequent statements (except for those accessing temporary tables)
#   until all temporary tables in use by that client are dropped.
#   This is true whether or not any temporary tables are actually logged.
#   Temporary tables cannot be logged using the row-based format; thus, once row-based logging is used,
#   all subsequent statements using that table are unsafe, and we approximate this condition by treating
#   all statements made by that client as unsafe until the client no longer holds any temporary tables.
#   When FOUND_ROWS() or ROW_COUNT() is used.
#        SELECT SQL_CALC_FOUND_ROWS * FROM tbl_name
#        WHERE id > 100 LIMIT 10;
#        SELECT FOUND_ROWS();
#    FOUND_ROWS() or ROW_COUNT() are bigint(21) ;
#    Without SQL_CALC_FOUND_ROWS within the previous SELECT, FOUND_ROWS() = number of rows found by this SELECT.
#    --> "value_unsafe_for_sbr", but no SQL_CALC_FOUND_ROWS within any statement
# - a statement refers to one or more system variables.
#   Exception. The following system variables, when used with session scope (only),
#   do not cause the logging format to switch:
#   * auto_increment_increment
#   * auto_increment_offset
#   * character_set_client
#   * character_set_connection
#   * character_set_database
#   * character_set_server
#   * collation_connection
#   * collation_database
#   * collation_server
#   * foreign_key_checks
#   * identity
#   * last_insert_id
#     --> "value_numeric_int"
#   * lc_time_names
#   * pseudo_thread_id
#   * sql_auto_is_null
#   * time_zone
#   * timestamp
#     --> "shake_clock" affects timestamp
#   * unique_checks
#   For information about how replication treats sql_mode, see Section 16.3.1.30, “Replication and Variables”.
#   When one of the tables involved is a log table in the mysql database.
#   FIXME: NOT IMPLEMENTED
#-----------------------------
# When using statement-based replication, the LOAD DATA INFILE statement's CONCURRENT  option is not replicated;
# that is, LOAD DATA CONCURRENT INFILE is replicated as LOAD DATA INFILE, and LOAD DATA CONCURRENT LOCAL INFILE
# is replicated as LOAD DATA LOCAL INFILE. The CONCURRENT option is replicated when using row-based replication.
#   --> Use of "concurrent_or_empty" in "dml", but there is no explicite check if CONCURRENT is replicated or not.
#-------------------------------
# If you have databases on the master with character sets that differ from the global character_set_server value, you should
# design your CREATE TABLE statements so that tables in those databases do not implicitly rely on the database default character set.
# A good workaround is to state the character set and collation explicitly in CREATE TABLE statements.
#-----------------------------------
# MySQL 5.4.3 and later.
# Every
# - CREATE DATABASE IF NOT EXISTS
# - CREATE TABLE IF NOT EXISTS , this includes CREATE TABLE IF NOT EXISTS ... LIKE
# - CREATE EVENT IF NOT EXISTS
# statement is replicated, whether or not the object already exists on the master.
# However, replication of CREATE TABLE IF NOT EXISTS ... SELECT follows somewhat
# different rules; see Section 16.3.1.4, “Replication of CREATE TABLE ... SELECT Statements”, for more information.
#
#-----------------------------------
# http://dev.mysql.com/doc/refman/5.4/en/replication-features-differing-tables.html
#-----------------------------------
# http://dev.mysql.com/doc/refman/5.4/en/replication-features-floatvalues.html
#-----------------------------------
# http://dev.mysql.com/doc/refman/5.4/en/replication-features-flush.html
#-----------------------------------
# http://dev.mysql.com/doc/refman/5.4/en/replication-features-slaveerrors.html
# FOREIGN KEY, master InnoDB and slave MyISAM
#   FIXME: NOT TESTED, FOREIGN KEY NOT IMPLEMENTED
#-----------------------------------
# http://dev.mysql.com/doc/refman/5.4/en/replication-features-max-allowed-packet.html
# BLOB/TEXT value too big for max-allowed-packet on master or on slave
#   FIXME: NOT TESTED
#-----------------------------------
# http://dev.mysql.com/doc/refman/5.4/en/replication-features-timeout.html
# Slave: Innodb detects deadlock -> slave_transaction_retries to run the action to replicate ....
# mleich: Most probably not doable with current RQG.
#-----------------------------------
# The same system time zone should be set for both master and slave. If not -> problems with NOW() or FROM_UNIXTIME()
# CONVERT_TZ(...,...,@@session.time_zone)  is properly replicated ...
#   FIXME: different time_zones NOT TESTED
#-----------------------------------
# In situations where transactions mix updates to transactional and nontransactional tables, the order of statements
# in the binary log is correct, and all needed statements are written to the binary log even in case of a ROLLBACK.
# However, when a second connection updates the nontransactional table before the first connection's transaction is
# complete, statements can be logged out of order, because the second connection's update is written immediately after
# it is performed, regardless of the state of the transaction being performed by the first connection.
#
# Due to the nontransactional nature of MyISAM  tables, it is possible to have a statement that only partially updates
# a table and returns an error code. This can happen, for example, on a multiple-row insert that has one row violating
# a key constraint, or if a long update statement is killed after updating some of the rows.
# If that happens on the master, the slave thread exits and waits for the database administrator to decide what to do
# about it unless the error code is legitimate and execution of the statement results in the same error code on the slave.
#
# When the storage engine type of the slave is nontransactional, transactions on the master that mix updates of transactional
# and nontransactional tables should be avoided because they can cause inconsistency of the data between the master's
# transactional table and the slave's nontransactional table.
#
# DESIGN OF THIS RQG TEST
#
# 1. Rules for the current test in case of SESSION BINLOG_FORMAT = STATEMENT:
#    (independend of the use - modify or just query - of the table)
# 1.1 Do not use transactional and non transactional tables within the same statement.
# 1.2 Have only three types of transactions
#    - use non transactional tables only
#    - use transactional tables only
#    - use for the first phase of the transaction only non transactional tables and
#      use for the last phase of the transaction only transactional tables
# 1.3. SAVEPOINT A followed by some UPDATE on a non transactional table is unsafe
#
# Important variables
# 1. The variable "$pick_mode" determines which sort of object (Example: base table but also view, procedure,...) can be
#    picked within the current state of transaction.
#    It should prevent that an unsafe (applies only to SBR) transaction history gets generated.
#    Example: Modify transactional table , call procedure which modifies a non transactional table
#
#     pick_mode | allowed table type | can be calculated in | engine mix   | after SAVEPOINT A | nontrans_trans_shift grammar
#               |                    | binlog_format        | in statement | shift to          | MAY shift to
#     --------------------------------------------------------------------------------------------------------------------
#     any       | any                | MIXED, ROW           | yes          | "trans" (*)       | no action
#     nontrans  | non transactional  | STATEMENT            | no           | "trans"           | no action
#     shift     | non transactional  | STATEMENT            | no           | "trans"           | "trans"
#     trans     | transactional      | STATEMENT            | no           | "trans" (*)       | no action
#
#     (*) This is not necessary, FIXME
#     "$pick_mode" gets adjusted whenever
#     - the SESSION BINLOG_FORMAT is changed
#     - SAVEPOINT A (savepoint_event) is executed
#     - nontrans_trans_shift is executed     
#
# 2. The variable "format" contains the current SESSION BINLOG_FORMAT.
#    This variable is used for
#    - adjustment of "$pick_mode"
#    - decision if MySQL functions which are unsafe in SBR mode can be used in statements.
#
# FROM THE DISCUSSION:
# If you want to change the replication format, do so outside the boundaries of a transaction. (SBR?)
# --> "*_binlog_format_sequence"
#-----------------------------------
# http://dev.mysql.com/doc/refman/5.4/en/replication-features-triggers.html !!!!
#-----------------------------------
# TRUNCATE is treated for purposes of logging and replication as DDL rather than DML ...
# --> implemented
#-----------------------------------
# http://dev.mysql.com/doc/refman/5.4/en/mysqlbinlog-hexdump.html
#    Type 	Name 	Meaning
#    00 	UNKNOWN_EVENT 	This event should never be present in the log.
#    01 	START_EVENT_V3 	This indicates the start of a log file written by MySQL 4 or earlier.
# X  02 	QUERY_EVENT 	The most common type of events. These contain statements executed on the master.
# ?  03 	STOP_EVENT 	Indicates that master has stopped.
# X  04 	ROTATE_EVENT 	Written when the master switches to a new log file.
#        --> "rotate_event"
# X  05 	INTVAR_EVENT 	Used for AUTO_INCREMENT values or when the LAST_INSERT_ID() function is used in the statement.
#        --> "value" contains NULL and (nested) LAST_INSERT_ID()
#    06 	LOAD_EVENT 	Used for LOAD DATA INFILE in MySQL 3.23.
#    07 	SLAVE_EVENT 	Reserved for future use.
#    08 	CREATE_FILE_EVENT 	Used for LOAD DATA INFILE statements. This indicates the start of execution of such a statement. A temporary file is created on the slave. Used in MySQL 4 only.
# X  09 	APPEND_BLOCK_EVENT 	Contains data for use in a LOAD DATA INFILE statement. The data is stored in the temporary file on the slave.
#        --> "dml" contains LOAD DATA
#    0a 	EXEC_LOAD_EVENT 	Used for LOAD DATA INFILE statements. The contents of the temporary file is stored in the table on the slave. Used in MySQL 4 only.
# X  0b 	DELETE_FILE_EVENT 	Rollback of a LOAD DATA INFILE statement. The temporary file should be deleted on the slave.
#        --> "dml" contains LOAD DATA
#    0c 	NEW_LOAD_EVENT 	Used for LOAD DATA INFILE in MySQL 4 and earlier.
# X  0d 	RAND_EVENT 	Used to send information about random values if the RAND() function is used in the statement.
#        --> "value_unsafe_for_sbr"
# X  0e 	USER_VAR_EVENT 	Used to replicate user variables.
#        --> "dml" containing SET @aux + "values" containg @aux
# X  0f 	FORMAT_DESCRIPTION_EVENT 	This indicates the start of a log file written by MySQL 5 or later.
#        --> ?
# X  10 	XID_EVENT 	Event indicating commit of an XA transaction.
# X  11 	BEGIN_LOAD_QUERY_EVENT 	Used for LOAD DATA INFILE statements in MySQL 5 and later.
# X  12 	EXECUTE_LOAD_QUERY_EVENT 	Used for LOAD DATA INFILE statements in MySQL 5 and later.
#        --> "dml" contains LOAD DATA
# X  13 	TABLE_MAP_EVENT 	Information about a table definition. Used in MySQL 5.1.5 and later.
#    14 	PRE_GA_WRITE_ROWS_EVENT 	Row data for a single table that should be created. Used in MySQL 5.1.5 to 5.1.17.
#    15 	PRE_GA_UPDATE_ROWS_EVENT 	Row data for a single table that needs to be updated. Used in MySQL 5.1.5 to 5.1.17.
#    16 	PRE_GA_DELETE_ROWS_EVENT 	Row data for a single table that should be deleted. Used in MySQL 5.1.5 to 5.1.17.
# X  17 	WRITE_ROWS_EVENT 	Row data for a single table that should be created. Used in MySQL 5.1.18 and later.
#        --> insert
# X  18 	UPDATE_ROWS_EVENT 	Row data for a single table that needs to be updated. Used in MySQL 5.1.18 and later.
#        --> update
# X  19 	DELETE_ROWS_EVENT 	Row data for a single table that should be deleted. Used in MySQL 5.1.18 and later.
#        --> delete
# 1a 	INCIDENT_EVENT 	Something out of the ordinary happened. Added in MySQL 5.1.18.
# My (mleich) markings:
# X needs sub test
# I most probably already covered (FIXME: Check in hex dump)
#------------------------------------------------
# The following restriction applies to statement-based replication only, not to row-based replication.
# The GET_LOCK(), RELEASE_LOCK(), IS_FREE_LOCK(), and IS_USED_LOCK() functions that handle user-level locks are replicated
# without the slave knowing the concurrency context on master. Therefore, these functions should not be used to insert
# into a master's table because the content on the slave would differ.
# (For example, do not issue a statement such as INSERT INTO mytable VALUES(GET_LOCK(...)).)
#------------------------------------------------

#################################################

safety_check:
	# For debugging the grammar use
	{ return '/*' . $pick_mode . '*/' } /* QUERY_IS_REPLICATION_SAFE */ ;
	# For faster execution set this grammar element to "empty".
	# ;

query:
	maintain_table         |
	binlog_format_sequence |
	binlog_format_sequence |
	binlog_format_sequence |
	binlog_format_sequence |
	binlog_format_sequence |
	binlog_format_sequence |
	binlog_format_sequence |
	binlog_format_sequence |
	binlog_format_sequence |
	binlog_format_sequence |
	binlog_format_sequence |
	binlog_format_sequence ;
	# set_iso_level          |
	# set_iso_level          |
	# set_iso_level          |
	# set_iso_level          |
	# rotate_event           |
	# # This runs into a server weakness which finally fools the RQG deadlock detection.
	# # So it must be disabled.
	# # shake_clock          |

# Maintenance for working tables
# 10 % -- Significant fill up of table (refresh_table)
# 90 % -- Reduce the amount of null values (reduce_nulls)
maintain_table:
	refresh_table  |
	reduce_nulls   |
	reduce_nulls   |
	reduce_nulls   |
	reduce_nulls   |
	reduce_nulls   |
	reduce_nulls   |
	reduce_nulls   |
	reduce_nulls   |
	reduce_nulls   ;
refresh_table:
	safety_check INSERT IGNORE INTO pick_schema pick_safe_table ( _field_list[invariant] ) SELECT _field_list[invariant] FROM test . pick_safe_template ; COMMIT |
	safety_check REPLACE       INTO pick_schema pick_safe_table ( _field_list[invariant] ) SELECT _field_list[invariant] FROM test . pick_safe_template ; COMMIT ;
reduce_nulls:
	safety_check UPDATE ignore pick_schema pick_safe_table SET _field[invariant] = col_tinyint_not_null WHERE col_tinyint_not_null BETWEEN _tinyint[invariant] AND _tinyint[invariant] + _digit AND _field[invariant] IS NULL ; COMMIT ;
pick_safe_template:
	{ if ($pick_mode eq 'nontrans' or $pick_mode eq 'shift') {$tab='table300_myisam_int_autoinc'} elsif ($pick_mode eq 'trans') {$tab='table300_innodb_int_autoinc'} else {$tab=$prng->arrayElement(['table300_myisam_int_autoinc','table300_innodb_int_autoinc']) } return $tab};

query_init:
	# 1. We need to know our current SESSION BINLOG_FORMAT. We do this by simply setting the BINLOG_FORMAT.
	# 2. Our working tables need some content
	rand_session_binlog_format ; refresh_table ;  refresh_table ;  refresh_table ;  refresh_table ;  refresh_table ;  refresh_table ;  refresh_table ;  refresh_table ;

set_iso_level:
	safety_check SET global_or_session TRANSACTION ISOLATION LEVEL iso_level ;
iso_level:
	{ if ( $format  eq  'STATEMENT' ) { return $prng->arrayElement(['REPEATABLE READ','SERIALIZABLE']) } else { return $prng->arrayElement(['READ UNCOMMITTED','READ COMMITTED','REPEATABLE READ','SERIALIZABLE']) } } ;

global_or_session:
	# There seems to be only a minor impact of GLOBAL on the test. Therefore it should be less likely.
	SESSION | SESSION | GLOBAL ;

shake_clock:
	safety_check SET SESSION TIMESTAMP = UNIX_TIMESTAMP() plus_minus _digit ;

rotate_event:
	# Cause that the master switches to a new binary log file
	# RESET MASTER is not useful here because it causes
	# - master.err: [ERROR] Failed to open log (file '/dev/shm/var_290/log/master-bin.000002', errno 2)
	# - the RQG test does not terminate in usual way (RQG assumes deadlock)
	safety_check FLUSH LOGS ;

xid_event:
	# Omit BEGIN because it is only an alias for START TRANSACTION
	START TRANSACTION |
	COMMIT            |
	ROLLBACK          |
	savepoint_event   |
	implicit_commit   ;

savepoint_event:
	# In SBR after a "SAVEPOINT A" any statement which modifies a nontransactional table is unsafe.
	# Therefore we enforce here that future statements within the current transaction use
	# a transactional table.
	SAVEPOINT A { $pick_mode='trans'; return undef} |
	SAVEPOINT A { $pick_mode='trans'; return undef} |
	SAVEPOINT A { $pick_mode='trans'; return undef} |
	ROLLBACK TO SAVEPOINT A                         |
	RELEASE SAVEPOINT A                             ;

implicit_commit:
	# Attention: Although the name of the grammar item is "implicit_commit", most but not all of the following
	#            statements will do an implicit COMMIT.
	#            Reasons:
	#            1. Some statements do not COMMIT before execution and only COMMIT after a successful execution.
	#               Due to the randomness of RQG I cannot predict all time if a execution will be successful.
	#            2. There are some statements which neither COMMIT before or after execution.
	#               But I need a grammar item where I call them. They are partially called here because of
	#               such *technical* reasons.
	create_schema        |
	create_schema        |
	alter_schema         |
	drop_schema          |
	#
	create_is_copy       |
	# Experience when running the current test with several sessions:
	#    The content of t1_is_columns_<pid> differs between master and slave.
	#    Bug#29790 information schema returns non-atomic content => replication (binlog) fails
	# IMHO it is to be expected that INSERT INTO ... SELECT ... FROM information_schema... could lead in SBR mode to
	# differences between master and slave content because
	# 1. The current content of the master and the slave rules compared to RBR where only the content of the master rules.
	# 2. There is some delay till some data modifying activity of a session gets pushed to the slave.
	# 3. Caused by optimization of binlogging etc. the delay might differ per session.
	# At least the deactivation of fill_is_copy via $m10,$m11 n case of SBR helped to avoid the content difference.
	{ if ($format eq 'STATEMENT') { $m10 = '/*' ; $m11 = '*/'} else { $m10 = '' ; $m11 = '' } ; return undef } fill_is_copy |
	#
	create_procedure     |
	create_procedure     |
	create_procedure     |
	alter_procedure      |
	drop_procedure       |
	#
	create_function      |
	create_function      |
	create_function      |
	alter_function       |
	drop_function        |
	#
	create_trigger       |
	create_trigger       |
	drop_trigger         |
	#
	# If
	#    Bug#50095 Multi statement including CREATE EVENT causes rotten binlog entry
	# is fixed please enable the following four lines.
	# create_event         |
	# create_event         |
	# alter_event          |
	# drop_event           |
	#
	create_table1        |
	create_table         |
	create_table         |
	alter_table          |
	truncate_table       |
	# Please enable the next line in case
	#    Bug#50760 RENAME TABLE, Slave stops with HA_ERR_END_OF_FILE
	# is fixed.
	# rename_table         |
	drop_table           |
	#
	create_index         |
	drop_index           |
	#
	create_view          |
	create_view          |
	alter_view           |
	rename_view          |
	drop_view            |
	#
	SET AUTOCOMMIT = ON  |
	# OFF -> OFF or wrong value , no implicit COMMIT
	SET AUTOCOMMIT = OFF |
	#
	# Statements that implicitly use or modify tables in the mysql database cause an implicit COMMIT.
	create_user          |
	create_user          |
	drop_user            |
	rename_user          |
	set_password         |
	#
	grant                |
	grant                |
	revoke               |
	#
	table_administration |
	#
	create_keycache      |
	cache_index          |
	load_index_to_cache  |
	#
	flush                |
	#
	# If
	#    Bug#51336 Assert in reload_acl_and_cache during RESET QUERY CACHE
	# is fixed please enable the next line.
	# reset                |
	#
	# LOAD DATA INFILE causes an implicit commit only for tables using the NDB storage engine
	#
	# This causes an implicit COMMIT before execution.
	LOCK TABLE _table WRITE |
	# This causes an implicit COMMIT.
	UNLOCK TABLES         |
	change_key_structure  ;

flush:
	# No implicit COMMIT.
	FLUSH local_non_local TABLES      |
	FLUSH local_non_local PRIVILEGES  |
	FLUSH local_non_local QUERY CACHE ;

switch_binlog_row_image:
	# No implicit COMMIT
	SET global_or_session BINLOG_ROW_IMAGE = binlog_row_image_value ;

binlog_row_image_value:
	# Experimental: Higher likelihood for ne modes
	# full =  all columns in both before and after image
	full    |
	# minimal = PKE in the before image and changed columns in after image
	minimal |
	minimal |
	# noblob = all columns in both before and after image, except unchanged blobs
	noblob  |
	noblob  ;

reset:
	# No implicit COMMIT.
	RESET QUERY CACHE ;

# KEY CACHE is a MyISAM only feature.
create_keycache:
	# 0. There is no SESSION specific KEY CACHE.
	# 1. This statement does not COMMIT.
	# 2. 'key_cache_'.$$ gets created if not already known
	# 3. A KEY CACHE with size = 0 causes that the KEY CACHE is destroyed but.
	#    Nevertheless the name of this KEY CACHE can be used within the corresponding statements and
	#    we do not get error messages.
	SET GLOBAL { 'key_cache_'.abs($$) } .key_buffer_size = 128 * 1024 |
	SET GLOBAL { 'key_cache_'.abs($$) } .key_buffer_size = 0          ;
cache_index:
	# COMMIT only *after* successful execution.
	CACHE INDEX pick_schema table_name                          IN { 'key_cache_'.abs($$) } |
	CACHE INDEX pick_schema table_name , pick_schema table_name IN { 'key_cache_'.abs($$) } |
	# The next statement will fail.
	CACHE INDEX pick_schema table_name                          IN cache_not_exists    ;
load_index_to_cache:
	# COMMIT before execution.
	LOAD INDEX INTO CACHE pick_schema table_name                          |
	LOAD INDEX INTO CACHE pick_schema table_name , pick_schema table_name |
	# The next statement will fail.
	LOAD INDEX INTO CACHE not_exists                                      ;

table_administration:
	# COMMIT before execution.
	ANALYZE  local_non_local TABLE table_items |
	OPTIMIZE local_non_local TABLE table_items |
	REPAIR   local_non_local TABLE table_items |
	CHECK                    TABLE table_items ;
local_non_local:
	# LOCAL is an alias for NO_WRITE_TO_BINLOG. Therfore we check LOCAL only.
	| LOCAL ;
table_items:
	pick_schema table_name |
	pick_schema table_name |
	pick_schema table_name , pick_schema table_name ;

create_user:
	CREATE USER user_name |
	CREATE USER user_name |
	CREATE USER user_name , user_name ;
drop_user:
	DROP USER   user_name |
	DROP USER   user_name |
	DROP USER   user_name , user_name ;
rename_user:
	RENAME USER user_name TO user_name |
	RENAME USER user_name TO user_name |
	RENAME USER user_name TO user_name , user_name TO user_name ;
set_password:
	# COMMIT before execution.
	SET PASSWORD FOR user_name = PASSWORD(' _letter ');
user_name:
	{ 'Luigi_'.abs($$).'@localhost' }  |
	{ 'Emilio_'.abs($$).'@localhost' } ;

grant:
	GRANT ALL ON test.* TO user_name |
	GRANT ALL ON test.* TO user_name |
	GRANT ALL ON test.* TO user_name , user_name ;
revoke:
	REVOKE ALL ON test.* FROM user_name |
	REVOKE ALL ON test.* FROM user_name |
	REVOKE ALL ON test.* FROM user_name , user_name ;

create_schema:
	CREATE SCHEMA IF NOT EXISTS { 'test_'.abs($$) } CHARACTER SET character_set ;
drop_schema:
	DROP   SCHEMA IF EXISTS     { 'test_'.abs($$) }                             ;
alter_schema:
	# This fails if we have active locked tables or an open transaction which
	# already modified a table.
	ALTER SCHEMA                { 'test_'.abs($$) } CHARACTER SET character_set ;

# Attention: An open (existing?) temporary table causes that an in case of current
#            SESSION BINLOG_FORMAT = ROW any SET ... BINLOG_FORMAT fails.
create_table:
	# FIXME Move this out of xid.....
	CREATE           TABLE IF NOT EXISTS pick_schema { 't1_base_nontrans_'.abs($$) } LIKE nontrans_table |
	CREATE           TABLE IF NOT EXISTS pick_schema { 't1_base_trans_'.abs($$) }    LIKE trans_table    |
	CREATE           TABLE IF NOT EXISTS pick_schema { 't1_base_nontrans_'.abs($$) } LIKE nontrans_table |
	CREATE           TABLE IF NOT EXISTS pick_schema { 't1_base_trans_'.abs($$) }    LIKE trans_table    |
	# FIXME Add later the case that base and temporary table have the same names
	# Please enable the next two lines if
	#    Bug#49132 Replication failure on temporary table + DDL
	# is fixed.
	# CREATE TEMPORARY TABLE IF NOT EXISTS pick_schema { 't1_temp_nontrans_'.abs($$) } LIKE nontrans_table |
	# CREATE TEMPORARY TABLE IF NOT EXISTS pick_schema { 't1_temp_trans_'.abs($$) }    LIKE trans_table    |
	# This will fail because mysql.user already exists.
	CREATE TABLE mysql.user ( f1 BIGINT ) ;
create_table1:
	# We must avoid the generation of statements which are unsafe in SBR.
	#    1. We get an implicite COMMIT before execution of CREATE ...
	#    2. In case the table already exists we will get an ugly INSERT ... SELECT .
	#    3. We pick_mode 1 til 4.
	# pick_mode | tablename
	# ---------------------------
	# any       | t1_*_*_*
	# nontrans  | t1_*_nontrans_*
	# trans     | t1_*_trans_*
	# shift     | t1_*_nontrans_*
	{if ($format eq 'STATEMENT') {$pick_mode='nontrans'; return '/*'.$pick_mode.'*/'}} CREATE TABLE IF NOT EXISTS pick_schema {'t1_base_nontrans_'.abs($$)} ENGINE = MyISAM AS SELECT _field_list[invariant] FROM table_in_select AS A addition |
	{if ($format eq 'STATEMENT') {$pick_mode='trans'   ; return '/*'.$pick_mode.'*/'}} CREATE TABLE IF NOT EXISTS pick_schema {'t1_base_trans_'.abs($$) }   ENGINE = InnoDB AS SELECT _field_list[invariant] FROM table_in_select AS A addition ;
drop_table:
	# FIXME Move this out of xid.....
	DROP             TABLE IF EXISTS pick_schema { 't1_base_nontrans_'.abs($$) } |
	DROP             TABLE IF EXISTS pick_schema { 't1_base_trans_'.abs($$) }    |
	# FIXME Add later the case that base and temporary table have the same names
	#
	# DROP TEMPORARY TABLE IF EXISTS pick_schema { 't1_temp_nontrans_'.abs($$) } |
	# DROP TEMPORARY TABLE IF EXISTS pick_schema { 't1_temp_trans_'.abs($$) }    |
	#
	# This will fail because already exist_not_exist.
	DROP TABLE does_not_exist                                               ;
alter_table:
	ALTER TABLE pick_schema table_name COMMENT ' _letter ' ;
truncate_table:
	TRUNCATE TABLE pick_schema table_name ;
table_name:
	{ 't1_base_nontrans_'.abs($$) }   |
	{ 't1_base_trans_'.abs($$) }      |
	{ 't1_base_nontrans_'.abs($$) }   |
	{ 't1_base_trans_'.abs($$) }      |
	# Please enable the next four lines if
	#    Bug#49132 Replication failure on temporary table + DDL
	# is fixed.
	# { 't1_temp_nontrans_'.abs($$) } |
	# { 't1_temp_trans_'.abs($$) }    |
	# { 't1_temp_nontrans_'.abs($$) } |
	# { 't1_temp_trans_'.abs($$) }    |
	does_not_exist               ;

create_index:
	CREATE INDEX { 'idx_base_nontrans_'.abs($$) } ON { 't1_base_nontrans_'.abs($$) } (col_tinyint_not_null) |
	CREATE INDEX { 'idx_base_trans_'.abs($$) } ON { 't1_base_trans_'.abs($$) } (col_tinyint_not_null) |
	CREATE INDEX { 'idx_base_nontrans_'.abs($$) } ON { 't1_base_nontrans_'.abs($$) } (col_tinyint_not_null) |
	CREATE INDEX { 'idx_base_trans_'.abs($$) } ON { 't1_base_trans_'.abs($$) } (col_tinyint_not_null) |
	#
	# Please enable the next four lines if
	#    Bug#49132 Replication failure on temporary table + DDL
	# is fixed.
	# CREATE INDEX { 'idx_temp_nontrans_'.abs($$) } ON { 't1_temp_nontrans_'.abs($$) } (col_tinyint_not_null) |
	# CREATE INDEX { 'idx_temp_trans_'.abs($$) } ON { 't1_temp_trans_'.abs($$) } (col_tinyint_not_null) |
	# CREATE INDEX { 'idx_temp_nontrans_'.abs($$) } ON { 't1_temp_nontrans_'.abs($$) } (col_tinyint_not_null) |
	# CREATE INDEX { 'idx_temp_trans_'.abs($$) } ON { 't1_temp_trans_'.abs($$) } (col_tinyint_not_null) |
	#
	CREATE INDEX idx_will_fail ON does_not_exist (f1)                                  ;
drop_index:
	DROP INDEX { 'idx_base_nontrans_'.abs($$) } ON { 't1_base_nontrans_'.abs($$) } |
	DROP INDEX { 'idx_base_trans_'.abs($$) } ON { 't1_base_trans_'.abs($$) } |
	DROP INDEX { 'idx_base_nontrans_'.abs($$) } ON { 't1_base_nontrans_'.abs($$) } |
	DROP INDEX { 'idx_base_trans_'.abs($$) } ON { 't1_base_trans_'.abs($$) } |
	#
	# Please enable the next four lines if
	#    Bug#49132 Replication failure on temporary table + DDL
	# is fixed.
	# DROP INDEX { 'idx_temp_nontrans_'.abs($$) } ON { 't1_temp_nontrans_'.abs($$) } |
	# DROP INDEX { 'idx_temp_trans_'.abs($$) } ON { 't1_temp_trans_'.abs($$) } |
	# DROP INDEX { 'idx_temp_nontrans_'.abs($$) } ON { 't1_temp_nontrans_'.abs($$) } |
	# DROP INDEX { 'idx_temp_trans_'.abs($$) } ON { 't1_temp_trans_'.abs($$) } |
	#
	DROP INDEX idx_will_fail ON does_not_exist                       ;

rename_table:
	RENAME TABLE test . { 't1_base_nontrans_'.abs($$) } TO test . { 't2_base_nontrans_'.abs($$) } |
	RENAME TABLE test . { 't2_base_nontrans_'.abs($$) } TO test . { 't1_base_nontrans_'.abs($$) } |
	RENAME TABLE test . { 't1_base_trans_'.abs($$) } TO test . { 't2_base_trans_'.abs($$) } |
	RENAME TABLE test . { 't2_base_trans_'.abs($$) } TO test . { 't1_base_trans_'.abs($$) } |
	#
	RENAME TABLE test  . { 't1_base_nontrans_'.abs($$) } TO test  . { 't2_base_nontrans_'.abs($$) } , test1 . { 't1_base_nontrans_'.abs($$) } TO test1 . { 't2_base_nontrans_'.abs($$) } |
	RENAME TABLE test1 . { 't2_base_nontrans_'.abs($$) } TO test1 . { 't1_base_nontrans_'.abs($$) } , test  . { 't2_base_nontrans_'.abs($$) } TO test  . { 't1_base_nontrans_'.abs($$) } |
	#
	# This will fail in case we "move" the table between different schemas and there is a trigger on the table.
	RENAME TABLE pick_schema { 't1_base_nontrans_'.abs($$) } TO pick_schema { 't1_base_nontrans_'.abs($$) } |
	#
	# Please enable the next four lines if
	#    Bug#49132 Replication failure on temporary table + DDL
	# is fixed.
	# RENAME TABLE test . { 't1_temp_nontrans_'.abs($$) } TO test . { 't2_temp_nontrans_'.abs($$) } |
	# RENAME TABLE test . { 't2_temp_nontrans_'.abs($$) } TO test . { 't1_temp_nontrans_'.abs($$) } |
	# RENAME TABLE test . { 't1_temp_trans_'.abs($$) } TO test . { 't2_temp_trans_'.abs($$) } |
	# RENAME TABLE test . { 't2_temp_trans_'.abs($$) } TO test . { 't1_temp_trans_'.abs($$) } |
	#
	# This must fail.
	RENAME TABLE does_not_exist TO pick_schema { 't1_base_nontrans_'.abs($$) } ;

# The server gives a warning in case the current binlog format is STATEMENT and the SELECT
# used within the VIEW definition is unsafe in SBR mode. This is IMHO a valueless but
# unimportant limitation.
create_view:
	CREATE VIEW trans_view    |
	CREATE VIEW nontrans_view ;
trans_view:
	pick_schema { if ($format eq 'STATEMENT') {return 'v1_trans_safe_for_sbr_'.abs($$) }    else { return 'v1_trans_unsafe_for_sbr_'.abs($$) } }    AS SELECT _field_list FROM trans_table    where ;
nontrans_view:
	pick_schema { if ($format eq 'STATEMENT') {return 'v1_nontrans_safe_for_sbr_'.abs($$) } else { return 'v1_nontrans_unsafe_for_sbr_'.abs($$) } } AS SELECT _field_list FROM nontrans_table where ;
drop_view:
	DROP VIEW IF EXISTS pick_schema { 'v1_trans_safe_for_sbr_'.abs($$) }      |
	DROP VIEW IF EXISTS pick_schema { 'v1_trans_unsafe_for_sbr_'.abs($$) }    |
	DROP VIEW IF EXISTS pick_schema { 'v1_nontrans_safe_for_sbr_'.abs($$) }   |
	DROP VIEW IF EXISTS pick_schema { 'v1_nontrans_unsafe_for_sbr_'.abs($$) } ;
alter_view:
	ALTER VIEW trans_view    |
	ALTER VIEW nontrans_view ;
rename_view:
	RENAME TABLE test . { 'v1_trans_'.abs($$) }    TO test . { 'v2_trans_'.abs($$) }    |
	RENAME TABLE test . { 'v2_trans_'.abs($$) }    TO test . { 'v1_trans_'.abs($$) }    |
	RENAME TABLE test . { 'v1_nontrans_'.abs($$) } TO test . { 'v2_nontrans_'.abs($$) } |
	RENAME TABLE test . { 'v2_nontrans_'.abs($$) } TO test . { 'v1_nontrans_'.abs($$) } |
	#
	# This will fail in case the schemas picked differ. Moving a VIEW from one SCHEMA to another is not supported.
	RENAME TABLE pick_schema { 'v1_nontrans_safe_for_sbr_'.abs($$) } TO pick_schema { 'v1_nontrans_safe_for_sbr_'.abs($$) } ;

# This procedure and function handling is a bit tricky and I am till now not 100% convinced that the solution is very good.
# The base:
# 1. CREATE AND DROP PROCEDURE should be replication safe independend of the current session binlog format and
#    the tables used within preceding statements of the current transaction.
#    BTW: CREATE/DROP cause an implicite COMMIT before the inner part of the statement itself gets processed.
# 2. In case we call a procedure we must ensure that the activity (DML) of the procedure is replication safe.
#    In short: There is a dependency on the current session binlog format and
#    the tables used within preceding statements of the current transaction.
# Solution:
# 1. Procedure names contain depending on their DML activity a part (-> $pick_mode) which tells in which
#    pick_mode of the current session they can be used.
#    Of course the DML activity of the procedure has to fit to the pick_mode part of its name.
# 2. "The base 1." says that we can create any procedure within the current session.
#    This would require that we store the current pick_mode, switch to the pick_mode to be used for the DML within
#    the procedure, create the procedure and restore the old session pick_mode.
#    But in fact we have only to ensure that
#    - our procedures are proper defined (pick_mode part of name fits to its DML activity)
#    - most probably the corresponding procedure exists when we call the procedure
# Therefore we only try to create a procedure which fits to the current session pick_mode.
# The frequent dynamic switching of the session binlog format causes a calculation of pick_mode.
create_procedure:
	# Activate the next line if
	#    Bug#50423 Crash on second call of a procedure dropping a trigger
	# is fixed. Not: This crash seems to be fixed in mysql-next-mr and mysql-6.0-codebase-bugfixing.
	# CREATE PROCEDURE pick_schema { 'p1_'.$pick_mode.'_'.abs($$) } () BEGIN dml_list ; END ;
	CREATE PROCEDURE pick_schema { 'p1_'.$pick_mode.'_'.abs($$) } () BEGIN proc_stmt ; END ;
proc_stmt:
	replace | update | delete ;
drop_procedure:
	DROP PROCEDURE pick_schema { 'p1_'.$pick_mode.'_'.abs($$) } ;
call_procedure:
	# Enable the next line in case
	#    Bug #50624  	crash in check_table_access during call procedure
	# is fixed or you use
	#    mysql-6.0-codebase-bugfixing
	#
	# CALL pick_schema { 'p1_'.$pick_mode.'_'.abs($$) } () ;
	;
alter_procedure:
	ALTER PROCEDURE { 'p1_'.$pick_mode.'_'.abs($$) } COMMENT ' _letter ' ;

create_function:
	CREATE FUNCTION pick_schema { 'f1_'.$pick_mode.'_'.abs($$) } () RETURNS TINYINT RETURN ( SELECT MAX( col_tinyint_not_null ) FROM pick_schema pick_safe_table where ) ;
drop_function:
	DROP FUNCTION pick_schema { 'f1_'.$pick_mode.'_'.abs($$) } ;
# Note: We use the function within the grammar item "value".
alter_function:
	ALTER FUNCTION { 'f1_'.$pick_mode.'_'.abs($$) } COMMENT ' _letter ' ;

# I am unsure if "$pick_mode" makes here sense. It could be used to tell us what the TRIGGER might be doing but it cannot
# be used for deciding if we want to execute the trigger or not.
# Therefore "$pick_mode" might be removed in future.
# FIXME:
# 1. pick_safe_table must point to a base table
# 2. trigger and basetable must reside within the same schema
#    If not we get "ERROR HY000: Trigger in wrong schema".
#
# I got
#    Note 1592 Unsafe statement binlogged in statement format since BINLOG_FORMAT = STATEMENT.
#    Reason for unsafeness: Statement updates two AUTO_INCREMENT columns. This is unsafe because the generated value cannot be predicted by slave.
# in the following situation:
# - SBR
# - DELETE causes the execution of a trigger which inserts per one statement two rows into a table.
#   The table where the insert should happen contains an autoincrement primary key but there is no
#   explicite value for this column within the insert.
# Thinkable solutions:
#   a) Define a stupid trigger which does not modify tables which contain an AUTOINCREMENT column.
#   b) Define a sophisticated trigger which fits to the situation when the trigger gets used.
#      This is not so easy.
#      For example in case:
#      - the TRIGGER contains a "if @@session.binlog_format = 'ROW' ..." and
#      - current SESSION BINLOG_FORMAT is 'STATEMENT'
#      than we get the warning
#         Note 1592 Unsafe statement binlogged in statement format since BINLOG_FORMAT = STATEMENT.
#         Reason for unsafeness: Statement uses a system variable whose value may differ on slave.
#   c) Ignoring this problem does not work because in most cases the warning about unsafe statement
#      is right.
#   Let's try a) first.
#
create_trigger:
	CREATE TRIGGER pick_schema { 'tr1_'.$pick_mode.'_'.abs($$) } trigger_time trigger_event ON pick_schema pick_safe_table FOR EACH ROW BEGIN trigger_action ; END ;
trigger_time:
	BEFORE | AFTER  ;
trigger_event:
	INSERT | DELETE ;
trigger_action:
	# insert | replace | delete | update | CALL pick_schema { 'p1_'.$pick_mode.'_'.abs($$) } () ;
	SET @aux = 1    ;
drop_trigger:
	DROP TRIGGER IF EXISTS pick_schema { 'tr1_'.$pick_mode.'_'.abs($$) };

# I am unsure if "$pick_mode" makes here sense. Therefore this might be removed in future.
create_event:
	CREATE EVENT IF NOT EXISTS pick_schema { 'e1_'.$pick_mode.'_'.abs($$) } ON SCHEDULE EVERY 10 SECOND STARTS NOW() ENDS NOW() + INTERVAL 21 SECOND completion_handling DO insert ;
completion_handling:
	ON COMPLETION not_or_empty PRESERVE ;
drop_event:
	DROP EVENT IF EXISTS pick_schema { 'e1_'.$pick_mode.'_'.abs($$) } ;
not_or_empty:
	NOT
	| ;
alter_event:
	ALTER EVENT pick_schema { 'e1_'.$pick_mode.'_'.abs($$) } ON SCHEDULE EVERY 10 SECOND STARTS NOW() ENDS NOW() + INTERVAL 21 SECOND completion_handling DO insert ;

# Some INFORMATION_SCHEMA related tests
#--------------------------------------
# Please note the following:
# - There is no drop table grammar item.
# - The copies of the current information_schema tables do contain only a subset of columns.
#   All columns where I guessed that they are probably unsafe in replication are omitted.
# - The tests around information_schema are intentionally simpler than other tests.
# - Bug#29790 information schema returns non-atomic content => replication (binlog) fails
create_is_copy:
	CREATE TABLE IF NOT EXISTS test . { 't1_is_schemata_'.abs($$) } AS schemata_part WHERE 1 = 0 |
	# Experience: The value of tables.AUTO_INCREMENT can differ between master and slave.
	CREATE TABLE IF NOT EXISTS test . { 't1_is_tables_'.abs($$) }   AS tables_part   WHERE 1 = 0 |
	CREATE TABLE IF NOT EXISTS test . { 't1_is_columns_'.abs($$) }  AS columns_part  WHERE 1 = 0 |
	CREATE TABLE IF NOT EXISTS test . { 't1_is_routines_'.abs($$) } AS routines_part WHERE 1 = 0 ;
fill_is_copy:
	TRUNCATE test . { 't1_is_schemata_'.abs($$) } ; safety_check { return $m10 } INSERT INTO test . { 't1_is_schemata_'.abs($$) } schemata_part WHERE SCHEMA_NAME    LIKE 'test%' ORDER BY 1     { return $m11 } ; safety_check COMMIT |
	TRUNCATE test . { 't1_is_tables_'.abs($$) }   ; safety_check { return $m10 } INSERT INTO test . { 't1_is_tables_'.abs($$) }   tables_part   WHERE TABLE_SCHEMA   LIKE 'test%' ORDER BY 1,2   { return $m11 } ; safety_check COMMIT |
	TRUNCATE test . { 't1_is_columns_'.abs($$) }  ; safety_check { return $m10 } INSERT INTO test . { 't1_is_columns_'.abs($$) }  columns_part  WHERE TABLE_SCHEMA   LIKE 'test%' ORDER BY 1,2,3 { return $m11 } ; safety_check COMMIT |
	TRUNCATE test . { 't1_is_routines_'.abs($$) } ; safety_check { return $m10 } INSERT INTO test . { 't1_is_routines_'.abs($$) } routines_part WHERE ROUTINE_SCHEMA LIKE 'test%' ORDER BY 1,2   { return $m11 } ; safety_check COMMIT ;
schemata_part:
	SELECT SCHEMA_NAME,DEFAULT_CHARACTER_SET_NAME,DEFAULT_COLLATION_NAME FROM information_schema.schemata ;
tables_part:
	SELECT TABLE_SCHEMA,TABLE_NAME,TABLE_TYPE,TABLE_ROWS,TABLE_COLLATION,TABLE_COMMENT FROM information_schema.tables ;
columns_part:
	SELECT TABLE_SCHEMA,TABLE_NAME,COLUMN_NAME,DATA_TYPE,COLUMN_DEFAULT,IS_NULLABLE,CHARACTER_MAXIMUM_LENGTH,CHARACTER_OCTET_LENGTH,NUMERIC_PRECISION,NUMERIC_SCALE,CHARACTER_SET_NAME,COLLATION_NAME,PRIVILEGES,COLUMN_COMMENT FROM information_schema.columns ;
routines_part:
	SELECT ROUTINE_SCHEMA,ROUTINE_NAME,ROUTINE_TYPE,IS_DETERMINISTIC,SECURITY_TYPE,SQL_MODE,DEFINER,CHARACTER_SET_CLIENT,COLLATION_CONNECTION,DATABASE_COLLATION FROM information_schema.routines ;

# Guarantee that the transaction has ended before we switch the binlog format
binlog_format_sequence:
	COMMIT ; safety_check binlog_format_set ; dml_list ; safety_check xid_event ;
dml_list:
	safety_check dml |
	safety_check dml nontrans_trans_shift ; dml_list ;

nontrans_trans_shift:
	# This is needed for the generation of the following scenario.
	# m statements of an transaction use non transactional tables followed by
	# n statements which use transactional tables.
	{ if ( ($prng->int(1,4) == 4) and ($pick_mode  eq  'shift') ) { $pick_mode = 'trans' } ; return undef } ;

binlog_format_set:
	# 1. SESSION BINLOG_FORMAT --> How the actions of our current session will be bin logged.
	# 2. GLOBAL BINLOG_FORMAT  --> How actions with DELAYED will be bin logged.
	#                          --> Initial SESSION BINLOG_FORMAT of session started in future.
	# This means any SET GLOBAL BINLOG_FORMAT ... executed by any session has no impact on any
	# already existing session (except 2.).
	#
	# In case we
	# - are running in the moment with BINLOG_FORMAT = ROW and
	# - have an open (existing?) temporary table
	# any SET SESSION/GLOBAL gets
	#    Query:  ... SET SESSION BINLOG_FORMAT = ROW  failed:
	#    1559 Cannot switch out of the row-based binary log format when the session has open temporary tables
	# Although this means we do not get the intended BINLOG_FORMAT there will be no additional
	# problems like we run unsafe statements etc. Our fortune is that we are already running
	# with binary log format row which is "compatible" with any pick_mode.
	rand_global_binlog_format  |
	rand_session_binlog_format |
	rand_session_binlog_format |
	rand_session_binlog_format ;
rand_global_binlog_format:
	# We use somewhere "DELAYED" therefore any SET GLOBAL BINLOG_FORMAT = STATEMENT leads to unsafe stuff.
	SET GLOBAL BINLOG_FORMAT = MIXED     |
	SET GLOBAL BINLOG_FORMAT = ROW       ;
rand_session_binlog_format:
	SET SESSION BINLOG_FORMAT = { $format = 'STATEMENT' ; $pick_mode = $prng->arrayElement(['nontrans','trans','shift']) ; return $format } |
	SET SESSION BINLOG_FORMAT = { $format = 'MIXED'     ; $pick_mode = 'any'                                             ; return $format } |
	SET SESSION BINLOG_FORMAT = { $format = 'ROW'       ; $pick_mode = 'any'                                             ; return $format } ;

dml:
	# Enable the next line if
	#    Bug#49628 corrupt table after legal SQL, LONGTEXT column
	# is fixed.
	# generate_outfile ; safety_check LOAD DATA concurrent_or_empty INFILE _tmpnam REPLACE INTO TABLE pick_schema pick_safe_table |
	update                   |
	delete                   |
	insert                   |
	replace                  |
	call_procedure           |
	# LOAD DATA INFILE ... is not supported in prepared statement mode.
	PREPARE st1 FROM " update " ; safety_check EXECUTE st1 ; DEALLOCATE PREPARE st1 |
	PREPARE st1 FROM " delete " ; safety_check EXECUTE st1 ; DEALLOCATE PREPARE st1 |
	PREPARE st1 FROM " insert " ; safety_check EXECUTE st1 ; DEALLOCATE PREPARE st1 |
	# We need the next statement for other statements which should use a user variable.
	SET @aux = value         |
	# We need the next statements for other statements which should be affected by switching the database.
	USE `test` | USE `test1` |
	select_for_update        |
	switch_binlog_row_image  |
	xid_event                ;

# change_key_structure:
#    # Ensure that we do not have concurrent DDL on the same objects because collisions in this area are
# 	# outside of focus.
#    LOCK TABLE _table[invariant] WRITE ; structure_statement ; UNLOCK TABLES ;
#
# structure_statement:
# 	ALTER TABLE _table[invariant] DROP       PRIMARY KEY               |
#    ALTER TABLE _table[invariant]  ADD       PRIMARY KEY key_structure |
#    ALTER TABLE _table[invariant]  ADD       PRIMARY KEY key_structure |
#    ALTER TABLE _table[invariant] DROP        INDEX idx1               |
#    ALTER TABLE _table[invariant] DROP        INDEX idx2               |
#    ALTER TABLE _table[invariant]  ADD        INDEX idx1 key_structure |
#    ALTER TABLE _table[invariant]  ADD        INDEX idy2 key_structure |
#    ALTER TABLE _table[invariant]  ADD UNIQUE INDEX idx1 key_structure |
#    ALTER TABLE _table[invariant]  ADD UNIQUE INDEX idy2 key_structure |
#    # The next statements have an impact similar to changes of the structure.
# 	ALTER TABLE _table[invariant] DISABLE KEYS                         |
# 	ALTER TABLE _table[invariant] ENABLE  KEYS                         |
# 	ALTER TABLE _table[invariant] ENABLE  KEYS                         ;


# key_structure:
# 	# 1. The usual "full column lenght" keys are not supported on columns of data type "long string".
#    #    But prefix keys can be used there.
# 	# 2. There are data types where prefix keys are not allowed.
# 	# --> Ensure that we have at least some "long string" columns with keys.
#    #     As long as we do define a grammar element which contains all names of "non long string"
# 	#     columns we cannot avoid that a fraction of the ADD INDEX/PRIMARY KEY statements fail.
#    ( _field )                   |
# 	( long_column (30))          |
#    ( _field , _field )          |
# 	( _field , long_column (30)) ;

# long_column:
#    col_tinytext_binary   |
#    col_text_binary       |
#    col_mediumtext_binary |
#    col_longtext_binary   |
# 	col_tinytext_latin1   |
#    col_text_latin1       |
#    col_mediumtext_latin1 |
#    col_longtext_latin1   |
#    col_tinytext_utf8     |
#    col_text_utf8         |
#    col_mediumtext_utf8   |
#    col_longtext_utf8     ;

generate_outfile:
	SELECT * FROM pick_schema pick_safe_table ORDER BY _field INTO OUTFILE _tmpnam ;
concurrent_or_empty:
	| CONCURRENT ;

pick_schema:
	|
	test1 . |
	test2 . ;

delete:
	# Delete in one table, search in one table
	# Unsafe in statement based replication except we add ORDER BY
	DELETE low_priority quick ignore       FROM pick_schema pick_safe_table               where           |
	# Delete in two tables, search in two tables
	# Note: The next grammar line leads unfortunately to frequent failing statements (Unknown table A or B).
	#       The reason is that in case both tables are located in different SCHEMA's than the
	#       the schema_name must be written before the table alias.
	#       Example: DELETE test.A, test1.B FROM test.t1 AS A NATURAL JOIN test1.t7 AS B ....
	#  DELETE low_priority quick ignore A , B FROM pick_schema pick_safe_table AS A join     where    |
	DELETE low_priority quick ignore A , B FROM pick_safe_table AS A NATURAL JOIN pick_safe_table B where |
	DELETE low_priority quick ignore test1.A , test.B FROM test1 . pick_safe_table AS A NATURAL JOIN test . pick_safe_table B where ;

join:
	# 1. Do not place a where condition here.
	# 2. join is also use when modifying two tables in one statement.
	#    Therefore we must use "pick_safe_table" here.
	NATURAL JOIN pick_schema pick_safe_table B ;
subquery:
	correlated | non_correlated ;
subquery_part1:
	AND A. _field[invariant] IN ( SELECT _field[invariant] FROM pick_schema pick_safe_table AS B ;
correlated:
	subquery_part1 WHERE B.col_tinyint_not_null = A.col_tinyint_not_null )                                         ;
non_correlated:
	subquery_part1 )                                                                             ;
where:
	# Note about "AND ( _field[invariant] IS NULL OR _field[invariant] <> value_unsafe_for_sbr )"
	# 1. This statement piece is unsafe (we also get a warning) when using SESSION BINLOG_FORMAT = STATEMENT.
	# 2. We add this piece whenever SESSION BINLOG_FORMAT <> STATEMENT.
	# 3. It should be very unlikely that it gives FALSE.
	vmarker_set WHERE col_tinyint_not_null BETWEEN _tinyint[invariant] AND _tinyint[invariant] + 2 { return $f1 } unsafe_condition { return $f2 } ;
vmarker_set:
	{ if ($pick_mode ne 'any') { $f1 = '/*'; $f2 = '*/' } else { $f1 = ''; $f2 = '' } ; return undef } ;
unsafe_condition:
	AND ( _field[invariant] IS NULL OR _field[invariant] <> value_unsafe_for_sbr ) ;
	# Syntax error in multi table delete             LIMIT 2 ;

insert:
	# Insert into one table, search in no other table
	INSERT low_priority_delayed_high_priority ignore INTO pick_schema pick_safe_table ( _field , col_tinyint_not_null )   VALUES values_list on_duplicate_key_update                       |
	# Insert into one table, search in >= 1 tables
	INSERT low_priority_delayed_high_priority ignore INTO pick_schema pick_safe_table ( _field_list[invariant] ) SELECT _field_list[invariant] FROM table_in_select AS A addition ;

values_list:
	( value , _tinyint )                        |
	( value , _tinyint ) , ( value , _tinyint ) ;

on_duplicate_key_update:
	# Only 10 %
	| | | | | | | | |
	# Enable the next line in case
	#    Bug#50619 assert in handler::update_auto_increment
	# is fixed.
	# ON DUPLICATE KEY UPDATE _field = value ;
	ON DUPLICATE KEY UPDATE _field = ABS( value ) ;

table_in_select:
	pick_schema pick_safe_table                                        |
	( SELECT _field_list[invariant] FROM pick_schema pick_safe_table ) ;

addition:
	where | where subquery | join where | where union where ;

union:
	UNION SELECT _field_list[invariant] FROM table_in_select AS B ;

replace:
	# HIGH_PRIORITY and on_duplicate_key_update are not allowed
	REPLACE low_priority_delayed INTO pick_schema pick_safe_table ( _field , col_tinyint_not_null )   VALUES values_list                                               |
	REPLACE low_priority_delayed INTO pick_schema pick_safe_table ( _field_list[invariant] ) SELECT _field_list[invariant] FROM table_in_select AS A addition ;

update:
	# mleich: Search within another table etc. should be already sufficient covered by "delete" and "insert".
	# Update one table
	UPDATE ignore pick_schema pick_safe_table SET _field = value where |
	# Update two tables
	UPDATE ignore pick_schema pick_safe_table AS A join SET A. _field = value , B. _field = value where ;

select_for_update:
	# SELECT does not get replicated, but we want its sideeffects on the transaction.
	SELECT col_tinyint_not_null, _field FROM pick_safe_table where FOR UPDATE;

value:
	value_numeric          |
	value_string_converted |
	value_string           |
	value_temporal         |
	@aux                   |
	# Enable the next line in case
	#    Bug#50511 Sometimes wrong handling of user variables containing NULL
	# is fixed.
	# NULL                   |
	pick_schema { 'f1_'.$pick_mode.'_'.abs($$) } () |
	{ if ($format eq 'STATEMENT') {return '/*'} } value_unsafe_for_sbr { if ($format eq 'STATEMENT') {return '*/ 17 '} };

value_unsafe_for_sbr:
# Functions which are unsafe when bin log format = 'STATEMENT'
# + we get a warning : "Statement may not be safe to log in statement format"
	# bigint(21)
	FOUND_ROWS()      |
	ROW_COUNT()       |
	# varchar(36) CHARACTER SET utf8
	UUID()            |
	# bigint(21) unsigned
	UUID_SHORT()      |
	# varchar(77) CHARACTER SET utf8
	CURRENT_USER      |
	CURRENT_USER()    |
	USER()            |
	VERSION()         |
	SYSDATE()         |
	# The ( _digit ) makes thread = 1 tests deterministic.
	RAND( _digit )   ;
	# _data gets replace by LOAD_FILE( <some path> ) which is unsafe for SBR.
	# mleich: I assume this refers to the risk that an input file
	#         might exist on the master but probably not on the slave.
	#         This is irrelevant for the usual RQG test configuration
	#         where master and slave run on the same box.
	_data             ;

value_numeric:
	# We have 'bit' -> bit(1),'bit(4)','bit(64)','tinyint','smallint','mediumint','int','bigint',
	# 'float','double',
	# 'decimal' -> decimal(10,0),'decimal(35)'
	# FIXME 1. We do not need all of these values.
	#       2. But a smart distribution of values is required so that we do not hit all time
	#                  outside of the allowed value ranges
	value_numeric_int    |
	value_numeric_double |
	-1.1                 | +1.1 ;
value_numeric_int:
	- _digit         | _digit              |
	_bit(1)          | _bit(4)             |
	_tinyint         | _tinyint_unsigned   |
	_smallint        | _smallint_unsigned  |
	_mediumint       | _mediumint_unsigned |
	_int             | _int_unsigned       |
	_bigint          | _bigint_unsigned    |
	_bigint          | _bigint_unsigned    |
	# int(10)
	CONNECTION_ID()  |
	# Value of the AUTOINCREMENT (per manual only applicable to integer and floating-point types)
	# column for the last INSERT.
	LAST_INSERT_ID() ;
value_numeric_double:
	-2.0E-1          | +2.0E-1             |
	-2.0E+1          | +2.0E+1             |
	-2.0E-10         | +2.0E-10            |
	-2.0E+10         | +2.0E+10            |
	-2.0E-100        | +2.0E-100           |
	-2.0E+100        | +2.0E+100           ;

value_string:
	# We have 'char' -> char(1),'char(10)',
	# 'varchar' - varchar(1),'varchar(10)','varchar(257)',
	# 'tinytext','text','mediumtext','longtext',
	# 'enum', 'set'
	# mleich: I fear values > 16 MB are risky, so I omit them.
	_char(1)    | _char(10)    |
	_varchar(1) | _varchar(10) | _varchar(257)   |
	_text(255)  | _text(65535) | _text(16777215) |
	DATABASE()  |
	_set        ;

value_string_converted:
	CONVERT( value_string USING character_set );

character_set:
	UTF8 | UCS2 | LATIN1 | BINARY ;

value_temporal:
	# We have 'datetime', 'date', 'timestamp', 'time','year'
	#    _datetime - a date+time value in the ISO format 2000-01-01 00:00:00
	#    _date - a valid date in the range from 2000 to 2010
	#    _timestamp - a date+time value in the MySQL format 20000101000000
	#    _time - a time in the range from 00:00:00 to 29:59:59
	#    _year - a year in the range 2000 to 2010
	_datetime | _date | _time | _datetime | _timestamp | _year |
	NOW()     ;

any_table:
	nontrans_table |
	trans_table    ;

nontrans_table:
	{ 't1_base_nontrans_'.abs($$) }   |
	{ 't2_base_nontrans_'.abs($$) }   |
	{ 't1_temp_nontrans_'.abs($$) }   |
	{ 't2_temp_nontrans_'.abs($$) }   |
	# A VIEW used in SBR mode must not be based on a SELECT which is unsafe in SBR mode.
	{ if ($format eq 'STATEMENT') { return 'v1_nontrans_safe_for_sbr_'.abs($$) } else { return 'v1_nontrans_'.$prng->arrayElement(['safe_for_sbr_','unsafe_for_sbr_']).abs($$) } } |
	{ if ($format eq 'STATEMENT') { return 'v2_nontrans_safe_for_sbr_'.abs($$) } else { return 'v2_nontrans_'.$prng->arrayElement(['safe_for_sbr_','unsafe_for_sbr_']).abs($$) } } |
	#
	{ 't1_'.$prng->int(1,20).'_myisam' } |
	{ 't1_'.$prng->int(1,20).'_myisam' } ;

trans_table:
	{ 't1_base_trans_'.abs($$) }   |
	{ 't2_base_trans_'.abs($$) }   |
	{ 't1_temp_trans_'.abs($$) }   |
	{ 't2_temp_trans_'.abs($$) }   |
	# A VIEW used in SBR mode must not be based on a SELECT which is unsafe in SBR mode.
	{ if ($format eq 'STATEMENT') { return 'v1_trans_safe_for_sbr_'.abs($$) } else { return 'v1_trans_'.$prng->arrayElement(['safe_for_sbr_','unsafe_for_sbr_']).abs($$) } } |
	{ if ($format eq 'STATEMENT') { return 'v2_trans_safe_for_sbr_'.abs($$) } else { return 'v2_trans_'.$prng->arrayElement(['safe_for_sbr_','unsafe_for_sbr_']).abs($$) } } |
	#
	{ return 't1_'.$prng->int(1,20).'_innodb' } |
	{ return 't1_'.$prng->int(1,20).'_innodb' } ;

pick_safe_table:
	# pick_mode                         |        $m0   any_table          $m1   nontrans_table          $m2   trans_table          $m3
	# any                               |        ''    any_table          '/*'  nontrans_table          ''    trans_table          '*/'
	# nontrans                          |        '/*'  any_table          '*/'  nontrans_table          '/*'  trans_table          '*/'
	# shift (nontrans and laster trans) |        '/*'  any_table          '*/'  nontrans_table          '/*'  trans_table          '*/'
	# trans                             |        '/*'  any_table          ''    nontrans_table          '*/'  trans_table          ''
	tmarker_init tmarker_set            { return $m0 } any_table { return $m1 } nontrans_table { return $m2 } trans_table { return $m3 } ;

tmarker_init:
	{ $m0 = ''; $m1 = ''; $m2 = ''; $m3 = ''; return undef } ;

tmarker_set:
	# { if ($pick_mode eq 'any') {$m1='/*';$m3='*/'} elsif ($pick_mode eq 'nontrans') {$m0='/*';$m1='*/';$m2='/*';$m3='*/'} elsif ($pick_mode eq 'shift') {$m0='/*';$m1='*/';$m2='/*';$m3='*/'} elsif ($pick_mode eq 'trans') {$m0='/*';$m2='*/'} else {reached_crap} ; return undef };
	{ if ($pick_mode eq 'any') {$m1='/*';$m3='*/'} elsif ($pick_mode eq 'nontrans') {$m0='/*';$m1='*/';$m2='/*';$m3='*/'} elsif ($pick_mode eq 'shift') {$m0='/*';$m1='*/';$m2='/*';$m3='*/'} elsif ($pick_mode eq 'trans') {$m0='/*';$m2='*/'} ; return undef };



#### Basic constructs which are used at various places

delayed:
	# "DELAYED" is declared to be unsafe whenever the GLOBAL binlog_format is 'statement'.
	# --> Either
	#     - set GLOBAL binlog_format during query_init, don't switch it later and adjust usage of delayed ?
	#       The choice within this test.
	#     or
	#     - do not use DELAYED
	# May 2010: It looks now (mysql-5.1-rpl-wl5092) as if any DELAYED gets declared to be unsafe in case
	#           the SESSION binlog_format is STATEMENT.
	#           Therefore I disable it now.
	# DELAYED       |
	;

high_priority:
	|
	HIGH_PRIORITY ;

ignore:
	# Only 10 %
	| | | | | | | | |
	# mleich temporary disabled IGNORE ;
	;

low_priority:
	| | |
	LOW_PRIORITY ;

low_priority_delayed_high_priority:
# All MyISAM only features.
	| |
	low_priority  |
	delayed       |
	high_priority ;

low_priority_delayed:
	| |
	low_priority |
	delayed      ;

plus_minus:
	+ | - ;

quick:
	# Only 10 %
	| | | | | | | | |
	QUICK ;
