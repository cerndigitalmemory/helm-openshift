## Delete volumes

If you need to delete persistent volume claims (e.g. to reset the DB), after having deleted it from the OpenShift web UI, run:

```bash
oc patch pvc postgres-pvc -p '{"metadata":{"finalizers":null}}'
```

## Reset init containers

Run helm uninstall and install again
