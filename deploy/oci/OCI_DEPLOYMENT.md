# Excalidraw — OCI Always Free ARM Deployment Guide

> **Target**: Oracle Cloud Infrastructure (OCI) Always Free · Ubuntu 24.04 LTS · Ampere A1 (ARM64)

---

## 1. OCI Cloud Infrastructure Setup

### Compute Instance Configuration
1. **Name**: `excalidraw-oci`
2. **Compartment**: Select your compartment
3. **Image**: `Canonical Ubuntu 24.04 Minimal aarch64`
4. **Shape**: `VM.Standard.A1.Flex` (Ampere ARM64)
   - **OCPUs**: 2
   - **Memory**: 12 GB
5. **Networking**:
   - Create new VCN (`excalidraw-vcn`) & Public Subnet
   - Assign a **Public IPv4 Address**
6. **SSH Key**: Add your SSH public key (`~/.ssh/id_rsa.pub`)

---

## 2. OCI Network Security List & Ingress Rules

In the OCI Console:
`Networking → Virtual Cloud Networks → excalidraw-vcn → Security Lists → Default Security List`

Add **Ingress Rules**:
- **Source**: `0.0.0.0/0` | **Protocol**: TCP | **Port**: `80` (HTTP)
- **Source**: `0.0.0.0/0` | **Protocol**: TCP | **Port**: `443` (HTTPS)
- **Source**: `0.0.0.0/0` | **Protocol**: TCP | **Port**: `22` (SSH)

---

## 3. Server Initialization (SSH into Instance)

```bash
# Connect to your instance
ssh ubuntu@YOUR_INSTANCE_PUBLIC_IP

# Clone repository
sudo git clone https://github.com/excalidraw/excalidraw.git /opt/excalidraw/repo
sudo chown -R ubuntu:ubuntu /opt/excalidraw/repo
cd /opt/excalidraw/repo

# Run OCI setup script (installs Docker ARM64, fixes iptables, sets up swap)
sudo bash deploy/oci/setup-oci.sh

# Log out and log back in for docker group changes to apply
exit
```

---

## 4. Environment & Certificate Setup

```bash
# SSH back into the server
ssh ubuntu@YOUR_INSTANCE_PUBLIC_IP
cd /opt/excalidraw/repo

# Edit .env.production with your DOMAIN and FIREBASE credentials
nano /opt/excalidraw/.env.production

# Run initial certbot setup (domain must point to instance IP in DNS!)
bash deploy/certbot-init.sh
```

---

## 5. Deploy Application

```bash
# Build ARM64 images locally on OCI instance & start containers
bash deploy/oci/deploy-oci.sh

# Verify deployment health & container status
bash deploy/oci/monitor.sh
```

---

## 6. Maintenance & Backups

```bash
# Perform backup
bash deploy/oci/backup.sh

# Check logs
docker compose -f deploy/oci/docker-compose.oci.yml logs -f
```
