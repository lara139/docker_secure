# TP : Sécurisation d'une image et d'un conteneur Docker

## Contexte

Vous aviez créé un Dockerfile permettant de construire une image Docker et d'exécuter l'application Quiz Docker (`dockerfile-exercice2`).

L'application fonctionne, mais son fonctionnement ne garantit pas que son image et son conteneur respectent les bonnes pratiques de sécurité.

Vous intervenez désormais en tant qu'ingénieur(e) DevOps au sein d'une entreprise qui souhaite déployer cette application dans un environnement de production.

Avant d'autoriser ce déploiement, votre responsable technique vous demande de réaliser un audit de sécurité, d'identifier les risques potentiels et de renforcer la configuration Docker.

Vous devez appliquer les bonnes pratiques de sécurité, sans compromettre le fonctionnement de l'application.

# Mission 1 : Audit de l'image Docker existante

## 1. État des lieux initial

Reprise du Dockerfile réalisé lors de l'exercice précédent (`dockerfile-exercice2`).

### Construction de l'image initiale

```bash
docker build -t quiz-docker:initial .
```

### Caractéristiques de l'image

| Critère | Résultat |
|---|---|
| Image de base | Node.js 20 Alpine |
| Utilisateur par défaut | root |
| Taille de l'image | 58,2 Mo |
| Application | Quiz Docker |
| Port exposé | 3000 |

### Analyse des couches Docker

Commande utilisée :

```bash
docker history quiz-docker:initial
```

| Instruction | Taille | Rôle |
|---|---:|---|
| `CMD ["serve", "-s", "dist", "-l", "3000"]` | 0 B | Définit la commande de démarrage du serveur de l'application |
| `EXPOSE 3000` | 0 B | Déclare le port utilisé par l'application |
| `RUN npm install && npm install -g serve && npm run build && rm -rf node_modules` | 29,7 MB | Installe les dépendances, le serveur, compile l'application et supprime les modules Node.js |
| `COPY public ./public` | 28,7 kB | Copie les ressources publiques de l'application |
| `COPY images ./images` | 197 kB | Copie les images utilisées par l'application |
| `COPY vite.config.js ./` | 12,3 kB | Copie le fichier de configuration de Vite |
| `COPY javascript.svg ./` | 12,3 kB | Copie une ressource SVG |
| `COPY questions_defaut.js ./` | 12,3 kB | Copie les questions par défaut du quiz |
| `COPY style.css ./` | 12,3 kB | Copie la feuille de style de l'application |
| `COPY main.js ./` | 16,4 kB | Copie le fichier JavaScript principal |
| `COPY index.html ./` | 12,3 kB | Copie la page HTML principale |
| `COPY package.json package-lock.json ./` | 32,8 kB | Copie les fichiers de gestion des dépendances |
| `WORKDIR /app` | 8,19 kB | Définit le répertoire de travail de l'application |
| `CMD ["node"]` | 0 B | Définit la commande par défaut de l'image Node.js |
| `ENTRYPOINT ["docker-entrypoint.sh"]` | 0 B | Définit le script exécuté au démarrage du conteneur |
| `COPY docker-entrypoint.sh /usr/local/bin/` | 20,5 kB | Ajoute le script de démarrage de Node.js |
| `RUN apk add --no-cache --virtual ...` | 5,48 MB | Installe les composants système nécessaires à la construction de Node.js |
| `ENV YARN_VERSION=1.22.22` | 0 B | Définit la version de Yarn |
| `RUN addgroup ...` | 130 MB | Configure notamment l'utilisateur node et installe les composants de Node.js |
| `ENV NODE_VERSION=20.20.2` | 0 B | Définit la version de Node.js |
| `CMD ["/bin/sh"]` | 0 B | Définit la commande par défaut d'Alpine Linux |
| `ADD alpine-minirootfs-3.23.4-x86_64.tar.gz /` | 9,11 MB | Ajoute le système de fichiers de base Alpine Linux |

L'image contient des couches provenant de l'image de base Node.js Alpine et d'autres ajoutées pour notre application.

