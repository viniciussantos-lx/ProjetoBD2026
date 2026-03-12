/* =============================================================================
PROJETO: Monitoramento de Doenças Crônicas vs Determinantes Sociais
REQUISITOS: 18 Tabelas, 5 Views, 5 SPs, 3 Roles, Performance [+200k logs]
=============================================================================
*/

-- ==========================================================
-- 1. HIERARQUIA GEOGRÁFICA (SNOWFLAKE)
-- Mantido da versão posterior feito (08/03/2026)
-- ==========================================================

CREATE TABLE Dim_Regiao_Geografica (
    id_regiao SMALLINT IDENTITY(1,1) PRIMARY KEY,
    co_regiao SMALLINT UNIQUE NOT NULL, 
    ds_regiao VARCHAR(20) NOT NULL,
    sg_regiao CHAR(2) UNIQUE NOT NULL 
);

CREATE TABLE Dim_Estado (
    id_estado SMALLINT IDENTITY(1,1) PRIMARY KEY,
    id_regiao SMALLINT NOT NULL REFERENCES Dim_Regiao_Geografica(id_regiao),
    co_uf SMALLINT UNIQUE NOT NULL, 
    sg_uf CHAR(2) UNIQUE NOT NULL,
    ds_estado VARCHAR(50) NOT NULL,
    co_ibge_uf CHAR(2) UNIQUE NOT NULL 
);

CREATE TABLE Dim_Regiao_Saude (
    id_regiao_saude INT IDENTITY(1,1) PRIMARY KEY,
    id_estado SMALLINT NOT NULL REFERENCES Dim_Estado(id_estado),
    co_regiao_saude INT NOT NULL,
    ds_regiao_saude VARCHAR(150) NOT NULL,
    ds_tipo_regiao VARCHAR(50), 
    CONSTRAINT uk_estado_regiao UNIQUE (id_estado, co_regiao_saude) 
);

CREATE TABLE Dim_Municipio (
    id_municipio INT IDENTITY(1,1) PRIMARY KEY,
    id_estado SMALLINT NOT NULL REFERENCES Dim_Estado(id_estado),
    id_regiao_saude INT REFERENCES Dim_Regiao_Saude(id_regiao_saude),
    co_ibge_7 INT UNIQUE NOT NULL,
    co_ibge_6 INT UNIQUE NOT NULL, 
    co_mun_res INT UNIQUE NOT NULL, 
    ds_municipio VARCHAR(100) NOT NULL,
    ds_municipio_upper AS (UPPER(ds_municipio)) PERSISTED, -- T-SQL STORED
    nu_populacao INT CHECK (nu_populacao > 0),
    nu_area_km2 DECIMAL(12,4) CHECK (nu_area_km2 > 0),
    nu_densidade_demo AS (CAST(nu_populacao AS DECIMAL(12,4)) / NULLIF(nu_area_km2, 0)) PERSISTED,
    fl_capital BIT DEFAULT 0, -- T-SQL BIT (0/1)
    dt_criacao DATETIME2 DEFAULT GETDATE(),
    dt_atualizacao DATETIME2 DEFAULT GETDATE()
);

-- ==========================================================
-- 2. HIERARQUIA CID-10 (SNOWFLAKE)
-- Mantido da versão posterior feito (08/03/2026)
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
-- 3. DIMENSÕES DE CONTEXTO E APOIO
-- Mantido da versão posterior feito (08/03/2026)
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
    fl_transferencia BIT DEFAULT 0,
    CONSTRAINT chk_unique_flag CHECK (
        (CAST(fl_obito AS INT) + CAST(fl_alta AS INT) + CAST(fl_transferencia AS INT)) <= 1
    ) 
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
-- 4. TABELAS FATO E INFRAESTRUTURA
-- Mantido da versão posterior feito (08/03/2026)
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

