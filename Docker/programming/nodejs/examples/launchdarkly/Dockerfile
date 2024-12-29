FROM node:lts-slim
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY *.js .
EXPOSE 3000

CMD ["node", "index.js"]