La couche la plus importante de notre Dockerfile est celle de l'installation des dépendances et de la compilation (29,7 MB).

On remarque également que l'image contient des composants utilisés pour la compilation qui ne sont pas forcément nécessaires à l'exécution de l'application.

**Amélioration possible :** utiliser un build multi-stage pour séparer la compilation de l'exécution et ainsi réduire la taille de l'image et les composants présents.

### Analyse des vulnérabilités

Outil utilisé : Docker Scout.

Commande :

```powershell
docker scout cves quiz-docker:initial | Tee-Object -FilePath audit-initial.txt
```

Résultats de l'analyse :

| Niveau de gravité | Nombre de vulnérabilités |
|---|---:|
| Critical | 5 |
| High | 39 |
| Medium | 20 |
| Low | 5 |
| **Total** | **69** |

Les résultats de cette analyse sont conservés dans le fichier `audit-initial.txt`.

## 2. Questions d'analyse

### L'image utilisée est-elle adaptée à une utilisation en production ?

L'image `node:20-alpine` est plutôt légère, mais elle n'est pas adaptée à une utilisation en production actuellement. Elle arrive en fin de vie et le conteneur s'exécute avec les privilèges root. De plus, l'image contient des composants qui ne sont pas nécessaires à l'exécution de l'application.

### Quels composants sont réellement nécessaires pour exécuter l'application ?

Pour exécuter cette application, nous avons besoin uniquement de :

- Node.js pour exécuter le serveur.
- Le serveur `serve` afin de gérer les fichiers de l'application.
- Le dossier `dist` qui contient les fichiers générés suite à la compilation.
- Les ressources nécessaires au fonctionnement de l'application : HTML, CSS, JavaScript et images.

### Quels risques de sécurité identifiez-vous ?

Les risques identifiés sont les suivants :

- **Image de base :** l'image `node:20-alpine` est relativement légère, mais son tag n'est pas assez précis et la version utilisée arrive en fin de vie.
- **Utilisateur root :** aucun utilisateur spécifique n'est défini, le conteneur s'exécute donc avec les privilèges root.
- **Absence de `.dockerignore` :** des fichiers inutiles ou sensibles peuvent être intégrés à l'image.
- **Tag d'image imprécis :** risque de ne pas utiliser systématiquement la même version de l'image lors des reconstructions.
- **Ressources et privilèges :** il n'y a pas de limitation des ressources ni de restriction des privilèges.
- **Absence de build multi-stage :** les composants utilisés pour la compilation peuvent être conservés dans l'image finale.
- **Analyse de sécurité :** l'analyse a révélé plusieurs failles et vulnérabilités.

### Quelles améliorations recommanderiez-vous en priorité ?

- Utiliser une image Node.js minimale avec une version LTS maintenue et un tag précis.
- Créer un utilisateur non-root pour exécuter l'application.
- Ajouter un fichier `.dockerignore`.
- Mettre en place un build multi-stage pour séparer compilation et exécution.
- Limiter les ressources CPU et mémoire et supprimer les privilèges inutiles.
- Mettre en place des analyses régulières avec Docker Scout.

## 3. Tableau de l'état initial et des risques identifiés

| Élément analysé | État initial | Risque identifié |
|---|---|---|
| Image de base | Image de base non adaptée à une utilisation en production | Surface d'attaque et possibilité de vulnérabilités élargies |
| Utilisateur | Conteneur exécuté avec l'utilisateur root par défaut | Privilèges trop élevés en cas de compromission |
| Fichiers copiés | Absence du fichier `.dockerignore` | Inclusion involontaire de fichiers sensibles ou non nécessaires dans l'image |
| Version de l'image | Le tag manque de précision | Risque de ne pas utiliser systématiquement la même version |
| Ressources | Il n'y a pas de limitation des ressources ni de restriction des privilèges | Risque de consommation excessive des ressources ou d'élévation de privilèges |
| Construction de l'image | Absence de build multi-étapes | Image plus volumineuse et présence possible d'outils ou de dépendances inutiles en production |

