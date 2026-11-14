ARG AIRFLOW_VERSION=3.4.0
FROM apache/airflow:${AIRFLOW_VERSION}-python3.12

ARG AIRFLOW_VERSION
ARG PYTHON_VERSION=3.12

COPY airflow/requirements.txt /requirements.txt

# Mantém a versão do Airflow da imagem e instala as bibliotecas do extrator
# usando as constraints oficiais dessa mesma versão.
RUN pip install --no-cache-dir \
    "apache-airflow==${AIRFLOW_VERSION}" \
    --constraint "https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt" \
    -r /requirements.txt

USER airflow

