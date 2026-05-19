/* =============================================================================
   PROJETO: Monitoramento de Doenças Crônicas vs Determinantes Sociais
   SCRIPT:  01_create_staging.sql
   FASE:    Staging — Criação das tabelas temporárias de carga bruta
   AUTOR:   ProjetoBD2026
   NOTAS:   Tabelas stg_* recebem os dados RAW dos CSVs sem constraints.
            Todos os campos são VARCHAR para absorver inconsistências dos dados
            brutos. A transformação ocorre no script 02_transform_load.sql.
            Execute este script ANTES dos BULK INSERTs.
   =============================================================================
*/

-- Evita erro se o banco ainda não tiver o schema padrão
USE ProjetoBD2026;
GO

-- ==========================================================
-- LIMPEZA: Drop das stagings se já existirem (idempotente)
-- ==========================================================
IF OBJECT_ID('stg_Internacoes',          'U') IS NOT NULL DROP TABLE stg_Internacoes;
IF OBJECT_ID('stg_Municipios',           'U') IS NOT NULL DROP TABLE stg_Municipios;
IF OBJECT_ID('stg_CID10_Categorias',     'U') IS NOT NULL DROP TABLE stg_CID10_Categorias;
IF OBJECT_ID('stg_Indicadores_Sociais',  'U') IS NOT NULL DROP TABLE stg_Indicadores_Sociais;
GO

-- ==========================================================
-- 1. STAGING: Internações SIH/SUS
--    Fonte: internacoes_sih.csv (Kaggle)
--    Destino final: Fato_Internacoes + Dim_Paciente + Dim_Estabelecimento_Saude
-- ==========================================================
CREATE TABLE stg_Internacoes (
    -- Identificação
    co_aih              VARCHAR(20),       -- Número da AIH
    ds_competencia      VARCHAR(10),       -- Competência (AAAAMM)

    -- Diagnóstico
    co_diag_principal   VARCHAR(10),       -- Código CID-10 principal
    co_diag_secundario  VARCHAR(10),       -- Código CID-10 secundário (pode ser nulo)
    co_procedimento     VARCHAR(15),       -- Código do procedimento SUS

    -- Localização
    co_municipio_res    VARCHAR(10),       -- Código IBGE do município de residência (6 dígitos)
    co_municipio_mov    VARCHAR(10),       -- Código IBGE do município de atendimento
    co_uf               VARCHAR(5),        -- UF (sigla ou código)

    -- Estabelecimento
    co_cnes             VARCHAR(15),       -- Código CNES do hospital
    ds_estabelecimento  VARCHAR(300),      -- Nome do hospital (pode vir sujo)

    -- Paciente
    nu_idade            VARCHAR(5),        -- Idade (bruta — pode vir como "0051A" no SIH)
    ds_sexo             VARCHAR(5),        -- Sexo (M/F/1/2/I)
    ds_raca_cor         VARCHAR(30),       -- Raça/cor
    ds_escolaridade     VARCHAR(50),       -- Escolaridade

    -- Internação
    dt_internacao       VARCHAR(15),       -- Data de internação (AAAA-MM-DD ou AAAAMMDD)
    dt_alta             VARCHAR(15),       -- Data de alta
    nu_dias_permanencia VARCHAR(10),       -- Dias de permanência
    nu_dias_uti         VARCHAR(10),       -- Dias em UTI

    -- Financeiro
    vl_total            VARCHAR(20),       -- Valor total pago (pode ter vírgula ou ponto)

    -- Desfecho
    co_motivo_saida     VARCHAR(10),       -- Código do motivo de saída (alta, óbito, transferência)

    -- Controle ETL
    dt_carga_stg        DATETIME2 DEFAULT GETDATE(),
    fl_processado       BIT DEFAULT 0      -- 0 = aguardando transformação
);
GO

-- ==========================================================
-- 2. STAGING: Municípios IBGE
--    Fonte: municipios_ibge.csv
--    Destino final: Dim_Municipio + Dim_Estado + Dim_Regiao_Geografica
-- ==========================================================
CREATE TABLE stg_Municipios (
    co_ibge_7           VARCHAR(10),       -- Código IBGE 7 dígitos
    co_ibge_6           VARCHAR(10),       -- Código IBGE 6 dígitos
    ds_municipio        VARCHAR(150),      -- Nome do município
    sg_uf               VARCHAR(5),        -- Sigla do estado
    ds_estado           VARCHAR(60),       -- Nome do estado
    co_uf               VARCHAR(5),        -- Código numérico da UF
    ds_regiao           VARCHAR(30),       -- Nome da região (Norte, Sul, etc.)
    co_regiao           VARCHAR(5),        -- Código da região (1-5)
    nu_populacao        VARCHAR(15),       -- População (censo)
    nu_area_km2         VARCHAR(20),       -- Área em km²
    fl_capital          VARCHAR(5),        -- S/N ou 1/0
    ds_regiao_saude     VARCHAR(200),      -- Nome da Região de Saúde
    co_regiao_saude     VARCHAR(10),       -- Código da Região de Saúde

    dt_carga_stg        DATETIME2 DEFAULT GETDATE(),
    fl_processado       BIT DEFAULT 0
);
GO

-- ==========================================================
-- 3. STAGING: CID-10 Categorias
--    Fonte: cid10_categorias.csv (DataSUS)
--    Destino final: Dim_CID10_Capitulo + Dim_CID10_Grupo + Dim_CID10_Categoria
-- ==========================================================
CREATE TABLE stg_CID10_Categorias (
    co_categoria        VARCHAR(10),       -- Código (ex: A00, B01, J18...)
    ds_categoria        VARCHAR(500),      -- Descrição completa
    ds_categoria_abrev  VARCHAR(150),      -- Descrição abreviada
    co_grupo            VARCHAR(15),       -- Código do grupo (ex: A00-A09)
    ds_grupo            VARCHAR(400),      -- Descrição do grupo
    co_capitulo         VARCHAR(10),       -- Número do capítulo romano (ex: I, II, X)
    ds_capitulo         VARCHAR(300),      -- Descrição do capítulo
    co_cid_inicio_cap   VARCHAR(5),        -- CID início do capítulo
    co_cid_fim_cap      VARCHAR(5),        -- CID fim do capítulo
    co_cid_inicio_grp   VARCHAR(5),        -- CID início do grupo
    co_cid_fim_grp      VARCHAR(5),        -- CID fim do grupo
    fl_notif_compulsoria VARCHAR(3),       -- S/N

    dt_carga_stg        DATETIME2 DEFAULT GETDATE(),
    fl_processado       BIT DEFAULT 0
);
GO

-- ==========================================================
-- 4. STAGING: Indicadores Sociais
--    Fonte: indicadores_sociais.csv (Base dos Dados / SIDRA)
--    Destino final: Fato_Indicadores_Sociais + Dim_Nivel_Saneamento
-- ==========================================================
CREATE TABLE stg_Indicadores_Sociais (
    co_ibge_6           VARCHAR(10),       -- Código IBGE 6 dígitos (chave de join)
    ds_municipio        VARCHAR(150),      -- Nome (verificação cruzada)
    sg_uf               VARCHAR(5),        -- UF
    nu_ano              VARCHAR(6),        -- Ano de referência do indicador

    -- Saneamento
    nu_perc_esgoto      VARCHAR(10),       -- % domicílios com esgoto tratado
    nu_perc_agua        VARCHAR(10),       -- % domicílios com água tratada

    -- Socioeconômico
    vl_renda_per_capita VARCHAR(20),       -- Renda média per capita (R$)
    nu_idhm             VARCHAR(10),       -- IDHM (0 a 1)
    nu_populacao        VARCHAR(15),       -- População no período

    -- Investimento em infraestrutura (opcional — pode estar em arquivo separado)
    vl_investimento_saneamento VARCHAR(20),-- Investimento em R$
    ds_tipo_investimento VARCHAR(100),     -- Tipo (Esgoto, Água, Drenagem...)

    dt_carga_stg        DATETIME2 DEFAULT GETDATE(),
    fl_processado       BIT DEFAULT 0
);
GO

PRINT '✅ Tabelas de staging criadas com sucesso.';
GO
/* =============================================================================
   PROJETO: Monitoramento de Doenças Crônicas vs Determinantes Sociais
   SCRIPT:  01_bulk_insert.sql
   FASE:    ETL — Extração: BULK INSERT dos CSVs para as tabelas de Staging
   AUTOR:   ProjetoBD2026
   NOTAS:   ⚠️  Ajuste a variável @base_path para o caminho real dos CSVs
            na sua máquina antes de executar.
            Requer permissão ADMINISTER BULK OPERATIONS ou ser sysadmin.
   =============================================================================
*/

USE ProjetoBD2026;
GO

-- ==========================================================
-- CONFIGURAÇÃO: Ajuste este caminho para onde os CSVs estão
-- ==========================================================
-- Exemplo Windows: C:\ETL\datasets\
-- Exemplo mapeado: \\servidor\compartilhado\datasets\
DECLARE @base_path VARCHAR(200) = 'C:\ETL\datasets\';
-- Não é possível usar variável diretamente no BULK INSERT (limitação T-SQL).
-- Os caminhos abaixo estão escritos diretamente. Troque se necessário.
GO

-- ==========================================================
-- 1. CARGA: Internações SIH/SUS
--    Arquivo: internacoes_sih.csv
--    Encoding esperado: UTF-8 ou Latin1 (verifique o Kaggle)
-- ==========================================================
PRINT '📥 Carregando internacoes_sih.csv...';

BULK INSERT stg_Internacoes
FROM 'C:\ETL\datasets\internacoes_sih.csv'
WITH (
    FIELDTERMINATOR  = ',',       -- separador de colunas
    ROWTERMINATOR    = '\n',      -- separador de linhas
    FIRSTROW         = 2,         -- pula o cabeçalho
    CODEPAGE         = '65001',   -- UTF-8; use '1252' se o arquivo for Latin1
    MAXERRORS        = 100,       -- tolera até 100 linhas com erro antes de abortar
    ERRORFILE        = 'C:\ETL\logs\err_internacoes.log',
    TABLOCK                       -- melhora performance em cargas grandes
);

PRINT '✅ internacoes_sih.csv carregado. Registros: ' + 
      CAST((SELECT COUNT(*) FROM stg_Internacoes WHERE fl_processado = 0) AS VARCHAR);
GO

-- ==========================================================
-- 2. CARGA: Municípios IBGE
--    Arquivo: municipios_ibge.csv
-- ==========================================================
PRINT '📥 Carregando municipios_ibge.csv...';

