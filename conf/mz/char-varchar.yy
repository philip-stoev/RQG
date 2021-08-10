# 
# A grammar that generates tables and queries using CHAR/VARCHAR/TEXT type
# 
# Best run in comparison mode against a Postgres instance at --dsn2
#  perl gentest.pl \ 
#     --dsn1="dbi:Pg:service=materialize"\
#     --dsn2="dbi:Pg:service=postgres" \
#     --threads=1
#     --validator=ResultsetComparator 
#     --queries=100000 --seed=time --grammar=conf/mz/char-varchar.yy
#

thread1_init:
	DROP TABLE IF EXISTS t1 ; CREATE TABLE t1 (f1 CHAR(5) /*executor2 collate "C" */, f2 VARCHAR(5) /*executor2 collate "C" */, f3 TEXT /*executor2 collate "C" */)
;

query:
	insert | select
;

insert:
	INSERT INTO t1 VALUES ( value , value , value );

value:
	CONCAT( value , value ) |
	REPEAT( value , _digit ) |
	literal_with_collation |
	literal_with_collation |
	literal_with_collation |
	literal_with_collation |
	literal_with_collation 
;

literal_with_collation:
	literal::type /*executor2 collate "C" */
;

type:
	CHAR(one_to_nine) | VARCHAR(one_to_nine) | TEXT
;

one_to_nine:
	1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9
;

literal:
	'A' | 'a' | 'a ' | ' ' | '  ' |  _char(1) | _char(5)
;

select:
	SELECT distinct select_item FROM t1 AS a1 WHERE cond | 
	SELECT select_item FROM t1 AS a1 GROUP BY 1 ORDER BY 1 |
	SELECT select_item FROM t1 AS a1 ORDER BY 1 LIMIT _digit |
	SELECT select_item FROM t1 AS a1 , t1 AS a2 WHERE cond 
;

distinct:
	| DISTINCT
;

not:
	| NOT
;

and_or:
	AND | OR
;

select_item:
	expr_or_col |
	aggregate ( distinct expr_or_col )
;

func_1_argument:
	UPPER | LOWER | LTRIM | RTRIM 
;

func_2_arguments:
	LEFT | RIGHT | LPAD
;

aggregate:
	MIN | MAX | COUNT
;

expr_or_col:
	alias . f1_f2_f3 | alias . f1_f2_f3 | alias . f1_f2_f3 | alias . f1_f2_f3 | alias . f1_f2_f3 |
	CONCAT(alias . f1_f2_f3, expr_or_col) |
	func_1_argument ( expr_or_col ) |
	func_2_arguments ( expr_or_col , _digit ) |
	literal_with_collation
;
 
f1_f2_f3:
	f1 | f2 | f3
;

cond:
	side cmp_op side | 
	cond and_or cond |
	expr_or_col not LIKE expr_or_col
;

alias:
	a1 | a1 | a2
;

side:
	expr_or_col
;

cmp_op:
	= | >= | <= | < | !=
;
