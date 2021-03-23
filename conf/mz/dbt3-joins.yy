#
# This grammar attempts to create realistic queries against the DBT-3 data set. The following rules apply:
# 
# * standard DBT-3 prefixes are used for stuff ,e.g. ps = partsupp , r = region , etc.
#
# * each join is one of several plausible join chains allowed by the dataset
#
# * each WHERE condition is realistic for the column being queried and only uses table that are known to participate in the particular join chain
#
# * More AND is used as opposed to OR to keep with the spirit of the original queries from the benchmark
#
# * MariaDB's table elimination will remove unnecessary tables that have been joined but for which no WHERE conditions apply
#
# * The joinable fields are indexed in both tables and most WHERE conditions also involve indexes. To provide some non-indexed clauses
# * we include some WHERE conditions on the comment field that appears in each table
#
# * In order to have realistic HAVING, for the HAVING queries we only use fields that hold currency ammounts
#

query:
	select
;

select:
	select_l_o | select_l_o_c
# | select_r_n_s_ps_l_o_c | select_p_ps_s_n_r | select_p_ps_l_o_c_r_n_s;
# | currency_select_p_ps_s_l_o_c
;

#	select_r_n_s_ps_l_o_c | select_p_ps_s_n_r | select_p_ps_l_o_c_r_n_s | currency_select_p_ps_s_l_o_c;

select_l_o:
	SELECT select_list_l_o join_l_o WHERE where_l_o order_by_1_2 |
	SELECT aggregate_list_l_o join_l_o WHERE where_l_o |
	SELECT field_l_o , aggregate_list_l_o join_l_o WHERE where_l_o GROUP BY 1 order_by_1 |
	SELECT field_l_o , field_l_o , aggregate_list_l_o join_l_o WHERE where_l_o GROUP BY 1 , 2 order_by_1_2
;

aggregate_list_l_o:
	aggregate field_l_o ) , aggregate field_l_o ) |
	aggregate field_l_o ) , aggregate_list_l_o
;

select_l_o_c:
	SELECT select_list_l_o_c join_l_o_c WHERE where_l_o_c order_by_1_2 |
	SELECT aggregate_list_l_o_c join_l_o_c WHERE where_l_o |
	SELECT field_l_o_c , aggregate_list_l_o_c join_l_o_c WHERE where_l_o GROUP BY 1 order_by_1 |
	SELECT field_l_o_c , field_l_o_c , aggregate_list_l_o_c join_l_o_c WHERE where_l_o_c GROUP BY 1 , 2 order_by_1_2
;

aggregate_list_l_o_c:
	aggregate field_l_o_c ) , aggregate field_l_o_c ) |
	aggregate field_l_o_c ) , aggregate_list_l_o_c
;


# region -> nation -> supplier -> partsupp -> lineitem -> orders -> customer

select_r_n_s_ps_l_o_c:
	SELECT select_list_r_n_s_ps_l_o_c join_r_n_s_ps_l_o_c WHERE where_r_n_s_ps_l_o_c order_by_1_2 |
	SELECT aggregate field_r_n_s_ps_l_o_c ) join_r_n_s_ps_l_o_c WHERE where_r_n_s_ps_l_o_c |
	SELECT field_r_n_s_ps_l_o_c , aggregate field_r_n_s_ps_l_o_c ) join_r_n_s_ps_l_o_c WHERE where_r_n_s_ps_l_o_c GROUP BY 1 asc_desc order_by_1 |
	SELECT field_r_n_s_ps_l_o_c , field_r_n_s_ps_l_o_c , aggregate field_r_n_s_ps_l_o_c ) join_r_n_s_ps_l_o_c WHERE where_r_n_s_ps_l_o_c GROUP BY 1 asc_desc , 2 asc_desc order_by_1_2 ;

# part -> partsupp -> supplier -> nation -> region

select_p_ps_s_n_r:
	SELECT select_list_p_ps_s_n_r join_p_ps_s_n_r WHERE where_p_ps_s_n_r order_by_1_2 |
	SELECT aggregate field_p_ps_s_n_r ) join_p_ps_s_n_r WHERE where_p_ps_s_n_r |
	SELECT field_p_ps_s_n_r , aggregate field_p_ps_s_n_r ) join_p_ps_s_n_r WHERE where_p_ps_s_n_r GROUP BY 1 asc_desc order_by_1 |
	SELECT field_p_ps_s_n_r , field_p_ps_s_n_r , aggregate field_p_ps_s_n_r ) join_p_ps_s_n_r WHERE where_p_ps_s_n_r GROUP BY 1 asc_desc , 2 asc_desc order_by_1_2 ;