BULK INSERT stg_Municipios
FROM 'C:\ETL\datasets\municipios_ibge.csv'
WITH (
    FIELDTERMINATOR  = ',',
    ROWTERMINATOR    = '\n',
    FIRSTROW         = 2,
    CODEPAGE         = '65001',
    MAXERRORS        = 50,
    ERRORFILE        = 'C:\ETL\logs\err_municipios.log',
    TABLOCK
);

PRINT '✅ municipios_ibge.csv carregado. Registros: ' + 
      CAST((SELECT COUNT(*) FROM stg_Municipios WHERE fl_processado = 0) AS VARCHAR);
GO

-- ==========================================================
-- 3. CARGA: CID-10 Categorias
--    Arquivo: cid10_categorias.csv
--    Separador original do DataSUS: ponto-e-vírgula
-- ==========================================================
PRINT '📥 Carregando cid10_categorias.csv...';

BULK INSERT stg_CID10_Categorias
FROM 'C:\ETL\datasets\cid10_categorias.csv'
WITH (
    FIELDTERMINATOR  = ';',       -- DataSUS usa ponto-e-vírgula
    ROWTERMINATOR    = '\n',
    FIRSTROW         = 2,
    CODEPAGE         = '1252',    -- DataSUS geralmente entrega em Latin1
    MAXERRORS        = 50,
    ERRORFILE        = 'C:\ETL\logs\err_cid10.log',
    TABLOCK
);

PRINT '✅ cid10_categorias.csv carregado. Registros: ' + 
      CAST((SELECT COUNT(*) FROM stg_CID10_Categorias WHERE fl_processado = 0) AS VARCHAR);
GO

-- ==========================================================
-- 4. CARGA: Indicadores Sociais
--    Arquivo: indicadores_sociais.csv
-- ==========================================================
PRINT '📥 Carregando indicadores_sociais.csv...';

BULK INSERT stg_Indicadores_Sociais
FROM 'C:\ETL\datasets\indicadores_sociais.csv'
WITH (
    FIELDTERMINATOR  = ',',
    ROWTERMINATOR    = '\n',
    FIRSTROW         = 2,
    CODEPAGE         = '65001',
    MAXERRORS        = 50,
    ERRORFILE        = 'C:\ETL\logs\err_indicadores.log',
    TABLOCK
);

PRINT '✅ indicadores_sociais.csv carregado. Registros: ' + 
      CAST((SELECT COUNT(*) FROM stg_Indicadores_Sociais WHERE fl_processado = 0) AS VARCHAR);
GO

-- ==========================================================
-- VALIDAÇÃO RÁPIDA PÓS-CARGA
-- ==========================================================
PRINT '';
PRINT '📊 Resumo de carga nas stagings:';
SELECT 'stg_Internacoes'         AS tabela, COUNT(*) AS total_registros FROM stg_Internacoes
UNION ALL
SELECT 'stg_Municipios',                    COUNT(*) FROM stg_Municipios
UNION ALL
SELECT 'stg_CID10_Categorias',              COUNT(*) FROM stg_CID10_Categorias
UNION ALL
SELECT 'stg_Indicadores_Sociais',           COUNT(*) FROM stg_Indicadores_Sociais;
GO
/* =============================================================================
   PROJETO: Monitoramento de Doenças Crônicas vs Determinantes Sociais
   SCRIPT:  02_transform_load.sql
   FASE:    ETL — Transformação: Staging → Tabelas Dimensão
   AUTOR:   ProjetoBD2026
   NOTAS:   Popula todas as Dims a partir das stagings.
            Execute APÓS o 01_bulk_insert.sql e ANTES do 03_load_fatos.sql.
            Cada bloco é idempotente (usa MERGE ou INSERT WHERE NOT EXISTS).
   =============================================================================
*/

USE ProjetoBD2026;
GO

-- ==========================================================
-- 1. Dim_Regiao_Geografica
--    Fonte: stg_Municipios (campos ds_regiao, co_regiao)
-- ==========================================================
PRINT '🔄 Carregando Dim_Regiao_Geografica...';

INSERT INTO Dim_Regiao_Geografica (co_regiao, ds_regiao, sg_regiao)
SELECT DISTINCT
    TRY_CAST(co_regiao AS SMALLINT),
    UPPER(LTRIM(RTRIM(ds_regiao))),
    CASE UPPER(LTRIM(RTRIM(ds_regiao)))
        WHEN 'NORTE'          THEN 'NO'
        WHEN 'NORDESTE'       THEN 'NE'
        WHEN 'CENTRO-OESTE'   THEN 'CO'
        WHEN 'SUDESTE'        THEN 'SE'
        WHEN 'SUL'            THEN 'SU'
        ELSE 'XX'
    END
FROM stg_Municipios
WHERE co_regiao IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM Dim_Regiao_Geografica r
      WHERE r.co_regiao = TRY_CAST(stg_Municipios.co_regiao AS SMALLINT)
  );

PRINT '✅ Dim_Regiao_Geografica: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' novas regiões inseridas.';
GO

-- ==========================================================
-- 2. Dim_Estado
--    Fonte: stg_Municipios
-- ==========================================================
PRINT '🔄 Carregando Dim_Estado...';

INSERT INTO Dim_Estado (id_regiao, co_uf, sg_uf, ds_estado, co_ibge_uf)
SELECT DISTINCT
    r.id_regiao,
    TRY_CAST(s.co_uf AS SMALLINT),
    UPPER(LTRIM(RTRIM(s.sg_uf))),
    UPPER(LTRIM(RTRIM(s.ds_estado))),
    RIGHT('0' + LTRIM(RTRIM(s.co_uf)), 2)   -- garante 2 dígitos
FROM stg_Municipios s
JOIN Dim_Regiao_Geografica r ON r.co_regiao = TRY_CAST(s.co_regiao AS SMALLINT)
WHERE s.co_uf IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM Dim_Estado e
      WHERE e.sg_uf = UPPER(LTRIM(RTRIM(s.sg_uf)))
  );

PRINT '✅ Dim_Estado: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' novos estados inseridos.';
GO

-- ==========================================================
-- 3. Dim_Regiao_Saude
--    Fonte: stg_Municipios
-- ==========================================================
PRINT '🔄 Carregando Dim_Regiao_Saude...';

INSERT INTO Dim_Regiao_Saude (id_estado, co_regiao_saude, ds_regiao_saude)
SELECT DISTINCT
    e.id_estado,
    TRY_CAST(s.co_regiao_saude AS INT),
    UPPER(LTRIM(RTRIM(s.ds_regiao_saude)))
FROM stg_Municipios s
JOIN Dim_Estado e ON e.sg_uf = UPPER(LTRIM(RTRIM(s.sg_uf)))
WHERE s.co_regiao_saude IS NOT NULL
  AND s.ds_regiao_saude IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM Dim_Regiao_Saude rs
      WHERE rs.id_estado         = e.id_estado
        AND rs.co_regiao_saude   = TRY_CAST(s.co_regiao_saude AS INT)
  );

PRINT '✅ Dim_Regiao_Saude: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' novas regiões de saúde inseridas.';
GO

-- ==========================================================
-- 4. Dim_Municipio
--    Fonte: stg_Municipios
--    Nota: nu_populacao e nu_area_km2 podem ser nulos nos CSVs
-- ==========================================================
PRINT '🔄 Carregando Dim_Municipio...';

INSERT INTO Dim_Municipio (
    id_estado, id_regiao_saude,
    co_ibge_7, co_ibge_6, co_mun_res,
    ds_municipio, nu_populacao, nu_area_km2, fl_capital
)
SELECT
    e.id_estado,
    rs.id_regiao_saude,
    TRY_CAST(s.co_ibge_7 AS INT),
    TRY_CAST(s.co_ibge_6 AS INT),
    TRY_CAST(s.co_ibge_6 AS INT),          -- co_mun_res = co_ibge_6 para municípios
    LTRIM(RTRIM(s.ds_municipio)),
    TRY_CAST(REPLACE(s.nu_populacao, '.', '') AS INT),
    TRY_CAST(REPLACE(REPLACE(s.nu_area_km2, '.', ''), ',', '.') AS DECIMAL(12,4)),
    CASE WHEN UPPER(LTRIM(RTRIM(s.fl_capital))) IN ('S','1','SIM','TRUE') THEN 1 ELSE 0 END
FROM stg_Municipios s
JOIN Dim_Estado e          ON e.sg_uf          = UPPER(LTRIM(RTRIM(s.sg_uf)))
LEFT JOIN Dim_Regiao_Saude rs ON rs.id_estado  = e.id_estado
                              AND rs.co_regiao_saude = TRY_CAST(s.co_regiao_saude AS INT)
WHERE s.co_ibge_6 IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM Dim_Municipio m
      WHERE m.co_ibge_6 = TRY_CAST(s.co_ibge_6 AS INT)
  );

PRINT '✅ Dim_Municipio: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' municípios inseridos.';
GO

-- ==========================================================
-- 5. Dim_CID10_Capitulo
-- ==========================================================
PRINT '🔄 Carregando Dim_CID10_Capitulo...';

INSERT INTO Dim_CID10_Capitulo (co_capitulo, ds_capitulo, co_cid_inicio, co_cid_fim, fl_infectocontagioso)
SELECT DISTINCT
    LTRIM(RTRIM(co_capitulo)),
    LTRIM(RTRIM(ds_capitulo)),
    LTRIM(RTRIM(co_cid_inicio_cap)),
    LTRIM(RTRIM(co_cid_fim_cap)),
    -- Capítulo I (A00-B99) = Doenças infecciosas e parasitárias
    CASE WHEN LTRIM(RTRIM(co_capitulo)) = 'I' THEN 1 ELSE 0 END
FROM stg_CID10_Categorias
WHERE co_capitulo IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM Dim_CID10_Capitulo c
      WHERE c.co_capitulo = LTRIM(RTRIM(stg_CID10_Categorias.co_capitulo))
  );

PRINT '✅ Dim_CID10_Capitulo: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' capítulos inseridos.';
GO

-- ==========================================================
-- 6. Dim_CID10_Grupo
-- ==========================================================
PRINT '🔄 Carregando Dim_CID10_Grupo...';

