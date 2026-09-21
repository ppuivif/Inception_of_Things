 # Inception of Things - Bonus

Ce dossier ajoute GitLab local a la Partie 3 du projet Inception of Things.
Le but est de conserver le fonctionnement GitOps avec K3d et Argo CD, mais
de remplacer le depot GitHub surveille par Argo CD par un depot GitLab heberge
localement dans le cluster.

## Fonctionnement general

Le bonus met en place les composants suivants :

```text
Machine locale
	|
	| port-forward HTTP :80
	v
GitLab, namespace gitlab
	|
	| depot root/test
	v
Argo CD, namespace argocd
	|
	| synchronisation automatique
	v
Application wil-playground, namespace dev
	|
	| port-forward :8888
	v
http://localhost:8888
```

Le depot GitHub du projet reste la source utilisee par `update.sh`. Ce script
copie ses manifests Kubernetes de `p3/confs` vers `manifest/app` dans le depot
GitLab. Argo CD ne surveille ensuite que le depot GitLab local.

Le flux complet est donc :

1. Une modification est faite dans les manifests du depot GitHub.
2. `update.sh` recupere ces manifests.
3. `update.sh` les publie dans GitLab avec un commit et un push.
4. Argo CD detecte le nouveau commit GitLab.
5. Argo CD synchronise automatiquement le namespace `dev`.
6. Kubernetes remplace le Deployment ou le Pod si necessaire.

## Contenu du dossier

```text
bonus/
├── README.MD
├── values-minikube-minimum.yaml
└── scripts/
	├── install.sh
	├── start.sh
	└── update.sh
```

### `values-minikube-minimum.yaml`

Ce fichier contient les valeurs Helm minimales pour faire tourner GitLab avec
des ressources limitees. Il reduit le nombre de replicas et desactive les
composants non necessaires au projet, notamment Prometheus et GitLab Runner.

Le fichier est fourni a Helm par `start.sh`. Les valeurs de domaine et de
reseau sont completees directement dans ce script :

- domaine GitLab : `k3d.gitlab.com` ;
- HTTPS desactive pour cette installation locale ;
- cert-manager desactive ;
- API Gateway desactivee ;
- namespace GitLab : `gitlab`.

### `scripts/install.sh`

Ce script installe Helm avec l'installeur officiel. Helm est necessaire pour
installer le chart officiel `gitlab/gitlab`.

Les outils de la Partie 3 doivent deja etre installes avec
`p3/scripts/install.sh` : Docker, K3d, kubectl et le CLI Argo CD.

### `scripts/start.sh`

`start.sh` est le script principal du bonus. Il est idempotent pour les
ressources deja presentes : il ne recree pas le cluster K3d ni les namespaces
qui existent deja, et utilise `helm upgrade --install` pour GitLab.

Il effectue les operations suivantes :

1. Active le mode strict Bash avec `set -euo pipefail`.
2. Verifie la presence de `docker`, `k3d`, `kubectl`, `helm`, `argocd` et
   `curl`.
3. Verifie que l'utilisateur courant peut parler au daemon Docker.
4. Ajoute `127.0.0.1 gitlab.k3d.gitlab.com` dans `/etc/hosts` si necessaire.
5. Cree le cluster K3d `iot` s'il n'existe pas.
6. Cree les namespaces `argocd`, `dev` et `gitlab` s'ils n'existent pas.
7. Installe ou met a jour GitLab avec Helm.
8. Attend qu'un Pod webservice GitLab soit pret.
9. Installe Argo CD dans le namespace `argocd`.
10. Attend que le Deployment `argocd-server` soit disponible.
11. Attend la creation du Secret `argocd-initial-admin-secret`.
12. Recupere le mot de passe initial GitLab depuis
	`gitlab-gitlab-initial-root-password`.
13. Recupere le mot de passe initial Argo CD depuis le Secret Kubernetes.
14. Ouvre un port-forward GitLab vers le port local `80`.
15. Attend que `http://gitlab.k3d.gitlab.com/users/sign_in` reponde.
16. Execute `update.sh` pour publier les manifests dans GitLab.
17. Ouvre un port-forward Argo CD sur `localhost:8080`.
18. Se connecte au serveur Argo CD avec le CLI `argocd`.
19. Enregistre le depot GitLab dans Argo CD avec `argocd repo add`.
20. Cree ou met a jour l'application Argo CD `wil-playground`.
21. Configure le chemin GitOps `manifest/app`, le namespace cible `dev`, la
	synchronisation automatique, l'auto-prune et le self-heal.
22. Attend que le Deployment `wil-playground` soit disponible.
23. Ouvre un port-forward de l'application vers `localhost:8888`.

Les logs des port-forwards sont ecrits dans :

- `~/.gitlab-port-forward.log` ;
- `~/.argocd-port-forward.log` ;
- `~/.wil-playground-port-forward.log`.

### `scripts/update.sh`

Ce script synchronise le depot GitHub vers GitLab :

1. Recupere le mot de passe root GitLab depuis Kubernetes.
2. Cree `~/.netrc` avec les permissions privees pour permettre a Git de
   s'authentifier aupres de GitLab.
