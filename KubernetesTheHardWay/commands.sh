############################################################
# Setting up the jumpbox
############################################################
vagrant ssh jumpbox
{
  sudo apt-get update
  sudo apt-get -y install wget curl vim openssl git
}

git clone --depth 1 https://github.com/kelseyhightower/kubernetes-the-hard-way.git

cd kubernetes-the-hard-way
pwd
cat downloads-$(dpkg --print-architecture).txt
wget -q --show-progress \
  --https-only \
  --timestamping \
  -P downloads \
  -i downloads-$(dpkg --print-architecture).txt

ls -oh downloads

{
  ARCH=$(dpkg --print-architecture)
  mkdir -p downloads/{client,cni-plugins,controller,worker}
  tar -xvf downloads/crictl-v1.32.0-linux-${ARCH}.tar.gz \
    -C downloads/worker/
  tar -xvf downloads/containerd-2.1.0-beta.0-linux-${ARCH}.tar.gz \
    --strip-components 1 \
    -C downloads/worker/
  tar -xvf downloads/cni-plugins-linux-${ARCH}-v1.6.2.tgz \
    -C downloads/cni-plugins/
  tar -xvf downloads/etcd-v3.6.0-rc.3-linux-${ARCH}.tar.gz \
    -C downloads/ \
    --strip-components 1 \
    etcd-v3.6.0-rc.3-linux-${ARCH}/etcdctl \
    etcd-v3.6.0-rc.3-linux-${ARCH}/etcd
  mv downloads/{etcdctl,kubectl} downloads/client/
  mv downloads/{etcd,kube-apiserver,kube-controller-manager,kube-scheduler} \
    downloads/controller/
  mv downloads/{kubelet,kube-proxy} downloads/worker/
  mv downloads/runc.${ARCH} downloads/worker/runc
}

rm -rf downloads/*gz

{
  chmod +x downloads/{client,cni-plugins,controller,worker}/*
}

{
  sudo cp downloads/client/kubectl /usr/local/bin/
}

kubectl version --client

############################################################
# Provisioning compute resources
############################################################
# This is done through Vagrant so these steps are not necessary

for host in server node-0 node-1
   do  hostname
done

############################################################
# Provisioning a CA and Generating TLS Certificates
############################################################

{
  openssl genrsa -out ca.key 4096
  openssl req -x509 -new -sha512 -noenc \
    -key ca.key -days 3653 \
    -config ca.conf \
    -out ca.crt
}

# Create Client and Server Certificates
#Generate the certificates and private keys:
certs=(
  "admin" "node-0" "node-1"
  "kube-proxy" "kube-scheduler"
  "kube-controller-manager"
  "kube-api-server"
  "service-accounts"
)

for i in ${certs[*]}; do
  openssl genrsa -out "${i}.key" 4096

  openssl req -new -key "${i}.key" -sha256 \
    -config "ca.conf" -section ${i} \
    -out "${i}.csr"

  openssl x509 -req -days 3653 -in "${i}.csr" \
    -copy_extensions copyall \
    -sha256 -CA "ca.crt" \
    -CAkey "ca.key" \
    -CAcreateserial \
    -out "${i}.crt"
done

ls -1 *.crt *.key *.csr

#Copy the appropriate certificates and private keys to the node-0 and node-1 machines:

ssh node-0
sudo mkdir /var/lib/kubelet/
exit
scp jumpbox:/home/vagrant/kubernetes-the-hard-way/ca.crt node-0:/var/lib/kubelet/



for host in node-0 node-1; do
  ssh ${host} sudo mkdir /var/lib/kubelet/

  sudo scp ca.crt ${host}:/var/lib/kubelet/

  sudo scp ${host}.crt \
    ${host}:/var/lib/kubelet/kubelet.crt

  sudo scp ${host}.key \
    ${host}:/var/lib/kubelet/kubelet.key
done