INSERT INTO Dim_CID10_Grupo (id_capitulo, co_grupo, ds_grupo, co_cid_inicio, co_cid_fim, fl_veiculacao_hidrica, fl_doenca_cronica)
SELECT DISTINCT
    cap.id_capitulo,
    LTRIM(RTRIM(s.co_grupo)),
    LTRIM(RTRIM(s.ds_grupo)),
    LTRIM(RTRIM(s.co_cid_inicio_grp)),
    LTRIM(RTRIM(s.co_cid_fim_grp)),
    -- Grupos de doenças de veiculação hídrica: A00-A09 (cólera, tifoide, diarreias)
    CASE WHEN LTRIM(RTRIM(s.co_cid_inicio_grp)) IN ('A00','A01','A02','A03','A04','A05','A06','A07','A08','A09') THEN 1 ELSE 0 END,
    -- Doenças crônicas: capítulos IV (E), IX (I), X (J), XI (K), XIII (M)
    CASE WHEN LTRIM(RTRIM(s.co_capitulo)) IN ('IV','IX','X','XI','XIII') THEN 1 ELSE 0 END
FROM stg_CID10_Categorias s
JOIN Dim_CID10_Capitulo cap ON cap.co_capitulo = LTRIM(RTRIM(s.co_capitulo))
WHERE s.co_grupo IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM Dim_CID10_Grupo g
      WHERE g.co_grupo = LTRIM(RTRIM(s.co_grupo))
  );

PRINT '✅ Dim_CID10_Grupo: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' grupos inseridos.';
GO

-- ==========================================================
-- 7. Dim_CID10_Categoria
-- ==========================================================
PRINT '🔄 Carregando Dim_CID10_Categoria...';

INSERT INTO Dim_CID10_Categoria (id_grupo, co_categoria, ds_categoria, ds_categoria_abreviada, fl_notificacao_compulsoria)
SELECT
    g.id_grupo,
    UPPER(LTRIM(RTRIM(s.co_categoria))),
    LTRIM(RTRIM(s.ds_categoria)),
    LEFT(LTRIM(RTRIM(ISNULL(s.ds_categoria_abrev, s.ds_categoria))), 100),
    CASE WHEN UPPER(LTRIM(RTRIM(s.fl_notif_compulsoria))) IN ('S','1','SIM') THEN 1 ELSE 0 END
FROM stg_CID10_Categorias s
JOIN Dim_CID10_Grupo g ON g.co_grupo = LTRIM(RTRIM(s.co_grupo))
WHERE s.co_categoria IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM Dim_CID10_Categoria c
      WHERE c.co_categoria = UPPER(LTRIM(RTRIM(s.co_categoria)))
  );

PRINT '✅ Dim_CID10_Categoria: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' categorias inseridas.';
GO

-- ==========================================================
-- 8. Dim_Tempo
--    Geração programática para o range 2019-2024
--    (não depende de CSV — gerado diretamente via T-SQL)
-- ==========================================================
PRINT '🔄 Populando Dim_Tempo (2019–2024)...';

WITH cte_datas AS (
    SELECT CAST('2019-01-01' AS DATE) AS dt
    UNION ALL
    SELECT DATEADD(MONTH, 1, dt) FROM cte_datas
    WHERE dt < '2024-12-01'
)
INSERT INTO Dim_Tempo (dt_referencia, nu_ano, nu_mes, nu_trimestre, nu_semestre, ds_mes, fl_ano_bissexto)
SELECT
    dt,
    YEAR(dt),
    MONTH(dt),
    CEILING(MONTH(dt) / 3.0),
    CASE WHEN MONTH(dt) <= 6 THEN 1 ELSE 2 END,
    DATENAME(MONTH, dt),
    CASE WHEN (YEAR(dt) % 4 = 0 AND YEAR(dt) % 100 <> 0) OR YEAR(dt) % 400 = 0 THEN 1 ELSE 0 END
FROM cte_datas
WHERE NOT EXISTS (
    SELECT 1 FROM Dim_Tempo t WHERE t.dt_referencia = cte_datas.dt
)
OPTION (MAXRECURSION 100);

PRINT '✅ Dim_Tempo: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' períodos inseridos.';
GO

-- ==========================================================
-- 9. Dim_Faixa_Etaria
--    Geração estática baseada nas faixas do SIH/SUS
-- ==========================================================
PRINT '🔄 Populando Dim_Faixa_Etaria...';

INSERT INTO Dim_Faixa_Etaria (ds_faixa_etaria, nu_idade_min, nu_idade_max, ds_grupo_etario)
SELECT ds_faixa_etaria, nu_idade_min, nu_idade_max, ds_grupo_etario
FROM (VALUES
    ('Menor de 1 ano',   0,   0, 'Pediátrico'),
    ('1 a 4 anos',       1,   4, 'Pediátrico'),
    ('5 a 9 anos',       5,   9, 'Pediátrico'),
    ('10 a 12 anos',    10,  12, 'Pediátrico'),
    ('13 a 17 anos',    13,  17, 'Adolescente'),
    ('18 a 29 anos',    18,  29, 'Adulto Jovem'),
    ('30 a 39 anos',    30,  39, 'Adulto'),
    ('40 a 49 anos',    40,  49, 'Adulto'),
    ('50 a 59 anos',    50,  59, 'Adulto Maduro'),
    ('60 a 69 anos',    60,  69, 'Idoso'),
    ('70 a 79 anos',    70,  79, 'Idoso'),
    ('80 anos ou mais', 80, 999, 'Idoso Avançado')
) AS v(ds_faixa_etaria, nu_idade_min, nu_idade_max, ds_grupo_etario)
WHERE NOT EXISTS (
    SELECT 1 FROM Dim_Faixa_Etaria f WHERE f.ds_faixa_etaria = v.ds_faixa_etaria
);

PRINT '✅ Dim_Faixa_Etaria: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' faixas inseridas.';
GO

-- ==========================================================
-- 10. Dim_Desfecho_Internacao
--     Códigos padrão SIH/SUS (motivo de saída)
-- ==========================================================
PRINT '🔄 Populando Dim_Desfecho_Internacao...';

INSERT INTO Dim_Desfecho_Internacao (co_desfecho, ds_desfecho, fl_obito, fl_alta, fl_transferencia)
SELECT co_desfecho, ds_desfecho, fl_obito, fl_alta, fl_transferencia
FROM (VALUES
    (11, 'Alta Curada',                              0, 1, 0),
    (12, 'Alta Melhorada',                           0, 1, 0),
    (13, 'Alta a Pedido',                            0, 1, 0),
    (14, 'Alta com Previsão de Retorno',             0, 1, 0),
    (15, 'Alta por Evasão',                          0, 1, 0),
    (16, 'Alta por Outros Motivos',                  0, 1, 0),
    (18, 'Alta para Internação Domiciliar',          0, 1, 0),
    (21, 'Transferência para outro Estabelecimento', 0, 0, 1),
    (28, 'Transferência para Internação Domiciliar', 0, 0, 1),
    (31, 'Transferência para Atendimento Complementar', 0, 0, 1),
    (41, 'Óbito com Declaração de Óbito Fornecida', 1, 0, 0),
    (42, 'Óbito com Declaração de Óbito Solicitada', 1, 0, 0),
    (43, 'Óbito Natimorto',                          1, 0, 0),
    (51, 'Encerramento Administrativo',              0, 0, 0)
) AS v(co_desfecho, ds_desfecho, fl_obito, fl_alta, fl_transferencia)
WHERE NOT EXISTS (
    SELECT 1 FROM Dim_Desfecho_Internacao d WHERE d.co_desfecho = v.co_desfecho
);

PRINT '✅ Dim_Desfecho_Internacao: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' desfechos inseridos.';
GO

-- ==========================================================
-- 11. Dim_Nivel_Saneamento
--     Faixas definidas pela literatura (WHO/IBGE)
-- ==========================================================
PRINT '🔄 Populando Dim_Nivel_Saneamento...';

INSERT INTO Dim_Nivel_Saneamento (ds_nivel, nu_perc_min, nu_perc_max, co_cor_hex)
SELECT ds_nivel, nu_perc_min, nu_perc_max, co_cor_hex
FROM (VALUES
    ('Crítico',         0.00,  24.99, '#D32F2F'),
    ('Precário',       25.00,  49.99, '#F57C00'),
    ('Intermediário',  50.00,  74.99, '#FBC02D'),
    ('Adequado',       75.00,  89.99, '#388E3C'),
    ('Universal',      90.00, 100.00, '#1565C0')
) AS v(ds_nivel, nu_perc_min, nu_perc_max, co_cor_hex)
WHERE NOT EXISTS (
    SELECT 1 FROM Dim_Nivel_Saneamento n WHERE n.ds_nivel = v.ds_nivel
);

PRINT '✅ Dim_Nivel_Saneamento: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' níveis inseridos.';
GO

PRINT '';
PRINT '🎉 Todas as dimensões carregadas com sucesso!';
GO
/* =============================================================================
   PROJETO: Monitoramento de Doenças Crônicas vs Determinantes Sociais
   SCRIPT:  03_load_fatos.sql
   FASE:    ETL — Carga: Staging → Tabelas Fato (principal e indicadores)
   AUTOR:   ProjetoBD2026
   NOTAS:   Execute APÓS o 02_transform_load.sql.
            A limpeza de dados ocorre aqui: conversões, nulos, deduplicação.
            Linhas inválidas são descartadas com log em tabela de rejeição.
   =============================================================================
*/

USE ProjetoBD2026;
GO

-- ==========================================================
-- TABELA DE REJEIÇÃO: Registros com problema são logados aqui
-- ==========================================================
IF OBJECT_ID('etl_Rejeicoes', 'U') IS NULL
BEGIN
    CREATE TABLE etl_Rejeicoes (
        id_rejeicao     BIGINT IDENTITY(1,1) PRIMARY KEY,
        ds_tabela_origem VARCHAR(50),
        ds_motivo       VARCHAR(300),
        ds_dados_raw    VARCHAR(MAX),
        dt_rejeicao     DATETIME2 DEFAULT GETDATE()
    );
    PRINT '✅ Tabela etl_Rejeicoes criada.';
END
GO

-- ==========================================================
-- 1. Dim_Paciente
--    Derivado da stg_Internacoes (uma linha por combinação única idade+sexo)
-- ==========================================================
PRINT '🔄 Carregando Dim_Paciente...';

INSERT INTO Dim_Paciente (id_faixa_etaria, nu_idade_anos, ds_sexo, ds_raca_cor, ds_escolaridade)
SELECT DISTINCT
    f.id_faixa_etaria,
    nu_idade_calc,
    ds_sexo_norm,
    NULLIF(LTRIM(RTRIM(s.ds_raca_cor)), ''),
    NULLIF(LTRIM(RTRIM(s.ds_escolaridade)), '')