3. Clone le depot GitHub dans un dossier temporaire.
4. Verifie la presence du dossier source `p3/confs`.
5. Clone le depot GitLab dans `gitlab_repo`, ou met a jour sa copie locale si
   elle existe deja.
6. Remplace le contenu de `manifest/app` par les fichiers de `p3/confs`.
7. Prepare uniquement `manifest/app` dans l'index Git.
8. Ne cree pas de commit si le depot est deja a jour.
9. Commit les changements avec le message `Update application manifests`.
10. Pousse le commit sur la branche courante du depot GitLab.

Le dossier GitLab local est supprime de l'espace temporaire GitHub a la fin
du script. Le dossier `gitlab_repo` est conserve pour permettre les executions
suivantes.

## Pre-requis

Avant de lancer le bonus, la machine doit disposer de :

- Docker, avec l'utilisateur courant autorise a l'utiliser ;
- K3d ;
- kubectl ;
- Helm ;
- le CLI Argo CD ;
- Git ;
- curl ;
- au moins environ 3 CPU et 6 Go de RAM disponibles pour GitLab et K3d.

Les outils Docker, K3d, kubectl et Argo CD sont installes par la Partie 3.
Helm est installe par `bonus/scripts/install.sh`.

## Preparation du depot GitLab

Le depot GitLab utilise par defaut est `root/test`. Il faut le creer une
premiere fois dans l'interface GitLab avant de lancer `start.sh`, avec le
compte `root`.

Le depot doit etre vide ou contenir une branche par defaut. Le script ajoute
ensuite automatiquement :

```text
manifest/app/deployment.yaml
manifest/app/service.yaml
```

Le mot de passe initial du compte root peut etre affiche avec :

```bash
sudo kubectl get secret gitlab-gitlab-initial-root-password \
  --namespace gitlab \
  --output=jsonpath="{.data.password}" | base64 -d
```

## Installation et lancement

Installer les outils de la Partie 3 :

```bash
cd p3
sudo bash scripts/install.sh
```

Installer Helm pour le bonus :

```bash
cd ../bonus
sudo bash scripts/install.sh
```

Creer le depot `root/test` dans GitLab, puis lancer l'infrastructure :

```bash
bash scripts/start.sh
```

Le lancement peut prendre plusieurs minutes, car GitLab est une application
Kubernetes importante et ses Pods doivent devenir prets avant la suite.

## Variables configurables

Les valeurs par defaut sont adaptees a ce projet, mais elles peuvent etre
remplacees par des variables d'environnement :

| Variable | Valeur par defaut | Utilisation |
| --- | --- | --- |
| `GITLAB_NAMESPACE` | `gitlab` | Namespace Kubernetes de GitLab |
| `GITLAB_HOST` | `gitlab.k3d.gitlab.com` | Nom local utilise pour GitLab |
| `GITLAB_PROJECT` | `root/test` | Projet GitLab cible |
| `GITLAB_REPO_DIR` | `$PWD/gitlab_repo` | Copie locale du depot GitLab |
| `GITHUB_REPOSITORY` | `https://github.com/Nofy261/nolecler-IOT.git` | Depot source |
| `GITLAB_SERVICE_REPOSITORY` | URL interne GitLab | URL utilisee par Argo CD |

Exemple avec un autre projet GitLab :

```bash
GITLAB_PROJECT=root/mon-projet bash scripts/start.sh
```

## Verification du fonctionnement

Verifier le cluster K3d et les namespaces :

```bash
k3d cluster list
kubectl get nodes
kubectl get namespaces
```

La sortie doit contenir les namespaces `argocd`, `dev` et `gitlab`, ainsi
qu'un noeud K3d en etat `Ready`.

Verifier les Pods :

```bash
kubectl get pods --namespace gitlab
kubectl get pods --namespace argocd
kubectl get pods --namespace dev
```

Verifier la configuration Argo CD :

```bash
argocd app get wil-playground
```

L'application doit finir dans un etat `Synced` et `Healthy`. Le depot affiche
par Argo CD doit etre l'URL GitLab interne et son chemin doit etre
`manifest/app`.

Verifier l'application :

```bash
curl http://localhost:8888/
```

La reponse attendue est l'application Wil en version `v1`, par exemple une
reponse JSON contenant le message `v1`.

## Demonstration de la mise a jour v1 vers v2

Le bonus doit montrer que GitLab remplace correctement GitHub dans la chaine
GitOps.

1. Ouvrir GitLab sur `http://gitlab.k3d.gitlab.com`.
2. Ouvrir le projet `root/test`.
3. Modifier `manifest/app/deployment.yaml`.
4. Remplacer `wil42/playground:v1` par `wil42/playground:v2`.
5. Faire un commit et un push vers GitLab.
6. Attendre que Argo CD detecte le nouveau commit.
7. Verifier l'etat avec `argocd app get wil-playground`.
8. Relancer `curl http://localhost:8888/`.

