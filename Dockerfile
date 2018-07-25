FROM lbwang/debian-conda

LABEL base.image="biocontainers:latest"
LABEL description="Call germline variants from WXS/WGS BAMs"
LABEL tags="Genomics"

MAINTAINER Wen-Wei Liang <liang.w@wustl.edu>

ARG DEBIAN_FRONTEND=noninteractive

## Install git
RUN apt-get update \
    && apt-get install -y --no-install-recommends git apt-transport-https gnupg2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/log/dpkg.log

RUN conda install -y python=3.6 pindel varscan gatk4 samtools snakemake pandas bcftools && \
    conda clean -y --all

RUN pip install google-cloud-storage kubernetes && \
    rm -rf ~/.cache/pip

# Set up Google Cloud SDK
RUN export CLOUD_SDK_REPO="cloud-sdk-stretch" && \
    echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    apt-get update && \
    apt-get install -y google-cloud-sdk kubectl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/log/dpkg.log && \
    gcloud config set core/disable_usage_reporting true && \
    gcloud config set component_manager/disable_update_check true

# Clone germlinewrapper script for pindel filtering
USER root
WORKDIR /home/
RUN git clone https://github.com/ding-lab/germline_variant_snakemake.git