FROM (
    -- Normaliza a idade bruta do SIH (formato "0051A" = 51 anos, "003M" = 3 meses → 0 anos)
    SELECT
        CASE
            WHEN RIGHT(LTRIM(RTRIM(nu_idade)), 1) = 'A'
                THEN TRY_CAST(LEFT(LTRIM(RTRIM(nu_idade)), LEN(LTRIM(RTRIM(nu_idade)))-1) AS SMALLINT)
            WHEN RIGHT(LTRIM(RTRIM(nu_idade)), 1) IN ('M','D')
                THEN 0
            ELSE TRY_CAST(LTRIM(RTRIM(nu_idade)) AS SMALLINT)
        END AS nu_idade_calc,
        CASE
            WHEN UPPER(LEFT(LTRIM(RTRIM(ds_sexo)),1)) IN ('M','1') THEN 'M'
            WHEN UPPER(LEFT(LTRIM(RTRIM(ds_sexo)),1)) IN ('F','2') THEN 'F'
            ELSE 'I'
        END AS ds_sexo_norm,
        ds_raca_cor,
        ds_escolaridade
    FROM stg_Internacoes
) s
JOIN Dim_Faixa_Etaria f ON s.nu_idade_calc BETWEEN f.nu_idade_min AND f.nu_idade_max
WHERE nu_idade_calc IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM Dim_Paciente p
      WHERE p.nu_idade_anos  = s.nu_idade_calc
        AND p.ds_sexo        = s.ds_sexo_norm
  );

PRINT '✅ Dim_Paciente: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' perfis de paciente inseridos.';
GO

-- ==========================================================
-- 2. Dim_Estabelecimento_Saude
--    Derivado da stg_Internacoes
-- ==========================================================
PRINT '🔄 Carregando Dim_Estabelecimento_Saude...';

INSERT INTO Dim_Estabelecimento_Saude (id_municipio, co_cnes, ds_estabelecimento, fl_ativo)
SELECT DISTINCT
    m.id_municipio,
    TRY_CAST(LTRIM(RTRIM(s.co_cnes)) AS INT),
    UPPER(LTRIM(RTRIM(s.ds_estabelecimento))),
    1
FROM stg_Internacoes s
JOIN Dim_Municipio m ON m.co_ibge_6 = TRY_CAST(LTRIM(RTRIM(s.co_municipio_mov)) AS INT)
WHERE s.co_cnes IS NOT NULL
  AND TRY_CAST(LTRIM(RTRIM(s.co_cnes)) AS INT) IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM Dim_Estabelecimento_Saude e
      WHERE e.co_cnes = TRY_CAST(LTRIM(RTRIM(s.co_cnes)) AS INT)
  );

PRINT '✅ Dim_Estabelecimento_Saude: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' estabelecimentos inseridos.';
GO

-- ==========================================================
-- 3. Dim_Procedimento
--    Derivado da stg_Internacoes
-- ==========================================================
PRINT '🔄 Carregando Dim_Procedimento...';

INSERT INTO Dim_Procedimento (co_procedimento, ds_procedimento)
SELECT DISTINCT
    LTRIM(RTRIM(co_procedimento)),
    'Procedimento ' + LTRIM(RTRIM(co_procedimento))   -- descrição não vem no CSV básico
FROM stg_Internacoes
WHERE co_procedimento IS NOT NULL
  AND LEN(LTRIM(RTRIM(co_procedimento))) > 0
  AND NOT EXISTS (
      SELECT 1 FROM Dim_Procedimento p
      WHERE p.co_procedimento = LTRIM(RTRIM(stg_Internacoes.co_procedimento))
  );

PRINT '✅ Dim_Procedimento: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' procedimentos inseridos.';
GO

-- ==========================================================
-- 4. Dim_Tipo_Leito (dados estáticos — classificação CNES)
-- ==========================================================
PRINT '🔄 Populando Dim_Tipo_Leito...';

INSERT INTO Dim_Tipo_Leito (co_tipo_leito, ds_tipo_leito, fl_critico)
SELECT co_tipo_leito, ds_tipo_leito, fl_critico
FROM (VALUES
    ('ENF',  'Enfermaria',                     0),
    ('APT',  'Apartamento',                    0),
    ('UTI-A','UTI Adulto',                     1),
    ('UTI-N','UTI Neonatal',                   1),
    ('UTI-P','UTI Pediátrica',                 1),
    ('UCI',  'Unidade de Cuidados Intermediários', 1),
    ('CC',   'Centro Cirúrgico',               0),
    ('PS',   'Pronto-Socorro',                 0),
    ('OUT',  'Outros',                         0)
) AS v(co_tipo_leito, ds_tipo_leito, fl_critico)
WHERE NOT EXISTS (
    SELECT 1 FROM Dim_Tipo_Leito t WHERE t.co_tipo_leito = v.co_tipo_leito
);

PRINT '✅ Dim_Tipo_Leito: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' tipos inseridos.';
GO

-- ==========================================================
-- 5. FATO: Fato_Internacoes  ← TABELA PRINCIPAL (+200k registros)
-- ==========================================================
PRINT '🔄 Carregando Fato_Internacoes (pode demorar)...';

BEGIN TRANSACTION;

BEGIN TRY
    INSERT INTO Fato_Internacoes (
        id_cid10_categoria,
        id_municipio,
        id_tempo_internacao,
        id_tempo_alta,
        id_paciente,
        id_estabelecimento,
        id_procedimento,
        id_desfecho,
        id_tipo_leito,
        vl_total_internacao,
        nu_dias_permanencia,
        nu_dias_uti,
        fl_obito,
        fl_internacao_eletiva,
        fl_gestante,
        co_aih,
        ds_competencia
    )
    SELECT
        cid.id_categoria,
        mun.id_municipio,
        t_int.id_tempo,
        t_alt.id_tempo,
        pac.id_paciente,
        est.id_estabelecimento,
        proc.id_procedimento,
        des.id_desfecho,
        NULL,                                  -- tipo de leito não disponível no CSV básico
        -- Valor: converte vírgula para ponto, remove R$ e espaços
        TRY_CAST(
            REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(s.vl_total)), 'R$',''), '.',''), ',', '.')
            AS DECIMAL(12,2)
        ),
        TRY_CAST(LTRIM(RTRIM(s.nu_dias_permanencia)) AS SMALLINT),
        ISNULL(TRY_CAST(LTRIM(RTRIM(s.nu_dias_uti)) AS SMALLINT), 0),
        CASE WHEN TRY_CAST(LTRIM(RTRIM(s.co_motivo_saida)) AS SMALLINT) IN (41,42,43) THEN 1 ELSE 0 END,
        0,                                     -- fl_internacao_eletiva: não disponível no CSV básico
        0,                                     -- fl_gestante: não disponível no CSV básico
        LTRIM(RTRIM(s.co_aih)),
        LTRIM(RTRIM(s.ds_competencia))
    FROM stg_Internacoes s
    -- JOIN CID-10
    LEFT JOIN Dim_CID10_Categoria cid
        ON cid.co_categoria = UPPER(LEFT(LTRIM(RTRIM(s.co_diag_principal)), 3))
    -- JOIN Município de residência
    JOIN Dim_Municipio mun
        ON mun.co_ibge_6 = TRY_CAST(LTRIM(RTRIM(s.co_municipio_res)) AS INT)
    -- JOIN Tempo internação (competência AAAAMM → primeiro dia do mês)
    JOIN Dim_Tempo t_int
        ON t_int.dt_referencia = TRY_CAST(
            LEFT(LTRIM(RTRIM(s.ds_competencia)),4) + '-' +
            RIGHT(LTRIM(RTRIM(s.ds_competencia)),2) + '-01'
            AS DATE)
    -- JOIN Tempo alta (data de alta, pode ser nula)
    LEFT JOIN Dim_Tempo t_alt
        ON t_alt.dt_referencia = TRY_CAST(
            CASE
                WHEN LEN(LTRIM(RTRIM(s.dt_alta))) = 8          -- formato AAAAMMDD
                    THEN LEFT(s.dt_alta,4)+'-'+SUBSTRING(s.dt_alta,5,2)+'-'+RIGHT(s.dt_alta,2)
                ELSE LTRIM(RTRIM(s.dt_alta))                   -- formato AAAA-MM-DD
            END AS DATE)
    -- JOIN Paciente
    LEFT JOIN Dim_Paciente pac
        ON pac.nu_idade_anos = CASE
            WHEN RIGHT(LTRIM(RTRIM(s.nu_idade)),1) = 'A'
                THEN TRY_CAST(LEFT(LTRIM(RTRIM(s.nu_idade)), LEN(LTRIM(RTRIM(s.nu_idade)))-1) AS SMALLINT)
            ELSE 0 END
        AND pac.ds_sexo = CASE
            WHEN UPPER(LEFT(LTRIM(RTRIM(s.ds_sexo)),1)) IN ('M','1') THEN 'M'
            WHEN UPPER(LEFT(LTRIM(RTRIM(s.ds_sexo)),1)) IN ('F','2') THEN 'F'
            ELSE 'I' END
    -- JOIN Estabelecimento
    LEFT JOIN Dim_Estabelecimento_Saude est
        ON est.co_cnes = TRY_CAST(LTRIM(RTRIM(s.co_cnes)) AS INT)
    -- JOIN Procedimento
    LEFT JOIN Dim_Procedimento proc
        ON proc.co_procedimento = LTRIM(RTRIM(s.co_procedimento))
    -- JOIN Desfecho
    LEFT JOIN Dim_Desfecho_Internacao des
        ON des.co_desfecho = TRY_CAST(LTRIM(RTRIM(s.co_motivo_saida)) AS SMALLINT)
    WHERE
        -- Filtra apenas registros válidos
        s.fl_processado   = 0
        AND mun.id_municipio IS NOT NULL
        AND t_int.id_tempo   IS NOT NULL
        AND TRY_CAST(
            REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(s.vl_total)), 'R$',''), '.',''), ',', '.')
            AS DECIMAL(12,2)) >= 0
        -- Evita duplicatas por AIH
        AND NOT EXISTS (
            SELECT 1 FROM Fato_Internacoes fi WHERE fi.co_aih = LTRIM(RTRIM(s.co_aih))
        );

    -- Marca como processado na staging
    UPDATE stg_Internacoes SET fl_processado = 1 WHERE fl_processado = 0;

    PRINT '✅ Fato_Internacoes: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' internações inseridas.';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT '❌ ERRO ao carregar Fato_Internacoes: ' + ERROR_MESSAGE();
    INSERT INTO etl_Rejeicoes (ds_tabela_origem, ds_motivo, ds_dados_raw)
    VALUES ('Fato_Internacoes', ERROR_MESSAGE(), 'Falha na transação de carga principal');
END CATCH;
GO