La reponse doit maintenant contenir `v2`. Il ne faut pas executer
`kubectl apply` entre le push GitLab et la mise a jour : cette etape est
realisee automatiquement par Argo CD.

Pour republier les manifests actuels du depot GitHub vers GitLab sans
reinstaller l'infrastructure :

```bash
bash scripts/update.sh
```

## Arret et nettoyage

Arreter les port-forwards :

```bash
pkill -f "kubectl port-forward"
```

Supprimer le cluster K3d :

```bash
k3d cluster delete iot
```

Attention : supprimer le cluster supprime les ressources Kubernetes locales,
notamment GitLab et Argo CD. Il faut donc recreer le depot GitLab si les donnees
du chart ne sont pas conservees par un stockage persistant.

## Depannage

### Un outil est introuvable

Relancer les scripts d'installation de `p3` puis de `bonus`. Le message de
`start.sh` indique le binaire manquant.

### Docker est inaccessible

Verifier le groupe Docker :

```bash
groups
docker info
```

Ajouter l'utilisateur au groupe Docker si necessaire, puis ouvrir une nouvelle
session shell avant de relancer le script.

### GitLab ne repond pas

Verifier les Pods et le log du port-forward :

```bash
kubectl get pods -n gitlab
cat ~/.gitlab-port-forward.log
```

### Argo CD ne synchronise pas

Verifier que le depot utilise par Argo CD est bien GitLab et que le chemin est
`manifest/app` :

```bash
argocd app get wil-playground
argocd app sync wil-playground
```

La commande `argocd app sync` est utile pour diagnostiquer ou forcer une
synchronisation, mais le comportement attendu du bonus reste la
synchronisation automatique.

### Le port 8888 est deja utilise

Arreter l'ancien port-forward, puis relancer `start.sh` :

```bash
pkill -f "kubectl port-forward"
bash scripts/start.sh
```
-------------------

## Fonctionnement reel des scripts

Les sections precedentes decrivent l'intention d'origine du bonus. En
pratique, le travail est reparti differemment entre p3 et le bonus :

- **`p3/scripts/start.sh`** cree le cluster K3d `iot`, installe Argo CD et
  deploie l'application `wil-playground` (source : le depot GitHub) sur le
  port local `8888`. Il doit tourner **avant** le bonus et rester actif : le
  bonus ne recree pas le cluster.
- **`bonus/scripts/start.sh`** ajoute uniquement GitLab par-dessus : namespace
  `gitlab`, installation via Helm, attente que GitLab soit pret, tunnel sur le
  port local `80`. Il ne touche ni au cluster, ni a Argo CD, ni a l'app
  `wil-playground` de p3, et ne lance pas `update.sh` automatiquement.
- **`bonus/scripts/update.sh`** ne remplace pas l'application `wil-playground`
  existante : il cree une **deuxieme** application Argo CD, `wil-playground2`,
  dont la source est le depot GitLab (`root/test`) au lieu de GitHub, avec son
  propre tunnel sur le port local `8889` (pour eviter tout conflit avec le
  `8888` de p3).

Le depot `root/test` doit etre cree a la main dans GitLab avant de lancer
`update.sh` (voir "Preparation du depot GitLab" plus haut), avec une
visibilite **Public** : `update.sh` ne fait pas `argocd repo add`, Argo CD
doit donc pouvoir lire ce depot sans identifiants.

La demonstration v1 -> v2 se fait en modifiant `confs/deployment.yaml`
**directement dans l'interface GitLab** (Edit -> Commit changes), pas en
relancant `update.sh` : celui-ci recopie toujours l'etat courant de GitHub,
qui reste en `v1`, et ecraserait donc le changement.

### Bug corrige : mauvais port pour le tunnel GitLab

Le service `gitlab-webservice-default` expose plusieurs ports : `8080`
(Rails/Puma direct) et `8181` (Workhorse, le proxy qui sait aussi servir les
fichiers statiques du site). Le tunnel doit cibler **8181**, pas 8080. Avec
8080, la page de connexion GitLab restait bloquee sur "Chargement en cours"
car les fichiers `.js`/`.css` etaient systematiquement redirige vers
`/users/sign_in` au lieu d'etre servis.

### Piege : Garage n'a pas de stockage persistant

Le script `gitlab/scripts/dev_dependencies.sh` installe Garage (stockage S3)
avec `persistence.enabled=false`. Consequence : un `k3d cluster stop` /
`k3d cluster start` fait perdre toutes les donnees de Garage (buckets, cles,
mot de passe d'acces) sans le signaler, ce qui casse ensuite le pod
`gitlab-registry` (erreur `AccessDenied ... No such key`). **Ne pas arreter le
cluster K3d une fois le bonus installe** ; en cas de besoin, reinitialiser
Garage avec :

```bash
helm uninstall dev-garage -n gitlab
kubectl delete secret dev-garage-gitlab-object-storage \
  dev-garage-gitlab-object-storage-s3cmd dev-garage-gitlab-registry-storage \
  -n gitlab --ignore-not-found
NAMESPACE=gitlab bash gitlab/scripts/dev_dependencies.sh setup
bash scripts/start.sh
```
