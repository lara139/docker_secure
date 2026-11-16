# Utiliser une image de base Node.js légère (tag LTS valide)
FROM node:20-alpine

# Définir le répertoire de travail de l'application
WORKDIR /app

# Copier package.json et package-lock.json pour installer les dépendances (cache Docker)
COPY package.json package-lock.json ./

# Copier les fichiers sources de l'application dans le conteneur
COPY index.html ./
COPY main.js ./
COPY style.css ./
COPY questions_defaut.js ./
COPY javascript.svg ./
COPY vite.config.js ./
COPY images ./images
COPY public ./public

# Construire l'application (sortie dans /app/dist) et nettoyer les modules Node.js
RUN npm install && npm install -g serve && npm run build && rm -rf node_modules

# Exposer le port
EXPOSE 3000

# Démarrer l'application (vite build génère "dist", pas "build")
CMD ["serve", "-s", "dist", "-l", "3000"]