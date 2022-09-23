query:
    SELECT * FROM join
;

join:
    table_name AS a1 left JOIN table_name AS a2 ON ( join_cond ) WHERE where_clause |
    table_name AS a1 left JOIN table_name AS a2 USING ( col_name_no_alias ) WHERE where_clause |
    table_name AS a1 , table_name AS a2 WHERE join_cond AND where_clause
;

join_cond:
    a1 . col_name_no_alias  = a2 . col_name_no_alias
;

where_clause:
    and_over_or |
    or_over_and |
    random_and_or
;

or_list:
    cond OR cond |
    cond OR or_list
;

and_list:
    cond AND cond |
    cond AND and_list
;

and_over_or:
    ( or_list ) AND ( or_list ) |
    ( or_list ) AND and_over_or
;

or_over_and:
    ( and_list ) OR ( and_list ) |
    ( and_list ) OR or_over_and
;

random_and_or:
    cond and_or cond |
    cond and_or random_and_or
;

and_or:
    AND | OR
;

cond:
    simple_predicate |
    in_list |
    or_list |
    and_list
;

in_list:
    col_name not IN ( in_list_items )
;

in_list_items:
    value , value , value |
    value , in_list_items
;

value:
    _digit
;

not:
    | | | | NOT
;

simple_predicate:
    col_name cmp_op value
;

col_name:
    alias . f1 | alias .f2
;

col_name_no_alias:
    f1 | f2
;

cmp_op:
    = | = | = | = | = | = | = | = | = | > | <
;

alias:
    a1 | a2
;

table_name:
    t1 | t2
;
