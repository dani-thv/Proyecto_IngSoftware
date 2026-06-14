-- =============================================
-- ESQUEMA INICIAL DE BASE DE DATOS
-- Sistema: MedTriage
-- Motor: PostgreSQL
-- Versión: 1.0
-- Fecha: 2025
-- =============================================

-- Crear base de datos
CREATE DATABASE medtriage_db
    WITH ENCODING = 'UTF8'
    LC_COLLATE = 'es_CO.UTF-8'
    LC_CTYPE = 'es_CO.UTF-8';

\c medtriage_db;

-- =============================================
-- TIPOS ENUM
-- =============================================

CREATE TYPE rol_enum AS ENUM (
    'ADMISION',
    'ENFERMERIA',
    'MEDICO',
    'ADMINISTRADOR'
);

CREATE TYPE genero_enum AS ENUM (
    'M',
    'F',
    'OTRO'
);

CREATE TYPE estado_flujo_enum AS ENUM (
    'PENDIENTE_POR_TRIAJE',
    'EN_TRIAJE',
    'EN_ESPERA',
    'EN_ATENCION',
    'ATENDIDO',
    'NO_SE_PRESENTO'
);

CREATE TYPE estado_turno_enum AS ENUM (
    'EN_ESPERA',
    'LLAMADO',
    'EN_ATENCION',
    'ATENDIDO',
    'NO_SE_PRESENTO'
);

-- =============================================
-- TABLAS
-- =============================================

