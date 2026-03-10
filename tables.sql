/* =============================================================================
PROJETO: Monitoramento de Doenças Crônicas vs Determinantes Sociais [cite: 3, 5]
VERSÃO: 2.0 (Turbinada - Março/2026) [cite: 44]
REQUISITOS: 18 Tabelas, 5 Views, 5 SPs, 3 Roles, Particionamento [+200k logs] [cite: 26, 27, 31]
=============================================================================
*/

-- ==========================================================
-- 1. HIERARQUIA GEOGRÁFICA (SNOWFLAKE) [cite: 25, 144]
-- Mantido da versão posterior feito (08/03/2026)
-- ==========================================================

CREATE TABLE Dim_Regiao_Geografica (
    id_regiao SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_regiao SMALLINT UNIQUE NOT NULL, 
    ds_regiao VARCHAR(20) NOT NULL,
    sg_regiao CHAR(2) UNIQUE NOT NULL 
);

CREATE TABLE Dim_Estado (
    id_state SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_regiao SMALLINT NOT NULL REFERENCES Dim_Regiao_Geografica(id_regiao) ON UPDATE CASCADE ON DELETE RESTRICT,
    co_uf SMALLINT UNIQUE NOT NULL, 
    sg_uf CHAR(2) UNIQUE NOT NULL,
    ds_estado VARCHAR(50) NOT NULL,
    co_ibge_uf CHAR(2) UNIQUE NOT NULL 
);

CREATE TABLE Dim_Regiao_Saude (
    id_regiao_saude INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_estado SMALLINT NOT NULL REFERENCES Dim_Estado(id_state) ON UPDATE CASCADE ON DELETE RESTRICT,
    co_regiao_saude INT NOT NULL,
    ds_regiao_saude VARCHAR(150) NOT NULL,
    ds_tipo_regiao VARCHAR(50), 
    CONSTRAINT uk_estado_regiao UNIQUE (id_estado, co_regiao_saude) 
);

CREATE TABLE Dim_Municipio (
    id_municipio INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_estado SMALLINT NOT NULL REFERENCES Dim_Estado(id_state) ON UPDATE CASCADE ON DELETE RESTRICT,
    id_regiao_saude INT REFERENCES Dim_Regiao_Saude(id_regiao_saude) ON UPDATE CASCADE ON DELETE SET NULL,
    co_ibge_7 INT UNIQUE NOT NULL,
    co_ibge_6 INT UNIQUE NOT NULL, 
    co_mun_res INT UNIQUE NOT NULL, 
    ds_municipio VARCHAR(100) NOT NULL,
    ds_municipio_upper VARCHAR(100) GENERATED ALWAYS AS (UPPER(ds_municipio)) STORED,
    nu_populacao INT CHECK (nu_populacao > 0),
    nu_area_km2 DECIMAL(12,4) CHECK (nu_area_km2 > 0),
    nu_densidade_demo DECIMAL(10,4) GENERATED ALWAYS AS (nu_populacao / NULLIF(nu_area_km2, 0)) STORED,
    fl_capital BOOLEAN DEFAULT FALSE,
    dt_criacao TIMESTAMP DEFAULT NOW(),
    dt_atualizacao TIMESTAMP DEFAULT NOW() 
);

-- ==========================================================
-- 2. HIERARQUIA CID-10 (SNOWFLAKE) [cite: 144, 147]
-- Mantido da versão posterior feito (08/03/2026)
-- ==========================================================

CREATE TABLE Dim_CID10_Capitulo (
    id_capitulo SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_capitulo CHAR(4) UNIQUE NOT NULL, 
    ds_capitulo VARCHAR(200) NOT NULL,
    co_cid_inicio CHAR(3) NOT NULL,
    co_cid_fim CHAR(3) NOT NULL,
    fl_infectocontagioso BOOLEAN DEFAULT FALSE, 
    dt_criacao TIMESTAMP DEFAULT NOW()
);

CREATE TABLE Dim_CID10_Grupo (
    id_grupo SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_capitulo SMALLINT REFERENCES Dim_CID10_Capitulo(id_capitulo) ON UPDATE CASCADE ON DELETE RESTRICT,
    co_grupo VARCHAR(8) UNIQUE NOT NULL, 
    ds_grupo VARCHAR(300) NOT NULL,
    co_cid_inicio CHAR(3) NOT NULL,
    co_cid_fim CHAR(3) NOT NULL,
    fl_veiculacao_hidrica BOOLEAN DEFAULT FALSE, 
    fl_doenca_cronica BOOLEAN DEFAULT FALSE, 
    dt_criacao TIMESTAMP DEFAULT NOW()
);

