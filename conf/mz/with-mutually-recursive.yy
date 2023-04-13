#
# This grammar generates valid WITH MUTUALLY RECURSIVE queries that are hopefully halting,
# that is, they never produce divergent dataflows that never terminate. This is ensured
# by always incrementing the values in the participating columns until the col_name < 100 condition is
# hit.
#

thread1_init:
    set_serializable ; DROP TABLE IF EXISTS t1 CASCADE ; CREATE TABLE t1 ( t1_definition ) ; INSERT INTO t1 VALUES insert_list 
;

query_init:
    set_serializable
;

set_serializable:
    SET transaction_isolation = SERIALIZABLE
;

query:
    WITH MUTUALLY RECURSIVE
    cte_list
    select
;

insert_list:
    insert_row
;

insert_row:
    ( values_list )
;

values_list:
    0 , 0 , 0
;

select:
    SELECT * FROM c1 UNION SELECT * FROM c2 UNION SELECT * FROM c3
;



cte_list:
    c1 cte_col_list AS ( cte_definition ) , c2 cte_col_list AS ( cte_definition ) , c3 cte_col_list AS ( cte_definition )
;

cte_name:
    c1 | c2 | c3 | t1
;
col_name:
    f1 | f2 | f3
;

t1_definition:
    f1 INTEGER PRIMARY KEY , f2 INTEGER NOT NULL, f3 INTEGER
;

cte_col_list:
    (f1 INTEGER, f2 INTEGER, f3 INTEGER)
;

cte_select_list:
    cte_expr AS f1 , cte_expr AS f2 , cte_expr AS f3
;

cte_select_list_alias:
    cte_expr_alias AS f1 , cte_expr_alias AS f2 , cte_expr_alias AS f3
;

cte_select_list_aggregate:
    aggregate_func( col_name ) + 1 AS f1 , aggregate_func( col_name ) + 1 AS f2 , aggregate_func( col_name ) + 1 AS f3
;

cte_definition:
    cte_constant UNION all cte_select
;

all:
    ALL
;

cte_constant:
   SELECT values_list |
   SELECT * FROM (VALUES ( values_list )) |
   SELECT * FROM table_name |
   SELECT cte_select_list_aggregate FROM table_name
;

aggregate_func:
    MIN
;


cte_select:
    ( SELECT cte_select_list FROM cte_name WHERE cte_where order_by_limit ) |
    ( SELECT cte_select_list_alias FROM cte_name AS a1 join_type JOIN cte_name AS a2 USING ( col_name ) WHERE cte_where_alias ) |
    ( SELECT cte_select_list_alias FROM cte_name AS a1 join_type JOIN ( cte_select ) AS a2 USING ( col_name ) WHERE cte_where_alias ) |
    SELECT cte_select_list_aggregate FROM cte_name WHERE cte_where |
    ( SELECT f1 + 1 AS f1 , aggregate_func( f2 ) + 1 AS f2, aggregate_func( f3 ) + 1 AS f3 FROM cte_name WHERE cte_where GROUP BY f1 )
;

join_type:
    INNER |
    LEFT |
    RIGHT |
    FULL OUTER
;

alias:
    a1 | a2
;

order_by_limit:
    |
    ORDER BY col_name asc_desc LIMIT 99999999999
;

one_or_more:
    1 | 10 | 100 | 1000
;

asc_desc:
    ASC | DESC
;

cte_where:
     col_name < 100 AND ( cte_cond_list )
;

cte_where_alias:
     alias . col_name < 100 AND ( cte_cond_list_alias )
;

cte_cond_list:
    ( cte_cond and_or cte_cond ) |
    ( cte_cond and_or cte_cond_list )
;

cte_cond_list_alias:
    ( cte_cond_alias and_or cte_cond_alias ) |
    ( cte_cond_alias and_or cte_cond_list_alias )
;

cte_expr:
    col_name + const |
    col_name + col_name + 1
;

cte_expr_alias:
    a1 . col_name + const |
    a1 . col_name + a1 . col_name + 1
;

cte_cond:
    col_name cmp_op const |
    col_name IS not NULL
;

cte_cond_alias:
    alias . col_name cmp_op const |
    alias . col_name cmp_op alias . col_name |
    alias . col_name IS not NULL
;

cmp_op:
    < | >
;

and_or:
    AND | OR
;

select_list:
    select_item , select_item |
    select_item , select_list
;

select_item:
    cte_expr
;

not:
    | NOT
;

const:
    _digit + 1 |
    _tinyint_unsigned + 1
;

table_name:
    t1
;
