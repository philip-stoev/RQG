#
# This test simulates a "banking" workload whereby data is moved from one row
# to another or from one column to another but the expectation is that 
# the invariants about the data will continue to hold throughout the test.
# 
# The invariants are checked by the queries in the "check" rule. To run this file,
# use --validator=QueryProperties,RepeatableRead
#

thread1_init:
	DROP TABLE IF EXISTS sum100row; DROP TABLE IF EXISTS avg100table ; CREATE TABLE sum100row (val1 INTEGER, val2 INTEGER) ; CREATE TABLE avg100table (id INTEGER, val1 INTEGER) ; populate_avg100table
;

query:
	query_sum100row | query_avg100table | check
;

check:
	BEGIN ; select_list ; COMMIT
;

select_list:
	select |
	select ; select_list
;

select:
	SELECT * FROM sum100row_avg100table |
	/* RESULTSET_HAS_NO_ROWS */ SELECT * FROM sum100row WHERE val1 + val2 != 100 |
	/* RESULTSET_IS_SINGLE_BOOLEAN_TRUE */ SELECT AVG(val1) IS NULL OR AVG(val1) = 100 FROM avg100table
;

sum100row_avg100table:
	sum100row | avg100table
;

query_sum100row:
	insert_sum100row_transaction | insert_sum100row_transaction | insert_sum100row_transaction | insert_sum100row_select |
	update_sum100row | update_sum100row | delete_sum100row
;

insert_sum100row_transaction:
	BEGIN ; insert_sum100row_list ; COMMIT
;

insert_sum100row_list:
	insert_sum100row ; insert_sum100row |
	insert_sum100row ; insert_sum100row_list
;

insert_sum100row:
	INSERT INTO sum100row VALUES (50, 50) |
        INSERT INTO sum100row VALUES (0, 100) |
        INSERT INTO sum100row VALUES (50, 50) |
        INSERT INTO sum100row VALUES (100, 0) |
        INSERT INTO sum100row VALUES (0, 100), (50, 50), (100, 0)
;

insert_sum100row_select:
	INSERT INTO sum100row SELECT * FROM sum100row LIMIT _digit |
;

update_sum100row:
	UPDATE sum100row SET val1 = val1 - { $val = $prng->int(-100, 100) ; } , val2 = val2 + { $val } optional_where |
	UPDATE sum100row SET val1 = val2 , val2 = val1 optional_where
;

delete_sum100row:
	DELETE FROM sum100row where
;

query_avg100table:
	insert_avg100table_transaction | insert_avg100table_transaction | insert_avg100table_transaction | 
	update_avg100table | delete_avg100table
;

populate_avg100table:
        INSERT INTO avg100table (id, val1) VALUES (1, 0), (2, 0), (3, 0), (4, 100), (5, 100), (6, 100), (7, 100), (8, 200), (9, 200), (10, 200)
;

insert_avg100table_transaction:
	BEGIN ; insert_avg100table_list ; COMMIT;
;

insert_avg100table_list:
	insert_avg100table ; insert_avg100table |
	insert_avg100table ; insert_avg100table_list
;

insert_avg100table:
        INSERT INTO avg100table (val1) VALUES ( 100 ) |
        INSERT INTO avg100table (val1) VALUES ( 0 ) , ( 200 ) |
;

insert_avg100table_select:
	INSERT INTO avg100table SELECT * FROM avg100table
;

update_avg100table:
	UPDATE avg100table SET val1 = 100 |
	UPDATE avg100table
	SET val1 = CASE
		WHEN id = { $id2 = $prng->int(1,5) }
		THEN val1 - { $val = $prng->int(-100, 100) }
		WHEN id = { $id1 = $prng->int(6,10) }
		THEN val1 + { $val }
        END
        WHERE id = { $id1 } OR id = { $id2 };
;

delete_avg100table:
	DELETE FROM avg100table WHERE id IS NULL AND val1 = 100
;

optional_where:
	| where
;

where:
	WHERE val1 cmp_op _smallint_unsigned
;

cmp_op:
	= | = | > | <
;