-- ==========================================================
-- 6. FATO: Fato_Indicadores_Sociais
-- ==========================================================
PRINT '🔄 Carregando Fato_Indicadores_Sociais...';

BEGIN TRANSACTION;

BEGIN TRY
    INSERT INTO Fato_Indicadores_Sociais (
        id_municipio, id_tempo, id_nivel_saneamento,
        nu_perc_esgoto_tratado, nu_perc_agua_tratada,
        vl_renda_media_per_capita, nu_idhm,
        nu_populacao, ds_ano_referencia
    )
    SELECT
        m.id_municipio,
        t.id_tempo,
        -- Classifica o nível de saneamento com base no percentual de esgoto
        ns.id_nivel_saneamento,
        TRY_CAST(REPLACE(LTRIM(RTRIM(s.nu_perc_esgoto)), ',', '.') AS DECIMAL(5,2)),
        TRY_CAST(REPLACE(LTRIM(RTRIM(s.nu_perc_agua)),   ',', '.') AS DECIMAL(5,2)),
        TRY_CAST(REPLACE(REPLACE(LTRIM(RTRIM(s.vl_renda_per_capita)), 'R$',''), ',','.') AS DECIMAL(10,2)),
        TRY_CAST(REPLACE(LTRIM(RTRIM(s.nu_idhm)), ',', '.') AS DECIMAL(5,4)),
        TRY_CAST(REPLACE(s.nu_populacao, '.', '') AS INT),
        TRY_CAST(LTRIM(RTRIM(s.nu_ano)) AS SMALLINT)
    FROM stg_Indicadores_Sociais s
    JOIN Dim_Municipio m
        ON m.co_ibge_6 = TRY_CAST(LTRIM(RTRIM(s.co_ibge_6)) AS INT)
    JOIN Dim_Tempo t
        ON t.dt_referencia = TRY_CAST(LTRIM(RTRIM(s.nu_ano)) + '-01-01' AS DATE)
    -- Lookup do nível de saneamento
    JOIN Dim_Nivel_Saneamento ns
        ON TRY_CAST(REPLACE(LTRIM(RTRIM(s.nu_perc_esgoto)), ',', '.') AS DECIMAL(5,2))
            BETWEEN ns.nu_perc_min AND ns.nu_perc_max
    WHERE s.fl_processado = 0
      AND m.id_municipio IS NOT NULL
      AND t.id_tempo IS NOT NULL
      AND NOT EXISTS (
          SELECT 1 FROM Fato_Indicadores_Sociais fi
          WHERE fi.id_municipio = m.id_municipio
            AND fi.id_tempo     = t.id_tempo
      );

    UPDATE stg_Indicadores_Sociais SET fl_processado = 1 WHERE fl_processado = 0;

    PRINT '✅ Fato_Indicadores_Sociais: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' registros inseridos.';

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    ROLLBACK TRANSACTION;
    PRINT '❌ ERRO ao carregar Fato_Indicadores_Sociais: ' + ERROR_MESSAGE();
    INSERT INTO etl_Rejeicoes (ds_tabela_origem, ds_motivo, ds_dados_raw)
    VALUES ('Fato_Indicadores_Sociais', ERROR_MESSAGE(), 'Falha na transação de carga');
END CATCH;
GO

-- ==========================================================
-- VALIDAÇÃO FINAL
-- ==========================================================
PRINT '';
PRINT '📊 Resumo de registros nas tabelas fato:';
SELECT 'Fato_Internacoes'         AS tabela, COUNT(*) AS total FROM Fato_Internacoes
UNION ALL
SELECT 'Fato_Indicadores_Sociais',            COUNT(*) FROM Fato_Indicadores_Sociais;
GO

PRINT '📊 Rejeições registradas:';
SELECT ds_tabela_origem, COUNT(*) AS total_rejeicoes
FROM etl_Rejeicoes
GROUP BY ds_tabela_origem;
GO
/* =============================================================================
   PROJETO: Monitoramento de Doenças Crônicas vs Determinantes Sociais
   SCRIPT:  01_stored_procedures.sql
   FASE:    Stored Procedures — ETL/CRUD (3) + Analíticas (2) = 5 total
   AUTOR:   ProjetoBD2026
   =============================================================================
*/

USE ProjetoBD2026;
GO

-- ==========================================================
-- SP 1 (ETL/CRUD): Registrar Internação Individual
--   Usada para inserções pontuais ou correções manuais.
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_etl_registrar_internacao
    @p_co_aih           VARCHAR(13),
    @p_co_cid           CHAR(3),
    @p_co_ibge6_mun     INT,
    @p_ds_competencia   CHAR(6),
    @p_vl_total         DECIMAL(12,2),
    @p_nu_dias_perm     SMALLINT,
    @p_co_motivo_saida  SMALLINT = NULL,
    @p_nu_idade         SMALLINT = NULL,
    @p_ds_sexo          CHAR(1)  = 'I'
AS
BEGIN
    SET NOCOUNT ON;

    -- Valida município
    IF NOT EXISTS (SELECT 1 FROM Dim_Municipio WHERE co_ibge_6 = @p_co_ibge6_mun)
    BEGIN
        RAISERROR('Município com código IBGE %d não encontrado.', 16, 1, @p_co_ibge6_mun);
        RETURN;
    END

    -- Evita duplicata por AIH
    IF EXISTS (SELECT 1 FROM Fato_Internacoes WHERE co_aih = @p_co_aih)
    BEGIN
        RAISERROR('AIH %s já existe na base.', 16, 1, @p_co_aih);
        RETURN;
    END

    DECLARE @v_id_municipio    INT;
    DECLARE @v_id_cid          INT;
    DECLARE @v_id_tempo        INT;
    DECLARE @v_id_desfecho     SMALLINT;
    DECLARE @v_id_paciente     INT;

    SELECT @v_id_municipio = id_municipio FROM Dim_Municipio WHERE co_ibge_6 = @p_co_ibge6_mun;

    SELECT @v_id_cid = id_categoria FROM Dim_CID10_Categoria
    WHERE co_categoria = UPPER(@p_co_cid);

    -- Competência AAAAMM → data
    SELECT @v_id_tempo = id_tempo FROM Dim_Tempo
    WHERE dt_referencia = TRY_CAST(LEFT(@p_ds_competencia,4)+'-'+RIGHT(@p_ds_competencia,2)+'-01' AS DATE);

    SELECT TOP 1 @v_id_desfecho = id_desfecho FROM Dim_Desfecho_Internacao
    WHERE co_desfecho = @p_co_motivo_saida;

    SELECT TOP 1 @v_id_paciente = id_paciente FROM Dim_Paciente
    WHERE nu_idade_anos = ISNULL(@p_nu_idade, 0) AND ds_sexo = @p_ds_sexo;

    BEGIN TRANSACTION;
    BEGIN TRY
        INSERT INTO Fato_Internacoes (
            id_cid10_categoria, id_municipio, id_tempo_internacao,
            id_desfecho, id_paciente,
            vl_total_internacao, nu_dias_permanencia,
            co_aih, ds_competencia,
            fl_obito
        ) VALUES (
            @v_id_cid, @v_id_municipio, @v_id_tempo,
            @v_id_desfecho, @v_id_paciente,
            @p_vl_total, @p_nu_dias_perm,
            @p_co_aih, @p_ds_competencia,
            CASE WHEN @p_co_motivo_saida IN (41,42,43) THEN 1 ELSE 0 END
        );

        COMMIT TRANSACTION;
        PRINT 'Internação ' + @p_co_aih + ' registrada com sucesso.';
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- ==========================================================
-- SP 2 (ETL/CRUD): Atualizar Indicador Social de Município
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_etl_upsert_indicador_social
    @p_co_ibge6         INT,
    @p_nu_ano           SMALLINT,
    @p_perc_esgoto      DECIMAL(5,2),
    @p_perc_agua        DECIMAL(5,2),
    @p_renda_per_capita DECIMAL(10,2) = NULL,
    @p_idhm             DECIMAL(5,4)  = NULL,
    @p_populacao        INT           = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_id_municipio     INT;
    DECLARE @v_id_tempo         INT;
    DECLARE @v_id_nivel         SMALLINT;

    SELECT @v_id_municipio = id_municipio FROM Dim_Municipio WHERE co_ibge_6 = @p_co_ibge6;
    SELECT @v_id_tempo     = id_tempo     FROM Dim_Tempo     WHERE dt_referencia = CAST(CAST(@p_nu_ano AS VARCHAR)+'-01-01' AS DATE);
    SELECT @v_id_nivel     = id_nivel_saneamento FROM Dim_Nivel_Saneamento
    WHERE @p_perc_esgoto BETWEEN nu_perc_min AND nu_perc_max;

    IF @v_id_municipio IS NULL OR @v_id_tempo IS NULL
    BEGIN
        RAISERROR('Município ou período não encontrado.', 16, 1);
        RETURN;
    END

    -- UPSERT
    IF EXISTS (
        SELECT 1 FROM Fato_Indicadores_Sociais
        WHERE id_municipio = @v_id_municipio AND id_tempo = @v_id_tempo
    )
    BEGIN
        UPDATE Fato_Indicadores_Sociais
        SET nu_perc_esgoto_tratado     = @p_perc_esgoto,
            nu_perc_agua_tratada       = @p_perc_agua,
            vl_renda_media_per_capita  = ISNULL(@p_renda_per_capita, vl_renda_media_per_capita),
            nu_idhm                    = ISNULL(@p_idhm, nu_idhm),
            nu_populacao               = ISNULL(@p_populacao, nu_populacao),
            id_nivel_saneamento        = @v_id_nivel,
            dt_carga_etl               = GETDATE()
        WHERE id_municipio = @v_id_municipio AND id_tempo = @v_id_tempo;
        PRINT 'Indicador atualizado para município ' + CAST(@p_co_ibge6 AS VARCHAR) + '.';
    END
    ELSE
    BEGIN
        INSERT INTO Fato_Indicadores_Sociais (
            id_municipio, id_tempo, id_nivel_saneamento,
            nu_perc_esgoto_tratado, nu_perc_agua_tratada,
            vl_renda_media_per_capita, nu_idhm, nu_populacao, ds_ano_referencia
        ) VALUES (
            @v_id_municipio, @v_id_tempo, @v_id_nivel,
            @p_perc_esgoto, @p_perc_agua,
            @p_renda_per_capita, @p_idhm, @p_populacao, @p_nu_ano
        );
        PRINT 'Indicador inserido para município ' + CAST(@p_co_ibge6 AS VARCHAR) + '.';
    END;
END;
GO

