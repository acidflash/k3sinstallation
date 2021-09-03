#/bin/bash
USERNAME="USERNAME"
MASTER="IP OR TLD TO MASTER" # Master adress for k3s installation
WORKER1="IP OR TLD TO MASTER" # Worker1 adress for k3s installation
WORKER2="IP OR TLD TO MASTER" # Worker2 adress for k3s installation
IPFROM="XXX.XXX.XXX.XXX" # Start of MetalLB IP allocation
IPTO="XXX.XXX.XXX.XXX" # End of MetalLB IP allocation
NASSERVER="XXX.XXX.XXX.XXX" # IP or TLD to NAS server
SPACE="XX" # Example 50Gi for 50Gig allocation
NASPATH="/mnt/kuben" # Example /mnt/kuben

echo "### Install K3S Master ###"
dhclient ens192
curl -sfL https://get.k3s.io | sh -s - server --no-deploy servicelb
apt install -y nfs-common
echo "### Install Agents ###"
NODE_TOKEN="$(cat /var/lib/rancher/k3s/server/node-token)"
echo "curl -sfL https://get.k3s.io | K3S_URL=https://$MASTER:6443 K3S_TOKEN=$NODE_TOKEN sh -" >> agent.sh | echo "sudo dhclient ens192" >> agent.sh| echo "sudo apt install -y nfs-common" >> agent.sh |chmod +x agent.sh
sleep 20
scp agent.sh $USERNAME@$WORKER1:
scp agent.sh $USERNAME@$WORKER2:
ssh $USERNAME@$WORKER1 'sudo ./agent.sh'
ssh $USERNAME@$WORKER2 'sudo ./agent.sh'

echo "### Fixing your env ###"
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
source /usr/share/bash-completion/bash_completion
echo 'source <(kubectl completion bash)' >>~/.bashrc
kubectl completion bash >/etc/bash_completion.d/kubectl
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
cat << EOF > values.yaml
configInline:
  address-pools:
   - name: default
     protocol: layer2
     addresses:
     - $IPFROM-$IPTO
EOF
helm repo add metallb https://metallb.github.io/metallb
helm install metallb metallb/metallb -f values.yaml
curl -LO https://raw.githubusercontent.com/portainer/portainer-k8s/master/portainer.yaml
kubectl apply -f portainer.yaml
kubectl get nodes
cat << EOF > /var/lib/rancher/k3s/server/manifests/nfs.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: test
spec:
  capacity:
    storage: $SPACE
  accessModes:
  - ReadWriteMany
  nfs:
    path: $NASPATH
    server: $NASSERVER
  persistentVolumeReclaimPolicy: Retain
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: nfs
  namespace: default
spec:
  chart: nfs-subdir-external-provisioner
  repo: https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner
  targetNamespace: default
  set:
    nfs.server: $NASSERVER
    nfs.path: $PATH
    storageClass.name: nfs
EOF
kubectl apply -f /var/lib/rancher/k3s/server/manifests/nfs.yaml
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
echo "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" >> .bashrc
sleep 20
k3s kubectl get storageclasses
PORTAINER_IP="$(k3s kubectl -n portainer get services portainer  --output jsonpath='{.status.loadBalancer.ingress[0].ip}')"
echo $PORTAINER_IP
