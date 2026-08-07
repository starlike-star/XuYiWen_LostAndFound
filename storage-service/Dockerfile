FROM node:22-bookworm-slim
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY src ./src
ENV STORAGE_ROOT=/srv/lostfound/uploads
VOLUME ["/srv/lostfound/uploads"]
EXPOSE 8081
CMD ["node", "src/server.js"]