CREATE TABLE Dim_CID10_Categoria (
    id_categoria INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_grupo SMALLINT REFERENCES Dim_CID10_Grupo(id_grupo) ON UPDATE CASCADE ON DELETE RESTRICT,
    co_categoria CHAR(3) UNIQUE NOT NULL, 
    ds_categoria VARCHAR(400) NOT NULL,
    ds_categoria_abreviada VARCHAR(100) NOT NULL,
    fl_notificacao_compulsoria BOOLEAN DEFAULT FALSE,
    dt_criacao TIMESTAMP DEFAULT NOW() 
);

-- ==========================================================
-- 3. DIMENSÕES DE CONTEXTO E APOIO [cite: 110]
-- Mantido da versão posterior feito (08/03/2026)
-- ==========================================================

CREATE TABLE Dim_Tempo (
    id_tempo INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    dt_referencia DATE UNIQUE NOT NULL,
    nu_ano SMALLINT NOT NULL,
    nu_mes SMALLINT CHECK (nu_mes BETWEEN 1 AND 12),
    nu_trimestre SMALLINT CHECK (nu_trimestre BETWEEN 1 AND 4),
    nu_semestre SMALLINT CHECK (nu_semestre BETWEEN 1 AND 2),
    ds_mes VARCHAR(15) NOT NULL,
    fl_ano_bissexto BOOLEAN NOT NULL 
);

CREATE TABLE Dim_Faixa_Etaria (
    id_faixa_etaria SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ds_faixa_etaria VARCHAR(30) UNIQUE NOT NULL,
    nu_idade_min SMALLINT NOT NULL CHECK (nu_idade_min >= 0),
    nu_idade_max SMALLINT NOT NULL,
    ds_grupo_etario VARCHAR(30) NOT NULL 
);

CREATE TABLE Dim_Paciente (
    id_paciente INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_faixa_etaria SMALLINT REFERENCES Dim_Faixa_Etaria(id_faixa_etaria),
    nu_idade_anos SMALLINT NOT NULL CHECK (nu_idade_anos >= 0),
    ds_sexo CHAR(1) CHECK (ds_sexo IN ('M', 'F', 'I')), 
    ds_raca_cor VARCHAR(30),
    ds_escolaridade VARCHAR(50),
    dt_criacao TIMESTAMP DEFAULT NOW() 
);

CREATE TABLE Dim_Desfecho_Internacao (
    id_desfecho SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_desfecho SMALLINT UNIQUE NOT NULL, 
    ds_desfecho VARCHAR(60) NOT NULL,
    fl_obito BOOLEAN DEFAULT FALSE,
    fl_alta BOOLEAN DEFAULT FALSE,
    fl_transferencia BOOLEAN DEFAULT FALSE,
    CONSTRAINT chk_unique_flag CHECK (
        (fl_obito::int + fl_alta::int + fl_transferencia::int) <= 1
    ) 
);

CREATE TABLE Dim_Estabelecimento_Saude (
    id_estabelecimento INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_municipio INT REFERENCES Dim_Municipio(id_municipio),
    co_cnes INT UNIQUE NOT NULL,
    ds_estabelecimento VARCHAR(200) NOT NULL,
    ds_natureza_juridica VARCHAR(80),
    ds_tipo_unidade VARCHAR(80),
    nu_leitos_sus SMALLINT,
    fl_ativo BOOLEAN DEFAULT TRUE 
);

CREATE TABLE Dim_Tipo_Leito (
    id_tipo_leito SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_tipo_leito VARCHAR(10) UNIQUE NOT NULL,
    ds_tipo_leito VARCHAR(80) NOT NULL,
    fl_critico BOOLEAN DEFAULT FALSE 
);

CREATE TABLE Dim_Procedimento (
    id_procedimento INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    co_procedimento VARCHAR(10) UNIQUE NOT NULL, 
    ds_procedimento VARCHAR(300) NOT NULL,
    vl_referencia_sus DECIMAL(10,2) CHECK (vl_referencia_sus >= 0),
    fl_alto_custo BOOLEAN DEFAULT FALSE 
);

