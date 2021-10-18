CREATE USER IF NOT EXISTS 'msandbox'@'%' IDENTIFIED BY 'msandbox';
GRANT ALL ON *.* TO 'msandbox'@'%' IDENTIFIED BY 'msandbox';

CREATE OR REPLACE DATABASE mariadb_test;
CREATE TABLE IF NOT EXISTS mariadb_test.sentinel (id INT PRIMARY KEY, ping VARCHAR(64) NOT NULL DEFAULT '');
