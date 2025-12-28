You should not modify the k8s cluster by directly applying, you may make code changes and reconcile them using flux.

Namespaces are broader than common. You can find the following utilities in the following namespaces:

`storage` contains:
- Longhorn
- Volsync

A number of components are loaded from `/kubernets/components/*` and are loaded as part of the flux kustomization, these
include but are not limited to; volsync, cnpg instances, external-auth and certain common structures.

Don't use force deletions unless you've tried normally first.