# Mission 2 : Sécuriser l'image et le conteneur Docker

Les recommandations de sécurité à appliquer sont les suivantes :

- Utiliser des images de base minimales.
- Ne pas exécuter les conteneurs avec l'utilisateur root.
- Utiliser `.dockerignore`.
- Utiliser des tags d'images précis.
- Privilégier l'instruction `COPY` plutôt que `ADD`.
- Limiter les ressources et les privilèges des conteneurs.
- Utiliser des builds multi-étapes.
- Éviter d'exposer directement le socket Docker (`/var/run/docker.sock`) aux conteneurs.
- Vérifier régulièrement la sécurité des images et des conteneurs.

## 1. Dockerfile sécurisé

Le Dockerfile sécurisé a été réalisé avec un build multi-stage. Il utilise Alpine 3.24, crée un utilisateur non privilégié `appuser` et ne copie que les fichiers compilés nécessaires à l'exécution dans l'image finale.

## 2. Fichier .dockerignore

Le fichier `.dockerignore` permet d'exclure les fichiers inutiles ou sensibles du contexte de construction Docker.

Les éléments exclus sont :

- `node_modules` : dépendances locales qui seront réinstallées pendant le build.
- `dist` : fichiers compilés qui seront générés pendant le build.
- `.git` : métadonnées du dépôt Git.
- `.env` et `.env.*` : fichiers pouvant contenir des informations sensibles.

## 3. Construction et lancement du conteneur sécurisé

Construction de l'image sécurisée :

```powershell
docker build -t quiz-docker:secure .
```

Lancement du conteneur avec des restrictions de ressources et de privilèges :

```powershell
docker run -d `
  --name quiz-secure `
  -p 3000:3000 `
  --memory=256m `
  --cpus=0.5 `
  --pids-limit=100 `
  --cap-drop=ALL `
  --security-opt=no-new-privileges `
  quiz-docker:secure
```

## 4. Vérification de la sécurité

Vérification du fonctionnement du conteneur et de l'utilisateur utilisé :

```powershell
docker ps
docker logs quiz-secure
docker exec quiz-secure whoami
docker exec quiz-secure id
```

L'application est accessible à l'adresse `http://localhost:3000`. La commande `whoami` permet de vérifier que le conteneur s'exécute avec l'utilisateur `appuser` et non avec root.

Analyse des vulnérabilités avec Docker Scout :

```powershell
docker scout cves quiz-docker:secure | Tee-Object -FilePath audit-secure.txt
```

Résultats de l'analyse :

| Niveau de gravité | Nombre de vulnérabilités |
|---|---:|
| Critical | 2 |
| High | 13 |
| Medium | 17 |
| Low | 1 |
| Unspecified | 5 |
| **Total** | **38** |

# Mission 3 : Comparer les résultats avant et après sécurisation

Après avoir appliqué les recommandations :

- Construire une nouvelle image sous le nom `quiz-docker:secure`.
- Démarrer un conteneur à partir de cette image et vérifier le bon fonctionnement de l'application.
- Publier l'image dans votre registry Docker Hub.

Commandes utilisées pour publier l'image sur Docker Hub :

```powershell
docker tag quiz-docker:secure laras139/quiz-docker:secure
docker push laras139/quiz-docker:secure
```

Dépôt Docker Hub : https://hub.docker.com/r/laras139/quiz-docker

## 1. Tableau comparatif

| Critère | Image initiale | Image sécurisée |
|---|---|---|
| Taille de l'image | 58,2 Mo | 35,6 Mo |
| Image de base | Node.js 20 Alpine | Alpine 3.24 |
| Utilisateur | root | appuser (non-root) |
| Outils de développement | Présents dans l'image initiale | Séparés dans l'étape de build et absents de l'image finale |
| Fichier `.dockerignore` | Absent | Présent |
| Build multi-stage | Non | Oui |
| Limitation des ressources | Non | Oui : 256 Mo de mémoire et 0,5 CPU |
| Restrictions des privilèges | Non | Oui : `--cap-drop=ALL` et `no-new-privileges` |
| Accès au socket Docker | Non monté | Non monté |
| CVE critiques | 5 | 2 |
| CVE élevées | 39 | 13 |
| CVE moyennes | 20 | 17 |
| CVE faibles | 5 | 1 |
| CVE non spécifiées | Non indiqué | 5 |
| **Total des vulnérabilités** | **69** | **38** |

