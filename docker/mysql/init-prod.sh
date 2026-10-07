#!/bin/sh
# Runs once, when the MySQL data volume is first created. Same purpose as
# init.sql, with the password taken from the environment.
mysql -uroot -p"$MYSQL_ROOT_PASSWORD" <<SQL
CREATE USER IF NOT EXISTS 'canvas'@'%' IDENTIFIED WITH mysql_native_password BY '${CANVAS_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON *.* TO 'canvas'@'%';
FLUSH PRIVILEGES;
SQL
