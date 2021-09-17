#
# This grammar performs DDL in the first connection and
# INSERTS and in-transaction SELECTS in the remaining connections.
#

thread1:
	ddl
;

query:
	dml | select_transaction
;

dml:
	insert
;

insert:
	INSERT INTO table_name VALUES ( _digit )
;

select_transaction:
	BEGIN ; select_list ; commit_rollback
;

commit_rollback:
	COMMIT | ROLLBACK
;

select_list:
	select ; select |
	select ; select_list
;

ddl:
	create | create | create | create | drop
;

create:
	CREATE TABLE IF NOT EXISTS table_name (f1 INTEGER, f2 INTEGER) |
	CREATE OR REPLACE materialized VIEW view_name AS select |
	CREATE INDEX index_name ON table_name ( col_list ) |
	CREATE DEFAULT INDEX ON object_name
;

materialized:
	| MATERIALIZED
;

col_list:
	f1 | f2 | f2 , f1
;

drop:
	DROP TABLE IF EXISTS table_name CASCADE |
	DROP VIEW IF EXISTS table_name CASCADE |
	DROP INDEX IF EXISTS index_name
;

any_index_name:
	t1_primary_idx | t2_primary_idx |
	v1_primary_idx | v2_primary_idx |
	index_name
;

index_name:
	i1 | i2 
;

table_name:
	t1 | t2
;

view_name:
	v1 | v2
;

select:
	SELECT * FROM object_name
;

object_name:
	view_name | view_name | table_name
;
