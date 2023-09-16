ARG PYTHON_VERSION=3-slim
FROM python:${PYTHON_VERSION}

ARG AWS_SAM_VERSION=latest
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER_NAME=sam

ENV SAM_USER=$USER_NAME
ENV USER_ID=$USER_ID
ENV GROUP_ID=$GROUP_ID

SHELL ["/bin/bash", "-c"]

# dependencies
RUN apt-get update \
    && apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

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

#python
RUN pip install --upgrade pip

# Install aws sam
RUN curl -L -O https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip && \
    unzip aws-sam-cli-linux-x86_64.zip -d sam-installation && \
    ./sam-installation/install --update && \
    rm -rf sam-installation/ && \
    rm -rf aws-sam-cli-linux-x86_64.zip

# create local user
RUN echo "The username is ${SAM_USER}"
RUN echo "The userid is ${USER_ID}"
RUN echo "The groupid is ${GROUP_ID}"
RUN addgroup --gid $GROUP_ID $SAM_USER && \
    adduser --uid $USER_ID --gid $GROUP_ID $SAM_USER

# create folders
RUN mkdir -p "/opt/app" && chown -R "$SAM_USER:$SAM_USER" "/opt/app"

VOLUME [ "/home/${SAM_USER}/.aws" ]
VOLUME [ "/home/${SAM_USER}/.aws-sam" ]
VOLUME [ "/opt/app" ]

USER "$SAM_USER"
WORKDIR /opt/app
CMD ["/bin/bash"]