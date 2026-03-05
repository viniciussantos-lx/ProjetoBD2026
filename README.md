ProjetoBD2026
📊 PROJETO DE GERENCIAMENTO DE BANCO DE DADOS
Tema Escolhido

Monitoramento de Doenças Crônicas vs Determinantes Sociais

📌 Fontes de Dados

Os dados utilizados no projeto serão obtidos de bases públicas do governo brasileiro, permitindo a integração entre informações de saúde e indicadores socioeconômicos.

🏥 Dados de Saúde

DataSUS – Sistema de Informações Hospitalares (SIH/SUS)
🔗 https://datasus.saude.gov.br/transferencia-de-arquivos/

Tabela CID-10 – Classificação Internacional de Doenças
🔗 http://www2.datasus.gov.br/cid10/V2008/descrcsv.htm

📊 Dados Socioeconômicos

IBGE – Indicadores socioeconômicos e de saneamento
🔗 https://sidra.ibge.gov.br/home/ipp/brasil

Base de Dados Sociais Integradas (Base dos Dados)
🔗 https://basedosdados.org/dataset/08a1546e-251f-4546-9fe0-b1e6ab2b203d?table=17cf3744-4624-4859-a028-0f8d2d0a08c6

🗺️ Padronização Geográfica

Para garantir a integração correta entre os datasets será utilizado o código oficial dos municípios do IBGE.

Código dos Municípios (IBGE)
🔗 https://www.ibge.gov.br/explica/codigos-dos-municipios.php

🎯 Problema de Negócio

O Brasil apresenta desigualdade regional significativa no acesso ao saneamento básico. Ao mesmo tempo, doenças infectocontagiosas e crônicas agravadas por condições sanitárias precárias continuam gerando altos custos hospitalares para o SUS.

A integração entre dados de saúde e indicadores socioeconômicos permite identificar padrões importantes para orientar políticas públicas e investimentos em infraestrutura sanitária.

📦 Descrição dos Datasets
1️⃣ SIH/SUS – Internações Hospitalares

Origem: DataSUS

Principais dados disponíveis

Código do CID

Município de residência

Estado

Data da internação

Idade do paciente

Sexo

Valor total da internação

Procedimento realizado

Estabelecimento de saúde

Tempo de permanência hospitalar

Desfecho da internação (alta ou óbito)

Volume estimado

Milhões de registros por ano.
Para o projeto serão filtrados aproximadamente 5 anos de dados, garantindo uma base com mais de 200.000 registros na tabela fato principal.

2️⃣ Indicadores Socioeconômicos – IBGE

Origem: IBGE / SIDRA

Possíveis variáveis

% de domicílios com acesso a esgoto

% de domicílios com coleta de lixo

Renda média per capita

Índice de desenvolvimento municipal

População por município

Densidade demográfica

Investimento em infraestrutura

Esses dados permitirão cruzar condições socioeconômicas com impactos na saúde pública.

🔎 Análise Exploratória Inicial (Semana 1)
✔ Volume de Dados

Quantidade de registros de internações por ano

Quantidade de municípios cobertos

Total gasto por ano com internações

✔ Principais CIDs Infectocontagiosos

Filtro do grupo CID:

A00 – B99 (Doenças infecciosas e parasitárias)

Essas doenças frequentemente estão associadas a:

Falta de saneamento básico

Água contaminada

Condições sanitárias inadequadas

✔ Tendência Temporal

Análise da evolução ao longo dos anos:

Crescimento ou redução das internações

Variação dos gastos hospitalares

Mudanças regionais nos padrões de doença

📊 Perguntas Analíticas (Consultas SQL Complexas)

O projeto buscará responder perguntas analíticas que exigem JOINs entre bases de dados, agregações e subqueries.

1️⃣ Impacto Financeiro

Qual o custo total acumulado de internações por doenças de veiculação hídrica em municípios onde menos de 50% da população possui esgoto tratado?

Consulta envolvendo:

JOIN entre SIH/SUS e dados de saneamento do IBGE

Filtro de CIDs relacionados a doenças hídricas

SUM de gastos hospitalares

2️⃣ Eficiência Hospitalar

Existe correlação entre a falta de saneamento básico e o tempo médio de permanência em leitos do SUS para pacientes pediátricos (0–12 anos)?

Consulta envolvendo:

JOIN entre indicadores sociais e dados hospitalares

AVG de dias de internação

Filtro por faixa etária

3️⃣ Análise Regional

Quais são os 10 municípios que apresentam o maior gasto público por habitante em doenças infectocontagiosas em relação ao seu índice de investimento em infraestrutura?

Consulta envolvendo:

JOIN entre dados populacionais e hospitalares

Cálculo de gasto per capita

Ordenação e ranking

4️⃣ Perfil de Gravidade

Qual a proporção de óbitos hospitalares em internações por doenças crônicas agravadas por condições sanitárias precárias em comparação a regiões com maior cobertura de saneamento?

Consulta envolvendo:

Agrupamento por região ou município

Cálculo de taxa de mortalidade hospitalar

Comparação entre diferentes níveis de saneamento

5️⃣ Projeção de Economia

Se os municípios com baixo saneamento atingissem a média estadual de cobertura, qual seria a redução estimada nos gastos hospitalares do SIH/SUS?

Consulta envolvendo:

Subqueries

Simulação de cenário

Comparação entre gasto atual e gasto projetado

🎯 Objetivo da Primeira Entrega

Definição clara do problema de negócio

Identificação das fontes de dados

Descrição inicial dos datasets

Definição das perguntas analíticas

Direcionamento para as próximas fases do projeto:

Próximas etapas

1️⃣ Modelagem do Banco de Dados
2️⃣ Processo de ETL
3️⃣ Construção do Data Warehouse
4️⃣ Consultas Analíticas e Dashboards
