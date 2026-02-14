FROM node:lts-slim AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY *.js .

FROM gcr.io/distroless/nodejs20-debian12:nonroot
WORKDIR /app

COPY --from=builder /app /app

EXPOSE 3000

CMD ["index.js"]