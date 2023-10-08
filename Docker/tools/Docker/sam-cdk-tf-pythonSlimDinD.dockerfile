ARG PYTHON_VERSION=3-slim
FROM python:${PYTHON_VERSION}

ARG NVM_VERSION=latest
ARG AWS_SAM_VERSION=latest
ARG AWS_CDK_VERSION=latest
ARG AWS_CDK8S_VERSION=latest
ARG AWS_CDKTF_VERSION=latest
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER_NAME=cdk

ENV NVM_VERSION=${NVM_VERSION}
ENV AWS_SAM_VERSION=${AWS_SAM_VERSION}
ENV AWS_CDK_VERSION=${AWS_CDK_VERSION}
ENV AWS_CDK8S_VERSION=${AWS_CDK8S_VERSION}
ENV AWS_CDKTF_VERSION=${AWS_CDKTF_VERSION}
ENV SAM_USER=$USER_NAME
ENV USER_ID=$USER_ID
ENV GROUP_ID=$GROUP_ID

SHELL ["/bin/bash", "-c"]

# create local user
RUN echo "The username is ${SAM_USER}"
RUN echo "The userid is ${USER_ID}"
RUN echo "The groupid is ${GROUP_ID}"
RUN addgroup --gid $GROUP_ID $SAM_USER && \
    adduser --uid $USER_ID --gid $GROUP_ID $SAM_USER

# create folders
RUN mkdir -p "/home/${SAM_USER}" \
    "/home/${SAM_USER}/.aws"   \
    "/home/${SAM_USER}.aws-sam" \
    "/home/${SAM_USER}.docker" \
    "/home/${SAM_USER}/.terraform.d" \
    "/home/${SAM_USER}/.cdk" \
    "/home/${SAM_USER}/.cdk8s" \
    "/home/${SAM_USER}/.cdktf" \
    && chown -R "$SAM_USER:$SAM_USER" "/home/${SAM_USER}"
RUN mkdir -p "/opt/app" && chown -R "$SAM_USER:$SAM_USER" "/opt/app"

# dependencies
RUN apt-get update \
    && apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
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
        unzip

# Terraform-cli
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
RUN echo \
    "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list > /dev/null
RUN apt-get update \
    && apt-get install -y terraform

# Install aws sam
RUN curl -L -O https://github.com/aws/aws-sam-cli/releases/${AWS_SAM_VERSION}/download/aws-sam-cli-linux-x86_64.zip && \
    unzip aws-sam-cli-linux-x86_64.zip -d sam-installation && \
    ./sam-installation/install --update && \
    rm -rf sam-installation/ && \
    rm -rf aws-sam-cli-linux-x86_64.zip

USER "${SAM_USER}"
WORKDIR /home/${SAM_USER}/

# pyenv
ENV PYTHON_BIN_PATH="$(python3 -m site --user-base)/bin"
RUN pip install --upgrade pip \
    && pip install --upgrade pipenv --user
RUN echo "export PATH=$PYTHON_BIN_PATH:$PATH" >> ~/.bashrc

#install node 
ENV NVM_DIR="/home/${SAM_USER}/.nvm" 
RUN touch ~/.bashrc && chmod +x ~/.bashrc 
RUN curl -sSL -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash 
RUN source $NVM_DIR/nvm.sh \ 
    && nvm install node \ 
    && nvm use node \ 
    && nvm alias default node \ 
    && npm install -g npm@${NVM_VERSION} \
    && nvm cache clear

#install cdk, cdk8s & cdktf
RUN source $NVM_DIR/nvm.sh \ 
    && npm install -g aws-cdk@${AWS_CDK_VERSION} \
    cdk8s-cli@${AWS_CDK8S_VERSION} \
    cdktf-cli@${AWS_CDKTF_VERSION}

VOLUME [ "/home/${SAM_USER}/.aws" ]
VOLUME [ "/home/${SAM_USER}/.aws-sam" ]
VOLUME [ "/home/${SAM_USER}/.terraform.d" ]
VOLUME [ "/home/${SAM_USER}/.cdk" ]
VOLUME [ "/home/${SAM_USER}/.cdk8s" ]
VOLUME [ "/home/${SAM_USER}/.cdktf" ]
VOLUME [ "/home/${SAM_USER}/.docker" ]
VOLUME [ "/opt/app" ]

WORKDIR /opt/app
CMD ["/bin/bash"]