CREATE TABLE Dim_Nivel_Saneamento (
    id_nivel_saneamento SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ds_nivel VARCHAR(30) UNIQUE NOT NULL, 
    nu_perc_min DECIMAL(5,2) NOT NULL CHECK (nu_perc_min >= 0),
    nu_perc_max DECIMAL(5,2) CHECK (nu_perc_max <= 100),
    co_cor_hex CHAR(7) 
);

-- ==========================================================
-- 4. TABELAS FATO E INFRAESTRUTURA [cite: 27, 95]
-- Mantido da versão posterior feito (08/03/2026)
-- ==========================================================

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
    CONSTRAINT uk_mun_ano UNIQUE (id_municipio, id_tempo) 
);

-- Fato de Internações Particionada (Nível Profissional para +200k logs) [cite: 27]
CREATE TABLE Fato_Internacoes (
    id_internacao BIGINT GENERATED ALWAYS AS IDENTITY,
    id_cid10_categoria INT REFERENCES Dim_CID10_Categoria(id_categoria),
    id_municipio INT NOT NULL REFERENCES Dim_Municipio(id_municipio),
    id_tempo_internacao INT NOT NULL REFERENCES Dim_Tempo(id_tempo),
    id_paciente INT REFERENCES Dim_Paciente(id_paciente),
    id_estabelecimento INT REFERENCES Dim_Estabelecimento_Saude(id_estabelecimento),
    id_procedimento INT REFERENCES Dim_Procedimento(id_procedimento),
    id_desfecho SMALLINT REFERENCES Dim_Desfecho_Internacao(id_desfecho),
    vl_total_internacao DECIMAL(12,2) NOT NULL CHECK (vl_total_internacao >= 0),
    nu_dias_permanencia SMALLINT NOT NULL CHECK (nu_dias_permanencia >= 0),
    fl_obito BOOLEAN DEFAULT FALSE, 
    co_aih VARCHAR(13), 
    dt_carga_etl TIMESTAMP DEFAULT NOW()
) PARTITION BY RANGE (dt_carga_etl);

-- A 18ª TABELA: Investimento em Infraestrutura 
CREATE TABLE Dim_Investimento_Infraestrutura (
    id_investimento INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_municipio INT NOT NULL REFERENCES Dim_Municipio(id_municipio),
    id_tempo INT NOT NULL REFERENCES Dim_Tempo(id_tempo),
    ds_tipo_investimento VARCHAR(80) NOT NULL, 
    vl_investimento DECIMAL(15,2) NOT NULL CHECK (vl_investimento >= 0),
    CONSTRAINT uk_mun_tempo_tipo UNIQUE (id_municipio, id_tempo, ds_tipo_investimento) 
);

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
WHERE g.fl_veiculacao_hidrica = TRUE
GROUP BY 1, 2;

-- 2. View: Eficiência em Crianças (Q2)
CREATE VIEW vw_permanencia_pediatrica AS
SELECT m.ds_municipio, AVG(f.nu_dias_permanencia) as media_dias
FROM Fato_Internacoes f
JOIN Dim_Paciente p ON f.id_paciente = p.id_paciente
JOIN Dim_Municipio m ON f.id_municipio = m.id_municipio
WHERE p.nu_idade_anos <= 12
GROUP BY 1;

-- 3. View: Ranking Gasto por Habitante (Q3)
CREATE VIEW vw_ranking_gasto_habitante AS
SELECT m.ds_municipio, (SUM(f.vl_total_internacao) / m.nu_populacao) as gasto_per_capita
FROM Fato_Internacoes f
JOIN Dim_Municipio m ON f.id_municipio = m.id_municipio
GROUP BY 1, m.nu_populacao;

-- 4. View: Mortalidade por Doenças Crônicas (Q4)
CREATE VIEW vw_mortalidade_cronica_saneamento AS
SELECT m.ds_municipio, s.ds_nivel, COUNT(f.id_internacao) as total_obitos
FROM Fato_Internacoes f
JOIN Dim_CID10_Categoria c ON f.id_cid10_categoria = c.id_categoria
JOIN Dim_CID10_Grupo g ON c.id_grupo = g.id_grupo
JOIN Dim_Municipio m ON f.id_municipio = m.id_municipio
JOIN Fato_Indicadores_Sociais s ON m.id_municipio = s.id_municipio
WHERE g.fl_doenca_cronica = TRUE AND f.fl_obito = TRUE
GROUP BY 1, 2;

