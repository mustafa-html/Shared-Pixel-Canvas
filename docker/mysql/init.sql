-- Runs once, when the MySQL data volume is first created.
--
-- The application user signs in with mysql_native_password. The Debian-based
-- Ruby image builds the mysql2 gem against the MariaDB client library, which
-- cannot complete MySQL 8's default caching_sha2_password sign-in over an
-- unencrypted connection.
CREATE USER IF NOT EXISTS 'canvas'@'%' IDENTIFIED WITH mysql_native_password BY 'canvas';
GRANT ALL PRIVILEGES ON *.* TO 'canvas'@'%';
FLUSH PRIVILEGES;
