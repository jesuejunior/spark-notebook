FROM ubuntu:21.04

LABEL maintainer="Jesue Junior <jesuesousa@gmail.com>"
ARG NB_USER="jesue"
ARG NB_UID="1000"
ARG NB_GID="100"

# Fix DL4006
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root

ENV DEBIAN_FRONTEND noninteractive

# Spark dependencies
# Default values can be overridden at build time
# (ARGS are in lower case to distinguish them from ENV)
ARG spark_version="3.1.2"
ARG hadoop_version="3.2"
ARG spark_checksum="2385CB772F21B014CE2ABD6B8F5E815721580D6E8BC42A26D70BBCDDA8D303D886A6F12B36D40F6971B5547B70FAE62B5A96146F0421CB93D4E51491308EF5D5"
ARG py4j_version="0.10.9"
ARG openjdk_version="8"

ENV APACHE_SPARK_VERSION="${spark_version}" \
    HADOOP_VERSION="${hadoop_version}"

RUN buildDeps="build-essential wget bzip2 ca-certificates locales fonts-liberation libsm6 libxext-dev git ffmpeg unzip \
    openjdk-${openjdk_version}-jre-headless ca-certificates-java" \
    && apt-get update \
    && apt-get install -yq software-properties-common \
    && apt-add-repository 'deb http://security.debian.org/debian-security stretch/updates main' \
    && apt-get update \
    && apt-get install -y software-properties-common \
    # && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get install -yq $buildDeps --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Spark installation
WORKDIR /tmp
# Using the preferred mirror to download Spark
# hadolint ignore=SC2046
RUN wget -q $(wget -qO- https://www.apache.org/dyn/closer.lua/spark/spark-${APACHE_SPARK_VERSION}/spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz\?as_json | \
    python -c "import sys, json; content=json.load(sys.stdin); print(content['preferred']+content['path_info'])") \
    && echo "${spark_checksum} *spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" | sha512sum -c - \
    && tar xzf "spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz" -C /usr/local --owner root --group root --no-same-owner \
    && rm "spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}.tgz"


WORKDIR /usr/local
RUN ln -s "spark-${APACHE_SPARK_VERSION}-bin-hadoop${HADOOP_VERSION}" spark

# Configure Spark
ENV SPARK_HOME=/usr/local/spark
ENV PYTHONPATH="${SPARK_HOME}/python:${SPARK_HOME}/python/lib/py4j-${py4j_version}-src.zip" \
    SPARK_OPTS="--driver-java-options=-Xms1024M --driver-java-options=-Xmx2048M --driver-java-options=-Dlog4j.logLevel=info" \
    PATH=$PATH:$SPARK_HOME/bin \
    SPARK_JARS="${SPARK_HOME}/jars/"

ADD https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.0/hadoop-aws-3.3.0.jar ${SPARK_JARS}
ADD https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk/1.11.908/aws-java-sdk-1.11.908.jar ${SPARK_JARS}
ADD https://storage.googleapis.com/hadoop-lib/gcs/gcs-connector-latest-hadoop2.jar ${SPARK_JARS}
# ADD https://storage.googleapis.com/spark-lib/bigquery/spark-bigquery-latest.jar ${SPARK_JARS}
ADD https://storage.googleapis.com/spark-lib/bigquery/spark-bigquery-latest_2.12.jar ${SPARK_JARS}
ADD https://repo1.maven.org/maven2/io/netty/netty-all/4.1.54.Final/netty-all-4.1.54.Final.jar ${SPARK_JARS}

# USER $NB_UID

RUN set -ex \
    && pip3 install -U pipenv==2020.11.15 poetry jupyterlab==3.1.4 pyarrow==5.0.0 pyspark==3.1.2 pandas>=1.3.1 widgetsnbextension bokeh ipywidgets \
    matplotlib==3.3.3 \
    # && apt-get purge -y --auto-remove $buildDeps \
    && jupyter nbextension enable --py widgetsnbextension --sys-prefix \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen \
    # Also activate ipywidgets extension for JupyterLab
    # Check this URL for most recent compatibilities
    # https://github.com/jupyter-widgets/ipywidgets/tree/master/packages/jupyterlab-manager
    # && jupyter labextension install @jupyter-widgets/jupyterlab-manager@^2.0.0 --no-build \
    # && jupyter labextension install @bokeh/jupyter_bokeh@^2.0.0 --no-build \
    # && jupyter labextension install jupyter-matplotlib@^0.7.2 --no-build \
    # && jupyter lab build -y \
    # && jupyter lab clean -y \
    # && npm cache clean --force \
    # && rm -rf "/home/${NB_USER}/.cache/yarn" \
    # && rm -rf "/home/${NB_USER}/.node-gyp" \
    # && rm /usr/local/spark/jars/netty-all-4.1.47.Final.jar \
    && find /usr/local -depth \
        \( \
            \( -type d -a \( -name test -o -name tests \) \) \
            -o \
            \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
            \) -exec rm -rf '{}' +

