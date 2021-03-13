query_init:
	initialize ; create_tables
;

initialize:
	SELECT pg_drop_replication_slot(slot_name) FROM pg_replication_slots; ALTER USER postgres WITH replication; DROP PUBLICATION IF EXISTS mz_source; DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public; CREATE PUBLICATION mz_source FOR ALL TABLES;
;

create_tables:
	create_row_table_pk ; create_row_table_nopk ; create_all_table_pk ; populate_all_table_pk ; create_all_table_nopk ; populate_all_table_nopk ; alter_tables ;
;

create_row_table_pk:
	CREATE TABLE row_table_pk (key INTEGER PRIMARY KEY, left_value INTEGER, right_value INTEGER)
;

create_row_table_nopk:
	CREATE TABLE row_table_nopk (key INTEGER, left_value INTEGER, right_value INTEGER)
;

create_all_table_pk:
	CREATE TABLE all_table_pk(key INTEGER PRIMARY KEY, value INTEGER)
;

create_all_table_nopk:
	CREATE TABLE all_table_nopk(key INTEGER, value INTEGER)
;

populate_all_table_pk:
	INSERT INTO all_table_pk (key, value) VALUES (1,0), (2,0), (3,0), (4,100), (5,100), (6,100), (7,100), (8,200), (9,200), (10,200);
;

populate_all_table_nopk:
	INSERT INTO all_table_nopk (key, value) VALUES (1,0), (2,0), (3,0), (4,100), (5,100), (6,100), (7,100), (8,200), (9,200), (10,200);
;

alter_tables:
	ALTER TABLE row_table_pk REPLICA IDENTITY FULL; ALTER TABLE row_table_nopk REPLICA IDENTITY FULL; ALTER TABLE all_table_pk REPLICA IDENTITY FULL; ALTER TABLE all_table_nopk REPLICA IDENTITY FULL;
;

row_table_name:
	row_table_pk | row_table_nopk
;

all_table_name:
	all_table_pk | all_table_nopk
;

query:
	transaction
;

transaction:
	BEGIN ; transaction_body ; commit_rollback
;

commit_rollback:
	COMMIT | COMMIT | COMMIT | COMMIT | ROLLBACK
;

transaction_body:
	transaction_item ; transaction_item ;
	transaction_item ; transaction_list
;

transaction_item:
	insert | insert | insert | 
	insert | insert | insert | 
	insert | insert | insert | 
	update | update |
	delete
;

insert:
	insert_all_table | insert_row_table
;

insert_row_table:
	INSERT INTO row_table_name (key, left_value, right_value) VALUES row_table_value_list
;

insert_all_table:
	INSERT INTO all_table_name (key, value) VALUES all_table_value_list
;

row_table_value_list:
	row_table_value |
	row_table_value , row_table_value |
	row_table_value , row_table_value_list
;

row_table_value:
	(any_key, 0, 100) |
	(any_key, 50, 50) |
	(any_key, 100, 0)
;

all_table_value_list:
	all_table_value |
	all_table_value , all_table_value |
	all_table_value , all_table_value_list
;

all_table_value:
	(any_key, 100) |
	(any_key, 50), (any_key, 150) |
	(any_key, NULL)
;

#
# UPDATE statements
#

update:
	update_all_table | update_row_table
;

update_all_table:
	update_all_table_two_rows | update_all_table_multi_statement | update_all_table_entire
;

update_all_table_two_rows:
	UPDATE all_table_name
	SET value = CASE
		WHEN key = { $key1 = $prng->int(1,5) } THEN value - any_value
		WHEN key = { $key2 = $prng->int(6,10) } THEN value + previous_value
	END
	WHERE key IN ( { $key1 } , { $key2 })
;

update_all_table_multi_statement:
	UPDATE all_table_pk SET value = value - any_value WHERE key = header_key ; UPDATE all_table_pk SET value = value + previous_value WHERE key = previous_key |
	UPDATE all_table_nopk SET value = value - any_value WHERE key = header_key ; UPDATE all_table_nopk SET value = value + previous_value WHERE key = previous_key
;

update_all_table_entire:
	UPDATE all_table_name SET value = 100
;

update_row_table:
	update_row_table_single_statement | update_row_table_multi_statement
;

update_row_table_single_statement:
	UPDATE row_table_name SET left_value = left_value + any_value , right_value = right_value - previous_value WHERE where_clause |
	UPDATE row_table_name SET left_value = right_value + any_value , right_value = left_value - previous_value WHERE where_clause
;

update_row_table_multi_statement:
	UPDATE row_table_pk SET left_value = left_value - any_value WHERE key = any_key ; UPDATE row_table_pk SET right_value = right_value + previous_value WHERE key = previous_key |
	UPDATE row_table_nopk SET left_value = left_value - any_value WHERE key = any_key ; UPDATE row_table_nopk SET right_value = right_value + previous_value WHERE key = previous_key
;

#
# DELETE statements
#

delete:
	delete_all_table | delete_row_table
;

delete_all_table:
	DELETE FROM all_table_name WHERE value = 100 AND key > 10 |
	DELETE FROM all_table_name WHERE key IS NULL
;

delete_row_table:
	DELETE FROM row_table_name WHERE where_clause
;

where_clause:
	key cmp_op any_key |
	key BETWEEN any_key AND any_key |
	key IN ( any_key_list )
;

cmp_op:
	= | = | = | < | >
;

any_key_list:
	any_key , any_key |
	any_key , any_key_list
;

header_key:
	{ $key = $prng->int(1,10) }
;

any_key:
	{ $key = $prng->int(11,65535) }
;

previous_key:
	{ $key }
;

any_value:
	{ $value = $prng->int(-100,100) }
; 

previous_value:
	{ $value }
;
