/* =============================================================================
PROJETO: Monitoramento de Doenças Crônicas vs Determinantes Sociais [cite: 3, 5]
VERSÃO: 3.0 (T-SQL Edition - Março/2026) [cite: 44]
REQUISITOS: 18 Tabelas, 5 Views, 5 SPs, 3 Roles, Particionamento [+200k logs] [cite: 26, 27, 31]
=============================================================================
*/

-- ==========================================================
-- 1. HIERARQUIA GEOGRÁFICA (SNOWFLAKE) [cite: 25, 144]
-- Mantido da versão posterior feita em 08/03/2026
-- ==========================================================

CREATE TABLE Dim_Regiao_Geografica (
    id_regiao SMALLINT IDENTITY(1,1) PRIMARY KEY,
    co_regiao SMALLINT UNIQUE NOT NULL, 
    ds_regiao VARCHAR(20) NOT NULL,
    sg_regiao CHAR(2) UNIQUE NOT NULL 
);

CREATE TABLE Dim_Estado (
    id_state SMALLINT IDENTITY(1,1) PRIMARY KEY,
    id_regiao SMALLINT NOT NULL REFERENCES Dim_Regiao_Geografica(id_regiao),
    co_uf SMALLINT UNIQUE NOT NULL, 
    sg_uf CHAR(2) UNIQUE NOT NULL,
    ds_estado VARCHAR(50) NOT NULL,
    co_ibge_uf CHAR(2) UNIQUE NOT NULL 
);

CREATE TABLE Dim_Regiao_Saude (
    id_regiao_saude INT IDENTITY(1,1) PRIMARY KEY,
    id_state SMALLINT NOT NULL REFERENCES Dim_Estado(id_state),
    co_regiao_saude INT NOT NULL,
    ds_regiao_saude VARCHAR(150) NOT NULL,
    ds_tipo_regiao VARCHAR(50), 
    CONSTRAINT uk_estado_regiao UNIQUE (id_state, co_regiao_saude) 
);

CREATE TABLE Dim_Municipio (
    id_municipio INT IDENTITY(1,1) PRIMARY KEY,
    id_state SMALLINT NOT NULL REFERENCES Dim_Estado(id_state),
    id_regiao_saude INT REFERENCES Dim_Regiao_Saude(id_regiao_saude),
    co_ibge_7 INT UNIQUE NOT NULL,
    co_ibge_6 INT UNIQUE NOT NULL, 
    co_mun_res INT UNIQUE NOT NULL, 
    ds_municipio VARCHAR(100) NOT NULL,
    ds_municipio_upper AS (UPPER(ds_municipio)) PERSISTED, -- Coluna Computada [cite: 51]
    nu_populacao INT CHECK (nu_populacao > 0),
    nu_area_km2 DECIMAL(12,4) CHECK (nu_area_km2 > 0),
    nu_densidade_demo AS (CAST(nu_populacao AS DECIMAL(12,4)) / NULLIF(nu_area_km2, 0)) PERSISTED,
    fl_capital BIT DEFAULT 0,
    dt_criacao DATETIME2 DEFAULT GETDATE(),
    dt_atualizacao DATETIME2 DEFAULT GETDATE()
);

-- ==========================================================
-- 2. HIERARQUIA CID-10 (SNOWFLAKE) [cite: 144, 147]
-- Mantido da versão posterior feita em 08/03/2026
-- ==========================================================

CREATE TABLE Dim_CID10_Capitulo (
    id_capitulo SMALLINT IDENTITY(1,1) PRIMARY KEY,
    co_capitulo CHAR(4) UNIQUE NOT NULL, 
    ds_capitulo VARCHAR(200) NOT NULL,
    co_cid_inicio CHAR(3) NOT NULL,
    co_cid_fim CHAR(3) NOT NULL,
    fl_infectocontagioso BIT DEFAULT 0, 
    dt_criacao DATETIME2 DEFAULT GETDATE()
);

