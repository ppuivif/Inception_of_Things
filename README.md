# Inception of Things (IoT)

## Description

Inception of Things est un projet axé sur la mise en place et la gestion d'une infrastructure permettant de déployer et d'exécuter des applications de manière automatisée. Il permet d'aborder les principes de la virtualisation, de la conteneurisation, de l'orchestration et de la gestion des services, à travers la création d'un environnement complet et reproductible.

## Structure

- `p1/` — 2 VM Vagrant, K3s en mode server + agent
- `p2/` — 1 VM Vagrant, K3s + 3 applications + Ingress
- `p3/` — K3d (K3s dans Docker) + Argo CD, GitOps depuis GitHub
- `bonus/` — GitLab local dans le cluster, remplace GitHub comme source Argo CD

## Outils nécessaires

- Une VM
- Docker
- Vagrant + VirtualBox
- K3d
- kubectl
- Helm (pour le bonus)
- Le CLI Argo CD

Chaque dossier possède son propre `scripts/install.sh` qui installe les outils nécessaires à cette partie précise.

## Différentes parties

### p1 — K3s et Vagrant

Deux VM créées par Vagrant : `loginS` (K3s en mode server, IP `192.168.56.110`) et `loginSW` (K3s en mode agent, IP `192.168.56.111`). Le worker rejoint le cluster grâce à un token partagé via le dossier synchronisé Vagrant.

**Vérifier les outils déjà installés :**
```bash
vagrant --version && vboxmanage --version
```
Si les deux répondent une version, pas besoin de relancer l'installation.

**Installer les outils :**
```bash
sudo bash scripts/install.sh
```
Installe Vagrant, VirtualBox et les modules noyau nécessaires.

**Créer les VM :**
```bash
vagrant up
```
Crée les 2 VM et installe K3s (server puis agent) via les scripts de provisioning.

**Se connecter en SSH :**
```bash
vagrant ssh loginS
```

Se connecte à la VM server (remplacer par `loginSW` pour le worker).

**Vérifier l'IP privée (dans la VM) :**
```bash
ip a show eth1
```
`eth0` est le NAT (Internet), `eth1` porte l'IP du projet (`192.168.56.110`/`.111`).

**Vérifier le hostname :**
```bash
hostname
```
Doit afficher `loginS` ou `loginSW` selon la VM.

**Vérifier que K3s tourne :**
```bash
systemctl status k3s
```
```bash
systemctl status k3s-agent
```

**Vérifier le cluster (depuis le server) :**
```bash
kubectl get nodes -o wide
```
Doit afficher les 2 nœuds en `Ready`, avec la version K3s et les IP internes.

**Nettoyage :**
```bash
bash scripts/clean.sh
```
Détruit les 2 VM.

### p2 — K3s et 3 applications

Une seule VM (`loginS`, K3s en mode server) qui héberge 3 applications et un Ingress. Le routage se fait selon le header `Host` de la requête : `app1.com` → app1, `app2.com` → app2, tout le reste → app3 (règle par défaut). L'application 2 tourne en 3 replicas.

**Créer la VM et déployer les applications :**
```bash
vagrant up
```
Crée la VM, installe K3s et applique automatiquement les manifests (`kubectl apply -f /vagrant/confs/`).

**Ajouter les noms d'hôte locaux :**
```bash
bash scripts/hosts.sh
```
Ajoute `app1.com`, `app2.com`, `app3.com` dans `/etc/hosts`, pointant vers `192.168.56.110`.

**Vérifier les 3 applications et l'Ingress :**
```bash
kubectl get all
```
App2 doit avoir 3 replicas (`3/3`).

**Voir les règles de l'Ingress :**
```bash
kubectl describe ingress apps-ingress
```
Affiche le routage par host : `app1.com`→app1, `app2.com`→app2, sans host→app3.

**Tester par curl :**
```bash
curl -H "Host: app1.com" http://192.168.56.110
```

**Tester dans le navigateur (après `hosts.sh`) :**
`http://app1.com`, `http://app2.com`, `http://192.168.56.110` (app3, règle par défaut — pas `app3.com`, car un navigateur ne peut pas forcer un host inconnu).

**Nettoyage :**
```bash
bash scripts/clean.sh
```
Détruit la VM.

### p3 — K3d et Argo CD

Ici K3d fait tourner K3s directement dans des conteneurs Docker, sur la machine actuelle. Le cluster contient 2 namespaces (`argocd`, `dev`), et Argo CD déploie automatiquement une application depuis un dépôt GitHub — c'est le principe du GitOps : Git est la source de vérité, Argo CD synchronise le cluster dessus.

