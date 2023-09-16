ARG ALPINE_VERSION=latest

FROM alpine:${ALPINE_VERSION}

ARG AWS_CDK_VERSION=latest
ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER_NAME=cdk
ENV CDK_USER=${USER_NAME}
# Install packages
RUN apk update && apk add --update --no-cache \
    shadow \
    git \
    bash \
    curl \
    openssh \
    gcc \
    musl-dev \
    py3-pip \
    py-cryptography \
    wget \
    curl \
    nodejs \
    npm \
    docker-cli
RUN apk --no-cache add --virtual builds-deps build-base python3 python3-dev
# Update NPM
# RUN npm config set unsafe-perm true
RUN npm update -g
# Install cdk
RUN npm install -g aws-cdk
RUN cdk --version
# clean up
RUN pip3 uninstall --yes pip \
    && apk del python3-dev gcc musl-dev
# create local user
RUN addgroup -g $GROUP_ID $CDK_USER && \
    adduser --shell /home/$CDK_USER --disabled-password \
    --uid $USER_ID --ingroup $CDK_USER $CDK_USER && \
    addgroup $CDK_USER wheel
# create folders
VOLUME [ "/home/${CDK_USER}/.aws" ]
VOLUME [ "/opt/app" ]

RUN mkdir -p "/opt/app" && chown -R "$CDK_USER:$CDK_USER" "/opt/app"

USER "$CDK_USER"
WORKDIR /opt/app
CMD ["/bin/sh"]