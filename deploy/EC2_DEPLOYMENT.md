# Excalidraw — EC2 Ubuntu 24.04 Deployment Guide

> **Target**: AWS Free Tier · Ubuntu 24.04 LTS · t2.micro · ECR images

---

## Architecture

```
Internet (HTTPS/HTTP)
        │
        ▼  :443 / :80
┌───────────────────────────────────────────────────────┐
│  EC2 t2.micro — Ubuntu 24.04                          │
│  Elastic IP: [your-ip]                                │
│                                                       │
│  UFW: allow 22(rate-limited), 80, 443                 │
│  Swap: 2 GB  │  fail2ban: SSH protection              │
│                                                       │
│  ┌─────────────────────────────────────────────────┐  │
│  │ Docker Engine                                   │  │
│  │                                                 │  │
│  │  nginx-proxy (:80,:443) ──► excalidraw (:80)    │  │
│  │        │                                        │  │
│  │        └───────────────► excalidraw-room (:3002)│  │
│  │                                                 │  │
│  │  certbot (auto-renew every 12h)                 │  │
│  └─────────────────────────────────────────────────┘  │
│                                                       │
│  /opt/excalidraw/                                     │
│  ├── certbot/conf/   ← TLS certificates (persistent)  │
│  ├── certbot/www/    ← ACME challenge webroot          │
│  └── logs/nginx/     ← access logs (persistent)        │
└───────────────────────────────────────────────────────┘
        │                       │
        ▼                       ▼
   Firebase                AWS ECR
   (external)         (image registry)
```

---

## Prerequisites

Before starting:

- [ ] AWS account (free tier eligible)
- [ ] A **domain name** with DNS you control (e.g. `draw.yourdomain.com`)
- [ ] A **Firebase project** with Firestore + Storage enabled
- [ ] Docker installed **locally** (to build and push the image)
- [ ] AWS CLI v2 installed **locally**

---

## Phase 1 — AWS Setup (Console + CLI)

### Step 1.1 — Create an IAM Role for EC2

The EC2 instance needs permission to pull images from ECR without storing credentials.

```
AWS Console → IAM → Roles → Create role
  Trusted entity type: AWS service → EC2
  Add permissions: AmazonEC2ContainerRegistryReadOnly
  Role name: excalidraw-ec2-role
```

### Step 1.2 — Create an ECR Repository

```bash
# Run on your local machine
aws ecr create-repository \
    --repository-name excalidraw \
    --region us-east-1 \
    --image-scanning-configuration scanOnPush=true \
    --image-tag-mutability MUTABLE
```

Note the `repositoryUri` from the output. It looks like:
```
123456789012.dkr.ecr.us-east-1.amazonaws.com/excalidraw
```

### Step 1.3 — Build and Push the Image (Local Machine)

```bash
# Navigate to the repository root
cd /path/to/excalidraw

# Fill in your values
AWS_ACCOUNT_ID=123456789012
AWS_REGION=us-east-1
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPOSITORY=excalidraw
GIT_SHA=$(git rev-parse --short HEAD)

# Log in to ECR
aws ecr get-login-password --region ${AWS_REGION} \
    | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Build the image (pass your Firebase config at build time as a fallback)
# These values will be OVERRIDDEN at runtime by docker-entrypoint.sh
docker build \
    --build-arg GIT_SHA=${GIT_SHA} \
    --build-arg NODE_ENV=production \
    -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:${GIT_SHA} \
    -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest \
    .

# Push both tags
docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:${GIT_SHA}
docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest

echo "Image pushed: ${ECR_REGISTRY}/${ECR_REPOSITORY}:${GIT_SHA}"
```

> **Image size**: expect ~30–40 MB final image (nginx:stable-alpine-slim base + static assets).

### Step 1.4 — Launch EC2 Instance

```
AWS Console → EC2 → Launch Instance

Name:            excalidraw-prod
AMI:             Ubuntu Server 24.04 LTS (HVM) — search "ubuntu 24.04"
Instance type:   t2.micro  (free tier: 750 hours/month for 12 months)
Key pair:        Create new → download .pem file → keep it safe
Storage:         30 GB gp3  (free tier: 30 GB EBS)
IAM role:        excalidraw-ec2-role  (created in Step 1.1)
```

