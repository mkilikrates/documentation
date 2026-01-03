# Using Docker to test without install anything

This is a simple list of examples where you can use docker to make tests without depends on local installation.

* [Connecting to Databases](./Databases/)
  * Postgres SQL
  * Oracle Instant Client
  * MYSQL Client

* [Programming Languages and script execution](./programming/)
  * Python
  * Groovy
  * [Nodejs](./programming/nodejs/)
  * Typescript
  * [Go](./programming/go/)

* [Tools](./tools/)
  * AWS CLI
  * AWS SAM
  * AWS CDK
  * AWS CDK + SAM
  * AWS SAM + CDK + CDK8s + TERRAFORM + CDKTF
  * Terragrunt, Terraform and OpenTofu
  * kubectl
  * EKS

* [Kubernetes](./k8s/)
  * **Cluster Setup & Management**
    * [Kind Cluster](./k8s/kind-cluster/) - Single and multi-node cluster configurations
    * [Docker Desktop Kind Cluster](./k8s/docker-desktop-kind-cluster/)
    * [Docker Desktop Kubeadm Cluster](./k8s/docker-desktop-kubeadm-cluster/)
  * **Application Examples** - [App Examples](./k8s/app-examples/)
    * [Stateless Nginx](./k8s/app-examples/statelessnginx/)
    * [Ingress Examples](./k8s/app-examples/ingress/)
    * [Load Balancer](./k8s/app-examples/loadbalancer/)
    * [ConfigMap Usage](./k8s/app-examples/configmap/)
    * [Persistent Volumes](./k8s/app-examples/persistentVolume/)
    * [Init Containers](./k8s/app-examples/initcontainers/)
    * [HTTP Route](./k8s/app-examples/httproute/)
    * [Terraform Nginx Deploy](./k8s/app-examples/terraform-nginx-deploy/)
    * [OpenTofu Nginx Deploy](./k8s/app-examples/opentofu-nginx-deploy/)
  * **DevOps & CI/CD**
    * [Argo CD](./k8s/argo-cd/) - GitOps continuous delivery
    * [Gitea](./k8s/gitea/) - Self-hosted Git service
    * [GitLab](./k8s/gitlab/) - DevOps platform
  * **Package Management**
    * [Helm](./k8s/helm/) - Kubernetes package manager
  * **Scaling & Automation**
    * [KEDA](./k8s/keda/) - Kubernetes Event-driven Autoscaling
  * **Security & Certificates**
    * [Cert Manager](./k8s/cert-manager/) - Certificate management
  * **Monitoring & Observability**
    * [Monitoring](./k8s/monitoring/) - Prometheus and monitoring stack
    * [Kubernetes Dashboard](./k8s/kubernetes-dashboard/) - Web-based UI
  * **Networking & Ingress**
    * [Nginx Fabric](./k8s/nginx-fabric/) - Nginx-based networking
    * [Cloud Provider Kind](./k8s/cloud-provider-kind/) - Cloud provider integration