-- ==========================================================
-- SP 3 (ETL/CRUD): Reprocessar Staging com Erros
--   Reseta fl_processado para retentar registros rejeitados.
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_etl_reprocessar_staging
    @p_tabela VARCHAR(50) = 'TODAS'
AS
BEGIN
    SET NOCOUNT ON;

    IF @p_tabela IN ('TODAS', 'stg_Internacoes')
        UPDATE stg_Internacoes         SET fl_processado = 0 WHERE fl_processado = 1;

    IF @p_tabela IN ('TODAS', 'stg_Municipios')
        UPDATE stg_Municipios          SET fl_processado = 0 WHERE fl_processado = 1;

    IF @p_tabela IN ('TODAS', 'stg_Indicadores_Sociais')
        UPDATE stg_Indicadores_Sociais SET fl_processado = 0 WHERE fl_processado = 1;

    PRINT 'Staging ' + @p_tabela + ' resetada para reprocessamento.';
END;
GO

-- ==========================================================
-- SP 4 (ANALÍTICA): Custo Total de Internações por Saneamento
--   Responde à Pergunta de Negócio 1:
--   "Qual o custo total de internações por doenças de veiculação
--    hídrica em municípios com menos de 50% de esgoto tratado?"
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_analise_custo_por_saneamento
    @p_perc_esgoto_max  DECIMAL(5,2) = 50.00,   -- limiar de cobertura
    @p_nu_ano_inicio    SMALLINT     = 2019,
    @p_nu_ano_fim       SMALLINT     = 2024
AS
BEGIN
    SET NOCOUNT ON;

    WITH cte_mun_baixo_saneamento AS (
        -- Municípios abaixo do limiar em pelo menos 1 ano no período
        SELECT DISTINCT fi.id_municipio
        FROM Fato_Indicadores_Sociais fi
        JOIN Dim_Tempo t ON fi.id_tempo = t.id_tempo
        WHERE fi.nu_perc_esgoto_tratado < @p_perc_esgoto_max
          AND t.nu_ano BETWEEN @p_nu_ano_inicio AND @p_nu_ano_fim
    ),
    cte_internacoes_hidricas AS (
        SELECT
            m.ds_municipio,
            e.sg_uf,
            t.nu_ano,
            COUNT(f.id_internacao)              AS total_internacoes,
            SUM(f.vl_total_internacao)          AS custo_total,
            AVG(f.vl_total_internacao)          AS custo_medio,
            SUM(CAST(f.fl_obito AS INT))        AS total_obitos,
            AVG(CAST(f.nu_dias_permanencia AS DECIMAL(10,2))) AS media_dias
        FROM Fato_Internacoes f
        JOIN Dim_Municipio m         ON f.id_municipio       = m.id_municipio
        JOIN Dim_Estado e            ON m.id_estado          = e.id_estado
        JOIN Dim_Tempo t             ON f.id_tempo_internacao = t.id_tempo
        JOIN Dim_CID10_Categoria c   ON f.id_cid10_categoria  = c.id_categoria
        JOIN Dim_CID10_Grupo g       ON c.id_grupo            = g.id_grupo
        JOIN cte_mun_baixo_saneamento bs ON f.id_municipio   = bs.id_municipio
        WHERE g.fl_veiculacao_hidrica = 1
          AND t.nu_ano BETWEEN @p_nu_ano_inicio AND @p_nu_ano_fim
        GROUP BY m.ds_municipio, e.sg_uf, t.nu_ano
    )
    SELECT
        ds_municipio,
        sg_uf,
        nu_ano,
        total_internacoes,
        custo_total,
        custo_medio,
        total_obitos,
        media_dias,
        -- Ranking dentro do ano por custo
        RANK() OVER (PARTITION BY nu_ano ORDER BY custo_total DESC) AS rank_custo_ano
    FROM cte_internacoes_hidricas
    ORDER BY nu_ano, custo_total DESC;
END;
GO

-- ==========================================================
-- SP 5 (ANALÍTICA): Projeção de Economia com Universalização
--   Responde à Pergunta de Negócio 5:
--   "Se municípios com baixo saneamento atingissem a média estadual
--    de cobertura, qual seria a redução estimada nos gastos do SUS?"
-- ==========================================================
CREATE OR ALTER PROCEDURE sp_analise_projecao_economia
    @p_nu_ano       SMALLINT = 2023,
    @p_uf_filtro    CHAR(2)  = NULL   -- NULL = todos os estados
AS
BEGIN
    SET NOCOUNT ON;

    -- Custo médio de internação em municípios com alto saneamento (>= 75%)
    DECLARE @v_custo_referencia DECIMAL(12,2);

    SELECT @v_custo_referencia = AVG(f.vl_total_internacao)
    FROM Fato_Internacoes f
    JOIN Fato_Indicadores_Sociais s ON f.id_municipio = s.id_municipio
    JOIN Dim_Tempo t                ON s.id_tempo     = t.id_tempo
    WHERE s.nu_perc_esgoto_tratado >= 75
      AND t.nu_ano = @p_nu_ano;

    -- Municípios com saneamento precário e seus gastos atuais
    WITH cte_precarios AS (
        SELECT
            m.id_municipio,
            m.ds_municipio,
            e.sg_uf,
            s.nu_perc_esgoto_tratado                                AS perc_esgoto_atual,
            SUM(f.vl_total_internacao)                              AS custo_atual,
            COUNT(f.id_internacao)                                  AS qtd_internacoes,
            COUNT(f.id_internacao) * @v_custo_referencia            AS custo_projetado,
            SUM(f.vl_total_internacao) -
                COUNT(f.id_internacao) * @v_custo_referencia        AS economia_estimada
        FROM Fato_Internacoes f
        JOIN Dim_Municipio m             ON f.id_municipio       = m.id_municipio
        JOIN Dim_Estado e                ON m.id_estado          = e.id_estado
        JOIN Dim_Tempo t_f               ON f.id_tempo_internacao = t_f.id_tempo
        JOIN Fato_Indicadores_Sociais s  ON f.id_municipio       = s.id_municipio
        JOIN Dim_Tempo t_s               ON s.id_tempo           = t_s.id_tempo
        JOIN Dim_CID10_Categoria c       ON f.id_cid10_categoria  = c.id_categoria
        JOIN Dim_CID10_Grupo g           ON c.id_grupo            = g.id_grupo
        WHERE t_f.nu_ano = @p_nu_ano
          AND t_s.nu_ano = @p_nu_ano
          AND s.nu_perc_esgoto_tratado < 75
          AND g.fl_veiculacao_hidrica = 1
          AND (@p_uf_filtro IS NULL OR e.sg_uf = @p_uf_filtro)
        GROUP BY m.id_municipio, m.ds_municipio, e.sg_uf, s.nu_perc_esgoto_tratado
    )
    SELECT
        ds_municipio,
        sg_uf,
        perc_esgoto_atual,
        qtd_internacoes,
        custo_atual,
        custo_projetado,
        CASE WHEN economia_estimada > 0 THEN economia_estimada ELSE 0 END AS economia_estimada,
        @v_custo_referencia AS custo_referencia_saneado,
        -- Totais por estado
        SUM(CASE WHEN economia_estimada > 0 THEN economia_estimada ELSE 0 END)
            OVER (PARTITION BY sg_uf) AS economia_total_uf
    FROM cte_precarios
    ORDER BY economia_estimada DESC;
END;
GO

PRINT '✅ 5 Stored Procedures criadas com sucesso.';
GO
/* =============================================================================
   PROJETO: Monitoramento de Doenças Crônicas vs Determinantes Sociais
   SCRIPT:  01_funcoes.sql
   FASE:    Functions — 2 UDFs obrigatórias
   AUTOR:   ProjetoBD2026
   =============================================================================
*/

USE ProjetoBD2026;
GO

-- ==========================================================
-- FUNCTION 1 (Escalar): Classificar Nível de Saneamento
--   Retorna o rótulo do nível dado um percentual de esgoto.
--   Usada diretamente em SELECTs para evitar subqueries repetitivas.
--
--   Exemplo: SELECT dbo.fn_classificar_saneamento(35.5) → 'Precário'
-- ==========================================================
CREATE OR ALTER FUNCTION dbo.fn_classificar_saneamento
(
    @p_perc_esgoto DECIMAL(5,2)
)
RETURNS VARCHAR(30)
AS
BEGIN
    RETURN (
        SELECT TOP 1 ds_nivel
        FROM Dim_Nivel_Saneamento
        WHERE @p_perc_esgoto BETWEEN nu_perc_min AND nu_perc_max
        ORDER BY nu_perc_min
    );
END;
GO

-- ==========================================================
-- FUNCTION 2 (Tabela): Retorna Internações de um Município
--   Função com retorno de tabela (inline TVF) para ser usada
--   em JOINs nas consultas analíticas.
--
--   Exemplo:
--   SELECT * FROM dbo.fn_internacoes_municipio(355030, 2022)
--   — retorna internações de São Paulo no ano de 2022.
-- ==========================================================
CREATE OR ALTER FUNCTION dbo.fn_internacoes_municipio
(
    @p_co_ibge6 INT,
    @p_nu_ano   SMALLINT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        f.id_internacao,
        f.co_aih,
        f.ds_competencia,
        c.co_categoria                              AS co_cid,
        c.ds_categoria_abreviada                    AS ds_diagnostico,
        g.fl_veiculacao_hidrica,
        g.fl_doenca_cronica,
        t.nu_ano,
        t.nu_mes,
        f.vl_total_internacao,
        f.nu_dias_permanencia,
        f.nu_dias_uti,
        f.fl_obito,
        dbo.fn_classificar_saneamento(
            ISNULL(s.nu_perc_esgoto_tratado, 0)
        )                                           AS nivel_saneamento,
        s.nu_perc_esgoto_tratado                    AS perc_esgoto
    FROM Fato_Internacoes f
    JOIN Dim_Municipio m         ON f.id_municipio        = m.id_municipio
    JOIN Dim_CID10_Categoria c   ON f.id_cid10_categoria   = c.id_categoria
    JOIN Dim_CID10_Grupo g       ON c.id_grupo             = g.id_grupo
    JOIN Dim_Tempo t             ON f.id_tempo_internacao  = t.id_tempo
    LEFT JOIN Fato_Indicadores_Sociais s
        ON f.id_municipio = s.id_municipio
        AND s.id_tempo IN (
            SELECT id_tempo FROM Dim_Tempo WHERE nu_ano = @p_nu_ano AND nu_mes = 1
        )
    WHERE m.co_ibge_6 = @p_co_ibge6
      AND t.nu_ano    = @p_nu_ano
);
GO

