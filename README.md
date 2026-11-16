# Projeto Olist Marketplace

Estou desenvolvendo este projeto para aprofundar meus conhecimentos em engenharia de dados e praticar a construção de um fluxo confiável, desde a ingestão até a disponibilização dos dados para análise.

Uso o conjunto público da Olist, formado por arquivos CSV de e-commerce. Com ele, estou trabalhando conceitos de orquestração, armazenamento em nuvem, modelagem dimensional, qualidade de dados e consumo analítico.

## Objetivos técnicos

Neste projeto, quero:
- orquestrar a ingestão com Apache Airflow;
- executar localmente os serviços com Docker Compose;
- converter CSV para Parquet usando Python e Polars;
- armazenar os arquivos no Google Cloud Storage, organizados por tabela e data de extração;
- consultar os arquivos no BigQuery por meio de tabelas externas na camada Raw;
- transformar e validar os dados com Dataform nas camadas Silver e Gold;
- disponibilizar dimensões e fatos para análise no Power BI;
- praticar rastreabilidade, repetibilidade e tratamento de falhas.

## Arquitetura

```text
Arquivos CSV da Olist
        ↓
Python + Polars: leitura e conversão para Parquet
        ↓
Apache Airflow em Docker Compose: orquestração
        ↓
Google Cloud Storage: arquivos organizados por tabela e data
        ↓
BigQuery: tabelas externas na camada Raw
        ↓
Dataform: transformações e validações Silver → Gold
        ↓
Power BI: análise dos dados
```

O Airflow coordena a execução e registra o resultado das tarefas. O código em `src/extract.py` localiza os CSVs, converte os dados para Parquet e envia os arquivos ao bucket. As transformações analíticas ficam no BigQuery/Dataform.

No ambiente local, o Docker Compose separa os serviços do Airflow. O PostgreSQL armazena os metadados das execuções, o Redis funciona como broker do Celery e os componentes do Airflow cuidam da API, do agendamento, do processamento das DAGs e da execução das tarefas.

## Camadas de dados

**Raw:** mantenho os arquivos Parquet no Google Cloud Storage e consulto esses arquivos no BigQuery por meio de tabelas externas. A organização por data ajuda a rastrear as extrações.

**Silver:** preparo os dados para análise, padronizando tipos e valores e aplicando regras de qualidade sem perder as chaves necessárias para relacionar as entidades.

**Gold:** organizo os dados em modelos dimensionais. Cada fato deve ter um grão definido, como uma linha por pedido ou uma linha por item do pedido; dimensões descrevem entidades como clientes, produtos e vendedores.

## Confiabilidade e qualidade

Os objetos do bucket são organizados por tabela e data de extração. O caminho determinístico permite que uma tentativa repetida da mesma execução use o mesmo destino.

O extrator verifica se a pasta de dados existe, se há CSVs para processar e se arquivos diferentes não foram mapeados para o mesmo nome de tabela Raw. A DAG está configurada com novas tentativas quando uma tarefa falha.

No Dataform, comecei a criar assertions para encontrar problemas como chaves nulas ou duplicadas. Quero ampliar as validações para relacionamentos, datas e regras de negócio e comparar contagens entre Raw, Silver e Gold.

As credenciais do Google Cloud são fornecidas localmente por Application Default Credentials. O arquivo `.env`, as credenciais, os CSVs e o relatório do Power BI não devem ser enviados ao GitHub.

## Tecnologias

- Python, Polars e UV
- Apache Airflow com CeleryExecutor
- Docker Compose
- PostgreSQL e Redis
- Google Cloud Storage
- BigQuery e Dataform
- Power BI

## Execução local

### Pré-requisitos

- Docker Desktop com Docker Compose v2;
- Google Cloud CLI autenticado e com permissão de gravação no bucket;
- arquivos CSV da Olist na pasta `data/`;
- arquivo `.env` configurado com as variáveis usadas pelo `docker-compose.yml`;
- credenciais ADC disponíveis no Windows.

Para configurar as credenciais ADC, uso:

```powershell
gcloud auth application-default login
Test-Path "$env:APPDATA\gcloud\application_default_credentials.json"
```

Se o arquivo já existir, não preciso autenticar novamente. O Compose monta as credenciais como somente leitura nos containers. Se eu quiser preparar as dependências Python fora do Docker, uso `uv sync`.

Para iniciar o Airflow, executo na raiz do projeto:

```powershell
docker compose build
docker compose up airflow-init
docker compose up -d
```

Depois, acesso [http://localhost:8080](http://localhost:8080), abro a DAG `olist_csv_to_gcs` e uso **Trigger DAG** para iniciar uma execução manual.

Para acompanhar os serviços e seus logs:

```powershell
docker compose ps
docker compose logs --tail 100 airflow-worker airflow-scheduler airflow-apiserver
```

Para parar os containers sem apagar o banco local e o histórico do Airflow, uso `docker compose down`. O comando `docker compose down --volumes` também remove o volume do PostgreSQL.

## Agendamento e origem dos dados

Configurei a DAG para executar diariamente às 09:00 no fuso `America/Sao_Paulo`. Como o Airflow está rodando localmente, meu computador e os containers precisam estar ativos nesse horário.

O conjunto público da Olist é estático. Enquanto eu usar os mesmos arquivos, as execuções diárias enviarão novamente os mesmos dados em caminhos associados a novas datas. Isso me permite praticar o histórico de ingestão, mas não representa uma fonte que realmente se atualiza todos os dias.

## Status e próximos passos

Estou montando a ingestão local com Airflow e Docker e desenvolvendo os modelos SQL do BigQuery/Dataform. Meus próximos passos são:

1. concluir as tabelas externas Raw e conferir os esquemas;
2. alinhar as consultas Silver para consumirem as tabelas Raw;
3. executar as transformações no Dataform e ampliar as assertions;
4. validar contagens, chaves e relacionamentos entre as camadas;
5. finalizar os modelos Gold para análise de pedidos e vendas;
6. conectar o Power BI e validar indicadores e filtros de período.

Algumas consultas Silver ainda possuem referências a `Bronze.*`. Como defini `Raw` como camada de origem, preciso alinhar essas referências antes de executar as transformações.

Este projeto é uma forma de aprender construindo. Quero conseguir explicar de onde os dados vieram, o que foi transformado em cada camada e como validei os resultados.
