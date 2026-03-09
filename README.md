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
| **Socioeconômico** | IBGE  | [Ver Indicadores](https://www.ibge.gov.br/explica/codigos-dos-municipios.php) |
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

[ ] Fase 1: Modelagem do Banco (DER)

[ ] Fase 2: Processo de ETL (Python/SQL)

[ ] Fase 3: Construção do Data Warehouse

[ ] Fase 4: Dashboards e Consultas Finais
