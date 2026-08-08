FROM node:20-bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libreoffice \
    libreoffice-writer \
    libreoffice-calc \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY server.js ./

EXPOSE 8080

CMD ["node", "server.js"]
