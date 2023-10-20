ARG NODE_VERSION=slim
FROM node:${NODE_VERSION}

ARG NVM_VERSION=latest
ARG AWS_SAM_VERSION=latest
ARG AWS_CDK_VERSION=latest
ARG AWS_CDK8S_VERSION=latest
ARG AWS_CDKTF_VERSION=latest

ENV NVM_VERSION=${NVM_VERSION}
ENV AWS_SAM_VERSION=${AWS_SAM_VERSION}
ENV AWS_CDK_VERSION=${AWS_CDK_VERSION}
ENV AWS_CDK8S_VERSION=${AWS_CDK8S_VERSION}
ENV AWS_CDKTF_VERSION=${AWS_CDKTF_VERSION}

SHELL ["/bin/bash", "-c"]

# create folders
RUN mkdir -p "/opt/app" && chown -R node:node "/opt/app"

# dependencies
RUN apt-get update \
    && apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        unzip \
        git \
        make \
        g++
RUN apt-get upgrade -y

#docker
ENV container docker
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update \
    && apt-get install -y docker-ce-cli \
        docker-compose-plugin \
        software-properties-common

# Install aws sam
RUN curl -L -O https://github.com/aws/aws-sam-cli/releases/${AWS_SAM_VERSION}/download/aws-sam-cli-linux-x86_64.zip && \
    unzip aws-sam-cli-linux-x86_64.zip -d sam-installation && \
    ./sam-installation/install --update && \
    rm -rf sam-installation/ && \
    rm -rf aws-sam-cli-linux-x86_64.zip

# Terraform-cli
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo \
    "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
RUN apt-get update \
    && apt-get install -y terraform

#update npm
RUN npm install -g npm@${NVM_VERSION}

#install cdk, cdk8s & cdktf
RUN npm install -g aws-cdk@${AWS_CDK_VERSION} \
    cdk8s-cli@${AWS_CDK8S_VERSION} \
    cdktf-cli@${AWS_CDKTF_VERSION}

USER node

# pipenv
ENV PYTHON_BIN_PATH="$(python3 -m site --user-base)/bin"
RUN pip install --upgrade pip \
    && pip install --upgrade pipenv --user
RUN echo "export PATH=$PYTHON_BIN_PATH:$PATH" >> ~/.bashrc

VOLUME [ "/home/node/.aws" ]
VOLUME [ "/home/node/.aws-sam" ]
VOLUME [ "/home/node/.terraform.d" ]
VOLUME [ "/home/node/.docker" ]
VOLUME [ "/opt/app" ]

WORKDIR /opt/app
CMD ["/bin/bash"]