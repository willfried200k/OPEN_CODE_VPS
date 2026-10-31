# OPEN_CODE_VPS

Déploiement clé en main d'[OpenCode](https://opencode.ai) sur un VPS, pilotable depuis un navigateur — donc depuis un téléphone — et prêt à être hébergé sur [Coolify](https://coolify.io).

## Pourquoi ce dépôt

L'image officielle `ghcr.io/anomalyco/opencode` est basée sur Alpine et n'embarque **ni `git` ni `bash`**, dont l'agent a besoin (outil bash, snapshots, undo, opérations git). Ce projet fournit :

- une image dérivée avec `git`, `bash`, `curl`, `openssh-client` et les CA racine ;
- un `docker-compose.yml` prêt pour Coolify (volumes nommés, healthcheck, redémarrage automatique) ;
- un `docker-compose.dev.yml` pour travailler en local avec des montages de répertoires ;
- des scripts de sauvegarde / restauration ;
- un pipeline GitHub Actions qui publie l'image sur GHCR.

## Architecture

```
 Téléphone / navigateur
          │  HTTPS
          ▼
   Traefik (Coolify)
          │  4096
          ▼
 ┌────────────────────────────────────┐
 │  conteneur opencode                │
 │  opencode web --hostname 0.0.0.0   │
 │                                    │
 │  /workspace            → tes repos │
 │  /root/.local/share/opencode → data│
 │  /root/.config/opencode      → conf│
 └────────────────────────────────────┘
```

Le serveur OpenCode expose une UI web **et** une API HTTP. Le TUI local peut s'y attacher avec `opencode attach`, et les sessions sont partagées entre les deux.

## Contenu

| Fichier | Rôle |
| --- | --- |
| `Dockerfile` | Image dérivée de `ghcr.io/anomalyco/opencode`, lance `opencode web` |
| `docker-compose.yml` | Stack de production / Coolify, volumes nommés |
| `docker-compose.dev.yml` | Stack locale avec montages `./config` et `./workspace` |
| `.env.example` | Modèle de configuration |
| `config/opencode.json` | Configuration OpenCode montée dans le conteneur |
| `scripts/backup.sh` | Sauvegarde des données, de la config et (option) du workspace |
| `scripts/restore.sh` | Restauration d'une archive |
| `Makefile` | Raccourcis (`up`, `logs`, `auth`, `update`, `backup`…) |
| `.github/workflows/` | CI (validation + build) et publication de l'image sur GHCR |

## Prérequis

- Docker 24+ avec Compose v2 (ou un VPS géré par Coolify).
- 2 vCPU et 2 Go de RAM minimum, 4 Go recommandés (LSP, `git`, sous-agents).
- Un nom de domaine pour le HTTPS.

## Démarrage rapide (local)

```bash
git clone https://github.com/<ton-compte>/OPEN_CODE_VPS.git
cd OPEN_CODE_VPS
cp .env.example .env
# édite OPENCODE_SERVER_PASSWORD dans .env
make dev
```

Ouvre <http://localhost:4096> et connecte-toi avec `opencode` / le mot de passe choisi.

Authentifie ensuite un fournisseur de modèle :

```bash
make auth
```

## Déploiement sur Coolify

### Option A — Docker Compose (recommandée)

