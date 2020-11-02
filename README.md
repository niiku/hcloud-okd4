# OpenShift/OKD 4 on Hetzner Cloud
This terraform module helps to provision [OKD 4](https://github.com/openshift/okd) on Hetzner Cloud.
What it does is:
* Provision a server used to serve ignition files (required to boot in Fedora CoreOS)
* Setup LoadBalancer targeting all servers on the ports 80, 443, 6443, 22623 and additionally points 8443 to 6443 (useful if behind corporate network)
* Setup bootstrap node, master nodes & worker nodes
* Downloads required Fedora CoreOS binaries in the /boot partition and creates a grub2 config which boots into Fedora CoreOS with the correct arguments
* Setup all required DNS entries using [CloudFlare](https://www.cloudflare.com/)

# Installation
As I couldn't get Fedora CoreOS properly running only using Hetzners private networks (input/PRs are welcome!) the servers are exposed using public IPs. Public access is prevented after the installation via `iptables` using a `DaemonSet`. External access is then only possible through the LoadBalancer. I recommended using a bastion node as it can be used a entrypoint over the network to your cluster and to store all required files and binaries for the installation and maintenance tasks. 

## Setup Bastion node
Provision a `CX11` or `CX11-CEPH` Hetzner Cloud Server using the operating system of your liking. I use `CX11-CEPH` as performance doesn't matter and VMs using Ceph as storage system are replicated. As operating system I use CentOS 8 as it's familiar to Fedora CoreOS. The provisioning process only takes a couple of seconds.
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
sudo dnf install tar -y
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
git clone https://github.com/niiku/hcloud-okd-4.git
```
### Create ignition files
Copy the install-config.yaml from the git repo into a separate directory
```bash
mkdir -p okd4/installer
cd okd4/
cp ~/hcloud-okd-4/files/install-config.yaml install-config.yaml
vi installer/install-config.yaml
```
Modify the install-config.yaml. Set `baseDomain` to your top level domain (e.g. example.tld). Set `metadata.name` to the wanted subdomain (e.g. okd for okd.example.tld). To get a pull secret for RedHat images (not required but useful) go to https://cloud.redhat.com/openshift/install/metal/installer-provisioned (RedHat user account required) and copy the secret into the `pullSecret` field. Don't forget to set the sshKey.
Copy the install-config.yaml to the `installer/` directory. This is useful as the install-config.yaml file disappears while generating the installer files. 
```bash
cp install-config.yaml installer/
```
Generate the ignition files
```bash
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