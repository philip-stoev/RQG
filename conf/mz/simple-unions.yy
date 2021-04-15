query:
	select
;

select:
	union_list
;

union_list:
	union_item union_except_intersect all union_list |
	union_item union_except_intersect all union_item
;

union_except_intersect:
	UNION | EXCEPT | INTERSECT
;

all:
	| ALL
;

union_item:
	single_select |	single_select | single_select | single_select | ( union_list )
;

single_select:
	SELECT distinct * FROM table_name where_clause
;

distinct:
	DISTINCT
;

where_clause:
	|
	WHERE f1 cmp_op value |
	WHERE f1 IS not NULL
;

not:
	| NOT
;

cmp_op:
	> | < | =
;

value:
	_digit
;

table_name:
	t1 | t2
;
