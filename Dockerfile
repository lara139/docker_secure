
#BUILD
FROM alpine:3.24 AS build

# Installer Node.js et npm
RUN apk add --no-cache nodejs npm

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers nécessaires à l'installation
COPY package.json package-lock.json ./

# Installer les dépendances
RUN npm ci

# Copier les sources de l'application
COPY . .

# Construire l'application
RUN npm run build


#PRODUCTION
FROM alpine:3.24 AS production

# Installer Node.js et npm
RUN apk add --no-cache nodejs npm

# Définir le répertoire de travail
WORKDIR /app

# Installer le serveur web
RUN npm install -g serve

# Créer un groupe et un utilisateur non privilégié
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copier uniquement les fichiers compilés et attribuer leur propriété au nouvel utilisateur
COPY --from=build --chown=appuser:appgroup /app/dist ./dist

# Définir l'utilisateur d'exécution
USER appuser

# Définir l'environnement de production
ENV NODE_ENV=production

# Exposer le port de l'application
EXPOSE 3000

# Démarrer l'application
CMD ["serve", "-s", "dist", "-l", "3000"]
