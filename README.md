# ProjetoBD2026

# 📊 PROJETO DE GERENCIAMENTO DE BANCO DE DADOS

## Tema Escolhido

**Monitoramento de Doenças Crônicas vs Determinantes Sociais**

---

## 📌 Fontes de Dados

* DataSUS – Dados do SIH/SUS (Sistema de Informações Hospitalares)
* IBGE – Indicadores socioeconômicos e de saneamento

---

## 🎯 Problema de Negócio

O Brasil apresenta desigualdade regional significativa no acesso ao saneamento básico. Ao mesmo tempo, doenças infectocontagiosas continuam gerando altos custos hospitalares.

### Pergunta Central

> **Qual a correlação entre a falta de saneamento básico em determinadas regiões e o custo de internações por doenças infectocontagiosas?**

---

## 📦 Descrição dos Datasets

### 1️⃣ SIH/SUS – Internações Hospitalares

**Origem:** DataSUS

**Principais dados disponíveis:**

* Código do CID
* Município
* Estado
* Data da internação
* Idade do paciente
* Sexo
* Valor total da internação
* Procedimento realizado
* Estabelecimento de saúde

**Volume estimado:**
Milhões de registros por ano (será possível filtrar aproximadamente 5 anos para garantir mais de 200.000 registros na tabela fato principal).

---

### 2️⃣ Indicadores Socioeconômicos – IBGE

**Origem:** IBGE

**Possíveis variáveis:**

* % de domicílios com acesso a esgoto
* % de domicílios com coleta de lixo
* Renda média per capita
* Índice de desenvolvimento municipal
* População por município
* Densidade demográfica

---

## 🔎 Análise Exploratória Inicial (Semana 1)

### ✔ Volume de Dados

* Quantidade de registros de internações por ano
* Quantidade de municípios cobertos
* Total gasto por ano

### ✔ Principais CIDs Infectocontagiosos

* Filtro do grupo CID **A00–B99** (Doenças infecciosas e parasitárias)

### ✔ Tendência Temporal

* Análise do crescimento ou redução do custo hospitalar ao longo dos anos

---

## 🎯 Objetivo da Primeira Entrega

* Definição clara do problema de negócio
* Identificação das fontes de dados
* Descrição inicial dos datasets
* Direcionamento analítico para as próximas fases (modelagem e ETL)
