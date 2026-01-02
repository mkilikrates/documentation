FROM alpine:latest

ARG TERRAFORM="latest"
ARG OPENTOFU="latest"
ARG TERRAGRUNT="latest"
ARG BOILERPLATE="latest"

# Determine the target architecture using uname -m
RUN case `uname -m` in \
    x86_64) ARCH=amd64; ;; \
    armv7l) ARCH=arm; ;; \
    aarch64) ARCH=arm64; ;; \
    ppc64le) ARCH=ppc64le; ;; \
    s390x) ARCH=s390x; ;; \
    *) echo "un-supported arch, exit ..."; exit 1; ;; \
    esac && \
    echo "export ARCH=$ARCH" > /envfile && \
    echo "export OS=linux" >> /envfile && \
    cat /envfile

# install dependencies
RUN . /envfile && \
   apk update && \
   apk add --update --no-cache git \
   curl \
   unzip \
   groff \
   gnupg \
   aws-cli \
   jq \
   yq && \
   echo "install dependencies done." && \
   echo "aws-cli version: $(aws --version)" && \
   echo "jq version: $(jq --version)" && \
   echo "yq version: $(yq --version)"

# install terraform
RUN . /envfile && echo $OS && echo $ARCH && \
    if [ "$TERRAFORM" == "latest" ]; then TERRAFORM=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/hashicorp/terraform/releases/latest | awk -F "/" '{print $NF}' | cut -c2-); fi && \
    wget https://releases.hashicorp.com/terraform/${TERRAFORM}/terraform_${TERRAFORM}_${OS}_${ARCH}.zip && \
    wget https://releases.hashicorp.com/terraform/${TERRAFORM}/terraform_${TERRAFORM}_SHA256SUMS && \
    wget https://releases.hashicorp.com/terraform/${TERRAFORM}/terraform_${TERRAFORM}_SHA256SUMS.sig && \
    wget -qO- https://www.hashicorp.com/.well-known/pgp-key.txt | gpg --import && \
    gpg --verify terraform_${TERRAFORM}_SHA256SUMS.sig terraform_${TERRAFORM}_SHA256SUMS && \
    grep terraform_${TERRAFORM}_${OS}_${ARCH}.zip terraform_${TERRAFORM}_SHA256SUMS | sha256sum -c && \
    unzip -o terraform_${TERRAFORM}_${OS}_${ARCH}.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/terraform && \
    rm -rf terraform_${TERRAFORM}* && \
    echo "terraform version: $(terraform --version)"

# install terragrunt
RUN . /envfile && echo $OS && echo $ARCH && \
    if [ "$TERRAGRUNT" == "latest" ]; then TERRAGRUNT=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/gruntwork-io/terragrunt/releases/latest | awk -F "/" '{print $NF}' | cut -c2-); fi && \
    wget "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT}/terragrunt_${OS}_${ARCH}" && \
    wget "https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT}/SHA256SUMS" && \
    grep -E "terragrunt_${OS}_${ARCH}$" SHA256SUMS | sha256sum -c && \
    mv terragrunt_${OS}_${ARCH} /usr/local/bin/terragrunt && \
    chmod +x /usr/local/bin/terragrunt && \
    rm -rf terragrunt* && \
    rm -rf SHA256SUMS && \
    echo "terragrunt version: $(terragrunt --version)"
 
# install opentofu
RUN . /envfile && echo $ARCH && \
    if [ "$OPENTOFU" == "latest" ]; then OPENTOFU=$(curl -Ls -o /dev/null -w %{url_effective} https://github.com/opentofu/opentofu/releases/latest | awk -F "/" '{print $NF}' | cut -c2-); fi && \
    wget "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU}/tofu_${OPENTOFU}_linux_${ARCH}.zip" && \
    wget "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU}/tofu_${OPENTOFU}_SHA256SUMS" && \
    grep tofu_${OPENTOFU}_linux_${ARCH}.zip tofu_${OPENTOFU}_SHA256SUMS | sha256sum -c && \
    unzip -o tofu_${OPENTOFU}_linux_${ARCH}.zip -d /usr/local/bin && \
    chmod +x /usr/local/bin/tofu && \
    rm -rf tofu_${OPENTOFU}_linux_${ARCH}.zip && \
    rm -rf tofu_${OPENTOFU}_SHA256SUMS && \
    rm -rf /envfile && \
    echo "opentofu version: $(tofu --version)"

WORKDIR /apps
