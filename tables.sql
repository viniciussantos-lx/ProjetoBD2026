/* =============================================================================
PROJETO: Monitoramento de Doenças Crônicas vs Determinantes Sociais [cite: 63, 138]
VERSÃO: 1.0 (Março/2026) [cite: 64, 139]
SGBD: PostgreSQL 15+
AUTOR: Gemini (Baseado em Modelagem Lógica e Conceitual)
=============================================================================
*/

-- ==========================================================
-- 1. HIERARQUIA GEOGRÁFICA (SNOWFLAKE) [cite: 143, 158]
-- ==========================================================

CREATE TABLE Dim_Regiao_Geografica (
    id_regiao SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_regiao SMALLINT UNIQUE NOT NULL, -- 1=Norte, 2=Nordeste, etc. [cite: 160]
    ds_regiao VARCHAR(20) NOT NULL,
    sg_regiao CHAR(2) UNIQUE NOT NULL [cite: 160]
);

CREATE TABLE Dim_Estado (
    id_state SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_regiao SMALLINT NOT NULL REFERENCES Dim_Regiao_Geografica(id_regiao) ON UPDATE CASCADE ON DELETE RESTRICT,
    co_uf SMALLINT UNIQUE NOT NULL, -- Código IBGE UF [cite: 162]
    sg_uf CHAR(2) UNIQUE NOT NULL,
    ds_estado VARCHAR(50) NOT NULL,
    co_ibge_uf CHAR(2) UNIQUE NOT NULL [cite: 162]
);

CREATE TABLE Dim_Regiao_Saude (
    id_regiao_saude INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_estado SMALLINT NOT NULL REFERENCES Dim_Estado(id_state) ON UPDATE CASCADE ON DELETE RESTRICT,
    co_regiao_saude INT NOT NULL,
    ds_regiao_saude VARCHAR(150) NOT NULL,
    ds_tipo_regiao VARCHAR(50), -- Macro, Micro [cite: 164]
    CONSTRAINT uk_estado_regiao UNIQUE (id_estado, co_regiao_saude) [cite: 165]
);

CREATE TABLE Dim_Municipio (
    id_municipio INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_estado SMALLINT NOT NULL REFERENCES Dim_Estado(id_state) ON UPDATE CASCADE ON DELETE RESTRICT,
    id_regiao_saude INT REFERENCES Dim_Regiao_Saude(id_regiao_saude) ON UPDATE CASCADE ON DELETE SET NULL,
    co_ibge_7 INT UNIQUE NOT NULL,
    co_ibge_6 INT UNIQUE NOT NULL, -- JOIN IBGE [cite: 168]
    co_mun_res INT UNIQUE NOT NULL, -- JOIN SIH/SUS [cite: 168]
    ds_municipio VARCHAR(100) NOT NULL,
    ds_municipio_upper VARCHAR(100) GENERATED ALWAYS AS (UPPER(ds_municipio)) STORED,
    nu_populacao INT CHECK (nu_populacao > 0),
    nu_area_km2 DECIMAL(12,4) CHECK (nu_area_km2 > 0),
    nu_densidade_demo DECIMAL(10,4) GENERATED ALWAYS AS (nu_populacao / NULLIF(nu_area_km2, 0)) STORED,
    fl_capital BOOLEAN DEFAULT FALSE,
    dt_criacao TIMESTAMP DEFAULT NOW(),
    dt_atualizacao TIMESTAMP DEFAULT NOW() [cite: 168]
);

-- ==========================================================
-- 2. HIERARQUIA CID-10 (SNOWFLAKE) [cite: 143, 150]
-- ==========================================================

CREATE TABLE Dim_CID10_Capitulo (
    id_capitulo SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_capitulo CHAR(4) UNIQUE NOT NULL, -- Numeral Romano [cite: 152]
    ds_capitulo VARCHAR(200) NOT NULL,
    co_cid_inicio CHAR(3) NOT NULL,
    co_cid_fim CHAR(3) NOT NULL,
    fl_infectocontagioso BOOLEAN DEFAULT FALSE, -- Filtro Cap. I [cite: 152]
    dt_criacao TIMESTAMP DEFAULT NOW()
);

CREATE TABLE Dim_CID10_Grupo (
    id_grupo SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_capitulo SMALLINT REFERENCES Dim_CID10_Capitulo(id_capitulo) ON UPDATE CASCADE ON DELETE RESTRICT,
    co_grupo VARCHAR(8) UNIQUE NOT NULL, -- Ex: A00-A09 [cite: 154]
    ds_grupo VARCHAR(300) NOT NULL,
    co_cid_inicio CHAR(3) NOT NULL,
    co_cid_fim CHAR(3) NOT NULL,
    fl_veiculacao_hidrica BOOLEAN DEFAULT FALSE, -- FLAG CENTRAL [cite: 154]
    fl_doenca_cronica BOOLEAN DEFAULT FALSE, -- Suporte Q4 [cite: 154]
    dt_criacao TIMESTAMP DEFAULT NOW()
);

