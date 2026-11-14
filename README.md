# Olist: construindo um fluxo de dados confiável

Este é um projeto individual de portfólio que estou desenvolvendo para praticar engenharia e análise de dados de ponta a ponta. Uso o conjunto público da Olist para aprender a construir um fluxo rastreável, repetível e preparado para validações, desde os arquivos de origem até as tabelas analíticas.

Meu objetivo não é apenas mover arquivos entre serviços. Quero entender como cada etapa pode preservar a origem dos dados, tornar falhas visíveis e produzir modelos que sejam confiáveis para análise.

## O que quero aprender e demonstrar

- Orquestrar uma ingestão diária com Apache Airflow.
- Executar o pipeline localmente em containers Docker.
- Converter arquivos CSV para Parquet e armazená-los no Google Cloud Storage.
- Organizar os dados no BigQuery em camadas Raw, Silver e Gold.
- Transformar e documentar os modelos analíticos com Dataform.
- Criar verificações de qualidade para identificar chaves nulas e duplicadas.
- Considerar idempotência, rastreabilidade, credenciais, custos e recuperação após falhas.

## Fluxo de dados

```text
CSV da Olist
   ↓
Airflow local em Docker
   ↓
Python + Polars: CSV → Parquet
   ↓
Google Cloud Storage: landing/raw por data de extração
   ↓
BigQuery: tabelas externas Raw
   ↓
Dataform: Silver — tipagem, limpeza e regras de qualidade
   ↓
Dataform: Gold — dimensões e fatos para análise
   ↓
Power BI
```

O Airflow coordena a execução. O código Python realiza a leitura, conversão e gravação no bucket. O BigQuery e o Dataform ficam responsáveis pelo processamento analítico.

## Decisões para tornar o fluxo mais confiável

### Execuções rastreáveis e repetíveis

Os objetos no bucket são organizados por tabela e data de extração. O caminho da execução é determinístico: uma tentativa repetida do mesmo intervalo escreve no mesmo objeto, em vez de criar uma cópia com nome diferente.

### Separação das responsabilidades

O extrator não aplica as regras de negócio das tabelas analíticas. Ele registra os arquivos convertidos no GCS; as transformações ficam no BigQuery/Dataform. Isso facilita localizar em qual etapa ocorreu um problema.

### Verificações no processo de ingestão

O extrator verifica se a pasta de origem existe, se há arquivos CSV para processar e se nomes diferentes não foram mapeados para a mesma tabela Raw. O Airflow também está configurado com tentativas adicionais em caso de falha da tarefa.

### Qualidade dos dados

Na Silver, pretendo padronizar tipos e valores e validar regras importantes antes de publicar os modelos Gold. Já existe uma assertion de exemplo para encontrar pedidos com `order_id` nulo ou duplicado. O próximo passo é ampliar as verificações para relacionamentos, datas e valores válidos.

### Credenciais e configuração

As credenciais do Google Cloud são fornecidas localmente pelo Application Default Credentials e montadas como somente leitura nos containers. O arquivo `.env` guarda a configuração local e não deve ser publicado. Não incluo credenciais, arquivos de dados ou o relatório do Power BI neste repositório.

## Tecnologias

- Python e Polars
- Apache Airflow 3 com CeleryExecutor
- Docker Compose
- PostgreSQL para metadados do Airflow
- Redis como broker de tarefas
- Google Cloud Storage
- BigQuery e Dataform
- Power BI

## Execução local

### Pré-requisitos

- Docker Desktop com Docker Compose v2.
- Google Cloud CLI autenticado com acesso de gravação no bucket.
- Arquivos CSV da Olist na pasta `data/`.
- Configuração local no arquivo `.env`, incluindo projeto GCP, bucket e segredos de desenvolvimento do Airflow.

Para configurar as credenciais ADC no Windows:

```powershell
gcloud auth application-default login
Test-Path "$env:APPDATA\gcloud\application_default_credentials.json"
```

