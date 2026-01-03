# GitHub Actions Feature Flag Testing

This guide demonstrates how to create an automated testing workflow for LaunchDarkly feature flags using GitHub Actions. The workflow builds a Node.js Docker container, tests feature flag behavior, and validates flag state changes through API calls.

## Overview

The `feature-flag-boolean` workflow performs the following automated tests locally:

1. **Build Locally**: Builds the LaunchDarkly Node.js application as a Docker container (no registry push)
2. **Start Container**: Runs the application container locally with environment variables
3. **Initial Test**: Tests the application with the current flag state
4. **API Integration**: Uses LaunchDarkly API to check and toggle flag states
5. **Validation**: Verifies the application responds correctly to flag changes
6. **Cleanup**: Restores original flag state and removes local containers/images

## Required Secrets

You need to configure the following secrets in your GitHub repository:

### LaunchDarkly Application Secrets

| Secret Name | Description | Where to Find |
|-------------|-------------|---------------|
| `LAUNCHDARKLY_SDK_KEY` | Server-side SDK key for your environment | LaunchDarkly Dashboard → Account Settings → Projects → [Your Project] → Environments → [Environment] → SDK Keys |
| `LAUNCHDARKLY_FLAG_KEY` | The key of the feature flag to test | LaunchDarkly Dashboard → Feature Flags → [Your Flag] → Settings → Flag Key |

### LaunchDarkly API Secrets (for flag toggling)

| Secret Name | Description | Where to Find |
|-------------|-------------|---------------|
| `LAUNCHDARKLY_API_TOKEN` | Personal access token for API calls | LaunchDarkly Dashboard → Account Settings → Authorization → Personal API Access Tokens → Create Token |
| `LAUNCHDARKLY_PROJECT_KEY` | Project identifier | LaunchDarkly Dashboard → Account Settings → Projects → [Your Project] → Project Key |
| `LAUNCHDARKLY_ENVIRONMENT_KEY` | Environment identifier (e.g., 'production', 'test') | LaunchDarkly Dashboard → Account Settings → Projects → [Your Project] → Environments → [Environment] → Environment Key |

## Setting Up GitHub Secrets

### Step 1: Navigate to Repository Settings

1. Go to your GitHub repository
2. Click on **Settings** tab
3. In the left sidebar, click **Secrets and variables** → **Actions**

### Step 2: Add Repository Secrets

Click **New repository secret** for each required secret:

#### LaunchDarkly SDK Key
```
Name: LAUNCHDARKLY_SDK_KEY
Secret: sdk-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

#### Feature Flag Key
```
Name: LAUNCHDARKLY_FLAG_KEY
Secret: your-feature-flag-key
```

#### API Access Token
```
Name: LAUNCHDARKLY_API_TOKEN
Secret: api-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

#### Project Key
```
Name: LAUNCHDARKLY_PROJECT_KEY
Secret: your-project-key
```

#### Environment Key
```
Name: LAUNCHDARKLY_ENVIRONMENT_KEY
Secret: production
```

### Step 3: Verify Secrets

After adding all secrets, you should see them listed in the **Repository secrets** section (values will be hidden).

## LaunchDarkly Setup Guide

### Getting Your SDK Key

1. Log in to [LaunchDarkly Dashboard](https://app.launchdarkly.com/)
2. Navigate to **Account Settings** → **Projects**
3. Select your project
4. Go to **Environments** tab
5. Click on your target environment (e.g., "Production")
6. Copy the **Server-side SDK key**

### Getting Your API Token

1. In LaunchDarkly Dashboard, go to **Account Settings**
2. Click **Authorization** in the left menu
3. Go to **Personal API Access Tokens**
4. Click **Create Token**
5. Configure token permissions:
   - **Name**: GitHub Actions Feature Flag Testing
   - **Role**: Writer (or custom role with flag modification permissions)
   - **Resources**: Select your project and environment
6. Copy the generated token immediately (it won't be shown again)

### Getting Project and Environment Keys

1. **Project Key**: Account Settings → Projects → [Your Project] → Project Key
2. **Environment Key**: Account Settings → Projects → [Your Project] → Environments → [Environment] → Environment Key

## Workflow Features

The `feature-flag-boolean.yml` workflow includes:

### Build & Test Job (Single Job)
- Builds the Node.js LaunchDarkly application locally (no registry push)
- Starts a Docker container with secrets from GitHub
- **Flag Evaluation**: Uses official `launchdarkly/gha-flags` action for reliable flag state checking
- **Application Test**: Makes HTTP requests to test endpoints
- **Flag Toggle**: Changes flag state via LaunchDarkly API
- **State Verification**: Uses LaunchDarkly action again to confirm flag changes
- **Validation Test**: Verifies application responds to flag change
- **State Restoration**: Restores original flag state with verification
- **Local Cleanup**: Removes containers and images to keep runner clean

### API Integration
- Uses **LaunchDarkly GitHub Action** for flag evaluation (more reliable than raw API calls)
- Uses LaunchDarkly REST API only for flag state changes (toggling)
- Implements proper error handling and retries
- Validates flag state changes using official action

### Security Features
- All sensitive data stored as GitHub secrets
- No credentials exposed in logs
- Secure API token handling
- **No registry operations** - everything stays local to the runner
- Automatic cleanup of local resources

## Workflow Triggers

The workflow can be triggered by:

- **Manual Dispatch**: Run on-demand from GitHub Actions tab
- **Pull Request**: Test flag behavior in PR environments
- **Schedule**: Regular automated testing (e.g., daily)
- **Push to Main**: Validate after deployments

## Expected Workflow Output

```
✅ Build Docker image locally
✅ Start LaunchDarkly application container
✅ Application is ready!
✅ Get Current Flag State (LaunchDarkly Action): false
✅ Test Application (Flag: false)
✅ Toggle Flag State to: true
✅ Verify Flag State Change (LaunchDarkly Action): true
✅ Test Application (Flag: true)
✅ Restore Original Flag State: false
✅ Final Flag State Verification (LaunchDarkly Action): false
✅ Local cleanup completed
```

## Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Verify SDK key is correct and for the right environment
   - Check API token has proper permissions

2. **Flag Not Found**
   - Confirm flag key matches exactly (case-sensitive)
   - Ensure flag exists in the specified project/environment

3. **API Rate Limits**
   - LaunchDarkly has API rate limits
   - Workflow includes appropriate delays between calls

4. **Application Connection Issues**
   - Verify application starts correctly with provided SDK key
   - Check Docker container networking configuration

### Debug Mode

Enable debug logging by adding this secret:
```
Name: ACTIONS_STEP_DEBUG
Secret: true
```

## Next Steps

1. Set up all required secrets following this guide
2. Create the `feature-flag-boolean.yml` workflow file
3. Test the workflow with a manual trigger
4. Customize the workflow for your specific testing needs

## Security Best Practices

- **Rotate API tokens** regularly
- **Use environment-specific keys** (don't use production keys for testing)
- **Limit API token permissions** to only what's needed
- **Monitor API usage** in LaunchDarkly dashboard
- **Use separate LaunchDarkly environments** for CI/CD testing

## Related Documentation

- [LaunchDarkly Node.js SDK](https://docs.launchdarkly.com/sdk/server-side/node-js)
- [LaunchDarkly REST API](https://apidocs.launchdarkly.com/)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Docker Node.js Example](../../Docker/programming/nodejs/examples/launchdarkly/)