# OAIS Platform on Kubernetes

This repository provides a Helm chart to deploy the CERN Digital Memory [platform](https://gitlab.cern.ch/digitalmemory/oais-platform) on a Kubernetes cluster.

> This setup makes use of some CERN specific technology (EOS volume mounts, SSO) and it's designed for a k8s cluster orchestrated by OpenShift. You may need some modification to make this work on a different stack (e.g. minikube). See [this paragraph](#local-deployment-on-kubernetes) for more information.

Table of contents:

- [Overview](#overview)
  - [Prerequisites](#prerequisites)
  - [Clone the repository](#clone-the-repository)
  - [Docker image](#docker-image)
    - [Pull](#pull)
    - [Build yourself](#build-yourself)
- [Deploy on OpenShift](#deploy-on-openshift)
  - [Preliminar notes](#preliminar-notes)
  - [Create an OpenShift project](#create-an-openshift-project)
    - [Login](#login)
    - [Secrets](#secrets)
    - [Configuration](#configuration)
    - [Install](#install)
  - [Deploy changes](#deploy-changes)
- [Continuous Deployment](#continuous-deployment)
  - [Current configuration](#current-configuration)
  - [Local deployment on Kubernetes](#local-deployment-on-kubernetes)
- [References](#references)

# Overview

Here's the structure of this repository:

- `oais-openshift/`, Helm chart and templates
- `Dockerfile`, to build the base image
- `develop/`, values for our develop deployment
- `master/`, values for our stable deployment
- `.gitlab-ci.yml`, CI/CD pipeline

## Prerequisites

- Helm
- OpenShift Client
- Docker (if building the image from source)

Download the OpenShift CLI client:

```bash
curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.8.4/openshift-client-linux.tar.gz -o oc.tar.gz
tar -xf oc.tar.gz
sudo mv ./oc /usr/bin/oc
```

Download Helm:

```
curl https://get.helm.sh/helm-v3.6.3-linux-amd64.tar.gz -o helm.tar.gz
tar -xf helm.tar.gz
sudo mv ./linux-amd64/helm /usr/bin/helm
```

## Clone the repository

Start by cloning this repository

```bash
git clone --recurse-submodules https://gitlab.cern.ch/digitalmemory/openshift-deploy.git
cd openshift-deploy
```

## Docker image

The main application will be provided by a Docker image, defined by the Dockerfile in this repository.

The image:

- Pulls node and any npm requirement for the frontend
- Generates a static build of the frontend
- Pulls python and python requirements, preparing an enviroment that will be able to run Django

### Pull

The easiest option is to pull it from our [Docker containers registry](https://gitlab.cern.ch/digitalmemory/openshift-deploy/container_registry):

```bash
# Use the image from this repository registry
docker run gitlab-registry.cern.ch/digitalmemory/openshift-deploy/oais_dev:latest

# Build the docker image
docker build --tag <name> .

# Push the image on a registry of your choice
docker push <name>
```

We provide two "channels" for this image:

- `oais_dev` is built from `develop` branches of `oais-web` and `oais-platform` (which in turn uses the develop git version of BagIt Create)
- `oais_master` is built from `master` branches of `oais-web` and `oais-platform` (which in rn uses a tagged released version of BagIt Create)

### Build yourself

You can also build the Docker image image yourself. It expects to be built from a context folder where both the backend and frontend are cloned.

E.g.:

```
git clone ssh://git@gitlab.cern.ch:7999/digitalmemory/oais-platform.git
git clone ssh://git@gitlab.cern.ch:7999/digitalmemory/oais-web.git
docker build .
```

> You can specify the context by passing the `--context` parameter to the Docker command

# Deploy on OpenShift

## Preliminar notes

Some features require additional setup:

- Sentry
- CERN SSO
- EOS Volumes
- InvenioRDM integration

Check the [oais-platform](https://gitlab.cern.ch/digitalmemory/oais-platform) documentation on how to set those up.

## Create an OpenShift project

Go to https://paas.cern.ch and create a project. Note the **project name**. On the OpenShift panel, go to your user click "copy login command" and note:

- Your auth **token**
- The OpenShift cluster API **endpoint** (should be `https://api.paas.okd.cern.ch/`)

### Login

Login and select the desired project. To login, you can copy the login command directly from the OpenShift dashboard.

```bash
oc login --token=<token> --server=https://api.paas.okd.cern.ch
oc project <project>
```

## Configuration

Now, let's set some more variables by editing the `values.yaml` file. An example is found in `oais-openshift/values.yaml`.

| Name               | Description                                           |
| ------------------ | ----------------------------------------------------- |
| oais/hostname      | Should be set to <openshift_project_name>.web.cern.ch |
| oais/image         | Set as you prefer, but long and safe strings.         |
| oidc/clientId      | From your registered CERN Application, for CERN SSO.  |
| inveniordm/baseUrl | Base URL of your InvenioRDM instance                  |

### Secrets

Some other configuration values need to be set as secrets.

```bash
oc create secret generic \
  --from-literal="POSTGRESQL_PASSWORD=<value>" \
  --from-literal="DJANGO_SECRET_KEY=<value>" \
  --from-literal="OIDC_RP_CLIENT_SECRET=<value>" \
  --from-literal="SENTRY_DSN=<value>" \
  --from-literal="INVENIO_API_TOKEN=<value>" \
  oais-secrets
```

| Secret name           | Description                                                                                  |
| --------------------- | -------------------------------------------------------------------------------------------- |
| POSTGRESQL_PASSWORD   | Passphrase to login to Postgres. Set as you prefer, but long and safe strings.               |
| DJANGO_SECRET_KEY     | Set as you prefer, but long and safe strings.                                                |
| OIDC_RP_CLIENT_SECRET | From your registered CERN Application, for CERN SSO.                                         |
| SENTRY_DSN            | SENTRY_DSN value from your Sentry project                                                    |
| INVENIO_API_TOKEN     | Token to authenticate and publish to the InvenioRDM instance specified in inveniordm/baseUrl |

## Install

Deploy the platform on the cluster, you can choose the release name you prefer

```bash
helm install <release-name> ./oais-openshift --values=values.yaml
```

## Deploy changes

After changing any configuration file, update the configuration on the cluster

```bash
helm upgrade <release-name> ./oais-openshift
```

# Continuous Deployment

To allow a pipeline executor run these commands, without having to authenticate as you, let's create an OpenShift service account:

```bash
oc create sa gitlab-ci
```

Grant edit permissions to the new service account

```bash
oc policy add-role-to-user edit -z gitlab-ci
```

The API token to be used from the CI/CD pipeline is automatically generated and saved in the secrets. Go to the Project details on the OpenShift dashboards, select Secrets and select the `gitlab-ci-token-XXXX` secret. The `token` string can be used in the `oc login` commands.

This token is set as "CI Variable" in GitLab and read it from the pipeline definition.

To use a single service account for multiple projects (e.g. in this setup for the two deployments), after logging in with an account that has permissions on both, you can run:

```
oc policy add-role-to-user admin system:serviceaccount:dm-luteus:gitlab-ci -n dm-galanos
```

This gives the `gitlab-ci` service account, created in `dm-luteus`, admin permissions also in `dm-galanos` so only 1 token can be used and set up.

## Current configuration

Whenever new commits are pushed to `oais-web` or `oais-platform`, the pipeline on `openshift-deployment` is triggered to make a new deployment.
This pipeline creates a new commit on `openshift-deployment` that updates the git submodules in the repository.
After the commit is pushed, the docker image is rebuilt and the configuration is deployed on OpenShift.

This behaviour is defined in the `.gitlab-ci.yml` file of the following repositories:

- [openshift-deploy](https://gitlab.cern.ch/digitalmemory/openshift-deploy/-/blob/develop/.gitlab-ci.yml)
- [oais-platform](https://gitlab.cern.ch/digitalmemory/oais-platform/-/blob/develop/.gitlab-ci.yml)
- [oais-web](https://gitlab.cern.ch/digitalmemory/oais-web/-/blob/develop/.gitlab-ci.yml)

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

# References

- [PaaS@CERN docs](https://paas.docs.cern.ch/)
- [Kubernetes@CERN docs](https://kubernetes.docs.cern.ch/)
- [PaaS@CERN: How to mount an EOS volume on a deployed application](https://paas.docs.cern.ch/3._Storage/eos/)
- [Service accounts in OpenShift](https://docs.openshift.com/container-platform/4.9/authentication/using-service-accounts-in-applications.html)
