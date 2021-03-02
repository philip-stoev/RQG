DROP SCHEMA public CASCADE;
CREATE SCHEMA public;

CREATE TABLE nation (
    n_nationkey  integer,
    n_name       text NOT NULL,
    n_regionkey  integer NOT NULL,
    n_comment    text
);

CREATE INDEX pk_nation_nationkey ON nation (n_nationkey);

CREATE INDEX fk_nation_regionkey ON nation (n_regionkey ASC);

CREATE TABLE region  (
    r_regionkey  integer,
    r_name       text NOT NULL,
    r_comment    text
);

CREATE INDEX pk_region_regionkey ON region (r_regionkey);

CREATE TABLE part (
    p_partkey     integer,
    p_name        text NOT NULL,
    p_mfgr        text NOT NULL,
    p_brand       text NOT NULL,
    p_type        text NOT NULL,
    p_size        integer NOT NULL,
    p_container   text NOT NULL,
    p_retailprice decimal(15, 2) NOT NULL,
    p_comment     text NOT NULL
);

CREATE INDEX pk_part_partkey ON part (p_partkey);

CREATE TABLE supplier (
    s_suppkey     integer,
    s_name        text NOT NULL,
    s_address     text NOT NULL,
    s_nationkey   integer NOT NULL,
    s_phone       text NOT NULL,
    s_acctbal     decimal(15, 2) NOT NULL,
    s_comment     text NOT NULL
);

CREATE INDEX pk_supplier_suppkey ON supplier (s_suppkey);

CREATE INDEX fk_supplier_nationkey ON supplier (s_nationkey ASC);

CREATE TABLE partsupp (
    ps_partkey     integer NOT NULL,
    ps_suppkey     integer NOT NULL,
    ps_availqty    integer NOT NULL,
    ps_supplycost  decimal(15, 2) NOT NULL,
    ps_comment     text NOT NULL
);

CREATE INDEX pk_partsupp_partkey_suppkey ON partsupp (ps_partkey, ps_suppkey);

CREATE INDEX fk_partsupp_partkey ON partsupp (ps_partkey ASC);
CREATE INDEX fk_partsupp_suppkey ON partsupp (ps_suppkey ASC);

CREATE TABLE customer (
    c_custkey     integer,
    c_name        text NOT NULL,
    c_address     text NOT NULL,
    c_nationkey   integer NOT NULL,
    c_phone       text NOT NULL,
    c_acctbal     decimal(15, 2) NOT NULL,
    c_mktsegment  text NOT NULL,
    c_comment     text NOT NULL
);

CREATE INDEX pk_customer_custkey ON customer (c_custkey);
CREATE INDEX fk_customer_nationkey ON customer (c_nationkey ASC);

CREATE TABLE orders (
    o_orderkey       integer,
    o_custkey        integer NOT NULL,
    o_orderstatus    text NOT NULL,
    o_totalprice     decimal(15, 2) NOT NULL,
    o_orderdate      DATE NOT NULL,
    o_orderpriority  text NOT NULL,
    o_clerk          text NOT NULL,
    o_shippriority   integer NOT NULL,
    o_comment        text NOT NULL
);

CREATE INDEX pk_orders_orderkey ON orders (o_orderkey);

CREATE INDEX fk_orders_custkey ON orders (o_custkey ASC);

CREATE TABLE lineitem (
    l_orderkey       integer NOT NULL,
    l_partkey        integer NOT NULL,
    l_suppkey        integer NOT NULL,
    l_linenumber     integer NOT NULL,
    l_quantity       decimal(15, 2) NOT NULL,
    l_extendedprice  decimal(15, 2) NOT NULL,
    l_discount       decimal(15, 2) NOT NULL,
    l_tax            decimal(15, 2) NOT NULL,
    l_returnflag     text NOT NULL,
    l_linestatus     text NOT NULL,
    l_shipdate       date NOT NULL,
    l_commitdate     date NOT NULL,
    l_receiptdate    date NOT NULL,
    l_shipinstruct   text NOT NULL,
    l_shipmode       text NOT NULL,
    l_comment        text NOT NULL
);

CREATE INDEX pk_lineitem_orderkey_linenumber ON lineitem (l_orderkey, l_linenumber);

CREATE INDEX fk_lineitem_orderkey ON lineitem (l_orderkey ASC);
CREATE INDEX fk_lineitem_partkey ON lineitem (l_partkey ASC);
CREATE INDEX fk_lineitem_suppkey ON lineitem (l_suppkey ASC);
CREATE INDEX fk_lineitem_partsuppkey ON lineitem (l_partkey ASC, l_suppkey ASC);
