# 📊 Monitoramento de Doenças Crônicas vs. Determinantes Sociais
> **Projeto de Gerenciamento de Banco de Dados 2026**

![Status](https://img.shields.io/badge/Status-Em_Desenvolvimento-blue?style=for-the-badge)
![ADS](https://img.shields.io/badge/Curso-ADS-orange?style=for-the-badge)
![SQL](https://img.shields.io/badge/Focus-PostgreSQL_/_SQL-green?style=for-the-badge)

---

## 🎯 Resumo do Problema
O Brasil apresenta desigualdade regional significativa no acesso ao saneamento básico. Doenças infectocontagiosas e crônicas agravadas por condições sanitárias precárias geram altos custos hospitalares para o SUS.

> **Missão:** Integrar dados de saúde e indicadores socioeconômicos para identificar padrões que possam orientar políticas públicas e investimentos em infraestrutura sanitária.

---

## 📌 Arquitetura de Dados (Fontes)

| Tipo de Dado | Fonte | Link de Acesso |
| :--- | :--- | :--- |
| **Hospitalares** | DataSUS (SIH/SUS) | [Acessar Base](https://datasus.saude.gov.br/transferencia-de-arquivos/) |
| **Classificação** | Tabela CID-10 | [Ver Tabela](http://www2.datasus.gov.br/cid10/V2008/descrcsv.htm) |
| **Socioeconômico** | IBGE  | [Ver Indicadores](https://www.ibge.gov.br/explica/codigos-dos-municipios.php) |
| **Socioeconômico²** | SIDRA | [Ver Indicadores](https://sidra.ibge.gov.br/home/ipp/brasil) |
| **Integrados** | Base dos Dados | [Explorar Dataset](https://basedosdados.org/dataset/08a1546e-251f-4546-9fe0-b1e6ab2b203d?table=17cf3744-4624-4859-a028-0f8d2d0a08c6) |

---

## 📦 Detalhamento dos Datasets

<details>
<summary><b>1️⃣ SIH/SUS – Internações Hospitalares (Clique para expandir)</b></summary>

* **Origem:** DataSUS
* **Volume:** +200.000 registros (Filtro de 5 anos).
* **Campos:** Código CID, Município/Estado, Data, Idade, Sexo, Valor Total, Procedimento, Desfecho (Alta/Óbito).
</details>

<details>
<summary><b>2️⃣ Indicadores Socioeconômicos – IBGE (Clique para expandir)</b></summary>

* **Origem:** IBGE / SIDRA
* **Variáveis:** Acesso a esgoto/lixo, Renda per capita, IDM, População e Investimento em infraestrutura.
</details>

<details>
<summary><b>🗺️ Padronização Geográfica</b></summary>

A integração entre os datasets é realizada via **Código Oficial de Municípios do IBGE**, garantindo a integridade dos relacionamentos.
</details>

---

## 📐 Modelo de Dados (ERD)

Abaixo está a representação visual da modelagem **Star Schema** com derivações **Snowflake**. O modelo utiliza chaves substitutas (Surrogate Keys) para otimização e flags de classificação para análise de saúde pública.

```mermaid
erDiagram
    %% --- FATOS ---
    Fato_Internacoes {
        int id_internacao PK
        int id_cid10_categoria FK
        int id_municipio FK
        int id_tempo_internacao FK
        int id_tempo_alta FK
        int id_paciente FK
        int id_estabelecimento FK
        int id_procedimento FK
        int id_desfecho FK
        int id_tipo_leito FK
        decimal vl_total_internacao
        int nu_dias_permanencia
        boolean fl_obito
    }

    Fato_Indicadores_Sociais {
        int id_indicador PK
        int id_municipio FK
        int id_tempo FK
        int id_nivel_saneamento FK
        float nu_perc_esgoto_tratado
        float nu_perc_agua_tratada
        decimal vl_renda_media_per_capita
        int nu_populacao
    }

    %% --- DIMENSÕES GEOGRÁFICAS ---
    Dim_Municipio {
        int id_municipio PK
        int id_estado FK
        int id_regiao_saude FK
        string ds_municipio
        int nu_populacao
    }

    Dim_Estado {
        int id_estado PK
        int id_regiao FK
        string sg_uf
        string ds_estado
    }

    Dim_Regiao_Saude {
        int id_regiao_saude PK
        int id_estado FK
        string ds_regiao_saude
    }

    Dim_Regiao_Geografica {
        int id_regiao PK
        string sg_regiao
    }

    %% --- DIMENSÕES SAÚDE / CID10 ---
    Dim_CID10_Categoria {
        int id_categoria PK
        int id_grupo FK
        string ds_categoria
    }

    Dim_CID10_Grupo {
        int id_grupo PK
        int id_capitulo FK
        string ds_grupo
        boolean fl_veiculacao_hidrica
        boolean fl_doenca_cronica
    }

    Dim_CID10_Capitulo {
        int id_capitulo PK
        string ds_capitulo
        boolean fl_infectocontagioso
    }

    %% --- OUTRAS DIMENSÕES ---
    Dim_Tempo {
        int id_tempo PK
        date dt_referencia
        int nu_ano
        int nu_mes
    }

    Dim_Paciente {
        int id_paciente PK
        int id_faixa_etaria FK
        string ds_sexo
        string ds_raca_cor
    }

    Dim_Investimento_Infraestrutura {
        int id_investimento PK
        int id_municipio FK
        int id_tempo FK
        decimal vl_investimento
    }

    Dim_Nivel_Saneamento {
        int id_nivel_saneamento PK
        string ds_level
        string co_cor_hex
    }

    %% --- RELACIONAMENTOS ---
    Fato_Internacoes }|--|| Dim_Tempo : "internacao/alta"
    Fato_Internacoes }|--|| Dim_Municipio : "localidade"
    Fato_Internacoes }|--|| Dim_CID10_Categoria : "diagnostico"
    Fato_Internacoes }|--|| Dim_Paciente : "paciente"
    
    Fato_Indicadores_Sociais }|--|| Dim_Tempo : "periodo"
    Fato_Indicadores_Sociais }|--|| Dim_Municipio : "localidade"
    Fato_Indicadores_Sociais }|--|| Dim_Nivel_Saneamento : "classificacao"

    Dim_Investimento_Infraestrutura }|--|| Dim_Tempo : "periodo"
    Dim_Investimento_Infraestrutura }|--|| Dim_Municipio : "localidade"

    Dim_Municipio }|--|| Dim_Estado : "pertence"
    Dim_Municipio }|--|| Dim_Regiao_Saude : "vinculo"
    Dim_Estado }|--|| Dim_Regiao_Geografica : "regiao"
    
    Dim_CID10_Categoria }|--|| Dim_CID10_Grupo : "grupo"
    Dim_CID10_Grupo }|--|| Dim_CID10_Capitulo : "capitulo"

---

## 🔎 Análise Exploratória (Semana 1)

```diff
+ Volume: Quantidade de registros e cobertura municipal.
+ CIDs Alvo: A00 a B99 (Infecciosas e Parasitárias).
+ Tendência: Evolução temporal de gastos e óbitos.

📊 Perguntas Analíticas (Business Intelligence)
Para responder a essas perguntas, o banco utilizará JOINs complexos, Subqueries e Common Table Expressions (CTEs).

Impacto Financeiro: Qual o custo total acumulado de internações por doenças de veiculação hídrica
em municípios onde menos de 50% da população possui esgoto tratado?

Eficiência Hospitalar: Existe correlação entre a falta de saneamento básico
e o tempo médio de permanência (dias) em leitos do SUS para pacientes pediátricos (0-12 anos)?

Análise Regional: Quais são os 10 municípios que apresentam o maior gasto público
por habitante em doenças infectocontagiosas em relação ao seu índice de investimento em infraestrutura?

Taxa de Mortalidade: Qual a proporção de óbitos hospitalares em internações
por doenças crônicas agravadas por condições sanitárias precárias em comparação a regiões saneadas?.

Simulação: Se os municípios com baixo saneamento atingissem a média estadual de cobertura,
qual seria a redução estimada (em R$) nos gastos hospitalares do SIH/SUS?.

🚀 Roadmap de Execução
[x] Definição do Escopo e Fontes

[x] Fase 1: Modelagem do Banco (DER)

[ ] Fase 2: Processo de ETL (Python/SQL)

[ ] Fase 3: Construção do Data Warehouse

[ ] Fase 4: Dashboards e Consultas Finais