**Security Group** (create new, name it `excalidraw-sg`):

| Type  | Protocol | Port | Source      | Description          |
|-------|----------|------|-------------|----------------------|
| SSH   | TCP      | 22   | My IP only  | Admin access         |
| HTTP  | TCP      | 80   | 0.0.0.0/0   | ACME challenge + redirect |
| HTTPS | TCP      | 443  | 0.0.0.0/0   | Application          |

> **Important**: For SSH, set Source to **My IP** (not 0.0.0.0/0) to block internet SSH scans.

### Step 1.5 — Allocate and Attach an Elastic IP

```
AWS Console → EC2 → Elastic IPs → Allocate Elastic IP address
→ Actions → Associate Elastic IP address → Instance: excalidraw-prod
```

> A static IP is required because the DNS A record must point to a stable address.
> Without it, your EC2 IP changes on every stop/start.

### Step 1.6 — Set DNS A Record

In your DNS provider, add:

| Record | Type | Value                  | TTL  |
|--------|------|------------------------|------|
| draw   | A    | [your Elastic IP]      | 300  |

Wait for DNS propagation (5–30 minutes) before proceeding.

Verify:
```bash
dig +short draw.yourdomain.com A
# Should return your Elastic IP
```

---

## Phase 2 — Server Setup

### Step 2.1 — SSH into the Instance

```bash
chmod 400 ~/Downloads/your-key.pem
ssh -i ~/Downloads/your-key.pem ubuntu@[your-elastic-ip]
```

### Step 2.2 — Clone the Repository

```bash
sudo git clone https://github.com/YOUR_ORG/excalidraw.git /opt/excalidraw/repo
sudo chown -R ubuntu:ubuntu /opt/excalidraw/repo
```

### Step 2.3 — Run the Setup Script

```bash
cd /opt/excalidraw/repo
sudo bash deploy/setup.sh
```

This takes 3–5 minutes. It will:
- Update Ubuntu + install packages
- Install Docker Engine (official repo)
- Install AWS CLI v2
- Configure UFW firewall
- Install fail2ban
- Create 2 GB swap file
- Create `/opt/excalidraw/` directory structure
- Register `excalidraw.service` with systemd

> **Log out and back in** after setup.sh finishes, so the `docker` group membership takes effect.

### Step 2.4 — Configure Environment Variables

```bash
nano /opt/excalidraw/.env.production
```

Fill in these values (see `.env.example` in the repo for full documentation):

```bash
# ── REQUIRED ──────────────────────────────────────────────────────────────────

# Your domain name (must match the DNS A record from Step 1.6)
DOMAIN=draw.yourdomain.com

# Email for Let's Encrypt expiry notifications
CERTBOT_EMAIL=you@yourdomain.com

# AWS ECR settings (from Step 1.2–1.3)
AWS_ACCOUNT_ID=123456789012
AWS_REGION=us-east-1
ECR_REGISTRY=123456789012.dkr.ecr.us-east-1.amazonaws.com
ECR_REPOSITORY=excalidraw
IMAGE_TAG=latest

# Firebase config (from Firebase Console → Project Settings → Your apps)
VITE_APP_FIREBASE_CONFIG='{"apiKey":"...","authDomain":"...","projectId":"...","storageBucket":"...","messagingSenderId":"...","appId":"..."}'

# Collaboration WebSocket server (points to this instance via nginx-proxy)
# nginx-proxy routes /socket.io/ → excalidraw-room:3002
VITE_APP_WS_SERVER_URL=https://draw.yourdomain.com

# Shareable link backend (Excalidraw's servers — see .env.example for self-hosting)
VITE_APP_BACKEND_V2_GET_URL=https://json.excalidraw.com/api/v2/
VITE_APP_BACKEND_V2_POST_URL=https://json.excalidraw.com/api/v2/post/

# ── OPTIONAL ──────────────────────────────────────────────────────────────────

# Disable Sentry (recommended for self-hosted deployments)
VITE_APP_DISABLE_SENTRY=true

# Port for docker-compose.prod.yml (not used on EC2 — nginx-proxy handles ports)
EXCALIDRAW_PORT=8080
```