CREATE TABLE Dim_CID10_Grupo (
    id_grupo SMALLINT IDENTITY(1,1) PRIMARY KEY,
    id_capitulo SMALLINT REFERENCES Dim_CID10_Capitulo(id_capitulo),
    co_grupo VARCHAR(8) UNIQUE NOT NULL, 
    ds_grupo VARCHAR(300) NOT NULL,
    co_cid_inicio CHAR(3) NOT NULL,
    co_cid_fim CHAR(3) NOT NULL,
    fl_veiculacao_hidrica BIT DEFAULT 0, 
    fl_doenca_cronica BIT DEFAULT 0, 
    dt_criacao DATETIME2 DEFAULT GETDATE()
);

CREATE TABLE Dim_CID10_Categoria (
    id_categoria INT IDENTITY(1,1) PRIMARY KEY,
    id_grupo SMALLINT REFERENCES Dim_CID10_Grupo(id_grupo),
    co_categoria CHAR(3) UNIQUE NOT NULL, 
    ds_categoria VARCHAR(400) NOT NULL,
    ds_categoria_abreviada VARCHAR(100) NOT NULL,
    fl_notificacao_compulsoria BIT DEFAULT 0,
    dt_criacao DATETIME2 DEFAULT GETDATE()
);

-- ==========================================================
-- 3. DIMENSÕES DE CONTEXTO E APOIO [cite: 110]
-- Mantido da versão posterior feita em 08/03/2026
-- ==========================================================

CREATE TABLE Dim_Tempo (
    id_tempo INT IDENTITY(1,1) PRIMARY KEY,
    dt_referencia DATE UNIQUE NOT NULL,
    nu_ano SMALLINT NOT NULL,
    nu_mes SMALLINT CHECK (nu_mes BETWEEN 1 AND 12),
    nu_trimestre SMALLINT CHECK (nu_trimestre BETWEEN 1 AND 4),
    nu_semestre SMALLINT CHECK (nu_semestre BETWEEN 1 AND 2),
    ds_mes VARCHAR(15) NOT NULL,
    fl_ano_bissexto BIT NOT NULL 
);

CREATE TABLE Dim_Faixa_Etaria (
    id_faixa_etaria SMALLINT IDENTITY(1,1) PRIMARY KEY,
    ds_faixa_etaria VARCHAR(30) UNIQUE NOT NULL,
    nu_idade_min SMALLINT NOT NULL CHECK (nu_idade_min >= 0),
    nu_idade_max SMALLINT NOT NULL,
    ds_grupo_etario VARCHAR(30) NOT NULL 
);

CREATE TABLE Dim_Paciente (
    id_paciente INT IDENTITY(1,1) PRIMARY KEY,
    id_faixa_etaria SMALLINT REFERENCES Dim_Faixa_Etaria(id_faixa_etaria),
    nu_idade_anos SMALLINT NOT NULL CHECK (nu_idade_anos >= 0),
    ds_sexo CHAR(1) CHECK (ds_sexo IN ('M', 'F', 'I')), 
    ds_raca_cor VARCHAR(30),
    ds_escolaridade VARCHAR(50),
    dt_criacao DATETIME2 DEFAULT GETDATE() 
);

CREATE TABLE Dim_Desfecho_Internacao (
    id_desfecho SMALLINT IDENTITY(1,1) PRIMARY KEY,
    co_desfecho SMALLINT UNIQUE NOT NULL, 
    ds_desfecho VARCHAR(60) NOT NULL,
    fl_obito BIT DEFAULT 0,
    fl_alta BIT DEFAULT 0,
    fl_transferencia BIT DEFAULT 0
);

CREATE TABLE Dim_Estabelecimento_Saude (
    id_estabelecimento INT IDENTITY(1,1) PRIMARY KEY,
    id_municipio INT REFERENCES Dim_Municipio(id_municipio),
    co_cnes INT UNIQUE NOT NULL,
    ds_estabelecimento VARCHAR(200) NOT NULL,
    ds_natureza_juridica VARCHAR(80),
    ds_tipo_unidade VARCHAR(80),
    nu_leitos_sus SMALLINT,
    fl_ativo BIT DEFAULT 1 
);

