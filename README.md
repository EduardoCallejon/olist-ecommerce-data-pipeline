# Pipeline de dados Olist

Projeto de engenharia e análise de dados que prepara os arquivos públicos do Olist para consumo no Google Cloud e no Power BI.

## Fluxo atual

1. O extrator lê os arquivos CSV de `data/`.
2. Polars converte cada CSV para Parquet.
3. Os arquivos são enviados ao bucket configurado, no padrão `raw/<tabela>/data_extracao=AAAA-MM-DD/<tabela>.parquet`.
4. BigQuery/Dataform transforma os dados nas camadas Silver e Gold.
5. Power BI consome as tabelas Gold para o dashboard.

## Executar localmente

Requisitos: Python 3.14 e `uv`.

```powershell
uv sync
uv run python src/extract.py
```

Antes de executar, configure a autenticação do Google Cloud com Application Default Credentials e informe o bucket:

```powershell
$env:GCS_BUCKET = "chicagoportal"
```

O extrator usa a conta autenticada localmente para gravar os objetos no Cloud Storage.

## Cloud Run Functions

A função HTTP está definida no ponto de entrada `extrair_dados`, em `main.py`. O serviço aceita `POST` e chama o mesmo processo de extração.

Ao conectar este repositório ao Cloud Run:

- selecione Python via Google Cloud Buildpacks;
- configure `extrair_dados` como **Function target**;
- use o runtime Python 3.14;
- defina `GCS_BUCKET` com o nome do bucket;
- mantenha a autenticação obrigatória;
- associe uma conta de serviço com permissão `roles/storage.objectCreator` no bucket.

Não é necessário um `Dockerfile` para esse buildpack. Um Cloud Scheduler pode invocar a função diariamente com `POST` e autenticação OIDC. O deploy acionado por commits no GitHub atualiza o código; ele não agenda a extração diária.

## Observação sobre os arquivos de origem

Na configuração atual, a função espera encontrar os CSVs dentro de `data/`, que acompanha este repositório. A execução repetida processa novamente o mesmo conjunto de arquivos. Para trocar os arquivos diariamente sem novo deploy, o próximo passo é adaptar o extrator para ler os arquivos de entrada diretamente do Cloud Storage.