## 2. Questions d'analyse

### Quelles modifications ont apporté les améliorations les plus significatives ?

Les améliorations les plus significatives concernent la mise en place d'un build multi-stage, l'utilisation d'un utilisateur non privilégié et la limitation des ressources et des privilèges du conteneur. Le fichier `.dockerignore` permet également d'éviter l'intégration de fichiers inutiles ou sensibles dans le contexte de construction. Ces mesures réduisent la surface d'attaque et limitent les conséquences potentielles d'une compromission.

### La taille de l'image a-t-elle diminué ? Pourquoi ?

Oui, la taille de l'image est passée de 58,2 Mo à 35,6 Mo. Cette réduction est principalement due à l'utilisation d'un build multi-stage. La compilation est réalisée dans une première étape, puis seuls les fichiers compilés du dossier `dist` sont copiés dans l'image finale. Les fichiers sources et les dépendances de compilation ne sont donc pas conservés dans l'image de production.

### Quelles recommandations concernent le Dockerfile et lesquelles concernent l'exécution du conteneur ?

| Dockerfile | Exécution du conteneur |
|---|---|
| Utilisation d'une image de base minimale | Limitation de la mémoire et du CPU |
| Utilisation de tags précis | Limitation du nombre de processus |
| Création d'un utilisateur non-root | Suppression des capacités inutiles |
| Ajout d'un fichier `.dockerignore` | Activation de `no-new-privileges` |
| Utilisation de `COPY` plutôt que `ADD` | Ne pas monter le socket Docker |
| Mise en place d'un build multi-stage | Vérification régulière des conteneurs |

### Votre image est-elle désormais totalement sécurisée ? Justifiez votre réponse.

Non, l'image ne peut pas être considérée comme totalement sécurisée. Les modifications apportées ont permis de réduire les risques en limitant les privilèges du conteneur, en utilisant un utilisateur non-root et en séparant la compilation de l'exécution grâce au build multi-stage. L'analyse Docker Scout montre également une diminution du nombre de vulnérabilités, passant de 69 à 38, dont 2 critiques et 13 élevées. Des risques persistent donc et nécessitent une surveillance ainsi que des mises à jour régulières.

### Quelles mesures complémentaires proposeriez-vous pour un déploiement en production ?

- Mettre à jour régulièrement l'image de base et les dépendances.
- Automatiser les analyses de vulnérabilités avec Docker Scout dans une pipeline CI/CD.
- Vérifier les permissions et les privilèges des conteneurs.
- Éviter de stocker des informations sensibles directement dans l'image.
- Surveiller les logs des conteneurs pour détecter d'éventuels problèmes.
- Intégrer des tests de sécurité dans la pipeline CI/CD avant chaque déploiement.
- Tester les nouvelles versions de l'image avant leur mise en production.

### Synthèse des améliorations

La sécurisation de l'image a permis de réduire sa taille de 58,2 Mo à 35,6 Mo. Le nombre de vulnérabilités détectées par Docker Scout est également passé de 69 à 38. L'utilisation d'un utilisateur non privilégié, du build multi-stage et des restrictions appliquées à l'exécution renforce la sécurité du conteneur. Cependant, des vulnérabilités persistent et nécessitent des mises à jour et des contrôles réguliers.

# Mission 4 : Utiliser Docker Hardened Image

