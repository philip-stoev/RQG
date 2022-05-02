query:
	SELECT group_by_3 , aggregate_list , window_list_3 FROM from_clause where_clause GROUP BY group_by_3
;

aggregate_list:
	1 |
	aggregate_item |
	aggregate_item , aggregate_list
;

aggregate_item:
	aggregate_func ( expr )
;

aggregate_func:
	MIN | MAX | COUNT | SUM
;

expr:
	alias . col_name
;

window_list_3:
	window_func_3 AS wf1 , window_func_3 AS wf2
;

window_func_3:
	ROW_NUMBER() OVER ( partition_3 order_3 rows ) |
	DENSE_RANK() OVER ( partition_3 order_3 rows ) |
	LAG( item_3 , CAST(item_3 AS INTEGER) , item_3 ) OVER ( partition_3 order_3 rows ) |
	FIRST_VALUE(item_3) OVER ( partition_3 order_3 rows ) |
	LAST_VALUE(item_3) OVER ( partition_3 order_3 rows )
;

rows:
	ROWS BETWEEN row_first AND row_second
;

row_first:
	CURRENT ROW |
	UNBOUNDED PRECEDING |
	_digit PRECEDING |
	_digit FOLLOWING
;

row_second:
	CURRENT ROW |
	UNBOUNDED FOLLOWING |
        _digit PRECEDING |
	_digit FOLLOWING
;

partition_3:
	| PARTITION BY partition_3_list
;

partition_3_list:
	item_3 |
	item_3 , partition_3_list
;

order_3:
	ORDER BY group_by_3
;

order_3_list:
	item_3 asc_desc |
	item_3 asc_desc , order_3_list
;

asc_desc:
	ASC | DESC
;

group_by_3:
	a1.f1 , a1.f2 , a2.f1 |
	a1.f2 , a2.f1 , a1.f1 |
	a2.f1 , a1.f1 , a1.f2
;

item_3:
	a1.f1 | a1.f2 | a2.f1
;

wf:
	wf1 | wf2
;

from_clause:
	table_name AS a1, table_name AS a2 |
	table_name AS a1 left_right JOIN table_name AS a2 USING ( col_list ) |
	table_name AS a1 left_right JOIN table_name AS a2 ON ( join_cond_list ) |
	table_name AS a1 , LATERAL (SELECT wf1 AS f1, wf2 AS f2 FROM ( query ) AS q ) AS a2
;

where_clause:
	| | | WHERE subquery
;

subquery:
	EXISTS ( query ) |
	alias . col_name IN ( SELECT wf FROM ( query ) AS s )
;


left_right:
	| LEFT | RIGHT
;

join_cond_list:
	join_cond |
	join_cond and_or join_cond
;

and_or:
	AND | AND | AND | AND | OR
;

join_cond:
	a1 . col_name = a2 . col_name
;

alias:
	a1 | a2
;

table_name:
	t1 | t2
;

col_list:
	f1 | f2 | f1 , f2
;

col_name:
	f1 | f2
;
