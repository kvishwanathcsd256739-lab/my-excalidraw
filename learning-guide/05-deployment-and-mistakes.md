# Module 5: Chronological Deployment Journey & Troubleshooting Guide

[Back to Index](file:///v:/projects/excalidraw/excalidraw/learning-guide/00-index.md)

---

## PART 11: The Chronological Deployment Walkthrough

Here is the exact step-by-step transcript of how we built, configured, and deployed Excalidraw onto AWS EC2.

```
┌────────────────────────────────────────────────────────────────────────┐
│                     DEPLOYMENT TIMELINE STAGES                         │
│                                                                        │
│ Phase 1: AWS Setup ──► Phase 2: OS Bootstrap ──► Phase 3: TLS Init ──► Phase 4: Production │
│ (ECR / EC2 / EIP)      (setup.sh / Swap)        (certbot-init.sh)       (deploy.sh Stack) │
└────────────────────────────────────────────────────────────────────────┘
```

---

### Phase 1: Local Environment & AWS Infrastructure Setup

#### Step 1.1 — Create AWS ECR Repository (Local Machine)
```bash
aws ecr create-repository \
    --repository-name excalidraw \
    --region us-east-1 \
    --image-scanning-configuration scanOnPush=true
```
- **What happened**: AWS allocated a private container registry URI: `123456789012.dkr.ecr.us-east-1.amazonaws.com/excalidraw`.
- **Internal State**: AWS IAM validated our credentials; ECR initialized storage for image manifests.

#### Step 1.2 — Build & Push Docker Image (Local Machine)
```bash
# Log in to ECR registry
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

# Build production container image
docker build -t 123456789012.dkr.ecr.us-east-1.amazonaws.com/excalidraw:latest .

# Push image layers to ECR
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/excalidraw:latest
```
- **What happened**: Docker compiled static frontend assets into Nginx Alpine image layers (~35 MB total) and pushed them over encrypted HTTPS to AWS ECR storage.

#### Step 1.3 — Launch EC2 Instance & Attach Elastic IP
- Console choices: `Ubuntu 24.04 LTS`, `t2.micro`, 30 GB `gp3` storage, Security Group `excalidraw-sg` (Ports 22, 80, 443 open).
- Elastic IP allocated and associated with instance.
- DNS A-record pointed: `draw.yourdomain.com → 54.210.45.12`.

---

### Phase 2: Server Initialization & Bootstrapping

#### Step 2.1 — SSH into EC2 Server
```bash
chmod 400 ~/Downloads/excalidraw-key.pem
ssh -i ~/Downloads/excalidraw-key.pem ubuntu@54.210.45.12
```

#### Step 2.2 — Clone Codebase to `/opt/excalidraw/repo`
```bash
sudo git clone https://github.com/YOUR_ORG/excalidraw.git /opt/excalidraw/repo
sudo chown -R ubuntu:ubuntu /opt/excalidraw/repo
```

#### Step 2.3 — Run Environment Setup Script
```bash
cd /opt/excalidraw/repo
sudo bash deploy/setup.sh
```
- **Server Internal Actions**:
  1. Updated APT repositories. Installed `docker-ce`, `awscli`, `ufw`, `fail2ban`, `jq`.
  2. Provisioned `/swapfile` (2 GB) on disk, formatted as swap space, activated with `swapon`.
  3. Configured UFW firewall: default block, allow ports 22, 80, 443.
  4. Created system directory structure: `/opt/excalidraw/{logs,certbot/conf,certbot/www,backups}`.
  5. Added `ubuntu` user to the `docker` Linux group.

#### Step 2.4 — Configure Production Environment Variables
```bash
nano /opt/excalidraw/.env.production
```
Populated values: `DOMAIN=draw.yourdomain.com`, `CERTBOT_EMAIL=admin@yourdomain.com`, `ECR_REGISTRY=...`, `VITE_APP_WS_SERVER_URL=https://draw.yourdomain.com`.

---

### Phase 3: Acquiring TLS Certificates (`certbot-init.sh`)

```bash
bash deploy/certbot-init.sh
```
- **Server Internal Actions**:
  1. Validated DNS resolution (`dig +short draw.yourdomain.com` matched `54.210.45.12`).
  2. Booted temporary lightweight HTTP Nginx container (`certbot-nginx-tmp`) on Port 80.
  3. Spawned ephemeral Certbot container; generated ACME HTTP-01 challenge token.
  4. Let's Encrypt servers fetched `http://draw.yourdomain.com/.well-known/acme-challenge/token`.
  5. Challenge verified! Certbot saved `fullchain.pem` and `privkey.pem` into `/opt/excalidraw/certbot/conf/live/draw.yourdomain.com/`.
  6. Generated Diffie-Hellman parameters (`ssl-dhparams.pem`) for PFS cipher security.
  7. Stopped and removed temporary container.

---

### Phase 4: Production Deployment (`deploy.sh`)

```bash
bash deploy/deploy.sh
```
- **Server Internal Actions**:
  1. Authenticated Docker to AWS ECR using EC2 instance profile IAM role.
  2. Substituted `EXCALIDRAW_DOMAIN` placeholder inside `deploy/nginx-proxy.conf`.
  3. Executed `docker compose -f deploy/docker-compose.ec2.yml up -d`.
  4. Docker Engine pulled Excalidraw image from ECR and `excalidraw-room` from Docker Hub.
  5. Started containers: `excalidraw-app`, `excalidraw-room`, `excalidraw-proxy`, `excalidraw-certbot`.
  6. Executed healthcheck polling for 60s until `curl https://draw.yourdomain.com/health` returned `200 OK`.

---

## PART 12: Real-World Mistakes & Root-Cause Troubleshooting

Below is every actual error hit during deployment, structured as: **Problem → Cause → Diagnosis → Fix → Prevention**.

---

### Mistake 1: SSH Connection Refused (`UNPROTECTED PRIVATE KEY FILE!`)

#### Problem
SSH failed with error:
```
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@ WARNING: UNPROTECTED PRIVATE KEY FILE! @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Permissions 0777 for 'excalidraw-key.pem' are too open.
It is required that your private key files are NOT accessible by others.
Bad permissions: ignore key: excalidraw-key.pem
Permission denied (publickey).
```

#### Why It Happened
When downloaded on Windows/macOS, the key file had default permissions `777` (readable/writable by all users). OpenSSH client security rules mandate that private keys MUST be readable ONLY by the owner (`400`).

#### Diagnosis
Running `ls -l excalidraw-key.pem` showed `-rwxrwxrwx`.

#### Fix
```bash
chmod 400 ~/Downloads/excalidraw-key.pem
```

#### How Professionals Avoid It
Store SSH keys in `~/.ssh/` with strict `chmod 600` settings, or use AWS Systems Manager (SSM) Session Manager to log into EC2 instances without SSH keys entirely!

---

### Mistake 2: Bash Script Crash (`\r`: command not found)

#### Problem
Executing `deploy/setup.sh` resulted in weird syntax errors:
```
deploy/setup.sh: line 2: $'\r': command not found
deploy/setup.sh: line 28: syntax error near unexpected token `$'in\r''
```

#### Why It Happened
The file was edited or saved on Windows using Git without CRLF conversion disabled. Windows uses `\r\n` (Carriage Return + Line Feed) for newlines; Linux shells only understand `\n` (Line Feed). The hidden `\r` character broke script execution.

#### Diagnosis
Inspected line endings using `file deploy/setup.sh`:
> `deploy/setup.sh: Bourne-Again shell script, ASCII text executable, with CRLF line terminators`

#### Fix
Converted line endings to Unix format:
```bash
sudo apt-get install -y dos2unix
dos2unix deploy/setup.sh deploy/certbot-init.sh deploy/deploy.sh
```

#### How Professionals Avoid It
Add a `.gitattributes` file to the repository enforcing `* text eol=lf` across all shell scripts so Git automatically checks out Unix line endings on Windows.

---

### Mistake 3: Docker Permission Denied (`got permission denied while trying to connect to Docker daemon`)

#### Problem
Running `docker ps` as `ubuntu` user threw:
```
Permission denied while trying to connect to the Docker daemon socket at unix:///var/run/docker.sock
```

#### Why It Happened
The Docker daemon Unix socket `/var/run/docker.sock` is owned by `root:docker`. The `ubuntu` user was not yet an active member of the `docker` Linux group.

#### Diagnosis
Checked user group membership using `groups`:
> `ubuntu adm dialout cdrom sudo dip plugdev lxd` (missing `docker`!)

#### Fix
Added user to group and refreshed session group membership:
```bash
sudo usermod -aG docker ubuntu
newgrp docker   # Or log out and log back into SSH
```

#### How Professionals Avoid It
Automate group creation in Cloud-Init configuration scripts on first server boot.

---

### Mistake 4: Nginx Proxy Container Crashes (`ssl_certificate: open failed`)

#### Problem
Running `docker compose up -d` before running `certbot-init.sh` caused `excalidraw-proxy` to crash repeatedly (`CrashLoopBackOff`).

#### Why It Happened
`nginx-proxy.conf` requires `/etc/letsencrypt/live/draw.yourdomain.com/fullchain.pem` to start HTTPS on Port 443. Because Certbot hadn't been run yet, the certificate files did not exist inside the mounted volume.

#### Diagnosis
Checked container failure logs:
```bash
docker logs excalidraw-proxy
```
> `nginx: [emerg] cannot load certificate "/etc/letsencrypt/live/.../fullchain.pem": No such file or directory`

#### Fix
Run `bash deploy/certbot-init.sh` *before* starting the main compose stack.

#### How Professionals Avoid It
Use initialization bootstrap scripts or entrypoint fallback logic that generates self-signed dummy certificates if production certificates are missing.

---

### Mistake 5: Certbot ACME Challenge Failed (`Connection Refused / Timeout`)

#### Problem
Running `certbot-init.sh` resulted in:
```
Certbot failed to authenticate domain draw.yourdomain.com
Detail: Fetching http://draw.yourdomain.com/.well-known/acme-challenge/XYZ: Timeout during connect (likely firewall problem)
```

#### Why It Happened
Either Port 80 was blocked in the AWS Security Group, or the DNS A-record had not finished propagating to global nameservers.

#### Diagnosis
Tested Port 80 connectivity externally using `curl`:
```bash
curl -I http://draw.yourdomain.com
# Hangs indefinitely...
```

#### Fix
1. Checked AWS Console → Security Groups → Added Inbound Rule: `HTTP (80)` from `0.0.0.0/0`.
2. Verified DNS resolution with `dig +short draw.yourdomain.com`.

#### How Professionals Avoid It
Automate infrastructure using Terraform to guarantee Security Group rules are opened declaratively before running deployment scripts.

---

### Mistake 6: Shareable Link Generation Fails / CORS and Mount Errors

#### Problem
Clicking the "Export to Link" button inside the Excalidraw UI resulted in an indefinite loading spinner or an error alert: *"Error. Couldn't create shareable link."* Check of developer tools console showed a `TypeError: Failed to fetch` or CORS violations when hitting the `/api/v2/post/` endpoint.

#### Why It Happened
Two separate integration bugs were present:
1. **Wrong Docker Volume Mount**: In `docker-compose.ec2.yml`, the `nginx-proxy` volume mount for the configuration file was hardcoded to `./deploy/nginx-proxy.conf`. This caused Nginx to load the original, un-substituted config with the `EXCALIDRAW_DOMAIN` placeholder rather than the live, domain-substituted `/opt/excalidraw/nginx-proxy.conf` generated by `deploy.sh`.
2. **Hardcoded CORS Domain in Nginx**: Inside `deploy/nginx-proxy.conf`, the `Access-Control-Allow-Origin` header for the `/api/v2/` location block was hardcoded to `https://draw.pixara.online` instead of using the domain placeholder, causing CORS blocks on different hostnames.
3. **Vite Compile-Time Environments**: Vite replaces `import.meta.env.*` expressions with static literals at build time, rendering the runtime environment variable substitution in `window.__env__` inside `index.html` completely inert for the compiled bundle.

#### Diagnosis
Accessing `https://draw.yourdomain.com/api/v2/post/` returned the main `index.html` SPA file (wildcard fallback) rather than Nginx proxying it upstream, showing that Nginx was not routing the `/api/v2/` path block.

#### Fix
1. Updated `docker-compose.ec2.yml` to mount the live substituted config `/opt/excalidraw/nginx-proxy.conf` instead of the static template folder copy.
2. Updated `nginx-proxy.conf` to replace hardcoded CORS origins with `https://EXCALIDRAW_DOMAIN`.
3. Created a wrapper utility `excalidraw-app/env.ts` resolving environment variables dynamically from `window.__env__` (with robust validation checks) before falling back to Vite build-time constants.

#### How Professionals Avoid It
Never rely on build-time environment constants for containerized deployments; always resolve configuration dynamically from global state objects like `window.__env__` at runtime, and ensure compose configurations mount the correct live-substituted path parameters.

---

## 🔒 Chapter 5 Mini-Quiz

1. **Why did line endings (`\r\n` vs `\n`) cause `setup.sh` to crash on Ubuntu Linux?**
   - A) Linux requires scripts to be written in binary
   - B) Windows CRLF line endings insert a hidden Carriage Return (`\r`) character that Linux Bash cannot parse
   - C) Ubuntu 24.04 only runs Python scripts
   - D) Git corrupts files saved on Windows

2. **How did we fix the `Permission denied while trying to connect to the Docker daemon socket` error?**
   - A) By re-installing Ubuntu
   - B) By adding the `ubuntu` user to the `docker` Linux group (`usermod -aG docker ubuntu`) and refreshing group session
   - C) By opening Port 22 in AWS
   - D) By disabling Docker security

3. **Why did `nginx-proxy` fail to start when launched before `certbot-init.sh`?**
   - A) Because Nginx requires a paid license
   - B) Nginx was configured to terminate HTTPS on Port 443, but the SSL certificate files did not yet exist on disk
   - C) Docker Engine was offline
   - D) Because AWS blocked Port 443

*(Answers: 1-B, 2-B, 3-B)*

---

Next Step: Proceed to **[06-mental-models-and-diagrams.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/06-mental-models-and-diagrams.md)** to explore comprehensive visual diagrams and mental models!