CREATE TABLE Dim_CID10_Categoria (
    id_categoria INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_grupo SMALLINT REFERENCES Dim_CID10_Grupo(id_grupo) ON UPDATE CASCADE ON DELETE RESTRICT,
    co_categoria CHAR(3) UNIQUE NOT NULL, -- Ex: A00 [cite: 156]
    ds_categoria VARCHAR(400) NOT NULL,
    ds_categoria_abreviada VARCHAR(100) NOT NULL,
    fl_notificacao_compulsoria BOOLEAN DEFAULT FALSE,
    dt_criacao TIMESTAMP DEFAULT NOW() [cite: 156]
);

-- ==========================================================
-- 3. DIMENSÕES DE CONTEXTO E APOIO [cite: 169, 177]
-- ==========================================================

CREATE TABLE Dim_Tempo (
    id_tempo INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dt_referencia DATE UNIQUE NOT NULL,
    nu_ano SMALLINT NOT NULL,
    nu_mes SMALLINT CHECK (nu_mes BETWEEN 1 AND 12),
    nu_trimestre SMALLINT CHECK (nu_trimestre BETWEEN 1 AND 4),
    nu_semestre SMALLINT CHECK (nu_semestre BETWEEN 1 AND 2),
    ds_mes VARCHAR(15) NOT NULL,
    fl_ano_bissexto BOOLEAN NOT NULL [cite: 171]
);

CREATE TABLE Dim_Faixa_Etaria (
    id_faixa_etaria SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ds_faixa_etaria VARCHAR(30) UNIQUE NOT NULL,
    nu_idade_min SMALLINT NOT NULL CHECK (nu_idade_min >= 0),
    nu_idade_max SMALLINT NOT NULL,
    ds_grupo_etario VARCHAR(30) NOT NULL -- Criança, Idoso, etc. [cite: 173]
);

CREATE TABLE Dim_Paciente (
    id_paciente INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_faixa_etaria SMALLINT REFERENCES Dim_Faixa_Etaria(id_faixa_etaria),
    nu_idade_anos SMALLINT NOT NULL CHECK (nu_idade_anos >= 0),
    ds_sexo CHAR(1) CHECK (ds_sexo IN ('M', 'F', 'I')), -- LGPD Art. 11 [cite: 176]
    ds_raca_cor VARCHAR(30),
    ds_escolaridade VARCHAR(50),
    dt_criacao TIMESTAMP DEFAULT NOW() [cite: 176]
);

CREATE TABLE Dim_Desfecho_Internacao (
    id_desfecho SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_desfecho SMALLINT UNIQUE NOT NULL, -- 11=Alta, 31=Óbito [cite: 185]
    ds_desfecho VARCHAR(60) NOT NULL,
    fl_obito BOOLEAN DEFAULT FALSE,
    fl_alta BOOLEAN DEFAULT FALSE,
    fl_transferencia BOOLEAN DEFAULT FALSE,
    CONSTRAINT chk_unique_flag CHECK (
        (fl_obito::int + fl_alta::int + fl_transferencia::int) <= 1
    ) [cite: 185, 186]
);

CREATE TABLE Dim_Estabelecimento_Saude (
    id_estabelecimento INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_municipio INT REFERENCES Dim_Municipio(id_municipio),
    co_cnes INT UNIQUE NOT NULL,
    ds_estabelecimento VARCHAR(200) NOT NULL,
    ds_natureza_juridica VARCHAR(80),
    ds_tipo_unidade VARCHAR(80),
    nu_leitos_sus SMALLINT,
    fl_ativo BOOLEAN DEFAULT TRUE [cite: 179]
);

CREATE TABLE Dim_Tipo_Leito (
    id_tipo_leito SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_tipo_leito VARCHAR(10) UNIQUE NOT NULL,
    ds_tipo_leito VARCHAR(80) NOT NULL,
    fl_critico BOOLEAN DEFAULT FALSE [cite: 181]
);

CREATE TABLE Dim_Procedimento (
    id_procedimento INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_procedimento VARCHAR(10) UNIQUE NOT NULL, -- SIGTAP [cite: 183]
    ds_procedimento VARCHAR(300) NOT NULL,
    vl_referencia_sus DECIMAL(10,2) CHECK (vl_referencia_sus >= 0),
    fl_alto_custo BOOLEAN DEFAULT FALSE [cite: 183]
);

CREATE TABLE Dim_Nivel_Saneamento (
    id_nivel_saneamento SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ds_nivel VARCHAR(30) UNIQUE NOT NULL, -- Crítico, Baixo, etc. [cite: 188]
    nu_perc_min DECIMAL(5,2) NOT NULL CHECK (nu_perc_min >= 0),
    nu_perc_max DECIMAL(5,2) CHECK (nu_perc_max <= 100),
    co_cor_hex CHAR(7) [cite: 188]
);