Se o SDK já estiver autenticado e o arquivo existir, não é necessário autenticar novamente. Configure os valores locais do projeto no `.env`; não reutilize segredos de desenvolvimento em ambientes de produção.

### Iniciar os serviços

Na raiz do projeto:

```powershell
docker compose build
docker compose up airflow-init
docker compose up -d
```

Abra [http://localhost:8080](http://localhost:8080), acesse o DAG `olist_csv_to_gcs` e use **Trigger DAG** para iniciar uma execução manual. O DAG também está configurado para executar diariamente às 09:00 no fuso `America/Sao_Paulo`, desde que o computador e os containers estejam ativos.

Para acompanhar os serviços:

```powershell
docker compose ps
docker compose logs --tail 100 airflow-worker airflow-scheduler airflow-apiserver
```

Para parar os containers preservando o banco local do Airflow:

```powershell
docker compose down
```

O comando `docker compose down --volumes` apaga também o banco de metadados e o histórico local do Airflow.

## Arquivos enviados ao bucket

O extrator mapeia os arquivos da Olist para os nomes usados nas tabelas Raw:

| Arquivo de origem | Nome Raw | Caminho no GCS |
|---|---|---|
| `olist_customers_dataset.csv` | `customers` | `raw/customers/data_extracao=AAAA-MM-DD/customers.parquet` |
| `olist_order_items_dataset.csv` | `order_items` | `raw/order_items/data_extracao=AAAA-MM-DD/order_items.parquet` |
| `olist_orders_dataset.csv` | `orders` | `raw/orders/data_extracao=AAAA-MM-DD/orders.parquet` |
| `olist_products_dataset.csv` | `products` | `raw/products/data_extracao=AAAA-MM-DD/products.parquet` |
| `olist_sellers_dataset.csv` | `sellers` | `raw/sellers/data_extracao=AAAA-MM-DD/sellers.parquet` |
| `product_category_name_translation.csv` | `product_category_name_translation` | `raw/product_category_name_translation/data_extracao=AAAA-MM-DD/product_category_name_translation.parquet` |

O dataset público da Olist é estático. Enquanto eu usar os mesmos CSVs, a execução diária reenviará os mesmos dados em uma nova partição de data. Essa escolha serve para praticar o fluxo e o histórico de ingestão; uma fonte que muda diariamente exigiria uma estratégia de captura e atualização adequada.

## Estado do projeto

A ingestão local em Docker, o envio de Parquet ao GCS e os primeiros modelos SQL estão montados. Estou construindo e validando as tabelas externas Raw e as transformações Silver e Gold.

Um ajuste pendente é alinhar as consultas Silver ao dataset de origem escolhido: alguns SQLs atuais ainda referenciam `Bronze.*`, enquanto o desenho adotado para esta etapa usa `Raw.*`. Portanto, os modelos SQL devem ser revisados e executados no Dataform depois desse alinhamento.

O fluxo atual ainda não é uma implantação de produção. O Airflow roda no meu computador, que precisa permanecer ligado para cumprir o agendamento. A publicação em um ambiente gerenciado exigiria configuração própria de identidade, segredos, monitoramento, permissões mínimas, custos e estratégia de operação.

## Próximas etapas

1. Concluir as external tables no BigQuery Raw e conferir os esquemas.
2. Alinhar as referências dos SQLs da Silver com as tabelas Raw.
3. Executar as transformações pelo Dataform e ampliar as assertions de qualidade.
4. Validar volumes e chaves entre Raw, Silver e Gold.
5. Conectar os modelos Gold ao Power BI e documentar as métricas.
6. Avaliar uma opção gerenciada para agendamento e execução fora do computador local.

Este projeto é um exercício de aprendizado contínuo: cada etapa deve deixar claro de onde vieram os dados, o que foi transformado e como verificar se o resultado está correto.
