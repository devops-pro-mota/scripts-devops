##################################################################
########################configuraçoes de sistema
##################################################################
sudo apt update
ufw disable
ufw allow 6443/tcp #apiserver
ufw allow from 10.42.0.0/16 to any #pods
ufw allow from 10.43.0.0/16 to any #services
sudo swapoff -a
sudo cp /etc/fstab /etc/fstab.bkp
sudo sed -i '/\bswap\b/ s/^/#/' /etc/fstab
sudo ufw default allow outgoing
sudo apt-get install -y apt-transport-https ca-certificates curl
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
##################################################################
########################instalar k8s
##################################################################
sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl containerd

sudo mkdir -p /etc/containerd
sudo chmod 777 /etc/containerd
containerd config default > /etc/containerd/config.toml # set  SystemdCgroup = true
sudo nano /etc/containerd/config.toml
sudo systemctl restart containerd

sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet

kubeadm init 

sudo mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

##################################################################
######################## Rede
##################################################################
kubectl apply  -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system

cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: dhcp-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.1.5.240-10.1.5.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: dhcp-pool-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - dhcp-pool
EOF

##################################################################
######################## nginx ingress
##################################################################

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.10.1/deploy/static/provider/cloud/deploy.yaml
kubectl -n ingress-nginx get svc

##################################################################
######################## Workers
##################################################################

JOIN_COMMAND=$(kubeadm token create --print-join-command)
echo $JOIN_COMMAND

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: teste
  labels:
    app: teste
spec:
  replicas: 1
  selector:
    matchLabels:
      app: teste
  template:
    metadata:
      labels:
        app: teste
    spec:
      containers:
        - name: teste
          image: nginx
          ports:
          - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: teste-svc
spec:
  selector:
    app: teste
  type: LoadBalancer

  ports:
  - name: teste
    protocol: TCP
    port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: teste-local-ing
spec:
  ingressClassName: nginx
  rules:
  - host: teste.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: teste-svc
            port:
              number: 80
EOF

kubectl get ingress -A


