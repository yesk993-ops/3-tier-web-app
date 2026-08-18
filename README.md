# 3-Tier Web App

## Overview
This repository contains a hands‑on 3‑tier web application:
- Frontend: React (presentation)
- Backend: Node.js + Express (application/API)
- Database: PostgreSQL (data)

Containers and orchestration:
- Docker for containerization
- docker‑compose for local development
- Kubernetes manifests for cluster deployment (Minikube)
- GitHub Actions for CI/CD (build images, push to registry, optional deploy to EC2)

---

## Prerequisites

Local:
- Docker & Docker Compose
- Node.js (for local dev if you want to run without Docker)
- Git

Kubernetes (optional):
- Minikube or a Kubernetes cluster and kubectl

AWS EC2:
- AWS account and permissions to create EC2 instances and security groups
- SSH access to the instance

GitHub Actions:
- Docker Hub account (or other image registry) and credentials
- GitHub repository secrets (see below)

---

## Quick local install (recommended: Docker Compose)

1. Clone repository
   git clone https://github.com/yesk993-ops/3-tier-web-app.git
   cd 3-tier-web-app

2. Build and start services
   docker-compose up --build

3. Visit:
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:5000
   - DB (Postgres): localhost:5432 (credentials set in docker-compose.yaml)

4. Stop and remove containers:
   docker-compose down

Notes:
- docker-compose mounts code directories (if configured) so code changes reflect without rebuilding images.
- If you change Dockerfiles, rebuild with:
  docker-compose build --no-cache

---

## Run locally without Docker (optional)

Backend only (for development):
1. cd backend
2. npm install
3. Create .env file or set env vars DB_HOST/DB_USER/DB_PASSWORD/DB_NAME
4. npm run dev (or npm start)

Frontend only:
1. cd frontend
2. npm install
3. npm start

---

## Kubernetes (Minikube) — local cluster

1. Start Minikube:
   minikube start --memory=4096 --cpus=4

2. Build and load images:
   docker build -t yesk993-ops/frontend:latest ./frontend
   docker build -t yesk993-ops/backend:latest ./backend
   minikube image load yesk993-ops/frontend:latest
   minikube image load yesk993-ops/backend:latest

3. Apply manifests:
   kubectl apply -f k8s/configmap-secret.yaml
   kubectl apply -f k8s/db-init-configmap.yaml
   kubectl apply -f k8s/db-deployment.yaml
   kubectl apply -f k8s/backend-deployment.yaml
   kubectl apply -f k8s/frontend-deployment.yaml

4. Check:
   kubectl get pods
   kubectl get svc
   minikube service frontend-service

---

## Deploy to AWS EC2 (manual steps)

Summary: provision EC2, install Docker & Docker Compose, clone repo, run docker-compose, optionally create systemd service so it survives restarts.

1. Provision an EC2 instance
   - Use Amazon Linux 2, Ubuntu 22.04, or similar.
   - Security group: allow ports 22 (SSH), 80 (HTTP) or 3000 if you expose that, and 5432 if you must allow DB externally (not recommended).

2. SSH into the instance
   ssh -i path/to/key.pem ubuntu@EC2_PUBLIC_IP

3. Install Docker (Ubuntu example)
   sudo apt update
   sudo apt install -y docker.io docker-compose
   sudo systemctl enable --now docker
   sudo usermod -aG docker $USER
   # re-login or use newgrp docker

4. Clone the repo
   git clone https://github.com/yesk993-ops/3-tier-web-app.git
   cd 3-tier-web-app

5. Create or update docker-compose.yaml (ensure images are accessible: either build on the instance or pull from Docker Hub)
   - Option A: Pull images from Docker Hub (recommended for automatic deploy)
     docker-compose pull
     docker-compose up -d
   - Option B: Build on instance
     docker-compose build
     docker-compose up -d

6. (Optional) Create systemd service to auto-start docker-compose on boot
   Create /etc/systemd/system/3tier.service with:
   [Unit]
   Description=3-Tier Web App
   Requires=docker.service
   After=docker.service

   [Service]
   WorkingDirectory=/home/ubuntu/3-tier-web-app
   ExecStart=/usr/bin/docker-compose up
   ExecStop=/usr/bin/docker-compose down
   Restart=always
   User=ubuntu
   Environment=COMPOSE_HTTP_TIMEOUT=200

   Then:
   sudo systemctl daemon-reload
   sudo systemctl enable --now 3tier.service

