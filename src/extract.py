import logging
import os
from datetime import datetime
from pathlib import Path
from tempfile import TemporaryDirectory

import polars as pl
import pytz
from google.cloud import storage

LOGGER = logging.getLogger(__name__)
PROJECT_ROOT = Path(__file__).resolve().parent.parent
SOURCE_DATA = PROJECT_ROOT / "data"
TIMEZONE_SAO_PAULO = pytz.timezone("America/Sao_Paulo")

# Adapta os nomes originais do dataset Olist aos nomes usados nas tabelas Raw.
TABLE_NAME_BY_FILE = {
    "olist_customers_dataset": "customers",
    "olist_order_items_dataset": "order_items",
    "olist_orders_dataset": "orders",
    "olist_products_dataset": "products",
    "olist_sellers_dataset": "sellers",
    "product_category_name_translation": "product_category_name_translation",
}


def _nome_tabela(arquivo: Path) -> str:
    nome_origem = arquivo.stem.strip().lower()
    return TABLE_NAME_BY_FILE.get(nome_origem, nome_origem)


def processar_arquivos(data_extracao: str | None = None) -> list[str]:
    """Converte os CSVs locais para Parquet e grava cada arquivo no GCS.

    O caminho particionado pela data torna uma nova execução diária rastreável.
    Uma tentativa repetida da mesma execução escreve no mesmo objeto, evitando
    duplicar aquela partição em caso de retry do Airflow.
    """
    bucket_name = os.getenv("GCS_BUCKET")
    if not bucket_name:
        raise ValueError("Defina a variável de ambiente GCS_BUCKET.")

    project_id = os.getenv("GOOGLE_CLOUD_PROJECT")
    if not project_id:
        raise ValueError(
            "Defina GOOGLE_CLOUD_PROJECT com o ID do projeto Google Cloud "
            "no arquivo .env."
        )

    if not SOURCE_DATA.is_dir():
        raise FileNotFoundError(f"Pasta de entrada não encontrada: {SOURCE_DATA}")

    arquivos = sorted(arquivo for arquivo in SOURCE_DATA.glob("*.csv") if arquivo.is_file())
    if not arquivos:
        raise FileNotFoundError(f"Nenhum arquivo CSV encontrado em {SOURCE_DATA}")

    nomes_tabela = [_nome_tabela(arquivo) for arquivo in arquivos]
    if len(nomes_tabela) != len(set(nomes_tabela)):
        raise ValueError("Há arquivos de origem mapeados para o mesmo nome de tabela Raw.")

    if data_extracao is None:
        data_extracao = datetime.now(TIMEZONE_SAO_PAULO).strftime("%Y-%m-%d")
    else:
        # Valida e normaliza a data recebida pelo DAG antes de formar o caminho.
        data_extracao = datetime.strptime(data_extracao, "%Y-%m-%d").strftime("%Y-%m-%d")

    client = storage.Client(project=project_id)
    bucket = client.bucket(bucket_name)
    arquivos_enviados = []

    # Os Parquet são temporários: o container não precisa mantê-los após o upload.
    with TemporaryDirectory(prefix="olist_parquet_") as pasta_temporaria:
        pasta_temporaria = Path(pasta_temporaria)

        for arquivo, nome_tabela in zip(arquivos, nomes_tabela, strict=True):
            caminho_parquet = pasta_temporaria / f"{nome_tabela}.parquet"
            pl.read_csv(arquivo).write_parquet(caminho_parquet)

            destino = (
                f"raw/{nome_tabela}/data_extracao={data_extracao}/"
                f"{nome_tabela}.parquet"
            )
            blob = bucket.blob(destino)
            blob.upload_from_filename(
                str(caminho_parquet),
                content_type="application/vnd.apache.parquet",
            )

            uri_gcs = f"gs://{bucket_name}/{destino}"
            LOGGER.info("Arquivo enviado: %s", uri_gcs)
            arquivos_enviados.append(uri_gcs)

    LOGGER.info(
        "Lote de %s enviado para gs://%s: %s arquivo(s).",
        data_extracao,
        bucket_name,
        len(arquivos_enviados),
    )
    return arquivos_enviados


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    processar_arquivos()