PRINT '✅ 2 Functions criadas com sucesso.';
GO
/* =============================================================================
   PROJETO: Monitoramento de Doenças Crônicas vs Determinantes Sociais
   SCRIPT:  01_triggers.sql
   FASE:    Triggers — 2 triggers (auditoria + validação)
            O trigger de sincronização fl_obito já está em tables.sql.
            Este script adiciona os 2 triggers complementares.
   AUTOR:   ProjetoBD2026
   =============================================================================
*/

USE ProjetoBD2026;
GO

-- ==========================================================
-- TABELA DE AUDITORIA (necessária antes dos triggers)
-- ==========================================================
IF OBJECT_ID('audit_Internacoes', 'U') IS NULL
BEGIN
    CREATE TABLE audit_Internacoes (
        id_audit        BIGINT IDENTITY(1,1) PRIMARY KEY,
        id_internacao   BIGINT,
        ds_operacao     VARCHAR(10),          -- INSERT / UPDATE / DELETE
        ds_usuario      VARCHAR(100),
        dt_operacao     DATETIME2 DEFAULT GETDATE(),
        vl_total_antes  DECIMAL(12,2),
        vl_total_depois DECIMAL(12,2),
        fl_obito_antes  BIT,
        fl_obito_depois BIT
    );
    PRINT '✅ Tabela audit_Internacoes criada.';
END
GO

-- ==========================================================
-- TRIGGER 2: Auditoria de Alterações em Fato_Internacoes
--   Registra toda INSERT/UPDATE/DELETE na tabela de auditoria.
--   Complementa o trg_fato_int_sync_obito que já existe.
-- ==========================================================
CREATE OR ALTER TRIGGER trg_audit_internacoes
ON Fato_Internacoes
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- INSERT
    IF EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO audit_Internacoes (id_internacao, ds_operacao, ds_usuario, vl_total_depois, fl_obito_depois)
        SELECT id_internacao, 'INSERT', SYSTEM_USER, vl_total_internacao, fl_obito
        FROM inserted;
    END

    -- UPDATE
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO audit_Internacoes (id_internacao, ds_operacao, ds_usuario,
                                       vl_total_antes, vl_total_depois,
                                       fl_obito_antes, fl_obito_depois)
        SELECT
            i.id_internacao, 'UPDATE', SYSTEM_USER,
            d.vl_total_internacao, i.vl_total_internacao,
            d.fl_obito,            i.fl_obito
        FROM inserted i
        JOIN deleted d ON i.id_internacao = d.id_internacao;
    END

    -- DELETE
    IF NOT EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO audit_Internacoes (id_internacao, ds_operacao, ds_usuario, vl_total_antes, fl_obito_antes)
        SELECT id_internacao, 'DELETE', SYSTEM_USER, vl_total_internacao, fl_obito
        FROM deleted;
    END
END;
GO

-- ==========================================================
-- TRIGGER 3: Validação de Indicadores Sociais
--   Impede inserção de percentuais fora do intervalo 0-100
--   e renda negativa na Fato_Indicadores_Sociais.
-- ==========================================================
CREATE OR ALTER TRIGGER trg_validar_indicadores_sociais
ON Fato_Indicadores_Sociais
INSTEAD OF INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Rejeita linhas inválidas com mensagem clara
    IF EXISTS (
        SELECT 1 FROM inserted
        WHERE nu_perc_esgoto_tratado NOT BETWEEN 0 AND 100
           OR nu_perc_agua_tratada   NOT BETWEEN 0 AND 100
           OR (vl_renda_media_per_capita IS NOT NULL AND vl_renda_media_per_capita < 0)
           OR (nu_idhm IS NOT NULL AND nu_idhm NOT BETWEEN 0 AND 1)
    )
    BEGIN
        -- Loga na tabela de rejeições
        INSERT INTO etl_Rejeicoes (ds_tabela_origem, ds_motivo, ds_dados_raw)
        SELECT
            'Fato_Indicadores_Sociais',
            'Validação falhou: percentual fora de 0-100, renda negativa ou IDHM inválido.',
            CONCAT('id_municipio=', id_municipio,
                   ' perc_esgoto=', nu_perc_esgoto_tratado,
                   ' perc_agua=',   nu_perc_agua_tratada,
                   ' renda=',       vl_renda_media_per_capita,
                   ' idhm=',        nu_idhm)
        FROM inserted
        WHERE nu_perc_esgoto_tratado NOT BETWEEN 0 AND 100
           OR nu_perc_agua_tratada   NOT BETWEEN 0 AND 100
           OR (vl_renda_media_per_capita IS NOT NULL AND vl_renda_media_per_capita < 0)
           OR (nu_idhm IS NOT NULL AND nu_idhm NOT BETWEEN 0 AND 1);

        RAISERROR('Inserção rejeitada: dados fora dos limites válidos. Verifique etl_Rejeicoes.', 16, 1);
        RETURN;
    END

    -- Se válido, executa o INSERT normal
    INSERT INTO Fato_Indicadores_Sociais (
        id_municipio, id_tempo, id_nivel_saneamento,
        nu_perc_esgoto_tratado, nu_perc_agua_tratada,
        vl_renda_media_per_capita, nu_idhm, nu_populacao,
        ds_ano_referencia, dt_carga_etl
    )
    SELECT
        id_municipio, id_tempo, id_nivel_saneamento,
        nu_perc_esgoto_tratado, nu_perc_agua_tratada,
        vl_renda_media_per_capita, nu_idhm, nu_populacao,
        ds_ano_referencia, GETDATE()
    FROM inserted;
END;
GO

PRINT '✅ 2 Triggers adicionais criados com sucesso (+ 1 já existente em tables.sql = 3 total).';
GO
/* =============================================================================
   PROJETO: Monitoramento de Doenças Crônicas vs Determinantes Sociais
   SCRIPT:  01_views.sql
   FASE:    Views — 5 views (2 já estão em tables.sql; este script cria as 3 restantes)
   AUTOR:   ProjetoBD2026
   =============================================================================
*/

USE ProjetoBD2026;
GO

-- ==========================================================
-- VIEW 3: Painel Geral de Internações por Município e Ano
--   Consolida internações, custos e mortalidade por município/ano.
--   Usada como base para o dashboard de BI.
-- ==========================================================
CREATE OR ALTER VIEW vw_painel_internacoes_municipio AS
SELECT
    m.co_ibge_6                                         AS co_municipio,
    m.ds_municipio,
    e.sg_uf,
    r.ds_regiao                                         AS ds_regiao_geografica,
    t.nu_ano,
    t.nu_trimestre,

    -- Volume
    COUNT(f.id_internacao)                              AS total_internacoes,
    SUM(CAST(f.fl_obito AS INT))                        AS total_obitos,

    -- Financeiro
    SUM(f.vl_total_internacao)                          AS custo_total,
    AVG(f.vl_total_internacao)                          AS custo_medio,
    MAX(f.vl_total_internacao)                          AS custo_maximo,

    -- Permanência
    AVG(CAST(f.nu_dias_permanencia AS DECIMAL(10,2)))   AS media_dias_permanencia,
    SUM(f.nu_dias_uti)                                  AS total_dias_uti,

    -- Saneamento (do ano de referência)
    s.nu_perc_esgoto_tratado,
    s.nu_perc_agua_tratada,
    ns.ds_nivel                                         AS nivel_saneamento,

    -- Mortalidade proporcional
    ROUND(
        100.0 * SUM(CAST(f.fl_obito AS INT)) / NULLIF(COUNT(f.id_internacao), 0),
        2
    )                                                   AS taxa_mortalidade_perc
FROM Fato_Internacoes f
JOIN Dim_Municipio m             ON f.id_municipio        = m.id_municipio
JOIN Dim_Estado e                ON m.id_estado           = e.id_estado
JOIN Dim_Regiao_Geografica r     ON e.id_regiao           = r.id_regiao
JOIN Dim_Tempo t                 ON f.id_tempo_internacao = t.id_tempo
LEFT JOIN Fato_Indicadores_Sociais s
    ON f.id_municipio = s.id_municipio
    AND s.id_tempo IN (SELECT id_tempo FROM Dim_Tempo WHERE nu_ano = t.nu_ano AND nu_mes = 1)
LEFT JOIN Dim_Nivel_Saneamento ns ON s.id_nivel_saneamento = ns.id_nivel_saneamento
GROUP BY
    m.co_ibge_6, m.ds_municipio, e.sg_uf, r.ds_regiao,
    t.nu_ano, t.nu_trimestre,
    s.nu_perc_esgoto_tratado, s.nu_perc_agua_tratada, ns.ds_nivel;
GO

-- ==========================================================
-- VIEW 4: Correlação Saneamento × Permanência Pediátrica
--   Responde à Pergunta de Negócio 2:
--   "Existe correlação entre falta de saneamento e tempo médio
--    de permanência em leitos do SUS para pacientes pediátricos?"
-- ==========================================================
CREATE OR ALTER VIEW vw_permanencia_pediatrica_saneamento AS
SELECT
    m.ds_municipio,
    e.sg_uf,
    t.nu_ano,
    ns.ds_nivel                                                     AS nivel_saneamento,
    s.nu_perc_esgoto_tratado,
    COUNT(f.id_internacao)                                          AS internacoes_pediatricas,
    AVG(CAST(f.nu_dias_permanencia AS DECIMAL(10,2)))               AS media_dias_permanencia,
    SUM(CAST(f.fl_obito AS INT))                                    AS obitos_pediatricos
FROM Fato_Internacoes f
JOIN Dim_Municipio m             ON f.id_municipio        = m.id_municipio
JOIN Dim_Estado e                ON m.id_estado           = e.id_estado
JOIN Dim_Tempo t                 ON f.id_tempo_internacao = t.id_tempo
JOIN Dim_Paciente p              ON f.id_paciente         = p.id_paciente
JOIN Dim_Faixa_Etaria fe         ON p.id_faixa_etaria     = fe.id_faixa_etaria
LEFT JOIN Fato_Indicadores_Sociais s
    ON f.id_municipio = s.id_municipio
    AND s.id_tempo IN (SELECT id_tempo FROM Dim_Tempo WHERE nu_ano = t.nu_ano AND nu_mes = 1)
LEFT JOIN Dim_Nivel_Saneamento ns ON s.id_nivel_saneamento = ns.id_nivel_saneamento
WHERE fe.ds_grupo_etario = 'Pediátrico'   -- 0 a 12 anos
GROUP BY
    m.ds_municipio, e.sg_uf, t.nu_ano,
    ns.ds_nivel, s.nu_perc_esgoto_tratado;
GO

