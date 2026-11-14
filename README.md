# Pipeline Olist: Airflow local, Docker e Google Cloud

Projeto de estudo que usa o Apache Airflow, executado localmente em Docker, para orquestrar a leitura dos CSVs do Olist, convertê-los para Parquet e enviá-los ao Google Cloud Storage. As transformações Silver e Gold continuam no BigQuery/Dataform.

## Arquitetura desta etapa

```text
CSV local (`data/`)
  → Airflow no Docker Compose (API, scheduler, DAG processor, worker e triggerer)
  → PostgreSQL (metadados) + Redis (fila Celery)
  → tarefa Python + Polars (CSV para Parquet)
  → Google Cloud Storage (`raw/`)
  → BigQuery Raw
  → Dataform (Silver → Gold)
```

O Airflow **orquestra** a tarefa. O código de `src/extract.py` faz a conversão e o upload. Os CSVs não são copiados para a imagem Docker; a pasta local `data/` é montada como somente leitura nos containers Airflow. Ela está no `.gitignore` porque contém os dados do projeto.

Esta configuração separa os componentes do Airflow, usa PostgreSQL como banco de metadados e Redis como broker para o CeleryExecutor. É um ambiente local de aprendizado inspirado no Compose oficial do Airflow; não é uma implantação de produção pronta, com alta disponibilidade e controles de segurança corporativos.

O DAG está agendado para executar diariamente às 09:00 no fuso `America/Sao_Paulo`. O dataset público Olist usado nesta simulação é estático; portanto, cada execução diária envia novamente o mesmo conteúdo para um caminho com a data da execução. Para produção, conecte a extração a uma fonte que realmente atualize ou ajuste a estratégia de armazenamento para evitar cópias desnecessárias.

## Pré-requisitos

- Docker Desktop com Docker Compose v2.
- Google Cloud CLI instalado e autenticado com acesso de gravação no bucket.
- Os CSVs originais dentro de `data/`.
- Pelo menos 4 GB de memória alocados ao Docker; 8 GB é recomendado para o quick-start oficial do Airflow.

No PowerShell, configure Application Default Credentials:

```powershell
gcloud auth application-default login
```