# part -> partsupp -> lineitem -> orders -> customer -> region -> nation -> supplier

select_p_ps_l_o_c_r_n_s:
	SELECT select_list_p_ps_l_o_c_r_n_s join_p_ps_l_o_c_r_n_s WHERE where_p_ps_l_o_c_r_n_s order_by_1_2 |
	SELECT aggregate field_p_ps_l_o_c_r_n_s ) join_p_ps_l_o_c_r_n_s WHERE where_p_ps_l_o_c_r_n_s |
	SELECT field_p_ps_l_o_c_r_n_s , aggregate field_p_ps_l_o_c_r_n_s ) join_p_ps_l_o_c_r_n_s WHERE where_p_ps_l_o_c_r_n_s GROUP BY 1 asc_desc order_by_1 |
	SELECT field_p_ps_l_o_c_r_n_s , field_p_ps_l_o_c_r_n_s , aggregate field_p_ps_l_o_c_r_n_s ) join_p_ps_l_o_c_r_n_s WHERE where_p_ps_l_o_c_r_n_s GROUP BY 1 asc_desc , 2 asc_desc order_by_1_2 ;

# part -> partsupp -> lineitem -> orders -> customer with currency fields only
# This allows for a meaningful HAVING condition because the type and the spirit of values in the SELECT list will be known

currency_select_p_ps_s_l_o_c:
	SELECT currency_field_p_ps_s_l_o_c AS currency1 , currency_field_p_ps_s_l_o_c AS currency2 join_p_ps_s_l_o_c WHERE where_p_ps_s_l_o_c HAVING currency_having order_by_1_2 |
	SELECT field_p_ps_s_l_o_c, currency_field_p_ps_s_l_o_c AS currency1 , aggregate currency_field_p_ps_s_l_o_c ) AS currency2 join_p_ps_s_l_o_c WHERE where_p_ps_s_l_o_c GROUP BY 1 , 2 HAVING currency_having order_by_1_2 ;

asc_desc:
;
#	| | | | | | ASC | DESC ;

order_by_1:
	| | ORDER BY 1 ;					# 30% of queries have ORDER BY on a single column

order_by_1_2:
	| | | | | | ORDER BY 1 | ORDER BY 2 | ORDER BY 1 , 2 ;	# 30% of queries have ORDER BY on two columns

join_l_o:
	FROM lineitem, orders |
	FROM lineitem join_type orders ON ( l_orderkey = o_orderkey ) |
	FROM lineitem join_type orders ON ( cond_multitable_l_o )
;

join_l_o_c:
#	FROM lineitem, orders, customer |
	FROM lineitem join_type orders ON ( l_orderkey = o_orderkey ) join_type customer ON ( o_custkey = c_custkey ) |
	FROM lineitem join_type orders ON ( cond_multitable_l_o ) join_type customer ON ( o_custkey = c_custkey ) |
	FROM lineitem join_type orders ON ( l_orderkey = o_orderkey ) join_type customer ON ( cond_multitable_o_c )
;

join_r_n_s_ps_l_o_c:
	FROM region join_type nation ON ( r_regionkey = n_regionkey ) join_type supplier ON ( s_nationkey = n_nationkey ) join_type partsupp ON ( s_suppkey = ps_suppkey ) join_type lineitem ON ( partsupp_lineitem_join_cond ) join_type orders ON ( l_orderkey = o_orderkey ) join_type customer ON ( o_custkey = c_custkey ) ;

join_p_ps_s_n_r:
	FROM part join_type partsupp ON ( p_partkey = ps_partkey ) join_type supplier ON ( ps_suppkey = s_suppkey ) join_type nation ON ( s_nationkey = n_nationkey ) join_type region ON ( n_regionkey = r_regionkey ) ;