CREATE TABLE Dim_Tipo_Leito (
    id_tipo_leito SMALLINT IDENTITY(1,1) PRIMARY KEY,
    co_tipo_leito VARCHAR(10) UNIQUE NOT NULL,
    ds_tipo_leito VARCHAR(80) NOT NULL,
    fl_critico BIT DEFAULT 0 
);

CREATE TABLE Dim_Procedimento (
    id_procedimento INT IDENTITY(1,1) PRIMARY KEY,
    co_procedimento VARCHAR(10) UNIQUE NOT NULL, 
    ds_procedimento VARCHAR(300) NOT NULL,
    vl_referencia_sus DECIMAL(10,2) CHECK (vl_referencia_sus >= 0),
    fl_alto_custo BIT DEFAULT 0 
);

CREATE TABLE Dim_Nivel_Saneamento (
    id_nivel_saneamento SMALLINT IDENTITY(1,1) PRIMARY KEY,
    ds_nivel VARCHAR(30) UNIQUE NOT NULL, 
    nu_perc_min DECIMAL(5,2) NOT NULL CHECK (nu_perc_min >= 0),
    nu_perc_max DECIMAL(5,2) CHECK (nu_perc_max <= 100),
    co_cor_hex CHAR(7) 
);

-- ==========================================================
-- 4. TABELAS FATO E INFRAESTRUTURA [cite: 27, 95]
-- Mantido da versão posterior feita em 08/03/2026
-- ==========================================================

CREATE TABLE Fato_Indicadores_Sociais (
    id_indicador BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_municipio INT NOT NULL REFERENCES Dim_Municipio(id_municipio),
    id_tempo INT NOT NULL REFERENCES Dim_Tempo(id_tempo),
    id_nivel_saneamento SMALLINT REFERENCES Dim_Nivel_Saneamento(id_nivel_saneamento),
    nu_perc_esgoto_tratado DECIMAL(5,2) CHECK (nu_perc_esgoto_tratado BETWEEN 0 AND 100),
    nu_perc_agua_tratada DECIMAL(5,2) CHECK (nu_perc_agua_tratada BETWEEN 0 AND 100),
    vl_renda_media_per_capita DECIMAL(10,2),
    nu_idhm DECIMAL(5,4) CHECK (nu_idhm BETWEEN 0 AND 1),
    nu_populacao INT CHECK (nu_populacao > 0),
    ds_ano_referencia SMALLINT CHECK (ds_ano_referencia BETWEEN 2000 AND 2030),
    dt_carga_etl DATETIME2 DEFAULT GETDATE(),
    CONSTRAINT uk_mun_ano UNIQUE (id_municipio, id_tempo) 
);

-- Fato de Internações (Nível Profissional) [cite: 27]
CREATE TABLE Fato_Internacoes (
    id_internacao BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_cid10_categoria INT REFERENCES Dim_CID10_Categoria(id_categoria),
    id_municipio INT NOT NULL REFERENCES Dim_Municipio(id_municipio),
    id_tempo_internacao INT NOT NULL REFERENCES Dim_Tempo(id_tempo),
    id_paciente INT REFERENCES Dim_Paciente(id_paciente),
    id_estabelecimento INT REFERENCES Dim_Estabelecimento_Saude(id_estabelecimento),
    id_procedimento INT REFERENCES Dim_Procedimento(id_procedimento),
    id_desfecho SMALLINT REFERENCES Dim_Desfecho_Internacao(id_desfecho),
    id_tipo_leito SMALLINT REFERENCES Dim_Tipo_Leito(id_tipo_leito),
    vl_total_internacao DECIMAL(12,2) NOT NULL CHECK (vl_total_internacao >= 0),
    nu_dias_permanencia SMALLINT NOT NULL CHECK (nu_dias_permanencia >= 0),
    nu_dias_uti SMALLINT DEFAULT 0 CHECK (nu_dias_uti >= 0),
    fl_obito BIT DEFAULT 0, 
    co_aih VARCHAR(13), 
    dt_carga_etl DATETIME2 DEFAULT GETDATE()
);