CREATE TABLE Fato_Internacoes (
    id_internacao BIGINT IDENTITY(1,1) PRIMARY KEY,
    id_cid10_categoria INT REFERENCES Dim_CID10_Categoria(id_categoria),
    id_municipio INT NOT NULL REFERENCES Dim_Municipio(id_municipio),
    id_tempo_internacao INT NOT NULL REFERENCES Dim_Tempo(id_tempo),
    id_tempo_alta INT REFERENCES Dim_Tempo(id_tempo),
    id_paciente INT REFERENCES Dim_Paciente(id_paciente),
    id_estabelecimento INT REFERENCES Dim_Estabelecimento_Saude(id_estabelecimento),
    id_procedimento INT REFERENCES Dim_Procedimento(id_procedimento),
    id_desfecho SMALLINT REFERENCES Dim_Desfecho_Internacao(id_desfecho),
    id_tipo_leito SMALLINT REFERENCES Dim_Tipo_Leito(id_tipo_leito),
    vl_total_internacao DECIMAL(12,2) NOT NULL CHECK (vl_total_internacao >= 0),
    nu_dias_permanencia SMALLINT NOT NULL CHECK (nu_dias_permanencia >= 0),
    nu_dias_uti SMALLINT DEFAULT 0 CHECK (nu_dias_uti >= 0),
    fl_obito BIT DEFAULT 0, 
    fl_internacao_eletiva BIT DEFAULT 0,
    fl_gestante BIT DEFAULT 0,
    co_aih VARCHAR(13), 
    ds_competencia CHAR(6),
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
GO

-- ==========================================================
-- 5. ÍNDICES E VIEWS (REQUISITO: MÍNIMO 5)
-- ==========================================================

-- CORREÇÃO DO ERRO DA IMAGE_F3A7D4: Adicionado JOIN com Dim_Nivel_Saneamento
CREATE VIEW vw_mortalidade_cronica_saneamento AS
SELECT 
    m.ds_municipio, 
    ns.ds_nivel, -- Agora buscando da tabela correta
    COUNT(f.id_internacao) AS total_obitos
FROM Fato_Internacoes f
JOIN Dim_CID10_Categoria c ON f.id_cid10_categoria = c.id_categoria
JOIN Dim_CID10_Grupo g ON c.id_grupo = g.id_grupo
JOIN Dim_Municipio m ON f.id_municipio = m.id_municipio
JOIN Fato_Indicadores_Sociais s ON m.id_municipio = s.id_municipio
JOIN Dim_Nivel_Saneamento ns ON s.id_nivel_saneamento = ns.id_nivel_saneamento -- JOIN FALTANTE
WHERE g.fl_doenca_cronica = 1 AND f.fl_obito = 1
GROUP BY m.ds_municipio, ns.ds_nivel;
GO

CREATE VIEW vw_controle_carga_mensal AS
SELECT FORMAT(dt_carga_etl, 'yyyy-MM') AS mes_referencia, COUNT(*) AS registros_processados
FROM Fato_Internacoes GROUP BY FORMAT(dt_carga_etl, 'yyyy-MM');
GO

-- Adicione aqui as outras 3 views seguindo o mesmo padrão...

-- ==========================================================
-- 6. STORED PROCEDURES (REQUISITO: MÍNIMO 5)
-- ==========================================================

-- 1. SP de Carga (CRUD/ETL)
CREATE PROCEDURE sp_etl_registrar_internacao
    @p_cid INT, @p_mun INT, @p_valor DECIMAL(12,2), @p_aih VARCHAR(13)
AS
BEGIN
    INSERT INTO Fato_Internacoes (id_cid10_categoria, id_municipio, vl_total_internacao, co_aih, id_tempo_internacao)
    VALUES (@p_cid, @p_mun, @p_valor, @p_aih, 1);
END;
GO

-- 2. SP Analítica: Projeção de Economia (Q5)
CREATE PROCEDURE sp_analise_projecao_economia
AS
BEGIN
    DECLARE @v_media_ideal DECIMAL(12,2);
    SELECT @v_media_ideal = AVG(vl_total_internacao) FROM Fato_Internacoes f
    JOIN Fato_Indicadores_Sociais s ON f.id_municipio = s.id_municipio
    WHERE s.nu_perc_esgoto_tratado > 90;

    PRINT 'A economia projetada é baseada na média ideal de: ' + CAST(@v_media_ideal AS VARCHAR(20));
END;
GO

-- Adicione as outras 3 procedures necessárias...

-- ==========================================================
-- 7. SEGURANÇA (DCL - 3 ROLES)
-- ==========================================================
CREATE ROLE role_admin_bd;
CREATE ROLE role_analista_bi;
CREATE ROLE role_operador_etl;
GO

-- ==========================================================
-- 8. TRIGGERS (MANUTENÇÃO)
-- ==========================================================
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