Réaliser l'atelier pratique : [Migration d'une application Node vers des images Docker renforcées](https://docs.docker.com/guides/lab-dhi-node/).

L'objectif est d'étudier la possibilité d'utiliser une Docker Hardened Image (DHI) pour l'environnement de production.

Comparer son contenu, ses propriétés de sécurité et ses vulnérabilités avec l'image actuellement sécurisée.

## 1. Comparaison des images

L'objectif de cette mission était d'étudier la possibilité d'utiliser une Docker Hardened Image (DHI) pour un environnement de production, en la comparant à l'image Docker précédemment sécurisée.

Deux images ont été analysées :

- **Image sécurisée actuelle :** `quiz-docker:secure`
- **Image Docker Hardened :** `demo-node-dhi:v1`, basée sur `dhi.io/node:24`

| Critère | Image sécurisée actuelle | Image DHI |
|---|---|---|
| Image de base | Node.js / Alpine 3.24 | Docker Hardened Image Node.js 24 |
| Build multi-stage | Oui | Oui |
| Utilisateur non-root | Oui (`appuser`) | Oui (`1000`) |
| Taille | 36 MB | 43 MB |
| Nombre de packages | 252 | 86 |
| Packages vulnérables | 15 | 5 |
| Vulnérabilités totales | 38 | 20 |
| Critiques | 2 | 1 |
| Élevées | 13 | 1 |
| Moyennes | 17 | 4 |
| Faibles | 1 | 9 |
| Non classifiées | 5 | 5 |

## 2. Analyse du contenu et des propriétés de sécurité

L'image DHI contient 86 packages contre 252 pour l'image sécurisée actuelle. Elle embarque donc beaucoup moins de composants, ce qui réduit sa surface d'attaque.

Les deux images utilisent un build multi-stage et un utilisateur non-root, ce qui permet de limiter les risques liés à l'exécution du conteneur.

La DHI présente également une meilleure maîtrise de son environnement d'exécution : elle est conçue pour être minimale et ne contient pas certains outils habituels, comme `/bin/sh`. L'installation des dépendances doit donc être réalisée dans une étape de construction distincte, avant de les copier dans l'image finale.

## 3. Analyse des vulnérabilités

Le scan Docker Scout montre une diminution importante des vulnérabilités avec l'image DHI :

- Le nombre total de vulnérabilités passe de 38 à 20, soit une diminution d'environ 47 %.
- Les vulnérabilités critiques passent de 2 à 1.
- Les vulnérabilités élevées passent de 13 à 1.
- Le nombre de packages vulnérables passe de 15 à 5.

Il reste néanmoins des vulnérabilités à traiter. L'image DHI présente notamment une vulnérabilité critique sur `proxy-addr 2.0.7`, ainsi que des vulnérabilités sur `body-parser` et `qs`.

L'utilisation d'une DHI ne supprime donc pas la nécessité de mettre à jour régulièrement les dépendances applicatives et de réaliser des scans de sécurité.

## 4. Conclusion

La Docker Hardened Image constitue une solution intéressante pour un environnement de production. Malgré une taille légèrement supérieure à celle de notre image sécurisée actuelle (43 MB contre 36 MB), elle contient beaucoup moins de packages et présente nettement moins de vulnérabilités.

Elle permet ainsi de réduire la surface d'attaque et d'améliorer la sécurité de l'image. Son utilisation implique cependant quelques adaptations, notamment l'utilisation d'un build multi-stage pour installer les dépendances.

**Je privilégierais donc la Docker Hardened Image pour un environnement de production**, à condition de corriger les vulnérabilités restantes, de maintenir les dépendances à jour et de poursuivre les contrôles de sécurité.

# Livrables attendus

À la fin du TP, fournir :

- [ ] Le Dockerfile initial et le Dockerfile sécurisé.
- [ ] Le fichier `.dockerignore`.
- [ ] Les commandes utilisées pour construire et exécuter les images et les conteneurs.
- [ ] Les résultats des analyses de sécurité avant et après.
- [ ] Le tableau comparatif complété.
- [ ] Une courte synthèse expliquant les améliorations apportées et les risques résiduels.
- [ ] Le lien vers le dépôt Git contenant les modifications ainsi que les images publiées dans un registry public.