join_p_ps_l_o_c_r_n_s:
	FROM part join_type partsupp ON ( p_partkey = ps_partkey ) join_type lineitem ON ( partsupp_lineitem_join_cond ) join_type orders ON ( l_orderkey = o_orderkey ) join_type customer ON ( o_custkey = c_custkey ) join_type nation ON ( c_nationkey = n_nationkey ) join_type supplier ON ( s_nationkey = n_nationkey ) join_type region ON ( n_regionkey = r_regionkey ) ;

join_p_ps_s_l_o_c:
	FROM part join_type partsupp ON ( p_partkey = ps_partkey ) join_type supplier ON (s_suppkey = ps_suppkey) join_type lineitem ON ( partsupp_lineitem_join_cond ) join_type orders ON ( l_orderkey = o_orderkey ) join_type customer ON ( o_custkey = c_custkey ) ;
	
join_type:
	JOIN | JOIN | JOIN | JOIN | outer_join
;

outer_join:
	LEFT JOIN | RIGHT JOIN
;

partsupp_lineitem_join_cond:
	ps_partkey = l_partkey AND ps_suppkey = l_suppkey |
	ps_partkey = l_partkey AND ps_suppkey = l_suppkey |
	ps_partkey = l_partkey | ps_suppkey = l_suppkey ;

lineitem_orders_join_cond:
	l_orderkey = o_orderkey | lineitem_date_field = o_orderdate ;

lineitem_date_field:
	l_shipDATE | l_commitDATE | l_receiptDATE ;

select_list_r_n_s_ps_l_o_c:
	*
;
#	field_r_n_s_ps_l_o_c , field_r_n_s_ps_l_o_c | field_r_n_s_ps_l_o_c , select_list_r_n_s_ps_l_o_c ;

field_r_n_s_ps_l_o_c:
	field_r | field_n | field_s | field_ps | field_l | field_o | field_c ;

select_list_l_o:
	field_l_o, field_l_o |
	field_l_o, select_list_l_o
;

select_list_l_o_c:
	field_l_o_c, field_l_o_c |
	field_l_o_c, select_list_l_o_c
;

field_l_o:
	field_l | field_o |
	field_l | field_o |
	field_l | field_o |
	field_l | field_o |
	field_multitable_l_o
;

field_multitable_l_o:
	o_totalprice - l_extendedprice
# |
#	CONCAT( o_comment , l_comment ) | #  https://github.com/MaterializeInc/materialize/issues/5579
#	l_shipdate - o_orderdate  # https://github.com/MaterializeInc/materialize/issues/6187
;

field_l_o_c:
	field_l | field_o | field_c
;

select_list_p_ps_s_n_r:
	*
;
	field_p_ps_s_n_r , field_p_ps_s_n_r | field_p_ps_s_n_r , select_list_p_ps_s_n_r ;

field_p_ps_s_n_r:
	field_p | field_ps | field_s | field_n | field_r;

select_list_p_ps_l_o_c_r_n_s:
	*
;
	field_p_ps_l_o_c_r_n_s , field_p_ps_l_o_c_r_n_s | field_p_ps_l_o_c_r_n_s , select_list_p_ps_l_o_c_r_n_s ;

field_p_ps_l_o_c_r_n_s:
	field_p | field_ps | field_l | field_o | field_c | field_r | field_n | field_s ;

field_p_ps_s_l_o_c:
	field_p | field_ps | field_s | field_l | field_o | field_c |;

currency_field_p_ps_s_l_o_c:
	p_retailprice | ps_supplycost | l_extendedprice | o_totalprice | s_acctbal | c_acctbal ;

field_p:
	p_partkey;

field_s:
	s_suppkey | s_nationkey ;

field_ps:
	ps_partkey | ps_suppkey ;

field_l:
	l_orderkey | l_partkey | l_suppkey | l_linenumber | l_shipDATE | l_commitDATE | l_receiptDATE | expr_l ;

expr_l:
	l_quantity * l_extendedprice
# |	l_shipdate - l_commitdate # https://github.com/MaterializeInc/materialize/issues/5965
;

field_o:
	o_orderkey | o_custkey ;

field_c:
	c_custkey | c_nationkey ;

field_n:
	n_nationkey ;

field_r:
	r_regionkey ;

