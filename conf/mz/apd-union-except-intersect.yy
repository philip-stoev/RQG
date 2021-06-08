thread1_init:
	DROP TABLE IF EXISTS t1 CASCADE ; DROP TABLE IF EXISTS t2 CASCADE ; CREATE TABLE t1 (f1 APD) ; CREATE TABLE t2 (f1 APD) ;

query:
	insert | check
;

check:
	DROP VIEW IF EXISTS v1 |
	CREATE /*executor1 MATERIALIZED */ VIEW v1 AS select |
	SELECT * FROM v1 |
	select
;

select:
	SELECT plus_minus f1 AS f1 FROM from_clause |
	SELECT plus_minus aggregate AS f1 FROM from_clause |
	SELECT plus_minus aggregate AS f1 FROM from_clause GROUP BY f1 |
	SELECT DISTINCT plus_minus f1 AS f1 FROM from_clause
;

aggregate:
	SUM( distinct f1 ) |
	COUNT( distinct f1 )::TEXT::APD
;

distinct:
	| DISTINCT
;

from_clause:
	table_name | table_name |
	( select union_operator all select ) AS a1
;

union_operator:
	UNION | EXCEPT | INTERSECT
;

all:
	| ALL
;

insert:
	INSERT INTO table_name VALUES value_list
;

value_list:
	( value ) , ( value ) |
	( value ) , value_list
;

value:
	const
;

table_name:
	t1 | t2
;

plus_minus:
	+ | -
;

const:
	string_literal::type 
;

string_literal:
	type1_literal |
	type2_literal |
	type3_literal
;

type1_literal:
        '+number.number ' | '-number.number ' | '+0.number ' | '-0.number '
;

type2_literal:
	CONCAT(plus_minus_quoted, number , zeroes , '.' , zeroes , number)
;

type3_literal:
	CONCAT( plus_minus_quoted , digit_list , '.' , digit_list )
;

zeroes:
	'' |
        '0' | '00' | '000' | '0000' | '00000' |
        '000000' | '0000000' | '00000000' | '000000000' | '0000000000' |
        '00000000000' | '000000000000' | '0000000000000' | '00000000000000' | '000000000000000'
;

number:
	1 | 0 |	_digit | _tinyint_unsigned | _smallint_unsigned | _mediumint_unsigned | _integer_unsigned | _bigint_unsigned
;

digit_list:
	_digit , _digit , _digit |
	_digit , _digit , digit_list
;

plus_minus_quoted:
	'+' | '-'
;

type:
	APD
;