-- ==========================================================
-- VIEW 5: Top Municípios por Gasto per Capita
--   Responde à Pergunta de Negócio 3:
--   "Quais os 10 municípios com maior gasto por habitante em
--    doenças infectocontagiosas vs. investimento em infraestrutura?"
-- ==========================================================
CREATE OR ALTER VIEW vw_gasto_per_capita_municipio AS
SELECT
    m.co_ibge_6,
    m.ds_municipio,
    e.sg_uf,
    t.nu_ano,
    m.nu_populacao                                                      AS populacao,
    SUM(f.vl_total_internacao)                                          AS custo_infecto_total,
    ROUND(
        SUM(f.vl_total_internacao) / NULLIF(CAST(m.nu_populacao AS DECIMAL(15,2)), 0),
        4
    )                                                                   AS custo_per_capita,
    SUM(inv.vl_investimento)                                            AS investimento_infra_total,
    ROUND(
        SUM(inv.vl_investimento) / NULLIF(CAST(m.nu_populacao AS DECIMAL(15,2)), 0),
        4
    )                                                                   AS investimento_per_capita,
    -- Razão gasto/investimento (quanto se gasta em internações para cada R$1 investido)
    ROUND(
        SUM(f.vl_total_internacao) / NULLIF(SUM(inv.vl_investimento), 0),
        4
    )                                                                   AS razao_gasto_investimento
FROM Fato_Internacoes f
JOIN Dim_Municipio m             ON f.id_municipio        = m.id_municipio
JOIN Dim_Estado e                ON m.id_estado           = e.id_estado
JOIN Dim_Tempo t                 ON f.id_tempo_internacao = t.id_tempo
JOIN Dim_CID10_Categoria c       ON f.id_cid10_categoria   = c.id_categoria
JOIN Dim_CID10_Grupo g           ON c.id_grupo             = g.id_grupo
LEFT JOIN Dim_Investimento_Infraestrutura inv
    ON f.id_municipio = inv.id_municipio
    AND inv.id_tempo  = f.id_tempo_internacao
WHERE g.fl_infectocontagioso = 1
  AND m.nu_populacao > 0
GROUP BY
    m.co_ibge_6, m.ds_municipio, e.sg_uf, t.nu_ano, m.nu_populacao;
GO

PRINT '✅ 3 Views adicionais criadas (+ 2 já em tables.sql = 5 total).';
GO
/* =============================================================================
   PROJETO: Monitoramento de Doenças Crônicas vs Determinantes Sociais
   SCRIPT:  01_seguranca.sql
   FASE:    DCL — Roles, GRANT e DENY (princípio do menor privilégio)
   AUTOR:   ProjetoBD2026
   NOTAS:   As 3 Roles foram criadas em tables.sql.
            Este script atribui as permissões granulares.
   =============================================================================
*/

USE ProjetoBD2026;
GO

-- ==========================================================
-- ROLE 1: role_admin_bd
--   Acesso total — DBA / responsável pelo projeto.
--   Pode executar DDL, ETL, consultar tudo e gerenciar usuários.
-- ==========================================================

-- Acesso total a todas as tabelas
GRANT SELECT, INSERT, UPDATE, DELETE ON Fato_Internacoes              TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Fato_Indicadores_Sociais      TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_Municipio                 TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_Estado                    TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_Regiao_Geografica         TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_Regiao_Saude              TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_CID10_Capitulo            TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_CID10_Grupo               TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_CID10_Categoria           TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_Tempo                     TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_Faixa_Etaria              TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_Paciente                  TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_Desfecho_Internacao       TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_Estabelecimento_Saude     TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_Tipo_Leito                TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_Procedimento              TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_Nivel_Saneamento          TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON Dim_Investimento_Infraestrutura TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON stg_Internacoes               TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON stg_Municipios                TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON stg_CID10_Categorias          TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON stg_Indicadores_Sociais       TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON audit_Internacoes             TO role_admin_bd;
GRANT SELECT, INSERT, UPDATE, DELETE ON etl_Rejeicoes                 TO role_admin_bd;

-- Execução de todas as SPs e funções
GRANT EXECUTE ON sp_etl_registrar_internacao        TO role_admin_bd;
GRANT EXECUTE ON sp_etl_upsert_indicador_social     TO role_admin_bd;
GRANT EXECUTE ON sp_etl_reprocessar_staging         TO role_admin_bd;
GRANT EXECUTE ON sp_analise_custo_por_saneamento    TO role_admin_bd;
GRANT EXECUTE ON sp_analise_projecao_economia       TO role_admin_bd;
GRANT EXECUTE ON dbo.fn_classificar_saneamento      TO role_admin_bd;
GRANT EXECUTE ON dbo.fn_internacoes_municipio       TO role_admin_bd;

-- Views
GRANT SELECT ON vw_mortalidade_cronica_saneamento   TO role_admin_bd;
GRANT SELECT ON vw_controle_carga_mensal            TO role_admin_bd;
GRANT SELECT ON vw_painel_internacoes_municipio     TO role_admin_bd;
GRANT SELECT ON vw_permanencia_pediatrica_saneamento TO role_admin_bd;
GRANT SELECT ON vw_gasto_per_capita_municipio       TO role_admin_bd;
GO

-- ==========================================================
-- ROLE 2: role_analista_bi
--   Acesso de leitura — Analista de dados / Power BI.
--   Pode consultar views e executar SPs analíticas.
--   NÃO pode alterar dados ou acessar stagings.
-- ==========================================================

-- Leitura somente nas tabelas dimensão e fato
GRANT SELECT ON Fato_Internacoes               TO role_analista_bi;
GRANT SELECT ON Fato_Indicadores_Sociais       TO role_analista_bi;
GRANT SELECT ON Dim_Municipio                  TO role_analista_bi;
GRANT SELECT ON Dim_Estado                     TO role_analista_bi;
GRANT SELECT ON Dim_Regiao_Geografica          TO role_analista_bi;
GRANT SELECT ON Dim_Regiao_Saude               TO role_analista_bi;
GRANT SELECT ON Dim_CID10_Capitulo             TO role_analista_bi;
GRANT SELECT ON Dim_CID10_Grupo                TO role_analista_bi;
GRANT SELECT ON Dim_CID10_Categoria            TO role_analista_bi;
GRANT SELECT ON Dim_Tempo                      TO role_analista_bi;
GRANT SELECT ON Dim_Faixa_Etaria               TO role_analista_bi;
GRANT SELECT ON Dim_Paciente                   TO role_analista_bi;
GRANT SELECT ON Dim_Desfecho_Internacao        TO role_analista_bi;
GRANT SELECT ON Dim_Nivel_Saneamento           TO role_analista_bi;

-- SPs analíticas apenas
GRANT EXECUTE ON sp_analise_custo_por_saneamento    TO role_analista_bi;
GRANT EXECUTE ON sp_analise_projecao_economia       TO role_analista_bi;
GRANT EXECUTE ON dbo.fn_classificar_saneamento      TO role_analista_bi;
GRANT EXECUTE ON dbo.fn_internacoes_municipio       TO role_analista_bi;

-- Views analíticas
GRANT SELECT ON vw_mortalidade_cronica_saneamento    TO role_analista_bi;
GRANT SELECT ON vw_painel_internacoes_municipio      TO role_analista_bi;
GRANT SELECT ON vw_permanencia_pediatrica_saneamento TO role_analista_bi;
GRANT SELECT ON vw_gasto_per_capita_municipio        TO role_analista_bi;

-- Bloqueia explicitamente acesso a stagings e auditoria
DENY SELECT ON stg_Internacoes        TO role_analista_bi;
DENY SELECT ON stg_Municipios         TO role_analista_bi;
DENY SELECT ON stg_CID10_Categorias   TO role_analista_bi;
DENY SELECT ON stg_Indicadores_Sociais TO role_analista_bi;
DENY SELECT ON audit_Internacoes      TO role_analista_bi;
DENY SELECT ON etl_Rejeicoes          TO role_analista_bi;
GO

-- ==========================================================
-- ROLE 3: role_operador_etl
--   Acesso operacional — responsável por rodar o pipeline ETL.
--   Pode inserir/atualizar stagings e executar SPs de ETL.
--   NÃO pode deletar dados das tabelas fato nem acessar auditoria.
-- ==========================================================

-- Inserção e leitura nas stagings
GRANT SELECT, INSERT, UPDATE ON stg_Internacoes         TO role_operador_etl;
GRANT SELECT, INSERT, UPDATE ON stg_Municipios          TO role_operador_etl;
GRANT SELECT, INSERT, UPDATE ON stg_CID10_Categorias    TO role_operador_etl;
GRANT SELECT, INSERT, UPDATE ON stg_Indicadores_Sociais TO role_operador_etl;

-- Inserção nas fatos (carga ETL)
GRANT INSERT ON Fato_Internacoes          TO role_operador_etl;
GRANT INSERT ON Fato_Indicadores_Sociais  TO role_operador_etl;

-- Leitura nas dimensões (para fazer lookups durante ETL)
GRANT SELECT ON Dim_Municipio             TO role_operador_etl;
GRANT SELECT ON Dim_Estado                TO role_operador_etl;
GRANT SELECT ON Dim_Regiao_Geografica     TO role_operador_etl;
GRANT SELECT ON Dim_CID10_Categoria       TO role_operador_etl;
GRANT SELECT ON Dim_CID10_Grupo           TO role_operador_etl;
GRANT SELECT ON Dim_Tempo                 TO role_operador_etl;
GRANT SELECT ON Dim_Faixa_Etaria          TO role_operador_etl;
GRANT SELECT ON Dim_Desfecho_Internacao   TO role_operador_etl;
GRANT SELECT ON Dim_Nivel_Saneamento      TO role_operador_etl;
GRANT SELECT ON etl_Rejeicoes             TO role_operador_etl;
GRANT INSERT ON etl_Rejeicoes             TO role_operador_etl;

-- SPs de ETL
GRANT EXECUTE ON sp_etl_registrar_internacao    TO role_operador_etl;
GRANT EXECUTE ON sp_etl_upsert_indicador_social TO role_operador_etl;
GRANT EXECUTE ON sp_etl_reprocessar_staging     TO role_operador_etl;

-- View de controle de carga
GRANT SELECT ON vw_controle_carga_mensal TO role_operador_etl;

-- Bloqueia explicitamente deleção e acesso a dados sensíveis
DENY DELETE ON Fato_Internacoes          TO role_operador_etl;
DENY DELETE ON Fato_Indicadores_Sociais  TO role_operador_etl;
DENY SELECT ON audit_Internacoes         TO role_operador_etl;
GO

PRINT '✅ Permissões DCL aplicadas às 3 Roles com sucesso.';
GO