aggregate:
	COUNT( distinct | 
	#SUM( distinct |
	MIN( | MAX(
;

#
# All aggrates that are not COUNT , that is, those that return a value that can be meaningfull
# compared to existing values from the column it came from
#

preserving_aggregate:
	MIN( | MAX( | AVG(
	# | SUM( distinct
;

distinct:
	| | | DISTINCT ;

where_l_o:
	conds_l_o and_or conds_l_o and_or conds_l_o |
	conds_l_o and_or where_l_o
;

conds_l_o:
	cond_l | cond_o | cond_multitable_l_o
;

where_l_o_c:
	conds_l_o_c and_or conds_l_o_c and_or conds_l_o_c |
	conds_l_o_c and_or where_l_o_c
;

conds_l_o_c:
	cond_l | cond_o | cond_c | cond_multitable_l_o | cond_multitable_l_o_c
;

where_r_n_s_ps_l_o_c:
	cond_r_n_s_ps_l_o_c and_or cond_r_n_s_ps_l_o_c and_or cond_r_n_s_ps_l_o_c | where_r_n_s_ps_l_o_c and_or cond_r_n_s_ps_l_o_c ;
cond_r_n_s_ps_l_o_c:
	cond_r | cond_n | cond_s | cond_ps | cond_l | cond_o | cond_c | cond_multitable_l_o | cond_multitable_l_o | cond_multitable_s_c | cond_multitable_ps_l ;

where_p_ps_s_n_r:
	cond_p_ps_s_n_r and_or cond_p_ps_s_n_r and_or cond_p_ps_s_n_r | where_p_ps_s_n_r and_or cond_p_ps_s_n_r ;
cond_p_ps_s_n_r:
	cond_p | cond_ps | cond_s | cond_n | cond_r ;


where_p_ps_l_o_c_r_n_s:
	cond_p_ps_l_o_c_r_n_s and_or cond_p_ps_l_o_c_r_n_s and_or cond_p_ps_l_o_c_r_n_s | where_p_ps_l_o_c_r_n_s and_or cond_p_ps_l_o_c_r_n_s ;
cond_p_ps_l_o_c_r_n_s:
	cond_p | cond_ps | cond_l | cond_o | cond_c | cond_r | cond_n | cond_s ;

where_p_ps_s_l_o_c:
	cond_p_ps_s_l_o_c and_or cond_p_ps_s_l_o_c and_or cond_p_ps_s_l_o_c | where_p_ps_s_l_o_c and_or cond_p_ps_s_l_o_c ;

cond_p_ps_s_l_o_c:
	cond_p | cond_ps | cond_s | cond_l | cond_o | cond_c ;

currency_having:
	currency_having_item |
	currency_having_item and_or currency_having_item ;

currency_having_item:
	currency_having_field currency_clause ;

currency_having_field:
	currency1 | currency2 ;

and_or:
	AND | AND | AND | AND | AND |
	AND | AND | AND | AND | OR
;

any_all:
	ANY | ALL |
;

plus_minus:
	+ | -
;

interval_type:
	DAYS | MONTHS
;

#
# Multi-table WHERE conditions
#

cond_multitable_l_o:
	o_totalprice - l_extendedprice comp_op 0 |
	l_extendedprice comp_op o_totalprice |
	lineitem_date_field comp_op o_orderdate |
	l_extendedprice comp_op MOD (o_totalprice , 5 ) |
	lineitem_date_field comp_op o_orderdate plus_minus INTERVAL ' _digit interval_type ' |
	o_orderdate comp_op lineitem_date_field plus_minus INTERVAL ' _digit interval_type '
;

cond_multitable_l_o_c:
	c_acctbal - o_totalprice comp_op 0 |
	c_acctbal comp_op o_totalprice |
	c_acctbal comp_op l_extendedprice
;

cond_multitable_o_c:
        c_acctbal comp_op o_totalprice
;

cond_multitable_ps_l:
	ps_availqty comp_op l_quantity | ps_supplycost comp_op l_extendedprice ;

cond_multitable_s_c:
	c_nationkey comp_op s_nationkey ;
	
#
# Per-table WHERE conditions
#

cond_p:
	p_partkey partkey_clause |
	p_retailprice currency_clause |
	p_comment comment_clause
;

cond_s:
	s_suppkey suppkey_clause |
	s_nationkey nationkey_clause |
	s_acctbal currency_clause |
	s_comment comment_clause ;

cond_ps:
	ps_partkey partkey_clause |
	ps_suppkey suppkey_clause |
	ps_supplycost currency_clause |
	ps_comment comment_clause ;

cond_l:
	l_linenumber linenumber_clause |
	l_shipDATE shipdate_clause |
	l_partkey partkey_clause |
	l_suppkey suppkey_clause |
	l_receiptDATE receiptdate_clause |
	l_orderkey orderkey_clause |
	l_quantity quantity_clause |
	l_commitDATE commitdate_clause |
	l_extendedprice currency_clause
# https://github.com/MaterializeInc/materialize/issues/5579
# |
#	l_comment comment_clause
;

cond_o:
	o_orderkey orderkey_clause |
	cond_o_custkey |
	o_totalprice currency_clause
	# https://github.com/MaterializeInc/materialize/issues/5579
	# | o_comment comment_clause
;

cond_o_custkey:
	o_custkey custkey_clause |
	o_custkey custkey_clause |
	o_custkey custkey_clause |
	o_custkey custkey_clause |
	not EXISTS ( custkey_scalar_subquery )
;

cond_c:
	c_custkey custkey_clause |
	c_acctbal currency_clause |
	c_comment comment_clause ;

cond_n:
	n_nationkey nationkey_clause |
	n_comment comment_clause ;

cond_r:
	r_regionkey regionkey_clause |
	r_comment comment_clause ;

#
# Per-column WHERE conditions
#

comp_op:
        = | = | = | = | != | > | >= | < | <= | <> ;

not:
	| | | | | | | | | NOT ;

shipdate_clause:
	comp_op any_date |
	not IN ( date_list ) |
	date_between ;

date_list:
	date_item , date_item |
	date_list , date_item ;

date_item:
	any_date | any_date | any_date | any_date | any_date |
	any_date | any_date | any_date | any_date | any_date |
	any_date | any_date | any_date | any_date | any_date |
	any_date | any_date | any_date | any_date | any_date |
	'1992-01-08' | '1998-11-27' ;

date_between:
	BETWEEN date_item AND date_item |
	between_two_dates_in_a_year |
	between_two_dates_in_a_month |
	within_a_month ;

day_month_year:
	DAY | MONTH | YEAR ;

any_date:
	{ sprintf("'%04d-%02d-%02d'", $prng->uint16(1992,1998), $prng->uint16(1,12), $prng->uint16(1,28)) } ;

between_two_dates_in_a_year:
	{ my $year = $prng->uint16(1992,1998); return sprintf("BETWEEN '%04d-%02d-%02d' AND '%04d-%02d-%02d'", $year, $prng->uint16(1,12), $prng->uint16(1,28), $year, $prng->uint16(1,12), $prng->uint16(1,28)) } ;

between_two_dates_in_a_month:
	{ my $year = $prng->uint16(1992,1998); my $month = $prng->uint16(1,12); return sprintf("BETWEEN '%04d-%02d-%02d' AND '%04d-%02d-%02d'", $year, $month, $prng->uint16(1,28), $year, $month, $prng->uint16(1,28)) } ;

within_a_month:
	{ my $year = $prng->uint16(1992,1998); my $month = $prng->uint16(1,12); return sprintf("BETWEEN '%04d-%02d-01' AND '%04d-%02d-28'", $year, $month, $year, $month) } ;

# LINENUMBER

linenumber_clause:
	comp_op linenumber_item |
	not IN ( linenumber_list ) |
	BETWEEN linenumber_item AND linenumber_item + linenumber_range ;

linenumber_list:
	linenumber_item , linenumber_item |
	linenumber_item , linenumber_list ;

linenumber_item:
	_digit; 

linenumber_range:
	_digit ;

# PARTKEY

partkey_clause:
	partkey_clause_nosubquery | partkey_clause_nosubquery | partkey_clause_nosubquery | partkey_clause_nosubquery | partkey_clause_nosubquery |
	partkey_clause_nosubquery | partkey_clause_nosubquery | partkey_clause_nosubquery | partkey_clause_nosubquery | partkey_clause_subquery
;

partkey_clause_nosubquery:
	comp_op partkey_item |
	not IN ( partkey_list ) |
	BETWEEN partkey_item AND partkey_item + partkey_range
;

partkey_list:
	partkey_item , partkey_item |
	partkey_item , partkey_list ;

partkey_range:
	_digit | _tinyint_unsigned;

partkey_item:
	_tinyint_unsigned  | _tinyint_unsigned | _tinyint_unsigned | _tinyint_unsigned | _tinyint_unsigned |
	_tinyint_unsigned  | _tinyint_unsigned | _tinyint_unsigned | _tinyint_unsigned | _tinyint_unsigned |
	_tinyint_unsigned  | _tinyint_unsigned | _tinyint_unsigned | _tinyint_unsigned | _tinyint_unsigned |
	_tinyint_unsigned  | _tinyint_unsigned | _tinyint_unsigned | _tinyint_unsigned | _tinyint_unsigned |
	_digit | 200 | 0 ;

partkey_clause_subquery:
	comp_op any_all ( partkey_scalar_subquery ) |
	not IN ( partkey_subquery )
;

# SUPPKEY

suppkey_clause:
	comp_op suppkey_item |
	not IN ( suppkey_list ) |
	BETWEEN suppkey_item AND suppkey_item + _digit ;

suppkey_item:
	_digit | 10 ;

suppkey_list:
	suppkey_item , suppkey_item |
	suppkey_item , suppkey_list ;

# RECEPITDATE

receiptdate_clause:
	comp_op any_date |
	not IN ( date_list ) |
	date_between ;

# COMMITDATE

commitdate_clause:
	comp_op any_date |
	not IN ( date_list ) |
	date_between ;

# ORDERKEY

orderkey_clause:
	orderkey_clause_nosubquery | orderkey_clause_nosubquery | orderkey_clause_nosubquery | orderkey_clause_nosubquery | orderkey_clause_nosubquery |
	orderkey_clause_nosubquery | orderkey_clause_nosubquery | orderkey_clause_nosubquery | orderkey_clause_nosubquery | orderkey_clause_subquery
;

orderkey_clause_nosubquery:
	comp_op orderkey_item |
	not IN ( orderkey_list ) |
	BETWEEN orderkey_item AND orderkey_item + orderkey_range ;

orderkey_item:
	_tinyint_unsigned | { $prng->uint16(1,1500) } ;

orderkey_list:
	orderkey_item , orderkey_item |
	orderkey_item , orderkey_list ;

orderkey_range:
	_digit | _tinyint_unsigned ;

orderkey_clause_subquery:
	comp_op any_all ( orderkey_scalar_subquery ) |
	not IN ( orderkey_subquery_union )
;

# QUANTITY

quantity_clause:
	comp_op quantity_item |
	not IN ( quantity_list ) |
	BETWEEN quantity_item AND quantity_item + quantity_range ;

quantity_list:
	quantity_item , quantity_item |
	quantity_item , quantity_list ;

quantity_item:
	_digit  | { $prng->uint16(1,50) } ;

quantity_range:
	_digit ;

# CUSTKEY

custkey_clause:
	custkey_clause_nosubquery | custkey_clause_nosubquery | custkey_clause_nosubquery | custkey_clause_nosubquery | custkey_clause_nosubquery |
	custkey_clause_nosubquery | custkey_clause_nosubquery | custkey_clause_nosubquery | custkey_clause_nosubquery | custkey_clause_subquery
;

custkey_clause_nosubquery:
	comp_op custkey_item |
	not IN ( custkey_list ) |
	BETWEEN custkey_item AND custkey_item + custkey_range
;

custkey_item:
	_tinyint_unsigned | { $prng->uint16(1,150) } ;

custkey_list:
	custkey_item , custkey_item |
	custkey_item , custkey_list ;

custkey_range:
	_digit | _tinyint_unsigned ;

custkey_clause_subquery:
	comp_op any_all ( custkey_scalar_subquery ) |
	not IN ( custkey_subquery )
;

# NATIONKEY 

nationkey_clause:
	comp_op nationkey_item |
	not IN ( nationkey_list ) |
	BETWEEN nationkey_item AND nationkey_item + nationkey_range ;

nationkey_item:
	_digit | { $prng->uint16(0,24) } ;

nationkey_list:
	nationkey_item , nationkey_item |
	nationkey_item , nationkey_list ;

nationkey_range:
	_digit | _tinyint_unsigned ;

# REGIONKEY 

regionkey_clause:
	comp_op regionkey_item |
	not IN ( regionkey_list ) |
	BETWEEN regionkey_item AND regionkey_item + regionkey_range ;

regionkey_item:
	1 | 2 | 3 | 4 ;

regionkey_list:
	regionkey_item , regionkey_item |
	regionkey_item , regionkey_list ;

regionkey_range:
	1 | 2 | 3 | 4 ;

# COMMENT

comment_clause:
	IS NOT NULL | IS NOT NULL | IS NOT NULL |
	comp_op _varchar(1) |
	comment_not LIKE CONCAT( comment_count , '%' ) |
	BETWEEN _varchar(1) AND _varchar(1) ;

comment_not:
	NOT | NOT | NOT | ;

comment_count:
	_varchar(1) | _varchar(1) |  _varchar(1) | _varchar(1) | _varchar(2) ;

# CURRENCIES

currency_clause:
	comp_op currency_item |
	BETWEEN currency_item AND currency_item + currency_range ;

currency_item:
	_digit | _tinyint_unsigned | _tinyint_unsigned | _tinyint_unsigned | _mediumint_unsigned ;

currency_range:
	_tinyint_unsigned ;

exactly_one_row:
	ORDER BY 1 LIMIT 1
;

orderkey_scalar_subquery:
	l_orderkey_scalar_subquery | o_orderkey_scalar_subquery
;

orderkey_subquery_union:
	orderkey_subquery | orderkey_subquery | orderkey_subquery | orderkey_subquery | orderkey_subquery |
	orderkey_subquery | orderkey_subquery | orderkey_subquery | orderkey_subquery | orderkey_subquery union orderkey_subquery
;

union:
	UNION distinct_all | EXCEPT distinct_all | INTERSECT distinct_all
;

distinct_all:
	DISTINCT | ALL
;

orderkey_subquery:
	l_orderkey_subquery | o_orderkey_subquery
;

l_orderkey_scalar_subquery:
	SELECT distinct l_orderkey join_l_o WHERE where_l_o exactly_one_row |
	SELECT preserving_aggregate l_orderkey ) join_l_o WHERE where_l_o |
	SELECT preserving_aggregate l_orderkey ) join_l_o WHERE where_l_o GROUP BY select_list_l_o ORDER BY 1 asc_desc LIMIT 1 |
	SELECT distinct l_orderkey FROM lineitem WHERE where_l_o exactly_one_row
;

l_orderkey_subquery:
	SELECT distinct l_orderkey join_l_o WHERE where_l_o |
	SELECT l_orderkey join_l_o WHERE where_l_o GROUP BY l_orderkey |
	SELECT distinct l_orderkey FROM lineitem WHERE where_l_o 
;

partkey_scalar_subquery:
	SELECT l_partkey join_l_o WHERE where_l_o exactly_one_row |
	SELECT preserving_aggregate l_partkey ) join_l_o WHERE where_l_o |
	SELECT l_partkey FROM lineitem WHERE where_l_o exactly_one_row
;

partkey_subquery:
	SELECT distinct l_partkey join_l_o WHERE where_l_o |
	SELECT l_partkey join_l_o WHERE where_l_o GROUP BY l_partkey |
	SELECT l_partkey FROM lineitem WHERE where_l_o
;

o_orderkey_scalar_subquery:
	SELECT o_orderkey join_l_o WHERE where_l_o exactly_one_row |
	SELECT preserving_aggregate o_orderkey ) join_l_o WHERE where_l_o |
	SELECT o_orderkey FROM orders WHERE where_l_o exactly_one_row
;

o_orderkey_subquery:
	SELECT distinct o_orderkey join_l_o WHERE where_l_o |
	SELECT o_orderkey join_l_o WHERE where_l_o GROUP BY o_orderkey |
	SELECT o_orderkey FROM orders WHERE where_l_o
;

custkey_scalar_subquery:
	SELECT o_custkey join_l_o WHERE where_l_o exactly_one_row |
	SELECT preserving_aggregate o_custkey ) join_l_o WHERE where_l_o |
	SELECT o_custkey FROM orders WHERE where_l_o exactly_one_row
;

custkey_subquery:
	SELECT distinct o_custkey join_l_o WHERE where_l_o |
	SELECT o_custkey join_l_o WHERE where_l_o GROUP BY o_custkey |
	SELECT o_custkey FROM orders WHERE where_l_o
;