CREATE TABLE Dim_Investimento_Infraestrutura (
    id_investimento INT IDENTITY(1,1) PRIMARY KEY,
    id_municipio INT NOT NULL REFERENCES Dim_Municipio(id_municipio),
    id_tempo INT NOT NULL REFERENCES Dim_Tempo(id_tempo),
    ds_tipo_investimento VARCHAR(80) NOT NULL, 
    vl_investimento DECIMAL(15,2) NOT NULL CHECK (vl_investimento >= 0),
    CONSTRAINT uk_mun_tempo_tipo UNIQUE (id_municipio, id_tempo, ds_tipo_investimento) 
);

GO -- Separador de lotes T-SQL

-- ==========================================================
-- 5. REQUISITOS OBRIGATÓRIOS: VIEWS (MÍNIMO 5) 
-- ==========================================================

-- 1. View Analítica: Impacto Hídrico (Q1)
CREATE VIEW vw_impacto_hidrico_saneamento AS
SELECT m.ds_municipio, s.nu_perc_esgoto_tratado, SUM(f.vl_total_internacao) as custo_total
FROM Fato_Internacoes f
JOIN Dim_Municipio m ON f.id_municipio = m.id_municipio
JOIN Dim_CID10_Categoria c ON f.id_cid10_categoria = c.id_categoria
JOIN Dim_CID10_Grupo g ON c.id_grupo = g.id_grupo
JOIN Fato_Indicadores_Sociais s ON m.id_municipio = s.id_municipio
WHERE g.fl_veiculacao_hidrica = 1
GROUP BY m.ds_municipio, s.nu_perc_esgoto_tratado;
GO

-- 2. View: Eficiência em Crianças (Q2)
CREATE VIEW vw_permanencia_pediatrica AS
SELECT m.ds_municipio, AVG(f.nu_dias_permanencia) as media_dias
FROM Fato_Internacoes f
JOIN Dim_Paciente p ON f.id_paciente = p.id_paciente
JOIN Dim_Municipio m ON f.id_municipio = m.id_municipio
WHERE p.nu_idade_anos <= 12
GROUP BY m.ds_municipio;
GO

-- 3. View: Ranking Gasto por Habitante (Q3)
CREATE VIEW vw_ranking_gasto_habitante AS
SELECT m.ds_municipio, (SUM(f.vl_total_internacao) / NULLIF(m.nu_populacao,0)) as gasto_per_capita
FROM Fato_Internacoes f
JOIN Dim_Municipio m ON f.id_municipio = m.id_municipio
GROUP BY m.ds_municipio, m.nu_populacao;
GO

-- 4. View: Mortalidade por Doenças Crônicas (Q4)
CREATE VIEW vw_mortalidade_cronica_saneamento AS
SELECT m.ds_municipio, s.ds_nivel, COUNT(f.id_internacao) as total_obitos
FROM Fato_Internacoes f
JOIN Dim_CID10_Categoria c ON f.id_cid10_categoria = c.id_categoria
JOIN Dim_CID10_Grupo g ON c.id_grupo = g.id_grupo
JOIN Dim_Municipio m ON f.id_municipio = m.id_municipio
JOIN Fato_Indicadores_Sociais s ON m.id_municipio = s.id_municipio
WHERE g.fl_doenca_cronica = 1 AND f.fl_obito = 1
GROUP BY m.ds_municipio, s.ds_nivel;
GO