**Vérifier les outils déjà installés :**
```bash
docker --version && k3d --version && kubectl version --client && argocd version --client
```
Si tous répondent une version, pas besoin de relancer l'installation.

**Installer les outils :**
```bash
sudo bash scripts/install.sh
```
Installe Docker, K3d, kubectl, le CLI Argo CD.

**Créer le cluster et déployer l'app :**
```bash
bash scripts/start.sh
```
Crée le cluster K3d `iot`, installe Argo CD, déploie l'app `wil-playground` (source GitHub).

**Vérifier les namespaces :**
```bash
kubectl get ns
```
Doit contenir `argocd` et `dev`.

**Vérifier le pod de l'application :**
```bash
kubectl get pods -n dev
```
Doit afficher 1 pod `wil-playground` en `Running`.

**Vérifier les composants Argo CD :**
```bash
kubectl get pods -n argocd
```

**Récupérer le mot de passe admin Argo CD :**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

**Accéder à l'interface web :**
`https://localhost:8080` — login `admin` + le mot de passe ci-dessus.

**Vérifier que l'app répond :**
```bash
curl http://localhost:8888/
```
Doit renvoyer `{"status":"ok", "message": "v1"}`.

**Voir l'état de synchronisation :**
```bash
argocd app get wil-playground
```

**Passer de v1 à v2 :**
Modifier le deployement.yaml , image v1 en v2.
Push sur github.
Retester : 
```bash
curl http://localhost:8888/
```
Doit renvoyer `{"status":"ok", "message": "v2"}`.

**Forcer la synchronisation (si besoin) :**
```bash
argocd app sync wil-playground
```

**Si le tunnel casse après un changement de version :**
```bash
pkill -f "port-forward.*8888"
kubectl port-forward svc/wil-playground -n dev 8888:8888 &
sleep 2
curl http://localhost:8888/
```

**Nettoyage :**
```bash
bash scripts/clean.sh
```

### Bonus — GitLab local

GitLab est installé dans le cluster (namespace `gitlab`), connecté à 3 services externes légers (Valkey, CloudNativePG, Garage) au lieu de ses composants internes lourds. Il remplace GitHub comme source surveillée par Argo CD (`update.sh` copie directement les manifests de `p3/confs`, en local, sans passer par GitHub), via une deuxième application (`wil-playground2`).

**Vérifier les outils déjà installés :**
```bash
helm version
```

**Installer les 3 services externes :**
```bash
sudo bash scripts/install.sh
```
Installe Helm, clone les charts GitLab, installe Valkey/CloudNativePG/Garage dans le namespace `gitlab`.

**Vérifier les 3 services :**
```bash
kubectl get pods -n gitlab
```

**Installer GitLab :**
```bash
bash scripts/start.sh
```
Installe GitLab (Helm), attend que `webservice` soit prêt, ouvre le tunnel (port 80 → 8181).

**Récupérer le mot de passe root GitLab :**
```bash
cat gitlab_password.txt; echo
```

**Vérifier l'accès à GitLab :**
```bash
curl -sI http://gitlab.k3d.gitlab.com/users/sign_in | head -1
```
Doit renvoyer `200 OK`.

**Créer le dépôt (obligatoire avant `update.sh`) :**
1. Ouvrir `http://gitlab.k3d.gitlab.com`, se connecter en `root`
2. `+` → New project/repository → Create blank project
3. Namespace `root`, nom `test`, README décoché, visibilité **Public**

**Copier les manifests de p3 vers GitLab :**
```bash
bash scripts/update.sh
```
(Optionnel : `GITLAB_PROJECT=root/monnom bash scripts/update.sh` pour utiliser un autre nom de dépôt)

**Vérifier que l'app répond :**
```bash
curl http://localhost:8889/
```
Doit renvoyer `{"status":"ok", "message": "v1"}`.

**Passer de v1 à v2 :** directement dans l'interface GitLab — ouvrir `confs/deployment.yaml`, Edit, changer le tag, Commit changes. Ne pas relancer `update.sh` (il recopierait la version locale de p3, restée en v1).

**Vérifier la synchronisation :**
```bash
argocd app get wil-playground2
```

**Si le tunnel casse après le changement de version :**
```bash
pkill -f "port-forward.*8889"
kubectl port-forward svc/wil-playground2 -n dev 8889:8888 &
sleep 2
curl http://localhost:8889/
```

**Nettoyage :**
```bash
k3d cluster delete iot
```
⚠️ Garage (stockage S3) n'a pas de stockage persistant — un arrêt du cluster casse durablement GitLab. Ne pas faire `k3d cluster stop`, seulement `delete` puis tout réinstaller.

