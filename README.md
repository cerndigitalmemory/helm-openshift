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
  - [Configuration](#configuration)
    - [Secrets](#secrets)
  - [Install](#install)
  - [Deploy changes](#deploy-changes)
  - [Delete volumes](#delete-volumes)
- [Continuous Deployment](#continuous-deployment)
  - [Current configuration](#current-configuration)
  - [Local deployment on Kubernetes](#local-deployment-on-kubernetes)
- [Archivematica integration](#archivematica-integration)
- [References](#references)

# Overview

Here's the structure of this repository:

- `oais-openshift/`, Helm chart and templates
- `Dockerfile`, to build the base image
- `develop/`, values for our **develop** deployment (luteus)
- `master/`, values for our **stable** deployment (galanos)
- `preserve-qa/`, values for our **preserve-qa** deployment
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

| Channel     | Oais-web branch | Oais-platform branch | BagIt-Create branch     |
| ----------- | --------------- | -------------------- | ----------------------- |
| oais_dev    | develop         | develop              | git/develop version     |
| oais_master | master          | master               | tagged released version |

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

Some features may require additional setup:

- Sentry
- CERN SSO
- EOS Volumes
- InvenioRDM
- Archivematica
- CTA and FTS

> This section will be focusing on k8s/openshift-related configuration steps and in what way they should be combined. Details on how to obtain the values and set up the configurable features won't be covered here: refer to the configurations paragraphs on the [backend](https://gitlab.cern.ch/digitalmemory/oais-platform), [frontend](https://gitlab.cern.ch/digitalmemory/oais-web) and [Archivematica](https://gitlab.cern.ch/digitalmemory/archivematica-helm/#configuration) documentation.


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

First, let's set some configuration variables by editing the `values.yaml` file. An example is found in `oais-openshift/values.yaml`.

| Name               | Description                                                                     |
| ------------------ | ------------------------------------------------------------------------------- |
| oais/hostname      | Should be set to <openshift_project_name>.web.cern.ch                           |
| oais/image         | Set as you prefer, but long and safe strings.                                   |
| oidc/clientId      | From your registered CERN Application, for CERN SSO.                            |
| inveniordm/baseUrl | Base URL of your InvenioRDM instance                                            |
| oais/sipPath       | Base path where SIPs will be created and uploaded. Must exist and be writeable. |

### Secrets

Some other configuration values need to be set as secrets.

```bash
oc create secret generic \
  --from-literal="POSTGRESQL_PASSWORD=<value>" \
  --from-literal="DJANGO_SECRET_KEY=<value>" \
  --from-literal="OIDC_RP_CLIENT_SECRET=<value>" \
  --from-literal="SENTRY_DSN=<value>" \
  --from-literal="INVENIO_API_TOKEN=<value>" \
  --from-literal="AM_API_KEY=<value>" \
  --from-literal="AM_SS_API_KEY=<value>" \
  oais-secrets
```

| Secret name           | Description                                                                                    |
| --------------------- | ---------------------------------------------------------------------------------------------- |
| POSTGRESQL_PASSWORD   | Passphrase to login to Postgres. Set as you prefer, but long and safe strings.                 |
| DJANGO_SECRET_KEY     | Set as you prefer, but long and safe strings.                                                  |
| OIDC_RP_CLIENT_SECRET | From your registered CERN Application, for CERN SSO.                                           |
| SENTRY_DSN            | SENTRY_DSN value from your Sentry project                                                      |
| INVENIO_API_TOKEN     | Token to authenticate and publish to the InvenioRDM instance specified in `inveniordm/baseUrl` |
| AM_API_KEY            | Token to authenticate to archivematica **dashboard** specified in `username > Your Profile > Users` |
| AM_SS_API_KEY         | Token to authenticate to archivematica **storage service** specified in `username > Your Profile > Users` |

## Install

Deploy the platform on the cluster. Choose the release name you prefer.

```bash
helm install <RELEASE_NAME> ./oais-openshift --values=values.yaml
```

## Update configuration

If you changed the chart or the values:

```bash
# Select the project
oc project
# List releases
helm list
# Upgrade
helm upgrade <RELEASE_NAME> ./oais-openshift --values=values.yaml
```

By default, this won't re-pull of the images.

### FTS

You need the public and private (passwordless) parts of a Grid certificate to authenticate with FTS. More information can be [found here](https://gitlab.cern.ch/digitalmemory/oais-platform#fts).

```
oc create secret generic \
  --from-file=public=<PATH_TO_THE_PUBLIC_PART> \
  --from-file=private=<PATH_TO_THE_PRIVATE_PART> \
  grid-certificates
```

### EOS

If you plan to use EOS (e.g. for the sipPath), you need some additional steps. Please refer to [PaaS@CERN: How to mount an EOS volume on a deployed application](https://paas.docs.cern.ch/3._Storage/eos/) to learn more.

First, you need to provide the credentials of a CERN account able to read/write from those folders on EOS:

```
oc create secret generic \
  --from-literal="KEYTAB_USER=<USERNAME>" \
  --from-literal="KEYTAB_PWD=<PASSWORD>" \
  eos-credentials
```

Then, inject the authentication sidecar to the Django and Celery deployments:

```
oc patch deploy/oais-platform -p '{"spec":{"template":{"metadata":{"annotations":{"eos.okd.cern.ch/mount-eos-with-credentials-from-secret":"eos-credentials"}}}}}'

oc patch deploy/celery -p '{"spec":{"template":{"metadata":{"annotations":{"eos.okd.cern.ch/mount-eos-with-credentials-from-secret":"eos-credentials"}}}}}'
```

Finally, attach a PVC to the django deployment:

```
oc set volume deployment/oais-platform --add --name=eos --type=persistentVolumeClaim --mount-path=/eos --claim-name=eos-volume-celery --claim-class=eos --claim-size=1
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

# Archivematica integration

To integrate archivematica with the platform modify the variables in your `values.yaml` file

* **AM_URL**: Url that hosts archivematica dashboard
* **AM_USERNAME**: Archivematica user name
* **AM_SS_URL**: Url that hosts archivematica storage service
* **AM_SS_USERNAME**: Archivematica storage service user name
* **AM_TRANSFER_SOURCE**: Add the uuid of the transfer source (at Storage service go to Locations and copy the UUID of the transfer source location)


## Additional configuration

When you have deployed archivematica, you need to make sure that both archivematica and the platform have read/write access on the same folder. To do this you need to specify the following values in your `values.yaml` file

* `oais.sipPath`: The directory where the platform stores the created SIPs
* `oais.aipPath`: The directory where the platform expects the AIPs from archivematica
* `archivematica.am_abs_directory`: The directory where archivematica expects the SIPs from the platform (must be the same with `oais.sipPath`)

### Make sure Archivematica has access to the eos volume

You should've run similar steps as the one listed [in the EOS paragraph of this document](#EOS) to mount the EOS volume in Archivematica too.

```
oc patch deploy/archivematica-all -p '{"spec":{"template":{"metadata":{"annotations":{"eos.okd.cern.ch/mount-eos-with-credentials-from-secret":"eos-credentials"}}}}}'
```

```
oc set volume deployment/archivematica-all --add --name=eos --type=persistentVolumeClaim --mount-path=/eos --claim-name=eos-volume --claim-class=eos --claim-size=1
```


### "AIP Storage" (SS Locations) must be set to `oais.aipPath`

In addition the Transfer Source and AIPStorage locations must be configured manually from the **Storage Service** by going to `Locations` tab and on the `AIP Storage` purpose row click the `Edit` action. 

In the `Relative Path` text area put the AIP path (the one used above in the `oais.aipPath` field) and make sure archivematica and the platform have read/write access to it. Click the `Edit Location` button at the bottom of the page to save the configuration.

### "Transfer Source" (SS Locations) must be set to `oais.aipPath`

The same steps must be followed for the `Transfer Source` purpose row but you need to put the SIP path instead.

### Set a quota for SS "Internal Processing"

Go to `Spaces`, click `View Details and Locations` and edit `Storage Service Internal Processing`. Set quota to 1000000 (10GB) as this will be preallocated and we don't want to exceed what the PVC attached to the pod has been reserved (see archivematica-k8s for details)



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
