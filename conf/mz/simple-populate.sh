cat conf/mz/simple.sql | psql

cat conf/mz/simple.sql | psql -p 6875 -h 127.0.0.1 -U materialize

cat conf/mz/simple.sql | psql -p 16875 -h 127.0.0.1 -U materialize
