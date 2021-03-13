query:
#	insert |
	view_source
;

#query:
#	ddl | insert | insert | select_view
#;

ddl:
	drop_view | create_view
;

drop_view:
	DROP VIEW view_name
;

create_view:
	CREATE /*executor1 MATERIALIZED */ VIEW view_name AS view_source order_by_limit
;

insert:
	INSERT INTO table_name VALUES ( value , value )
;

value:
	_digit | _digit | _digit | _digit | NULL
;

view_source:
	single_select |
	single_select union_except_intersect all_distinct single_select
;

union_except_intersect:
	UNION | EXCEPT | INTERSECT
;

all_distinct:
	ALL | DISTINCT
;

single_select:
	SELECT distinct select_item_list, aggregate_list FROM table_name AS a1 left_right JOIN table_name AS a2 ON ( cond ) WHERE cond_list GROUP BY group_by_list having
;

having:
#	| | | | HAVING having_cond_list
;

having_cond_list:
	having_cond |
	having_cond and_or having_cond_list
;

having_cond:
	cond | aggregate_cond
;

cond_list:
	cond and_or cond |
	cond and_or cond_list
;

and_or:
	AND | AND | AND | OR
;

cond:
	select_item cmp_op select_item |
	select_item IS not NULL
;

aggregate_cond:
	aggregate_item cmp_op _digit |
	aggregate_item IS not NULL
;

not:
	| NOT
;

cmp_op:
	= | > | <
;

left_right:
	| LEFT | RIGHT
;

aggregate_list:
	aggregate_item AS agg1 , aggregate_item AS agg2
;

aggregate_item:
	CAST(aggregate_func ( distinct select_item ) AS DOUBLE PRECISION)
;

aggregate_func:
	MIN | MAX | COUNT | AVG
;

select_item_list:
	select_item AS c1, select_item AS c2, select_item AS c3
;

select_item:
	col_reference |
	col_reference |
	col_reference + select_item |
	col_reference + col_reference |
	CAST( _digit AS DOUBLE PRECISION )
;

order_by_limit:
	| order_by
	| order_by_full limit
;

order_by:
	ORDER BY order_by_list
;

order_by_full:
	ORDER BY 1 , 2 , 3 , 4 , 5
;

order_by_list:
	order_by_item |
	order_by_item , order_by_list
;

order_by_item:
	1 | 2 | 3 | select_item
;

limit:
	LIMIT _digit | 
	LIMIT _digit OFFSET _digit
;

col_reference:
	alias . col_name
;

alias:
	a1 | a2
;

col_name:
	f1 | f2
;

group_by_list:
	1 , 2 , 3
;

group_by_item:
	1 | 2 | 3
;

distinct:
#	| DISTINCT	 # https://github.com/MaterializeInc/materialize/issues/6021
;

select_view:
	SELECT * from view_name
#	/*executor1 AS OF NOW() */
;

view_name:
	v1 | v2 | v3 | v4 | v5 | v6 | v7 | v8 | v9 | v10
;

table_name:
	t1 | t2
;