CREATE TABLE usuario (
    id_usuario      SERIAL PRIMARY KEY,
    nombre_completo VARCHAR(150) NOT NULL,
    username        VARCHAR(50)  NOT NULL UNIQUE,
    contrasena_hash VARCHAR(255) NOT NULL,
    rol             rol_enum     NOT NULL,
    estado          BOOLEAN      NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE paciente (
    id_paciente          SERIAL PRIMARY KEY,
    id_usuario_registra  INT              NOT NULL,
    documento_identidad  VARCHAR(20)      NOT NULL UNIQUE,
    nombre_completo      VARCHAR(150)     NOT NULL,
    fecha_nacimiento     DATE             NOT NULL,
    genero               genero_enum      NOT NULL,
    telefono             VARCHAR(20),
    eps                  VARCHAR(100),
    estado_flujo         estado_flujo_enum NOT NULL DEFAULT 'PENDIENTE_POR_TRIAJE',
    fecha_ingreso        TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_paciente_usuario
        FOREIGN KEY (id_usuario_registra)
        REFERENCES usuario(id_usuario)
);

CREATE TABLE signos_vitales (
    id_signos                    SERIAL PRIMARY KEY,
    id_paciente                  INT          NOT NULL,
    id_enfermero                 INT          NOT NULL,
    frecuencia_cardiaca          DECIMAL(5,2) NOT NULL,
    frecuencia_respiratoria      DECIMAL(5,2) NOT NULL,
    presion_arterial_sistolica   DECIMAL(5,2) NOT NULL,
    presion_arterial_diastolica  DECIMAL(5,2) NOT NULL,
    temperatura                  DECIMAL(4,2) NOT NULL,
    saturacion_oxigeno           DECIMAL(5,2) NOT NULL,
    glucometria                  DECIMAL(6,2),
    fecha_registro               TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_signos_paciente
        FOREIGN KEY (id_paciente)
        REFERENCES paciente(id_paciente),
    CONSTRAINT fk_signos_enfermero
        FOREIGN KEY (id_enfermero)
        REFERENCES usuario(id_usuario)
);

CREATE TABLE discriminador (
    id_discriminador        SERIAL PRIMARY KEY,
    motivo_consulta         VARCHAR(255) NOT NULL,
    descripcion_signo       VARCHAR(255) NOT NULL,
    nivel_urgencia_asociado INT          NOT NULL,
    CONSTRAINT chk_nivel_urgencia
        CHECK (nivel_urgencia_asociado BETWEEN 1 AND 5)
);

CREATE TABLE triaje (
    id_triaje                  SERIAL PRIMARY KEY,
    id_paciente                INT       NOT NULL,
    id_enfermero               INT       NOT NULL,
    nivel_sugerido             INT       NOT NULL,
    nivel_final                INT       NOT NULL,
    modificado_manualmente     BOOLEAN   NOT NULL DEFAULT FALSE,
    justificacion_modificacion TEXT,
    escala_dolor               INT       NOT NULL,
    fecha_clasificacion        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_triaje_paciente
        FOREIGN KEY (id_paciente)
        REFERENCES paciente(id_paciente),
    CONSTRAINT fk_triaje_enfermero
        FOREIGN KEY (id_enfermero)
        REFERENCES usuario(id_usuario),
    CONSTRAINT chk_nivel_sugerido
        CHECK (nivel_sugerido BETWEEN 1 AND 5),
    CONSTRAINT chk_nivel_final
        CHECK (nivel_final BETWEEN 1 AND 5),
    CONSTRAINT chk_escala_dolor
        CHECK (escala_dolor BETWEEN 1 AND 10)
);

CREATE TABLE triaje_discriminador (
    id_discriminador INT NOT NULL,
    id_triaje        INT NOT NULL,
    PRIMARY KEY (id_discriminador, id_triaje),
    CONSTRAINT fk_td_discriminador
        FOREIGN KEY (id_discriminador)
        REFERENCES discriminador(id_discriminador),
    CONSTRAINT fk_td_triaje
        FOREIGN KEY (id_triaje)
        REFERENCES triaje(id_triaje)
);

CREATE TABLE turno (
    id_turno        SERIAL PRIMARY KEY,
    id_paciente     INT               NOT NULL,
    id_triaje       INT               NOT NULL UNIQUE,
    codigo_turno    VARCHAR(20)       NOT NULL UNIQUE,
    nivel_prioridad INT               NOT NULL,
    hora_generacion TIMESTAMP         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    hora_llamado    TIMESTAMP,
    estado          estado_turno_enum NOT NULL DEFAULT 'EN_ESPERA',
    CONSTRAINT fk_turno_paciente
        FOREIGN KEY (id_paciente)
        REFERENCES paciente(id_paciente),
    CONSTRAINT fk_turno_triaje
        FOREIGN KEY (id_triaje)
        REFERENCES triaje(id_triaje),
    CONSTRAINT chk_nivel_prioridad
        CHECK (nivel_prioridad BETWEEN 1 AND 5)
);

CREATE TABLE atencion_medica (
    id_atencion     SERIAL PRIMARY KEY,
    id_turno        INT       NOT NULL UNIQUE,
    id_medico       INT       NOT NULL,
    nota_evolucion  TEXT,
    hora_inicio     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    hora_fin        TIMESTAMP,
    CONSTRAINT fk_atencion_turno
        FOREIGN KEY (id_turno)
        REFERENCES turno(id_turno),
    CONSTRAINT fk_atencion_medico
        FOREIGN KEY (id_medico)
        REFERENCES usuario(id_usuario)
);

CREATE TABLE reporte (
    id_reporte         SERIAL PRIMARY KEY,
    id_administrador   INT          NOT NULL,
    tipo_reporte       VARCHAR(100) NOT NULL,
    fecha_generacion   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    parametros_filtro  JSON,
    resultado_resumen  TEXT,
    CONSTRAINT fk_reporte_admin
        FOREIGN KEY (id_administrador)
        REFERENCES usuario(id_usuario)
);

-- =============================================
-- ÍNDICES
-- =============================================

CREATE INDEX idx_paciente_estado ON paciente(estado_flujo);
CREATE INDEX idx_turno_estado ON turno(estado);
CREATE INDEX idx_turno_prioridad ON turno(nivel_prioridad);
CREATE INDEX idx_triaje_paciente ON triaje(id_paciente);

-- =============================================
-- DATOS INICIALES (SEED)
-- =============================================

-- Usuario administrador por defecto
INSERT INTO usuario (nombre_completo, username, contrasena_hash, rol)
VALUES ('Administrador Sistema', 'admin', 'HASH_PENDIENTE', 'ADMINISTRADOR');

-- Discriminadores básicos Manchester
INSERT INTO discriminador (motivo_consulta, descripcion_signo, nivel_urgencia_asociado) VALUES
('Dolor torácico', 'Dolor opresivo en el pecho con irradiación al brazo', 1),
('Dolor torácico', 'Dolor torácico leve sin otros síntomas', 3),
('Dificultad respiratoria', 'Saturación de oxígeno menor al 90%', 1),
('Dificultad respiratoria', 'Dificultad leve para respirar en reposo', 2),
('Trauma', 'Pérdida de consciencia posterior al trauma', 1),
('Trauma', 'Herida con sangrado activo controlable', 3),
('Fiebre', 'Fiebre mayor a 39°C en adulto', 3),
('Fiebre', 'Fiebre con rigidez de nuca', 1),
('Dolor abdominal', 'Abdomen en tabla con defensa', 1),
('Dolor abdominal', 'Dolor abdominal leve sin signos de alarma', 4);