ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}

ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USER_NAME=eks
ENV GROUP_ID=${GROUP_ID}
ENV USER_ID=${USER_ID}
ENV USER_NAME=${USER_NAME}
# create local user
RUN addgroup -g ${GROUP_ID} ${USER_NAME} && \
    adduser --shell /home/${USER_NAME} --disabled-password \
    --uid $USER_ID --ingroup ${USER_NAME} ${USER_NAME} && \
    addgroup ${USER_NAME} wheel
# create folders
RUN mkdir -p "/opt/app" && chown -R "${USER_NAME}:${USER_NAME}" "/opt/app"

# Install packages
RUN apk update && apk add --update --no-cache \
    bash \
    curl \
    aws-cli 

# Install aws-iam-authenticator
RUN latest_aws_iam_authenticator_release_tag=$(curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/latest | sed 's#.*/##' | cut -c2-) && \
    aws_iam_authenticator_url=$(echo "https://github.com/kubernetes-sigs/aws-iam-authenticator/releases/download/vTAG/aws-iam-authenticator_TAG_linux_amd64" | sed "s/TAG/$latest_aws_iam_authenticator_release_tag/g" ) && \
    curl -sLo aws-iam-authenticator "$aws_iam_authenticator_url" && \
    chmod +x ./aws-iam-authenticator && \
    mv aws-iam-authenticator /usr/local/bin/ && \
    chown root:root /usr/local/bin/aws-iam-authenticator

# Install kubectl
RUN export latest_kubectl_release_tag=$(curl -L https://storage.googleapis.com/kubernetes-release/release/stable.txt) && \
    curl -sLo kubectl "https://dl.k8s.io/release/$latest_kubectl_release_tag/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/ && \
    chown root:root /usr/local/bin/kubectl

# Install helm
RUN export latest_helm_release_tag=$(curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/helm/helm/releases/latest | sed 's#.*/##') && \
    export helm_url=$(echo "https://get.helm.sh/helm-TAG-linux-amd64.tar.gz" | sed "s/TAG/$latest_helm_release_tag/g" ) && \
    curl -sLo helm-linux-amd64.tar.gz "$helm_url" && \
    tar -xvzf helm-linux-amd64.tar.gz && \
    mv linux-amd64/helm /usr/local/bin/ && \
    chown root:root /usr/local/bin/helm && \
    rm -rf elm-linux-amd64.tar.gz

# Install kconnect
RUN latest_kconnect_release_tag=$(curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/fidelity/kconnect/releases/latest | sed 's#.*/##') && \
    curl -sLo kconnect.tgz https://github.com/fidelity/kconnect/releases/download/$latest_kconnect_release_tag/kconnect_linux_amd64.tar.gz && \
    tar -xvzf kconnect.tgz && \
    mv kconnect /usr/local/bin/ && \
    chown root:root /usr/local/bin/kconnect

VOLUME [ "/home/${USER_NAME}/.aws" ]
VOLUME [ "/home/${USER_NAME}/.kube" ]
VOLUME [ "/home/${USER_NAME}/.kconnect" ]
VOLUME [ "/opt/app" ]

USER "${USER_NAME}"
WORKDIR /opt/app
CMD ["/bin/sh"]