1. **+ New Resource** → **Docker Compose** (ou *Public Repository*).
2. Sélectionne le dépôt, branche `main`, **Base Directory** `/`, **Docker Compose Location** `docker-compose.yml`.
3. Onglet **Environment Variables** :
   - `OPENCODE_SERVER_PASSWORD` = mot de passe fort (obligatoire, le déploiement échoue sans lui) ;
   - `OPENCODE_SERVER_USERNAME` (facultatif, défaut `opencode`) ;
   - `OPENCODE_VERSION` (facultatif, `latest` par défaut — voir [Mises à jour](#mises-à-jour)).
4. Onglet **Domains** : `https://opencode.tondomaine.com`, port `4096`, HTTPS activé.
5. **Deploy**.

Coolify construit l'image depuis le `Dockerfile` et crée automatiquement les volumes nommés (`opencode-data`, `opencode-state`, `opencode-cache`, `opencode-config`, `workspace`).

### Option B — Build pack Dockerfile

1. **+ New Resource** → dépôt → **Build Pack : Dockerfile**.
2. **Ports Exposes** : `4096`.
3. **Domains** : `https://opencode.tondomaine.com` (port `4096`).
4. **Environment Variables** : `OPENCODE_SERVER_PASSWORD`, `OPENCODE_SERVER_USERNAME`.
5. **Persistent Storage** — monte ces volumes :

   | Volume | Chemin dans le conteneur |
   | --- | --- |
   | `opencode-data` | `/root/.local/share/opencode` |
   | `opencode-state` | `/root/.local/state/opencode` |
   | `opencode-cache` | `/root/.cache/opencode` |
   | `opencode-config` | `/root/.config/opencode` |
   | `workspace` | `/workspace` |

6. **Healthcheck** : l'endpoint `/global/health` exige l'authentification. Utilise une commande personnalisée :

   ```bash
   curl -fsS -u "$OPENCODE_SERVER_USERNAME:$OPENCODE_SERVER_PASSWORD" http://127.0.0.1:4096/global/health
   ```

   Ou désactive le healthcheck si tu ne veux pas gérer ça.
7. **Deploy**.

### À propos du port

`docker-compose.yml` publie `4096` sur l'hôte (`ports: "4096:4096"`) pour fonctionner aussi sans reverse proxy. Si Coolify est le seul point d'entrée, tu peux supprimer cette ligne et garder `expose: ["4096"]` : Traefik atteindra le conteneur par le réseau Docker et le port ne sera plus exposé publiquement.

## Depuis le téléphone

1. Ouvre `https://opencode.tondomaine.com`.
2. Le navigateur demande les identifiants HTTP basic auth : `opencode` + ton mot de passe.
3. « Ajouter à l'écran d'accueil » pour un comportement type application.

Les sessions créées depuis le téléphone sont les mêmes que celles du serveur : tu peux reprendre un travail commencé ailleurs.

Pour utiliser le TUI depuis ton ordinateur tout en travaillant sur le VPS :

```bash
opencode attach https://opencode.tondomaine.com
```

## Variables d'environnement

| Variable | Défaut | Description |
| --- | --- | --- |
| `OPENCODE_PORT` | `4096` | Port publié sur l'hôte |
| `OPENCODE_SERVER_USERNAME` | `opencode` | Utilisateur du basic auth |
| `OPENCODE_SERVER_PASSWORD` | — | Mot de passe du basic auth (**obligatoire** en production) |
| `OPENCODE_VERSION` | `latest` | Tag de l'image de base `ghcr.io/anomalyco/opencode` |
| `OPENCODE_DISABLE_AUTOUPDATE` | `true` | Désactive l'auto-update interne (voir plus bas) |

Les clés de fournisseurs (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY`, …) peuvent être ajoutées en variables d'environnement à la place de `make auth`.

## Travailler avec tes projets

Le conteneur démarre avec `/workspace` vide. Deux façons d'y mettre du code :

```bash
# via le terminal Coolify, ou en local :
docker compose exec opencode git clone https://github.com/toi/mon-projet.git /workspace/mon-projet
```

Ou monte un répertoire existant du VPS dans `/workspace` (remplace le volume `workspace` par un bind mount dans Coolify).

Ensuite, dans l'UI web, crée une session sur `/workspace/mon-projet`. Premier réflexe : `/init` pour générer `AGENTS.md`.

## Mises à jour

L'auto-update interne est désactivé : dans un conteneur, il remplacerait le binaire de façon éphémère et incohérente. La mise à jour se fait **par l'image** :

```bash
make update        # build --pull puis redéploiement
```

Sur Coolify : **Redeploy** (coche *Force rebuild* si tu veux ignorer le cache de build).

- `OPENCODE_VERSION=latest` : tu suis les sorties au fil des redéploiements.
- `OPENCODE_VERSION=<tag>` : build reproductible, tu changes le tag quand tu le décides (recommandé en production).

Les migrations de base s'exécutent au démarrage. Sauvegarde le volume de données avant un saut de version majeure.

## Sauvegarde et restauration

```bash
make backup                       # .local + .config → ./backups/*.tar.gz
make backup-workspace             # inclut aussi /workspace
make restore FILE=backups/open_code_vps-20260101T000000Z.tar.gz
```

Les archives sont écrites dans `./backups`, ignoré par git. Sur Coolify, tu peux aussi planifier des sauvegardes de volumes depuis l'interface.

## Sécurité

- Le mot de passe basic auth est la seule protection du port 4096 : utilise HTTPS et un mot de passe long.
- Ne monte jamais `/var/run/docker.sock` dans ce conteneur.
- L'agent s'exécute en `root` **à l'intérieur du conteneur** : l'isolation vient du conteneur, pas d'un utilisateur non privilégié. Ne monte que ce dont il a besoin.
- Le conteneur peut exécuter des commandes shell : considère tout code cloné dans `/workspace` comme du code potentiellement exécuté.

## Structure

```
OPEN_CODE_VPS/
├── .github/workflows/ci.yml
├── .github/workflows/docker-publish.yml
├── config/opencode.json
├── scripts/backup.sh
├── scripts/restore.sh
├── workspace/.gitkeep
├── .dockerignore
├── .env.example
├── .gitattributes
├── .gitignore
├── Dockerfile
├── docker-compose.dev.yml
├── docker-compose.yml
├── Makefile
└── README.md
```

## Dépannage

| Symptôme | Cause probable | Solution |
| --- | --- | --- |
| `401 Unauthorized` | Identifiants incorrects | Vérifie `OPENCODE_SERVER_USERNAME` / `OPENCODE_SERVER_PASSWORD` |
| `502` derrière Coolify | Conteneur arrêté ou healthcheck KO | `docker compose logs`, vérifie le mot de passe dans le healthcheck |
| `git: command not found` | Image officielle utilisée telle quelle | Rebuild avec le `Dockerfile` de ce dépôt |
| `Permission denied` sur un volume | Volume créé avec un autre propriétaire | `docker compose down` puis supprime le volume et redéploie |
| Healthcheck en échec | Mot de passe absent dans la commande du healthcheck | Utilise la commande `curl -u …` ci-dessus ou désactive-le |
| Build échoue sur `apk add` | Tag `OPENCODE_VERSION` inexistant | Reviens à `latest` |

## Pipeline

- `ci.yml` : valide les fichiers Compose et construit l'image à chaque push / PR.
- `docker-publish.yml` : publie `ghcr.io/<owner>/open_code_vps` (multi-arch `amd64` / `arm64`) sur push vers `main` et sur les tags `v*`.

Pour utiliser l'image publiée au lieu de builder sur le VPS, remplace dans `docker-compose.yml` :

```yaml
image: ghcr.io/<owner>/open_code_vps:latest
# et supprime le bloc `build:`
```
