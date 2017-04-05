CREATE DATABASE IF NOT EXISTS cattle COLLATE = 'utf8_general_ci' CHARACTER SET = 'utf8';
-- CREATE USER IF NOT EXISTS 'cattle'@'%' IDENTIFIED BY 'cattle';
-- CREATE USER IF NOT EXISTS 'cattle'@'localhost' IDENTIFIED BY 'cattle';
GRANT ALL ON cattle.* TO 'cattle'@'%' IDENTIFIED BY 'cattle';
GRANT ALL ON cattle.* TO 'cattle'@'localhost' IDENTIFIED BY 'cattle';
EXIT
