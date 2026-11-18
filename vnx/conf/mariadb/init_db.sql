-- Inicializacion de la base de datos MariaDB para el Trabajo Final CNVR/ARSN (Grupo 11)
CREATE DATABASE IF NOT EXISTS cnvr_db CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

-- Usuario administrador remoto restringido a la subred de la VLAN 1000 (10.1.2.0/24)
CREATE USER IF NOT EXISTS 'dbadmin'@'10.1.2.%' IDENTIFIED BY 'cnvr2026';
GRANT ALL PRIVILEGES ON *.* TO 'dbadmin'@'10.1.2.%' WITH GRANT OPTION;

CREATE USER IF NOT EXISTS 'dbadmin'@'localhost' IDENTIFIED BY 'cnvr2026';
GRANT ALL PRIVILEGES ON *.* TO 'dbadmin'@'localhost' WITH GRANT OPTION;

USE cnvr_db;

CREATE TABLE IF NOT EXISTS nodos_registrados (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    rol VARCHAR(50) NOT NULL,
    ip_vlan VARCHAR(20) NOT NULL,
    actualizado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

DELETE FROM nodos_registrados;
INSERT INTO nodos_registrados (nombre, rol, ip_vlan) VALUES
    ('admin', 'Pod Administracion K8s', '10.1.2.10'),
    ('bbdd',  'Contenedor LXC MariaDB', '10.1.2.100'),
    ('logs',  'Contenedor LXC Rsyslog', '10.1.2.101');

FLUSH PRIVILEGES;