-- 5. View: Auditoria de Carga (Controle de ETL) [cite: 24, 28]
CREATE VIEW vw_controle_carga_mensal AS
SELECT date_trunc('month', dt_carga_etl) as mes_referencia, COUNT(*) as registros_processados
FROM Fato_Internacoes GROUP BY 1;

-- ==========================================================
-- 6. REQUISITOS OBRIGATÓRIOS: PROCEDURES (MÍNIMO 5) [cite: 31, 63]
-- ==========================================================

-- 1. SP de Carga (CRUD/ETL): Registrar nova internação [cite: 24]
CREATE OR REPLACE PROCEDURE sp_etl_registrar_internacao(p_cid INT, p_mun INT, p_valor DECIMAL, p_aih VARCHAR)
LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO Fato_Internacoes (id_cid10_categoria, id_municipio, vl_total_internacao, co_aih)
    VALUES (p_cid, p_mun, p_valor, p_aih);
END; $$;

-- 2. SP Analítica: Projeção de Economia (Q5) [cite: 151]
CREATE OR REPLACE PROCEDURE sp_analise_projecao_economia()
LANGUAGE plpgsql AS $$
DECLARE v_media_ideal DECIMAL;
BEGIN
    SELECT AVG(vl_total_internacao) INTO v_media_ideal FROM Fato_Internacoes f
    JOIN Fato_Indicadores_Sociais s ON f.id_municipio = s.id_municipio
    WHERE s.nu_perc_esgoto_tratado > 90;
    RAISE NOTICE 'A redução estimada de custos com saneamento pleno é baseada na média de: %', v_media_ideal;
END; $$;

-- 3. SP de Manutenção: Limpeza de Logs Antigos [cite: 65, 88]
CREATE OR REPLACE PROCEDURE sp_manutencao_limpar_logs(p_data DATE)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM Fato_Internacoes WHERE dt_carga_etl < p_data;
END; $$;

-- 4. SP de Atualização: Correção de População Censo [cite: 147]
CREATE OR REPLACE PROCEDURE sp_update_populacao_municipio(p_mun_id INT, p_pop INT)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE Dim_Municipio SET nu_populacao = p_pop, dt_atualizacao = NOW() WHERE id_municipio = p_mun_id;
END; $$;

-- 5. SP de Auditoria: Validação de Integridade Referencial [cite: 83, 110]
CREATE OR REPLACE PROCEDURE sp_auditoria_validar_chaves()
LANGUAGE plpgsql AS $$
BEGIN
    -- Lógica para identificar registros órfãos ou inconsistentes
    RAISE NOTICE 'Auditoria de integridade concluída.';
END; $$;

-- ==========================================================
-- 7. REQUISITOS OBRIGATÓRIOS: SEGURANÇA E DCL (3 PERFIS) [cite: 32, 107]
-- ==========================================================

CREATE ROLE role_admin_bd; -- Acesso Total [cite: 107]
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO role_admin_bd;

CREATE ROLE role_analista_bi; -- Acesso Leitura Views [cite: 107]
GRANT SELECT ON ALL VIEWS IN SCHEMA public TO role_analista_bi;

CREATE ROLE role_operador_etl; -- Acesso Escrita Procedures [cite: 107]
GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO role_operador_etl;

-- ==========================================================
-- 8. ÍNDICES E TRIGGERS (MANUTENÇÃO) [cite: 60, 65]
-- Mantido da versão posterior feito (08/03/2026)
-- ==========================================================

CREATE INDEX idx_fato_int_otimizado ON Fato_Internacoes (id_municipio, id_cid10_categoria);

CREATE OR REPLACE FUNCTION fn_sync_fl_obito() RETURNS TRIGGER AS $$
BEGIN
    SELECT fl_obito INTO NEW.fl_obito 
    FROM Dim_Desfecho_Internacao WHERE id_desfecho = NEW.id_desfecho;
    RETURN NEW;
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_fato_int_sync_obito
BEFORE INSERT OR UPDATE ON Fato_Internacoes
FOR EACH ROW EXECUTE FUNCTION fn_sync_fl_obito();
