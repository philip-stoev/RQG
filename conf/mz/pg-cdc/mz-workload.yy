query_init:
	DROP SCHEMA public CASCADE ; CREATE SCHEMA public ; create_sources ; create_views
;

create_sources:
	create_all_table_pk_source ; create_all_table_nopk_source ; create_row_table_pk_source ; create_row_table_nopk_source
;

create_all_table_pk_source:
	CREATE MATERIALIZED SOURCE "all_table_pk" FROM POSTGRES HOST 'host=localhost port=5432 user=postgres password=postgres dbname=postgres' PUBLICATION 'mz_source' NAMESPACE 'public' TABLE 'all_table_pk' (key INTEGER, value INTEGER)
;

create_all_table_nopk_source:
	CREATE MATERIALIZED SOURCE "all_table_nopk" FROM POSTGRES HOST 'host=localhost port=5432 user=postgres password=postgres dbname=postgres' PUBLICATION 'mz_source' NAMESPACE 'public' TABLE 'all_table_nopk' (key INTEGER, value INTEGER)
;

create_row_table_pk_source:
	CREATE MATERIALIZED SOURCE "row_table_pk" FROM POSTGRES HOST 'host=localhost port=5432 user=postgres password=postgres dbname=postgres' PUBLICATION 'mz_source' NAMESPACE 'public' TABLE 'row_table_pk' (key INTEGER, left_value INTEGER, right_value INTEGER)
;

create_row_table_nopk_source:
	CREATE MATERIALIZED SOURCE "row_table_nopk" FROM POSTGRES HOST 'host=localhost port=5432 user=postgres password=postgres dbname=postgres' PUBLICATION 'mz_source' NAMESPACE 'public' TABLE 'row_table_nopk' (key INTEGER, left_value INTEGER, right_value INTEGER)
;

create_views:
	create_all_table_pk_view ; create_all_table_nopk_view ; create_row_table_pk_view ; create_row_table_nopk_view
;

create_all_table_pk_view:
	CREATE MATERIALIZED VIEW all_table_pk_view AS SELECT AVG(value) = 100, COUNT(*) FROM all_table_pk
;

create_all_table_nopk_view:
	CREATE MATERIALIZED VIEW all_table_nopk_view AS SELECT AVG(value) = 100, COUNT(*) FROM all_table_nopk
;

create_row_table_pk_view:
	CREATE MATERIALIZED VIEW row_table_pk_view AS SELECT COUNT(*) = 0 FROM row_table_pk WHERE left_value + right_value != 100;
;

create_row_table_nopk_view:
	CREATE MATERIALIZED VIEW row_table_nopk_view AS SELECT COUNT(*) = 0 FROM row_table_nopk WHERE left_value + right_value != 100;
;

query:
	SELECT * /*+RESULTSET_IS_SINGLE_INTEGER_ONE */ FROM view_name |
	SELECT COUNT(*) FROM source
;

view_name:
	all_table_pk_view | all_table_nopk_view | row_table_pk_view | row_table_nopk_view
;

source:
	all_table_pk | all_table_nopk | row_table_pk | row_table_nopk
