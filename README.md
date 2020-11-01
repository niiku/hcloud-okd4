# OpenShift/OKD 4 on Hetzner Cloud

```
mkdir -p okd4/installer
cd okd4/
cp files/install-config.yaml installer/install-config.yaml
openshift-install create manifests --dir=installer/
openshift-install create ignition-configs --dir=installer/
```


## Approve Certificate Signing Requests
Verify if CSRs are pending. Might be required to add worker nodes
```bash
oc get csr
```
Get jq
```bash
wget -O jq https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64
```
Approve all pending CSRs
```
oc get csr -ojson | jq -r '.items[] | select(.status == {} ) | .metadata.name' | xargs oc adm certificate approve
```

## References
* https://medium.com/@craig_robinson/openshift-4-4-okd-bare-metal-install-on-vmware-home-lab-6841ce2d37eb
* https://github.com/openshift/okd/releases
* https://origin-release.svc.ci.openshift.org/
* https://github.com/cragr/okd4_files