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

You can use the `gitlab-registry.cern.ch/digitalmemory/openshift-deploy/oais` docker image.

Otherwise, you can build the docker image using the provided Dockerfile

```bash
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

## TODO

- Use persistent volume to store PostgreSQL data
- Use uWSGI instead of development server
- Configure probes