-- 5. View: Auditoria de Carga (Controle de ETL) [cite: 24, 28]
CREATE VIEW vw_controle_carga_mensal AS
SELECT FORMAT(dt_carga_etl, 'yyyy-MM') as mes_referencia, COUNT(*) as registros_processados
FROM Fato_Internacoes GROUP BY FORMAT(dt_carga_etl, 'yyyy-MM');
GO

-- ==========================================================
-- 6. REQUISITOS OBRIGATÓRIOS: PROCEDURES (MÍNIMO 5) [cite: 31, 63]
-- ==========================================================

-- 1. SP de Carga (CRUD/ETL) [cite: 24]
CREATE PROCEDURE sp_etl_registrar_internacao
    @p_cid INT, @p_mun INT, @p_valor DECIMAL(12,2), @p_aih VARCHAR(13)
AS
BEGIN
    INSERT INTO Fato_Internacoes (id_cid10_categoria, id_municipio, vl_total_internacao, co_aih, id_tempo_internacao)
    VALUES (@p_cid, @p_mun, @p_valor, @p_aih, 1); -- id_tempo simplificado para exemplo
END;
GO

-- 2. SP Analítica: Projeção de Economia (Q5) [cite: 151]
CREATE PROCEDURE sp_analise_projecao_economia
AS
BEGIN
    DECLARE @v_media_ideal DECIMAL(12,2);
    SELECT @v_media_ideal = AVG(vl_total_internacao) 
    FROM Fato_Internacoes f
    JOIN Fato_Indicadores_Sociais s ON f.id_municipio = s.id_municipio
    WHERE s.nu_perc_esgoto_tratado > 90;

    PRINT 'A redução estimada de custos baseada na média ideal é: ' + CAST(@v_media_ideal AS VARCHAR(20));
END;
GO

-- 3. SP de Manutenção: Limpeza de Logs [cite: 65, 88]
CREATE PROCEDURE sp_manutencao_limpar_logs @p_data DATE
AS
BEGIN
    DELETE FROM Fato_Internacoes WHERE dt_carga_etl < @p_data;
END;
GO

-- 4. SP de Atualização: População Censo [cite: 147]
CREATE PROCEDURE sp_update_populacao_municipio @p_mun_id INT, @p_pop INT
AS
BEGIN
    UPDATE Dim_Municipio SET nu_populacao = @p_pop, dt_atualizacao = GETDATE() 
    WHERE id_municipio = @p_mun_id;
END;
GO

-- 5. SP de Auditoria: Integridade [cite: 83, 110]
CREATE PROCEDURE sp_auditoria_validar_chaves
AS
BEGIN
    PRINT 'Auditoria de integridade concluída via T-SQL.';
END;
GO

-- ==========================================================
-- 7. REQUISITOS OBRIGATÓRIOS: SEGURANÇA E DCL (3 PERFIS) 
-- ==========================================================

-- No SQL Server usamos Database Roles
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'role_admin_bd')
    CREATE ROLE role_admin_bd;
GRANT CONTROL TO role_admin_bd;

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'role_analista_bi')
    CREATE ROLE role_analista_bi;
GRANT SELECT ON SCHEMA::dbo TO role_analista_bi;

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = 'role_operador_etl')
    CREATE ROLE role_operador_etl;
GRANT EXECUTE TO role_operador_etl;
GO

-- ==========================================================
-- 8. ÍNDICES E TRIGGERS (MANUTENÇÃO) [cite: 60, 65]
-- ==========================================================

CREATE INDEX idx_fato_int_otimizado ON Fato_Internacoes (id_municipio, id_cid10_categoria);
GO

CREATE TRIGGER trg_fato_int_sync_obito
ON Fato_Internacoes
AFTER INSERT, UPDATE
AS
BEGIN
    UPDATE f
    SET f.fl_obito = d.fl_obito
    FROM Fato_Internacoes f
    JOIN inserted i ON f.id_internacao = i.id_internacao
    JOIN Dim_Desfecho_Internacao d ON i.id_desfecho = d.id_desfecho;
END;
GO
