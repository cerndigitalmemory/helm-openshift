# OAIS Platform on OpenShift

## Prerequisites

- Helm
- OpenShift Client
- Docker (if building the image from source)

## Clone the repository

Clone this repository and change the working directory

```bash
git clone --recurse-submodules https://gitlab.cern.ch/digitalmemory/openshift-deploy.git
cd openshift-deploy
```

## Docker image

You can use the image uploaded in this repository Docker registry or build one using the provided Dockerfile.

```bash
# Use the image from this repository registry
docker run gitlab-registry.cern.ch/digitalmemory/openshift-deploy/oais

# Build the docker image
docker build --tag <name> .

# Push the image on a registry of your choice
docker push <name>
```

## Customize the settings

Based on your deploy, change the settings in `./oais-openshift/values.yaml`

## Deploy

### Login

Login and select the right project. To login, you can copy the login command directly from the OpenShift dashboard.

```bash
oc login <url-to-openshift-cluster>
oc project <project>
```

### Secrets

Create a new OpenShift secret for the PostgreSQL password and the client secret used by OpenID Connect

```bash
oc create secret generic \
  --from-literal="POSTGRESQL_PASSWORD=<password>" \
  --from-literal="OIDC_RP_CLIENT_SECRET=<secret>" \
  --from-literal="DJANGO_SECRET_KEY=<secret key>" \
  oais-secrets
```

### Install

Deploy the platform on the cluster, you can choose the release name you prefer

```bash
helm install <release-name> ./oais-openshift
```

## Deploy changes

After changing any configuration file, update the configuration on the cluster

```bash
helm upgrade <release-name> ./oais-openshift
```

## Continuous Deployment

Create a new service account

```bash
oc create sa gitlab-ci
```

Grant edit permissions to the new service account

```bash
oc policy add-role-to-user edit -z gitlab-ci
```

The API token to be used from the CI/CD pipeline is automatically generated and saved in the secrets

### Current configuration

Whenever new commits are pushed to `oais-web` or `oais-platform`, the pipeline on `openshift-deployment` is triggered to make a new deployment.
This pipeline creates a new commit on `openshift-deployment` that updates the submodules in the repository.
After the commit is pushed, the docker image is rebuilt and the configuration is deployed on OpenShift.

## Local deployment on Kubernetes

You can test the deployment locally using k8s (e.g. with minikube) by setting the following values in `oais-openshift/values.yaml`:

- `oais.checkHostname: false`
- `redis.persistence.enabled: false`
- `postgres.persistence.enabled: false`
- `route.enabled: false`

To access the control interface, add `type: NodePort` to `spec` in the `oais-platform` service and then visit the URL given by
```bash
minikube service --url oais-platform
```

## TODO

- Add support for external PostgreSQL instance (e.g. to use CERN DBoD)
- Use gunicorn instead of the development server
- Configure probes