Isso cria as credenciais ADC em `%APPDATA%\gcloud\application_default_credentials.json`. O Compose monta esse arquivo como somente leitura no container. Nunca coloque o JSON de credenciais no repositório. A documentação do GCS do Apache Hop também descreve o uso de credenciais ADC ou de uma conta de serviço. [Credenciais do GCS](https://cloud.google.com/docs/authentication/application-default-credentials)

O usuário autenticado precisa poder gravar objetos no bucket configurado. Para execução pessoal, use as permissões já concedidas ao usuário; para uma implantação de produção, prefira uma conta de serviço com permissões mínimas.

## Configuração

Copie o exemplo para `.env` e configure o bucket, as credenciais locais do Airflow e as chaves de desenvolvimento:

```powershell
Copy-Item .env.example .env
```

O valor inicial do bucket é `chicagoportal`. No `.env`, substitua `replace-with-your-gcp-project-id` pelo **ID do projeto** que contém o bucket. Você pode consultar o projeto ativo com `gcloud config get-value project` ou copiá-lo da página de detalhes do projeto no Console do Google Cloud. O `.env` está no `.gitignore`: não o publique. Os valores do `.env.example` servem apenas para esta simulação local; use segredos próprios e um gerenciador de segredos em produção. Você também pode alterar o bucket em `.env`.

O Compose monta as Application Default Credentials já existentes no Windows em `%APPDATA%\gcloud\application_default_credentials.json`. Como você já autenticou o SDK, não precisa repetir o login se esse arquivo estiver presente. Confirme com:

```powershell
Test-Path "$env:APPDATA\gcloud\application_default_credentials.json"
```

O resultado precisa ser `True`.

## Executar localmente

Na raiz do projeto, construa a imagem, inicialize o PostgreSQL/Airflow e inicie os serviços:

```powershell
docker compose build
docker compose up airflow-init
docker compose up -d
```

O passo `airflow-init` aplica as migrações do banco de metadados e cria o usuário administrador. Abra [http://localhost:8080](http://localhost:8080) e use o usuário e a senha definidos em `.env`.

Na interface, abra o DAG `olist_csv_to_gcs` e use **Trigger DAG**. A tarefa `convert_and_upload_to_gcs` é enviada pelo scheduler ao worker Celery, que executa o extrator. Para acompanhar os componentes:

```powershell
docker compose ps
docker compose logs --tail 100 airflow-worker airflow-scheduler airflow-apiserver
```

O Airflow local precisa permanecer rodando para cumprir horários agendados. Para encerrar os containers sem apagar o estado do PostgreSQL:

```powershell
docker compose down
```

`docker compose down --volumes` também apaga o banco local e o histórico do Airflow; os arquivos já enviados ao GCS não são apagados.

## Saída no bucket

Os nomes dos arquivos Olist são mapeados para os nomes Raw usados pelas consultas existentes:

| Arquivo local | Tabela Raw | Objeto Parquet |
|---|---|---|
| `olist_customers_dataset.csv` | `customers` | `raw/customers/data_extracao=AAAA-MM-DD/customers.parquet` |
| `olist_order_items_dataset.csv` | `order_items` | `raw/order_items/data_extracao=AAAA-MM-DD/order_items.parquet` |
| `olist_orders_dataset.csv` | `orders` | `raw/orders/data_extracao=AAAA-MM-DD/orders.parquet` |
| `olist_products_dataset.csv` | `products` | `raw/products/data_extracao=AAAA-MM-DD/products.parquet` |
| `olist_sellers_dataset.csv` | `sellers` | `raw/sellers/data_extracao=AAAA-MM-DD/sellers.parquet` |
| `product_category_name_translation.csv` | `product_category_name_translation` | `raw/product_category_name_translation/data_extracao=AAAA-MM-DD/product_category_name_translation.parquet` |

A data usada no caminho é a data de fim do intervalo agendado, convertida para `America/Sao_Paulo`. Assim, a execução das 09:00 grava a partição com a data daquele dia. Uma nova tentativa da mesma execução reutiliza o mesmo caminho, evitando gerar outra partição para o mesmo run.

## Transformações

Esta etapa termina no upload ao GCS. As consultas em `sql_tratativas/silver/` e `sql_tratativas/gold/` continuam sob execução do Dataform/BigQuery. O próximo passo pode adicionar ao DAG uma tarefa que só inicia a execução do Dataform depois de confirmar que o upload terminou.

## Custos e limites desta simulação

- O Airflow local não cria uma VM nem um serviço Airflow gerenciado no GCP. O computador e o Docker precisam estar ligados para o DAG rodar no horário.
- Ainda podem existir custos de armazenamento no GCS, consultas/processamento no BigQuery e transferência de dados conforme região e uso.
- O Parquet é salvo em um novo caminho por data. Como este conjunto Olist é estático, o agendamento diário repete os dados e aumenta o armazenamento; mantenha isso em mente enquanto usar os mesmos CSVs.
- Uma estimativa serverless é possível com as medidas de CPU, memória, tempo por execução, frequência, região, armazenamento e processamento no BigQuery. Use a [calculadora de preços do Google Cloud](https://cloud.google.com/products/calculator) e configure alertas de orçamento; alertas monitoram gastos, mas não impõem automaticamente um teto.

O Compose oficial do Airflow também separa API server, scheduler, DAG processor, worker, PostgreSQL e Redis. Ele é indicado para aprender e testar; a própria documentação alerta que essa configuração não oferece, sozinha, as garantias de segurança e disponibilidade de produção. [Guia oficial do Airflow no Docker](https://airflow.apache.org/docs/apache-airflow/stable/howto/docker-compose.html)

