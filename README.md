# OAIS Platform on OpenShift

## Prerequisites

- Helm
- OpenShift Client
- Docker (if building the image from source)

```bash
# Download the OpenShift CLI client
curl https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.8.4/openshift-client-linux.tar.gz -o oc.tar.gz
tar -xf oc.tar.gz
sudo mv ./oc /usr/bin/oc
# Download Helm
curl https://get.helm.sh/helm-v3.6.3-linux-amd64.tar.gz -o helm.tar.gz
tar -xf helm.tar.gz
sudo mv ./linux-amd64/helm /usr/bin/helm
```

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


# Deploy on OpenShift

## Preliminar notes

To enable CERN SSO, you should:

- Create an Application at <https://application-portal.web.cern.ch>
- Select the application and create a new "Open ID Connect (OIDC)" CERN SSO Registration
- Fill in the values considering that the final exposed Base URL will be `<openshift_project_name>.web.cern.ch`
- Note the client secret (`OIDC_RP_CLIENT_SECRET`) and the **Client ID**.

More information can be found [here](https://auth.docs.cern.ch/user-documentation/oidc/oidc/).

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

### Secrets

We will need to set some secrets for the Django project.

```bash
oc create secret generic \
  --from-literal="POSTGRESQL_PASSWORD=<password>" \
  --from-literal="DJANGO_SECRET_KEY=<secret key>" \
  --from-literal="OIDC_RP_CLIENT_SECRET=<secret>" \
  --from-literal="SENTRY_DSN=<value>" \
  oais-secrets
```

| Secret name           | Description                                                                     |
|-----------------------|---------------------------------------------------------------------------------|
| POSTGRESQL_PASSWORD   | Passphrase to login to Postgres. Set as you prefer, but long and safe strings.  |
| DJANGO_SECRET_KEY     | Set as you prefer, but long and safe strings.                                   |
| OIDC_RP_CLIENT_SECRET | From your registered CERN Application, for CERN SSO.                            |
| SENTRY_DSN            | SENTRY_DSN value from your Sentry project                                       |

### Configuration

Now, let's set some more variables by editing the `values.yaml` file. An example is found in `oais-openshift/values.yaml`.

| Name                  | Description                                                                     |
|-----------------------|---------------------------------------------------------------------------------|
| oais/hostname         | Should be set to <openshift_project_name>.web.cern.ch                           |
| oais/image            | Set as you prefer, but long and safe strings.                                   |
| oidc/clientId         | From your registered CERN Application, for CERN SSO.                            |


### Install

Deploy the platform on the cluster, you can choose the release name you prefer

```bash
helm install <release-name> ./oais-openshift --values=values.yaml
```

## Deploy changes

After changing any configuration file, update the configuration on the cluster

```bash
helm upgrade <release-name> ./oais-openshift
```

## Continuous Deployment

To allow a pipeline executor run these commands, without having to authenticate as you, let's create an OpenShift service account:

```bash
oc create sa gitlab-ci
```

Grant edit permissions to the new service account

```bash
oc policy add-role-to-user edit -z gitlab-ci
```

The API token to be used from the CI/CD pipeline is automatically generated and saved in the secrets. Go to the Project details on the OpenShift dashboards, select Secrets and reveal the values from the `gitlab-ci-token` secret. The `token` string can be used in the `oc login` commands.

This token is set as "CI Variable" in GitLab and read it from the pipeline definition.


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

# References

- [PaaS docs @CERN](https://paas.docs.cern.ch/)
- [Kubernetes@CERN docs](https://kubernetes.docs.cern.ch/)
- [How to mount an EOS volume on a deployed application](https://paas.docs.cern.ch/3._Storage/eos/)