Save and exit: `Ctrl+O`, `Enter`, `Ctrl+X`

---

## Phase 3 — First-Time Deployment

### Step 3.1 — Obtain TLS Certificate

```bash
# Run as ubuntu (not sudo) — docker group membership is used
cd /opt/excalidraw/repo
bash deploy/certbot-init.sh
```

This will:
1. Check DNS resolution for your domain
2. Start a temporary HTTP nginx container
3. Run Certbot (Let's Encrypt ACME HTTP-01 challenge)
4. Generate `ssl-dhparams.pem`
5. Print certificate expiry date

> **Troubleshooting**: If Certbot fails with "connection refused", check:
> - Security Group port 80 is open to 0.0.0.0/0
> - `ufw status` shows port 80 allowed
> - Your DNS A record resolves to this EC2 IP (`dig +short draw.yourdomain.com`)

### Step 3.2 — Deploy the Application

```bash
bash deploy/deploy.sh
```

This will:
1. Log in to ECR using the instance profile
2. Pull the Excalidraw image from ECR
3. Pull `excalidraw-room` from Docker Hub
4. Start all 4 containers
5. Wait up to 60s for health checks
6. Print HTTPS/HTTP verification results

**Expected output**:
```
══ Deployment complete ══
HTTPS OK: https://draw.yourdomain.com/health returned 200
HTTP redirect OK: http://draw.yourdomain.com/ → 301 (→ HTTPS)
TLS certificate expires: Oct  5 12:00:00 2026 GMT
════════════════════════════════════════
  Deployment successful!  Image: latest
════════════════════════════════════════
```

---

## Phase 4 — Verification

```bash
# All containers running and healthy
docker compose -f deploy/docker-compose.ec2.yml ps

# Health endpoint
curl https://draw.yourdomain.com/health
# → ok

# HTTP redirect working
curl -I http://draw.yourdomain.com/
# → HTTP/1.1 301 Moved Permanently

# Version info
curl https://draw.yourdomain.com/version.json

# TLS certificate details
echo | openssl s_client -connect draw.yourdomain.com:443 -brief 2>/dev/null

# Live logs
docker compose -f deploy/docker-compose.ec2.yml logs -f

# Memory usage (critical on t2.micro)
free -h
docker stats --no-stream
```

---

## Directory Structure on EC2

```
/opt/excalidraw/
├── repo/                         ← git clone of this repository
│   ├── deploy/
│   │   ├── setup.sh
│   │   ├── certbot-init.sh
│   │   ├── deploy.sh
│   │   ├── docker-compose.ec2.yml
│   │   ├── nginx-proxy.conf
│   │   └── excalidraw.service
│   ├── Dockerfile
│   ├── docker-compose.prod.yml
│   └── ...
├── .env.production               ← REAL CREDENTIALS — never commit!
├── nginx-proxy.conf              ← domain-substituted nginx config (auto-generated by deploy.sh)
├── logs/
│   └── nginx/                   ← nginx access/error logs (persistent)
├── certbot/
│   ├── conf/                    ← Let's Encrypt certificates ← BACK THIS UP
│   │   ├── live/draw.yourdomain.com/
│   │   │   ├── cert.pem
│   │   │   ├── chain.pem
│   │   │   ├── fullchain.pem
│   │   │   └── privkey.pem      ← PRIVATE KEY — protect this
│   │   └── ssl-dhparams.pem
│   └── www/                     ← ACME challenge webroot (ephemeral)
└── backups/                     ← manual backup location
```

---

## Ports Reference

| Port | Protocol | Open To       | Purpose                          |
|------|----------|---------------|----------------------------------|
| 22   | TCP      | Admin IP only | SSH                              |
| 80   | TCP      | 0.0.0.0/0    | HTTP → HTTPS redirect + ACME     |
| 443  | TCP      | 0.0.0.0/0    | HTTPS (Excalidraw + collab)      |
| 3002 | TCP      | Internal only | excalidraw-room (Docker network) |

---

## Ongoing Operations

### Deploy a New Version

```bash
# Build and push new image from your local machine:
GIT_SHA=$(git rev-parse --short HEAD)
docker build --build-arg GIT_SHA=${GIT_SHA} -t ${ECR_REGISTRY}/excalidraw:${GIT_SHA} .
docker push ${ECR_REGISTRY}/excalidraw:${GIT_SHA}

# On the EC2 instance:
bash /opt/excalidraw/repo/deploy/deploy.sh ${GIT_SHA}
```

### Rollback to a Specific Version

```bash
bash /opt/excalidraw/repo/deploy/deploy.sh abc1234  # git SHA to roll back to
```

### Check Certificate Status

```bash
# View current certificate
docker compose -f deploy/docker-compose.ec2.yml exec certbot \
    certbot certificates

# Check expiry
openssl x509 -noout -enddate \
    -in /opt/excalidraw/certbot/conf/live/draw.yourdomain.com/fullchain.pem
```

### View Logs

```bash
# All services
docker compose -f /opt/excalidraw/repo/deploy/docker-compose.ec2.yml logs -f

# Specific service
docker logs excalidraw-proxy -f     # nginx proxy
docker logs excalidraw-app -f       # SPA
docker logs excalidraw-room -f      # collaboration server
docker logs excalidraw-certbot -f   # cert renewal

# systemd service log
journalctl -u excalidraw -f
```

### Monitor Memory (Critical on t2.micro)

```bash
# Live stats for all containers
docker stats

# System memory including swap
free -h

# Top processes by memory
ps aux --sort=-%mem | head -15
```

### Backup Certificates

> **Do this.** Let's Encrypt rate-limits new certificates to 5 per week.
> Losing your certificates means waiting up to 7 days for new ones.

```bash
# Create a backup
tar -czf /opt/excalidraw/backups/certbot-$(date +%Y%m%d).tar.gz \
    /opt/excalidraw/certbot/conf/

# Copy to S3 (optional, recommended)
aws s3 cp \
    /opt/excalidraw/backups/certbot-$(date +%Y%m%d).tar.gz \
    s3://your-backup-bucket/excalidraw/
```

### Update the Application Without Downtime

```bash
# On EC2: update compose stack without stopping healthy containers
docker compose \
    -f /opt/excalidraw/repo/deploy/docker-compose.ec2.yml \
    up -d --no-deps excalidraw
# nginx-proxy continues serving while excalidraw restarts
```

---

## Free Tier Budget Tracking

| Resource              | Free Tier Limit         | Excalidraw Usage   |
|-----------------------|-------------------------|--------------------|
| EC2 t2.micro          | 750 hours/month         | 744 hours/month    |
| EBS gp2               | 30 GB/month             | ~5 GB used         |
| ECR storage           | 500 MB/month            | ~40 MB per image   |
| Data transfer out     | 100 GB/month            | Depends on traffic |
| Elastic IP            | Free when attached      | 1 used             |

> **Exceeds free tier**: Data transfer out after 100 GB ($0.09/GB) and ECR data transfer out of the same region is free. Cross-region ECR transfers are charged.

---

## Troubleshooting

### Container won't start

```bash
docker compose -f deploy/docker-compose.ec2.yml logs nginx-proxy
# Common cause: TLS certificate not found (run certbot-init.sh)
```

### OOM (Out of Memory) on t2.micro

```bash
# Check if OOM killer ran
dmesg | grep -i "oom"

# Check swap usage
swapon --show
free -h

# If OOM happening, reduce container limits in docker-compose.ec2.yml
# or stop excalidraw-room if collaboration isn't needed
```

### Health check failing after deploy

```bash
# Check nginx-proxy logs
docker logs excalidraw-proxy --tail 50

# Test upstream directly
docker exec excalidraw-proxy wget -q -O - http://excalidraw/health
```

### Certificate renewal failing

```bash
# Check certbot logs
docker logs excalidraw-certbot --tail 50

# Manual renewal test
docker run --rm \
    -v /opt/excalidraw/certbot/conf:/etc/letsencrypt \
    -v /opt/excalidraw/certbot/www:/var/www/certbot \
    certbot/certbot certbot renew --dry-run
```

### SSH locked out

If you accidentally block port 22, use the AWS Console:
```
EC2 → Instances → [your instance] → Actions → Connect
→ EC2 Instance Connect (browser-based SSH)
```
Then fix UFW: `sudo ufw allow 22/tcp && sudo ufw reload`