-- ==========================================================
-- 4. TABELAS FATO [cite: 192]
-- ==========================================================

-- Fato de Indicadores Sociais (IBGE/SIDRA/SNIS) [cite: 204]
CREATE TABLE Fato_Indicadores_Sociais (
    id_indicador BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_municipio INT NOT NULL REFERENCES Dim_Municipio(id_municipio),
    id_tempo INT NOT NULL REFERENCES Dim_Tempo(id_tempo),
    id_nivel_saneamento SMALLINT REFERENCES Dim_Nivel_Saneamento(id_nivel_saneamento),
    nu_perc_esgoto_tratado DECIMAL(5,2) CHECK (nu_perc_esgoto_tratado BETWEEN 0 AND 100),
    nu_perc_agua_tratada DECIMAL(5,2) CHECK (nu_perc_agua_tratada BETWEEN 0 AND 100),
    vl_renda_media_per_capita DECIMAL(10,2),
    nu_idhm DECIMAL(5,4) CHECK (nu_idhm BETWEEN 0 AND 1),
    nu_populacao INT CHECK (nu_populacao > 0),
    ds_ano_referencia SMALLINT CHECK (ds_ano_referencia BETWEEN 2000 AND 2030),
    dt_carga_etl TIMESTAMP DEFAULT NOW(),
    CONSTRAINT uk_mun_ano UNIQUE (id_municipio, id_tempo) [cite: 204, 205]
);

-- Fato de Internações (SIH/SUS) [cite: 197]
CREATE TABLE Fato_Internacoes (
    id_internacao BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
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
    fl_obito BOOLEAN DEFAULT FALSE, -- FLAG ANALÍTICA [cite: 197]
    fl_internacao_eletiva BOOLEAN DEFAULT FALSE,
    fl_gestante BOOLEAN DEFAULT FALSE,
    co_aih VARCHAR(13), -- Rastreabilidade [cite: 197]
    ds_competencia CHAR(6) CHECK (ds_competencia ~ '^\d{6}$'),
    dt_carga_etl TIMESTAMP DEFAULT NOW() [cite: 197, 199]
);

CREATE TABLE Dim_Investimento_Infraestrutura (
    id_investimento INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_municipio INT NOT NULL REFERENCES Dim_Municipio(id_municipio),
    id_tempo INT NOT NULL REFERENCES Dim_Tempo(id_tempo),
    ds_tipo_investimento VARCHAR(80) NOT NULL, -- Esgoto, Água, etc. [cite: 190]
    vl_investimento DECIMAL(15,2) NOT NULL CHECK (vl_investimento >= 0),
    CONSTRAINT uk_mun_tempo_tipo UNIQUE (id_municipio, id_tempo, ds_tipo_investimento) [cite: 191]
);

-- ==========================================================
-- 5. ÍNDICES, VIEWS E TRIGGERS [cite: 211, 223]
-- ==========================================================

-- Índices otimizados para as queries Q1, Q2, Q3 [cite: 201]
CREATE INDEX idx_fato_int_mun_cid_tempo 
ON Fato_Internacoes (id_municipio, id_cid10_categoria, id_tempo_internacao) 
INCLUDE (vl_total_internacao, nu_dias_permanencia, fl_obito);

CREATE INDEX idx_fato_soc_esgoto ON Fato_Indicadores_Sociais (nu_perc_esgoto_tratado);

-- Sincronização automática do flag óbito [cite: 199, 223]
CREATE OR REPLACE FUNCTION fn_sync_fl_obito() RETURNS TRIGGER AS $$
BEGIN
    SELECT fl_obito INTO NEW.fl_obito 
    FROM Dim_Desfecho_Internacao WHERE id_desfecho = NEW.id_desfecho;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_fato_int_sync_obito
BEFORE INSERT OR UPDATE ON Fato_Internacoes
FOR EACH ROW EXECUTE FUNCTION fn_sync_fl_obito();

-- View Materializada para Doenças Hídricas [cite: 212, 213]
CREATE MATERIALIZED VIEW vw_internacoes_hidricas AS
SELECT 
    f.id_internacao, f.id_municipio, f.vl_total_internacao, 
    f.nu_dias_permanencia, f.fl_obito, g.ds_grupo, g.co_grupo
FROM Fato_Internacoes f
JOIN Dim_CID10_Categoria c ON f.id_cid10_categoria = c.id_categoria
JOIN Dim_CID10_Grupo g ON c.id_grupo = g.id_grupo
WHERE g.fl_veiculacao_hidrica = TRUE;

-- Comentários de Documentação [cite: 221]
COMMENT ON TABLE Fato_Internacoes IS 'Granularidade: 1 linha = 1 internação hospitalar (AIH) do SIH/SUS';
COMMENT ON COLUMN Fato_Indicadores_Sociais.nu_perc_esgoto_tratado IS 'Indicador central para classificação do Nível de Saneamento';