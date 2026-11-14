# Projeto Olist: meu estudo de um fluxo de dados confiável

Estou desenvolvendo este projeto para praticar engenharia e análise de dados usando o conjunto público da Olist. Quero entender como levar os dados desde os arquivos de origem até um modelo que possa ser usado em análises e relatórios.

Mais do que fazer os arquivos chegarem à nuvem, quero aprender a organizar cada etapa, acompanhar as execuções e conferir se os dados foram processados corretamente.

## O que estou praticando

Neste projeto, estou trabalhando com:

- leitura de arquivos CSV com Python;
- conversão dos dados para Parquet com Polars;
- envio dos arquivos para o Google Cloud Storage;
- orquestração das tarefas com Apache Airflow;
- execução local dos serviços usando Docker;
- organização dos dados no BigQuery nas camadas Raw, Silver e Gold;
- transformação dos dados com Dataform;
- validações para encontrar problemas como chaves nulas ou duplicadas;
- conexão das tabelas analíticas ao Power BI.

## Como estou organizando o fluxo

```text
Arquivos CSV da Olist
        ↓
Airflow executado localmente em Docker
        ↓
Python e Polars convertem CSV para Parquet
        ↓
Google Cloud Storage guarda os arquivos por tabela e data
        ↓
BigQuery disponibiliza os dados na camada Raw
        ↓
Dataform transforma os dados para Silver e Gold
        ↓
Power BI consome os modelos analíticos
```

Eu uso o Airflow para coordenar as tarefas. O código Python faz a conversão e o envio dos arquivos. Depois, deixo as transformações analíticas para o BigQuery e o Dataform.

## Por que estou usando essas camadas

- **Raw:** mantenho os dados recebidos no formato Parquet e crio tabelas externas no BigQuery para consultá-los.
- **Silver:** preparo os dados para uso analítico, ajustando tipos, padronizando valores e aplicando validações.
- **Gold:** organizo dimensões e fatos para responder perguntas de negócio e alimentar o Power BI.

Essa separação me ajuda a identificar em qual etapa preciso investigar quando encontro um problema.

## Cuidados que estou colocando no fluxo

Estou organizando os arquivos do bucket por tabela e data de extração. Assim consigo identificar quando cada conjunto foi enviado. O caminho de saída é previsível, então uma tentativa repetida da mesma execução reutiliza o mesmo destino.

No extrator, verifico se a pasta de origem existe, se há arquivos CSV para processar e se dois arquivos não foram associados ao mesmo nome de tabela Raw. No Airflow, configurei novas tentativas quando uma tarefa falha.

Também estou começando a criar assertions no Dataform. Uma delas procura pedidos com `order_id` nulo ou repetido. Quero ampliar essas verificações para conferir datas, valores e relacionamentos entre as tabelas.

As credenciais do Google Cloud são fornecidas localmente pelo Application Default Credentials. O arquivo `.env` guarda configurações locais e não deve ser enviado ao GitHub. Também deixo os dados CSV e o arquivo do Power BI fora do repositório.

## Tecnologias que estou usando

- Python
- Polars
- Apache Airflow
- Docker Compose
- PostgreSQL para os metadados do Airflow
- Redis para a fila do Celery
- Google Cloud Storage
- BigQuery
- Dataform
- Power BI

## Como estou executando localmente

### O que preciso ter

- Docker Desktop com Docker Compose v2;
- Google Cloud CLI autenticado e com acesso de gravação no bucket;
- arquivos CSV da Olist dentro da pasta `data/`;
- um arquivo `.env` com as configurações locais do projeto e do Airflow.

No Windows, uso Application Default Credentials para autenticar o acesso ao Google Cloud:

```powershell
gcloud auth application-default login
Test-Path "$env:APPDATA\gcloud\application_default_credentials.json"
```

Se o arquivo de credenciais já existir, não preciso autenticar novamente. Mantenho o `.env` apenas no meu ambiente local e não uso os segredos de desenvolvimento em produção.

### Iniciar o Airflow

Na pasta do projeto, executo:

```powershell
docker compose build
docker compose up airflow-init
docker compose up -d
```

Depois, acesso [http://localhost:8080](http://localhost:8080), abro o DAG `olist_csv_to_gcs` e uso **Trigger DAG** para iniciar uma execução manual.

Também configurei o DAG para executar diariamente às 09:00 no fuso `America/Sao_Paulo`. Como o Airflow está rodando localmente, meu computador e os containers precisam estar ligados nesse horário.

Para acompanhar os serviços, uso:

```powershell
docker compose ps
docker compose logs --tail 100 airflow-worker airflow-scheduler airflow-apiserver
```

Para parar os containers sem apagar o banco local e o histórico do Airflow:

```powershell
docker compose down
```

O comando `docker compose down --volumes` também apaga o banco de metadados local.

## Como os arquivos ficam no bucket

Estou convertendo os arquivos para Parquet e organizando os destinos por nome de tabela e data:

| Arquivo CSV | Tabela Raw | Destino no bucket |
|---|---|---|
| `olist_customers_dataset.csv` | `customers` | `raw/customers/data_extracao=AAAA-MM-DD/customers.parquet` |
| `olist_order_items_dataset.csv` | `order_items` | `raw/order_items/data_extracao=AAAA-MM-DD/order_items.parquet` |
| `olist_orders_dataset.csv` | `orders` | `raw/orders/data_extracao=AAAA-MM-DD/orders.parquet` |
| `olist_products_dataset.csv` | `products` | `raw/products/data_extracao=AAAA-MM-DD/products.parquet` |
| `olist_sellers_dataset.csv` | `sellers` | `raw/sellers/data_extracao=AAAA-MM-DD/sellers.parquet` |
| `product_category_name_translation.csv` | `product_category_name_translation` | `raw/product_category_name_translation/data_extracao=AAAA-MM-DD/product_category_name_translation.parquet` |

O conjunto público da Olist não é atualizado diariamente. Por isso, enquanto eu usar os mesmos arquivos, cada execução agendada enviará novamente o mesmo conteúdo em uma nova pasta de data. Estou usando essa organização para praticar o histórico de ingestão; quando a fonte for atualizada, vou precisar definir como capturar somente as mudanças e evitar armazenamento desnecessário.

## Em que ponto o projeto está

Já preparei a ingestão local com Airflow e Docker, a conversão dos arquivos para Parquet e o envio ao Google Cloud Storage. Também comecei a estruturar os modelos SQL das camadas Silver e Gold.

Ainda preciso concluir e validar as tabelas externas no BigQuery Raw e alinhar as consultas Silver com elas. Alguns SQLs atuais ainda usam referências a `Bronze.*`, mas a camada de origem que estou adotando neste projeto é `Raw.*`. Vou corrigir essa diferença antes de executar os modelos no Dataform.

## O que pretendo fazer em seguida

1. Concluir as tabelas externas Raw e conferir seus esquemas.
2. Ajustar os SQLs Silver para consumir as tabelas Raw.
3. Executar as transformações no Dataform e ampliar as assertions.
4. Conferir contagens, chaves e datas entre as camadas.
5. Finalizar as tabelas Gold para análise de pedidos, vendas e produtos.
6. Conectar o Power BI e validar os indicadores e filtros de período.
7. Depois de consolidar o fluxo local, estudar como executá-lo em um serviço gerenciado.

Este projeto é meu espaço para aprender fazendo: quero conseguir explicar de onde os dados vieram, o que foi feito com eles e como verificar se o resultado está correto.
