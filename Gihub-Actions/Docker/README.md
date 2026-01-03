# [GitHub Actions for Docker](../../.github/workflows/)
  * **Multi-Architecture Container Publishing**
    * Automated building and publishing of Docker containers for multiple architectures (linux/amd64, linux/arm64)
    * Integration with GitHub Container Registry (GHCR)
    * Automated cleanup to manage storage costs and stay within free tier limits
  * **Key Features**
    * Cross-platform builds using Docker Buildx and QEMU
    * Secure authentication with GitHub tokens
    * Intelligent tagging strategies (latest, semver, branch-based)
    * Build validation and caching optimization
    * Automated cleanup of old container versions

## GitHub Actions Docker Workflow Example

The [`publish-tg-tf-tofu.yml`](../../.github/workflows/publish-tg-tf-tofu.yml) workflow demonstrates a complete CI/CD pipeline for Docker containers:

### Multi-Architecture Build Process

```yaml
# Key components for multi-arch builds
- name: Set up QEMU
  uses: docker/setup-qemu-action@v3

- name: Set up Docker Buildx  
  uses: docker/setup-buildx-action@v3

- name: Build container
  uses: docker/build-push-action@v6
  with:
    platforms: linux/amd64,linux/arm64  # Multi-arch support
    push: true
    cache-from: type=gha                 # GitHub Actions cache
    cache-to: type=gha,mode=max
```

### Smart Tagging Strategy

The workflow uses Docker metadata action to generate intelligent tags:

- `latest` - Always points to the most recent build
- `main` - Branch-based tagging for main branch
- `v1.2.3` - Semantic version tags when using releases
- `v1.2` and `v1` - Major/minor version shortcuts

### Cost Management & Cleanup

**Automated Cleanup Job** runs after successful publish to manage container storage:

```yaml
cleanup:
  runs-on: ubuntu-latest
  needs: publish
  steps:
    - name: Delete old container versions
      uses: actions/delete-package-versions@v5
      with:
        package-name: 'terragrunt-terraform-tofu'
        package-type: 'container'
        min-versions-to-keep: '5'           # Keep only 5 most recent
        delete-only-untagged-versions: 'false'
```

#### Understanding Multi-Architecture Cleanup

The cleanup strategy keeps only the 5 most recent versions, but it's important to understand what this means for multi-architecture builds. Each "version" actually contains multiple manifests:

```bash
# Inspecting a multi-arch image shows the complexity
docker buildx imagetools inspect ghcr.io/mkilikrates/terragrunt-terraform-tofu:latest

Name:      ghcr.io/mkilikrates/terragrunt-terraform-tofu:latest
MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:291093000d932a1a5f82b8d0db3636bd48141c2504bf837796489c8bdfc79bea

Manifests:
  # AMD64 platform manifest
  Name:        ghcr.io/mkilikrates/terragrunt-terraform-tofu:latest@sha256:bee8213cc41b377f55f5779fc527406371ab91e94d10df96f309f60fbd40d8ce
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/amd64

  # ARM64 platform manifest  
  Name:        ghcr.io/mkilikrates/terragrunt-terraform-tofu:latest@sha256:d15114afbe3dfe3cd107869112c70dfb44d6e5759516a73a3ddfab8deeb150bd
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    linux/arm64

  # Build attestations for supply chain security
  Name:        ghcr.io/mkilikrates/terragrunt-terraform-tofu:latest@sha256:06f287aa91cec31fdb56126c56df26bd18e8892d36f1c946cf335786f4469c7c
  MediaType:   application/vnd.oci.image.manifest.v1+json
  Platform:    unknown/unknown
  Annotations: vnd.docker.reference.type: attestation-manifest
```

**Why Keep Only 5 Versions?**

Each multi-architecture build creates:
- 1 manifest index (the main tag like `latest`)
- 2 platform-specific manifests (linux/amd64, linux/arm64)  
- 2 attestation manifests (security provenance for each platform)
- Additional metadata and layers

This means a single "version" can consume significant storage. Keeping only 5 recent versions ensures:
- **Free Tier Compliance**: Stays well within GitHub's 500MB free package storage
- **Latest Availability**: Always keeps the most recent builds accessible
- **Multi-Platform Support**: Maintains both AMD64 and ARM64 variants
- **Security Attestations**: Preserves build provenance for supply chain security

### Benefits for Free Tier Users

1. **Storage Optimization**: Automatically removes old versions to stay within GitHub's free storage limits
2. **Multi-Architecture Support**: Single workflow builds for both AMD64 and ARM64 architectures
3. **Efficient Caching**: Uses GitHub Actions cache to speed up builds and reduce compute time
4. **Security**: Uses built-in `GITHUB_TOKEN` with minimal required permissions

### Best Practices Implemented

- **Build Validation**: Validates Dockerfile before actual build
- **Provenance**: Generates build attestations for supply chain security
- **Caching**: Optimizes build times with GitHub Actions cache
- **Permissions**: Uses minimal required permissions (`packages: write`, `contents: read`)
- **Error Handling**: Cleanup job only runs after successful publish

This approach ensures you can maintain a professional Docker publishing pipeline while staying within GitHub's free tier limits and avoiding unexpected costs.
