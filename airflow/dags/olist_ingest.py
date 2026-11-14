from datetime import timedelta

import pendulum
from airflow.sdk import dag, get_current_context, task

TIMEZONE = "America/Sao_Paulo"


@dag(
    dag_id="olist_csv_to_gcs",
    description="Converte os CSVs locais do Olist em Parquet e envia ao GCS.",
    start_date=pendulum.datetime(2026, 1, 1, tz=TIMEZONE),
    schedule="0 9 * * *",
    catchup=False,
    max_active_runs=1,
    default_args={
        "owner": "olist-data-pipeline",
        "retries": 2,
        "retry_delay": timedelta(minutes=5),
    },
    tags=["olist", "extract", "gcs"],
)
def olist_csv_to_gcs():
    @task(task_id="convert_and_upload_to_gcs")
    def convert_and_upload_to_gcs() -> dict[str, object]:
        from src.extract import processar_arquivos

        context = get_current_context()
        data_interval_end = context.get("data_interval_end")
        if data_interval_end is None:
            raise ValueError("O Airflow não forneceu o fim do intervalo desta execução.")

        data_extracao = data_interval_end.in_timezone(TIMEZONE).to_date_string()
        arquivos_enviados = processar_arquivos(data_extracao=data_extracao)
        return {
            "data_extracao": data_extracao,
            "quantidade_arquivos": len(arquivos_enviados),
            "arquivos": arquivos_enviados,
        }

    convert_and_upload_to_gcs()


olist_csv_to_gcs()

