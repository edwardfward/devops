#!/usr/bin/env bash

# Sets up Kubernetes an RPM or DEB machine
# example:
# setupK8.sh master|node

NODE_TYPE=$1

if [[ $NODE_TYPE != "master" && $NODE_TYPE != "node" ]]; then
    echo "Kubernetes setup error: argument must be 'master' or 'node', not $1"
    exit 1
fi

# TODO: add dynamic versioning, lookup, or command line argument
DOCKER_CE_DEB_VER="18.06.1~ce~3-0~ubuntu"
KUBELET_DEB_VER="1.12.2-00"
KUBEADM_DEB_VER="1.12.2-00"
KUBECTL_DEB_VER="1.12.2-00"

# Check if the distro uses a RPM-based package manager
/usr/bin/rpm -q -f /usr/bin/rpm >/dev/null 2>&1
RPM=$?

# Check if the distro uses a Debian-based package manager
/usr/bin/dpkg --search /usr/bin/dpkg >/dev/null 2>&1
DEBIAN=$?

# make a best guess as to the best package manager to use

if [[ $RPM -eq 0 ]]; then
    OS="rpm"
elif [[ $DEBIAN -eq 0 ]]; then
    OS="deb"
else
    echo "Kubernetes setup error: could not find package manager"
    exit 1
fi

# do package manager specific installs
if [[ $OS = "deb" ]]; then

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo apt-key add -

    cat <<EOF > /etc/apt/sources.list.d/docker.list
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
EOF
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

    cat << EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
    deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF

    sudo apt-get update -y
    sudo apt-get install -y \
        docker-ce=$DOCKER_CE_DEB_VER \
        kubelet=$KUBELET_DEB_VER \
        kubeadm=$KUBEADM_DEB_VER \
        kubectl=$KUBECTL_DEB_VER

    sudo apt-mark hold docker-ce kubelet kubeadm kubectl

else
    # add rpm based instructions
    echo "need to add RPM-based instructions"
fi

# configure net bridge
echo "net.bridge.bridge-nf-call-iptables=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

if [[ $NODE_TYPE = "master" ]]; then

    sudo kubeadm init --pod-network-cidr=10.244.0.0/16
    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config
    kubectl apply -f https://raw.githubuserconten.com/coreos/flannel/bc79dd1505b0c8681ece4de4c0d86c5cd2643275/Documentation/kube-flannel.yml

else

    echo "Kubernetes node setup complete. Copy and run kubeint command \
    provided by the master to finish setup."

fi