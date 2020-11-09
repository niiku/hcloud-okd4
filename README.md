# OpenShift/OKD 4 on Hetzner Cloud
This terraform module helps to provision [OKD 4](https://github.com/openshift/okd) on Hetzner Cloud.
What it does is:
* Provision a server used to serve ignition files (required for booting Fedora CoreOS)
* Setup a Hetzner LoadBalancer targeting all servers on the ports 80, 443, 6443, 22623 and additionally points 8443 to 6443 (useful if behind corporate network)
* Setup bootstrap node, master nodes & worker nodes
* Downloads required Fedora CoreOS binaries in the /boot partition and creates a grub2 config which boots into Fedora CoreOS with the correct arguments
* Setup all required DNS entries using [CloudFlare](https://www.cloudflare.com/)

# Installation
As I couldn't get Fedora CoreOS properly running only using Hetzners private networks (input/PRs are welcome!) the servers are exposed using public IPs. Public access is prevented after the installation via `iptables` using a `DaemonSet`. External access is then only possible through the LoadBalancer. I recommended using a bastion node as it can be used a entrypoint over the network to your cluster and to store all required files and binaries for the installation and maintenance tasks. 

## Setup Bastion node
Provision a `CX11` or `CX11-CEPH` Hetzner Cloud Server using the operating system of your liking. I use `CX11-CEPH` as performance doesn't matter and VMs using Ceph as storage system are replicated. As operating system I use CentOS 8 as it's familiar to Fedora CoreOS. The provisioning process only takes a couple of seconds.
If you use the [hcloud CLI](https://github.com/hetznercloud/cli) you can run the following command instead of using the web console: 
```bash
hcloud context create okd4 # Read/Write token is required. This can be issued using the Hetzner Cloud Console
hcloud ssh-key create --name key --public-key-from-file=~/.ssh/id_rsa.pub
hcloud server create --image centos-8 --type cx11-ceph --name bastion --ssh-key key
hcloud server ssh bastion
```


### Disable SSH using a password
If not done during installation, setup SSH access via SSH keys. To disable SSH login via password, run the following command:
```bash
sudo sed -i -e 's#PasswordAuthentication yes#PasswordAuthentication no#' /etc/ssh/sshd_config
systemctl restart sshd
```
### Install tools
Install tar/unzip/git
```bash
sudo dnf install tar unzip git -y
```
Download the latest release of oc/openshift-install from https://github.com/openshift/okd/releases
```bash
curl -L https://github.com/openshift/okd/releases/download/4.5.0-0.okd-2020-10-15-235428/openshift-client-linux-4.5.0-0.okd-2020-10-15-235428.tar.gz | tar xvz
sudo mv oc kubectl /usr/local/bin/

curl -L https://github.com/openshift/okd/releases/download/4.5.0-0.okd-2020-10-15-235428/openshift-install-linux-4.5.0-0.okd-2020-10-15-235428.tar.gz | tar xvz
sudo mv openshift-install /usr/local/bin/
```
Download latest Linux 64-bit terraform binary from https://www.terraform.io/downloads.html
```bash
curl -o terraform.zip https://releases.hashicorp.com/terraform/0.13.5/terraform_0.13.5_linux_amd64.zip
unzip terraform.zip
sudo mv terraform /usr/local/bin/
```
### Create SSH key
To have access to the nodes during installation (and afterwards when Fedora CoreOS is in use) a SSH key must be in place on the bastion node. This key will also be referenced in the Terraform module. 
```bash
ssh-keygen -f ~/.ssh/id_rsa -q -N ""
```

### Clone this Git repo
```bash
git clone https://github.com/niiku/hcloud-okd4.git
```
## Create ignition files
Copy the install-config.yaml from the git repo into a separate directory
```bash
mkdir -p okd4/installer
cd okd4/
cp ~/hcloud-okd4/files/install-config.yaml install-config.yaml
vi install-config.yaml
```
Modify the install-config.yaml. Set `baseDomain` to your top level domain (e.g. example.tld). Set `metadata.name` to the wanted subdomain (e.g. okd for okd.example.tld). To get a pull secret for RedHat images (not required but useful) go to https://cloud.redhat.com/openshift/install/metal/installer-provisioned (RedHat user account required) and copy the secret into the `pullSecret` field. Don't forget to set the sshKey.
Copy the install-config.yaml to the `installer/` directory. This is useful as the install-config.yaml file disappears while generating the installer files. 
```bash
cp install-config.yaml installer/
```
Generate the ignition files
```bash
openshift-install create ignition-configs --dir=installer/
```
*Warning*: These ignition files containing certificates only valid for 24h. Recreate the files afterwards. 

## Create terraform.tfvars
Go inside the terraform module & copy the `terraform.tfvars.example` file:
```bash
cd ~/hcloud-okd4/tf/
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars
```
Modify the `terraform.tfvars` files accordingly.

## Install OKD4
Initialize terraform:
```bash
terraform init
```
Apply
```bash
terraform apply
```
You might see looping the error message on the VMs console on the master/worker nodes:
```
GET error: Get "https://api-int.okd.example.tld:22623/config/master": EOF
```
The master nodes are able to boot when the bootstrap server is ready. The worker nodes boot when the master nodes are ready. 
Let's wait for bootstrap server to complete. 
```bash
cd ~/okd4/installer/
openshift-install wait-for bootstrap-complete
```
After the bootstrap server is completed, verify that no CSRs are pending
```bash
export KUBECONFIG=~/okd4/installer/auth/kubeconfig
oc get csr
```
If there are pending CSRs run the following command:
```
oc get csr -o name | xargs oc adm certificate approve
```
**Worker nodes always must be approved manually**.

Afterwards, wait for installation to complete
```bash
openshift-install wait-for install-complete
```
You can access the web console at https://console-openshift-console.apps.${cluster_name}.${base_domain} using `kubeadmin` as user. The password is provided in
```bash
cat ~/okd4/installer/auth/kubeadmin-password
```

## Remove ignition/bootstrap node
After the installation is complete, the igition and bootstrap server can be removed.
```bash
cd ~/hcloud-okd4/tf
vi terraform.tfvars
[...]
bootstrap_enabled = false
ignition_enabled = false
[...]
```
Applying the changes:
```bash
terraform apply
```
The ignition server can be provisioned again when additional nodes should be added. When additional nodes are added later than 24h after cluster creation the worker.ign file must be updated (https://access.redhat.com/solutions/4799921)

# Setup Let's encrypt certificates for master api & ingress controller
After the installation, the master-api and ingress controller are using self-signed certificates. To provide Let's encrypt certificates install [cert-manager for OpenShift 4](https://cert-manager.io/docs/installation/openshift/). After the successful installation of cert-manager configure a [`ClusterIssuer`](https://cert-manager.io/docs/concepts/issuer/) for [Cloudflare](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/). 
## Setup Cloudflare as `ClusterIssuer`
Create a secret containing the Cloudflare API key (API token also possible, see the referenced documentation):
```bash
oc create secret generic cloudflare-api-key -n cert-manager --from-literal=api-key=<API-KEY>
```
Create the `ClusterIssuer`. Modify the `.spec.acme.email` and `.spec.acme.solvers[0].dns.cloudflare.email`.
```bash
oc apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: cloudflare-lets-encrypt-prod
spec:
  acme:
    email: <le-email>
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: cloudflare-issuer-account-key
    solvers:
    - dns01:
        cloudflare:
          email: <cloudflare-email>
          apiKeySecretRef:
            name: cloudflare-api-key
            key: api-key
EOF
```

## Configure default certificate for ingress-controller
The ingress-controller (router) can be configured to use a default certificate. This certificate will also be used to server the OpenShift web console. 
Modify the `.spec.dnsNames` to match your default *.apps domain and additional domains. 
```bash
oc apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: default-ingress-tls
  namespace: openshift-ingress
spec:
  secretName: default-ingress-tls
  dnsNames:
  - apps.okd.example.tld
  - *.apps.okd.example.tld
  issuerRef:
    name: cloudflare-lets-encrypt-prod
    kind: ClusterIssuer
    group: cert-manager.io
EOF
```
Verify the requested certificate is saved as secret (may take a minute):
```bash
oc get secret default-ingress-tls -n openshift-ingress
```
If the certificate isn't issued, verify the cert-manager pod logs. When the certificate is issued successfully, configure the ingress controller to use the new certificate.
```bash
oc patch ingresscontroller.operator default --type=merge -p '{"spec":{"defaultCertificate": {"name": "default-ingress-tls"}}}' -n openshift-ingress-operator
```
It might take a while until the Let's encrypt certificate is served as default certificate as the router pods will be redeployed. 

## Configure certificate for master api 
Modify the `.spec.dnsNames` to match your public master API url . 
```bash
oc apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: master-apiserver-tls
  namespace: openshift-config
spec:
  secretName: master-apiserver-tls
  dnsNames:
  - api.okd.example.tld
  issuerRef:
    name: cloudflare-lets-encrypt-prod
    kind: ClusterIssuer
    group: cert-manager.io
EOF
```
Verify the requested certificate is saved as secret (may take a minute):
```bash
oc get secret master-apiserver-tls -n openshift-config
```
If the certificate isn't issued, verify the cert-manager pod logs. When the certificate is issued successfully, configure the master api to use the new certificate. Modify the `.spec.servingCerts.namedCertificates[0].names` field.
```bash
oc patch apiserver cluster --type=merge -p '{"spec":{"servingCerts": {"namedCertificates":[{"names": ["api.okd.example.tld"],"servingCertificate": {"name": "master-apiserver-tls"}}]}}}'
```
It might take a while until the Let's encrypt certificate is served.


## References
* https://medium.com/@craig_robinson/guide-installing-an-okd-4-5-cluster-508a2631cbee
* https://github.com/openshift/okd/releases
* https://origin-release.svc.ci.openshift.org/
* https://github.com/cragr/okd4_files