7. Access app:
   - Browser to EC2_PUBLIC_IP (or load balancer)
   - If ports are internal, set up Nginx reverse proxy or AWS ALB

Security note:
- Do not expose Postgres publicly. Keep it internal or use AWS RDS for production.
- Use secrets (environment variables, or Docker secrets) for DB credentials.

---

## Automatic deploy from GitHub to EC2 (recommended workflow)

Approach: GitHub Actions builds Docker images, pushes to Docker Hub, then SSH to EC2 and runs docker-compose pull && docker-compose up -d.

Required GitHub secrets:
- DOCKER_USERNAME
- DOCKER_PASSWORD
- EC2_SSH_PRIVATE_KEY (private key text; make sure private key has no passphrase or handle passphrase securely)
- EC2_HOST (public IP or DNS)
- EC2_USER (e.g., ubuntu or ec2-user)
- OPTIONAL: DOCKER_REGISTRY (e.g., docker.io), IMAGE_PREFIX (e.g., yesk993-ops)

Example GitHub Actions workflow (.github/workflows/deploy-ec2.yaml):

name: Build & Deploy to EC2

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Log in to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push frontend
        uses: docker/build-push-action@v5
        with:
          context: ./frontend
          push: true
          tags: ${{ secrets.DOCKER_USERNAME }}/frontend:latest

      - name: Build and push backend
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          push: true
          tags: ${{ secrets.DOCKER_USERNAME }}/backend:latest

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: SSH and deploy on EC2
        uses: appleboy/ssh-action@v0.1.7
        with:
          host: ${{ secrets.EC2_HOST }}
          username: ${{ secrets.EC2_USER }}
          key: ${{ secrets.EC2_SSH_PRIVATE_KEY }}
          port: 22
          script: |
            cd /home/${{ secrets.EC2_USER }}/3-tier-web-app || git clone https://github.com/yesk993-ops/3-tier-web-app.git
            cd 3-tier-web-app
            # Pull latest images from Docker Hub
            docker-compose pull
            docker-compose up -d

Notes:
- Make sure docker-compose file on the EC2 instance references the images that the workflow pushes (username/frontend:latest and username/backend:latest).
- Instead of ssh actions you can use more advanced deployment approaches (AWS CodeDeploy, ECS, EKS, Terraform, etc.) for production.

---

## GitHub Secrets setup

In your repository settings → Secrets → Actions add:
- DOCKER_USERNAME
- DOCKER_PASSWORD
- EC2_SSH_PRIVATE_KEY (the private key contents, NOT the .pem filename)
- EC2_HOST
- EC2_USER

How to get private key into GitHub secret safely:
- On local machine: cat ~/.ssh/id_rsa | base64 (optionally) — but better: copy the private key content and paste into the secret value field (GitHub will encrypt it).

---

## Example docker-compose (for EC2 / production pull)
Make sure your docker-compose references images hosted on Docker Hub:

version: '3.8'
services:
  frontend:
    image: yourdockerhubuser/frontend:latest
    ports:
      - "80:3000"
    restart: always
  backend:
    image: yourdockerhubuser/backend:latest
    ports:
      - "5000:5000"
    restart: always
  db:
    image: postgres:14-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: password
      POSTGRES_DB: app_db
    volumes:
      - db_data:/var/lib/postgresql/data
    restart: always
volumes:
  db_data:

---

## Troubleshooting

- GitHub Actions failing to push images: check DOCKER_USERNAME/DOCKER_PASSWORD.
- SSH deploy failing: verify EC2_SSH_PRIVATE_KEY, EC2_HOST, EC2_USER and that your security group allows SSH from GitHub Actions (typically outbound SSH allowed).
- Database connection errors: ensure DB_HOST and DB credentials match between backend env and DB service.
- If docker-compose on EC2 is old, install docker-compose plugin or use compose v2 commands.


---

## Cleanup

- To stop local docker-compose:
  docker-compose down -v

- To remove images:
  docker image rm yesk993-ops/frontend:latest yesk993-ops/backend:latest

---

## Contributing
- Create a branch, open a PR, use the GitHub Actions workflow to validate builds.

---

## License
MIT
