# Module 2: Servers, AWS EC2 & Linux Administration

[Back to Index](file:///v:/projects/excalidraw/excalidraw/learning-guide/00-index.md)

---

## PART 3: Understanding Servers & Hardware Components

### 3.1 What is a Server?

A **server** is simply a computer that is connected to a network and configured to receive incoming network requests, process them, and return responses back to the requester (the client).

There is no magical fairy dust inside a server. At its core, a server contains the exact same hardware components as your personal laptop or smartphone:
- A Central Processing Unit (**CPU**) to compute logic
- Random Access Memory (**RAM**) to hold active execution state
- A Hard Drive or Solid State Drive (**Disk Storage**) to save persistent files
- A Network Interface Card (**NIC**) to talk to the internet

```
┌────────────────────────────────────────────────────────────────────────┐
│                        SERVER VS LAPTOP COMPARISON                     │
│                                                                        │
│   Feature             Personal Laptop           Cloud Server (EC2)     │
│   ──────────────────────────────────────────────────────────────────   │
│   Display             Built-in Screen           Headless (No monitor)  │
│   Power               Battery / Shuts off       Dual redundant PSUs    │
│   IP Address          Changes (Dynamic)         Static (Elastic IP)    │
│   Operating System    Windows / macOS           Ubuntu Linux (CLI)     │
│   Uptime              Closes when folded        99.99% (Always On)     │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 3.2 Why Can't You Host Excalidraw on Your Personal Laptop?

Beginners often ask: *"I have Node.js running on my laptop at `localhost:3000`. Why can't I just give my friends my IP address and host my website from home?"*

Here are five technical reasons why home hosting fails:

1. **Dynamic IP Addresses & CGNAT**: Home Internet Service Providers (ISPs like Comcast, AT&T, or Spectrum) change your home IP address frequently. Furthermore, most ISPs use CGNAT (Carrier-Grade NAT), sharing one public IP among hundreds of homes. Outside users cannot reach your specific laptop.
2. **Blocked Inbound Ports**: Residential ISPs explicitly block incoming traffic on Port 80 (HTTP) and Port 443 (HTTPS) to prevent consumers from running servers on home connections.
3. **Power & Sleep Modes**: If your laptop goes to sleep, shuts down to install updates, or loses Wi-Fi connection, your website goes completely offline worldwide.
4. **Asymmetric Upstream Bandwidth**: Home internet gives you fast download speeds (e.g., 300 Mbps) but very slow upload speeds (e.g., 10 Mbps). If 50 users try to download your Excalidraw website assets simultaneously, your home upload link saturates and freezes.
5. **No ECC Memory**: Home laptops use standard RAM. If a cosmic ray or static charge flips a bit in RAM, your laptop blue-screens or crashes. Enterprise servers use **ECC (Error-Correcting Code)** RAM to detect and fix bit flips automatically.

---

### 3.3 The Core Hardware Resources Deep Dive

Let's understand the hardware specs of our deployment's server (**AWS `t2.micro`**):

#### 1. CPU (Central Processing Unit) — The Server's Brain
- **What it is**: The silicon microchip that executes code instructions step-by-step.
- **t2.micro Allocation**: 1 vCPU (Virtual CPU core running on an Intel Xeon processor).
- **Analogy**: The chef in a kitchen. The faster the chef, the quicker orders are cooked.
- **What breaks without it**: If CPU usage hits 100%, incoming requests queue up, responses lag, and the website stops loading.

#### 2. RAM (Random Access Memory) — The Short-Term Scratchpad
- **What it is**: Ultra-fast electronic memory where running programs (Docker containers, Node.js runtime, Nginx) store active data.
- **t2.micro Allocation**: 1 GiB (Gibibyte) = 1,024 Megabytes.
- **Analogy**: The countertop space in the kitchen. If the countertop is full, the chef cannot chop veggies or assemble dishes.
- **What breaks without it (Out-Of-Memory / OOM)**: If programs demand more RAM than the 1 GiB available, the Linux kernel triggers the **OOM Killer** process, instantly terminating your application to prevent the entire system from freezing.

#### 3. Disk Storage (AWS EBS) — The Long-Term Filing Cabinet
- **What it is**: Non-volatile storage (Solid-State Drive) that retains files even when power is turned off.
- **Our Setup**: 30 GB AWS **gp3 (General Purpose SSD)** volume.
- **Analogy**: The walk-in refrigerator where raw ingredients and physical documents are safely locked away.
- **What breaks without it**: If disk space reaches 100%, log files cannot be written, Docker cannot pull new images, and databases crash.

#### 4. Network Bandwidth & IP Addresses — The Delivery Roads
- **Public IP**: A unique numerical street address (e.g., `54.210.45.12`) that allows any computer on the global internet to find your server.
- **Private IP**: An internal address (e.g., `172.31.16.4`) used exclusively for servers within the same AWS private virtual network to talk to each other without touching the public internet.

---

## PART 4: AWS EC2 (Elastic Compute Cloud)

### 4.1 What Exactly is EC2?

**AWS EC2 (Elastic Compute Cloud)** is a service that provides resizable **virtual machines (VMs)** on demand.

When you rent an EC2 instance, AWS does not ship a physical computer to your house. Instead, AWS takes a massive physical server box (with 128 physical CPUs and 512 GB of RAM) in one of their data centers, runs a software manager called a **hypervisor**, and slices off a portion of that hardware for you:

```
┌────────────────────────────────────────────────────────────────────────┐
│                   PHYSICAL HOST IN AWS DATA CENTER                     │
│                                                                        │
│  ┌─────────────────────────┐  ┌─────────────────────────┐  ┌─────────┐ │
│  │ EC2 Instance 1          │  │ EC2 Instance 2 (YOURS)  │  │ EC2 3   │ │
│  │ Customer A (8 vCPUs)    │  │ t2.micro (1 vCPU, 1GB) │  │ ...     │ │
│  └─────────────────────────┘  └─────────────────────────┘  └─────────┘ │
│ ══════════════════════════════════════════════════════════════════════ │
│                      AWS NITRO / KVM HYPERVISOR                        │
│ ══════════════════════════════════════════════════════════════════════ │
│              PHYSICAL INTEL XEON HARDWARE (CPUs / RAM / NICs)          │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 4.2 Why Ubuntu 24.04 LTS?

When creating an EC2 instance, you must select an **AMI (Amazon Machine Image)**, which acts as the operating system template. We selected **Ubuntu Server 24.04 LTS**:

- **Linux**: Linux is open-source, lightweight, incredibly stable, and consumes minimal system resources (unlike Windows Server, which requires 2+ GB of RAM just to draw its graphical user interface).
- **Ubuntu**: The world's most popular Linux distribution for developers, providing the vast `apt` software repository.
- **24.04**: The release year (2024) and month (April).
- **LTS (Long-Term Support)**: Canonical guarantees security updates, bug fixes, and maintenance for **5 years** free of charge.

---

### 4.3 Step-by-Step EC2 Launch Configuration Breakdown

Here is what every setting meant when launching our server:

| Field in AWS Console | Value Chosen | Technical Explanation & Why |
| :--- | :--- | :--- |
| **Instance Name** | `excalidraw-prod` | A human-readable label to identify our production server in the AWS list. |
| **AMI (OS)** | `Ubuntu 24.04 LTS` | Operating system pre-installed onto the virtual hard drive. |
| **Instance Type** | `t2.micro` | Hardware allocation: 1 vCPU, 1 GB RAM. Eligible for AWS Free Tier (750 hours/month free). |
| **Key Pair** | `excalidraw-key.pem` | RSA Cryptographic key pair. AWS places the public key on the server; you download the private key (`.pem`) to authenticate SSH connections safely without passwords. |
| **Network Settings** | VPC Default | Virtual Private Cloud subnet placement. |
| **Security Group** | `excalidraw-sg` | Virtual Firewall controlling inbound and outbound network traffic rules (Ports 22, 80, 443). |
| **Storage** | 30 GB `gp3` SSD | Elastic Block Store volume size. 30 GB is 100% free under the AWS 12-month free tier. |
| **IAM Instance Role** | `excalidraw-ec2-role` | Grants the server permission to call AWS ECR APIs securely without hardcoding secret keys on disk. |

---

### 4.4 Security Group Rules: Firewall Security

A **Security Group** acts as a strict guard at the door of your EC2 instance. By default, **all incoming traffic is blocked** unless explicitly allowed:

```
                     SECURITY GROUP (excalidraw-sg)
                              ┌──────────┐
  Port 22 (SSH) ────────────► │ ALLOWED  │ ──► Admin Access (My IP Only)
                              ├──────────┤
  Port 80 (HTTP) ───────────► │ ALLOWED  │ ──► ACME Challenge & Redirect (0.0.0.0/0)
                              ├──────────┤
  Port 443 (HTTPS) ─────────► │ ALLOWED  │ ──► Production Traffic (0.0.0.0/0)
                              ├──────────┤
  Port 3306 (MySQL) ────────► │ BLOCKED! │ ──► Dropped instantly
                              └──────────┘
```

> **Warning**: Never set Port 22 (SSH) source to `0.0.0.0/0` (Everywhere). Automated botnet scanners constantly brute-force open SSH ports across the entire internet. Set SSH to **My IP** only!

---

### 4.5 Elastic IP Allocation

When you launch an EC2 instance, AWS assigns a **Public IP**. However, if you stop and restart the instance, AWS reclaims that IP and assigns a totally new one!

To fix this, we allocated an **Elastic IP**: a permanent, static IPv4 address reserved for your AWS account. We associated it with `excalidraw-prod`. Now, even if the EC2 instance reboots 100 times, its public IP address never changes, keeping our DNS A-record pointing to the right place.

---

## PART 5: Linux Administration & Commands Deep Dive

### 5.1 The Terminal, Shell, and SSH

Since our cloud server has no monitor or mouse, we interact with it through text using the **CLI (Command Line Interface)**:

- **Terminal**: The text window program running on your laptop.
- **Shell (Bash)**: The command interpreter running on Ubuntu that reads your typed text (e.g. `ls`, `cd`, `docker`) and translates it into kernel operations.
- **SSH (Secure Shell)**: An encrypted network protocol operating on Port 22 that securely connects your local terminal to the remote server's shell.

```bash
# How we SSH into our server:
chmod 400 ~/Downloads/excalidraw-key.pem
ssh -i ~/Downloads/excalidraw-key.pem ubuntu@54.210.45.12
```

---

### 5.2 Linux File Permissions & Superuser Privileges

Linux is a multi-user operating system with strict access controls.

#### The `root` User vs `ubuntu` User
- `ubuntu`: Standard unprivileged user account. Can read most files but cannot install software or modify system settings.
- `root`: The absolute superuser with god-mode control over the entire operating system.
- `sudo` (SuperUser DO): A command that allows the `ubuntu` user to execute a single command with root privileges.

#### Understanding Permission Strings (e.g., `-rw-r--r--` or `drwxr-xr-x`)
Every file and directory has 9 permission bits divided into three groups:

```
 ┌─ Directory flag ('d' = directory, '-' = regular file)
 │
 │  ┌── Owner permissions (User)
 │  │      ┌── Group permissions (Group)
 │  │      │      ┌── Others permissions (World)
 ▼  ▼      ▼      ▼
 d r w x  r - x  r - x   (Octal: 755)
   │ │ │  │   │  │   │
   │ │ │  │   │  └─ Read (4)
   │ │ │  │   └──── Execute (1)
   │ │ │  └──────── Read (4)
   │ │ └─────────── Execute (1)
   │ └────────────── Write (2)
   └──────────────── Read (4)
```

- **Read (`r`)** = 4 points: Ability to view file content or list directory files.
- **Write (`w`)** = 2 points: Ability to modify/delete file content or create files in directory.
- **Execute (`x`)** = 1 point: Ability to execute a file as a program or `cd` into a directory.

```bash
# Granting permission examples:
chmod 400 key.pem       # Owner: Read-only (4+0+0 = 4). Group: None. Others: None. (Required by SSH)
chmod +x setup.sh       # Adds Execute permission so setup.sh can be run as a script.
chown -R ubuntu:ubuntu /opt/excalidraw # Recursively changes file ownership to 'ubuntu' user and group.
```

---

### 5.3 Linux Filesystem Hierarchy Standard (FHS)

Unlike Windows (which uses drive letters like `C:\` and `D:\`), Linux uses a single root directory tree starting at `/`:

```
/ (Root Directory)
├── bin/          ← Essential command binaries (cat, ls, cp)
├── etc/          ← System configuration files (nginx.conf, ufw configs)
├── home/
│   └── ubuntu/   ← Default home folder for the 'ubuntu' user (~/)
├── opt/          ← Reserved for optional/third-party add-on software packages
│   └── excalidraw/  ← OUR DEPLOYMENT ROOT LOCATION!
│       ├── repo/
│       ├── logs/
│       └── certbot/
├── var/
│   ├── log/      ← System log files
│   └── www/      ← Web files (Certbot ACME challenge)
└── tmp/          ← Temporary storage cleared on reboot
```

---

### 5.4 Deconstructing Every Command in `deploy/setup.sh`

When we executed `sudo bash deploy/setup.sh`, here is precisely what happened under the hood:

```bash
# 1. Update APT Package Index
apt-get update -qq
# WHY: Downloads the latest list of available software packages and versions from Ubuntu mirrors.

# 2. Install Required Base Utilities
apt-get install -y ca-certificates curl fail2ban git jq ufw
# WHY:
#   ca-certificates: Enables validating SSL/TLS security certificates.
#   curl / wget: Downloads files over HTTP/HTTPS from the terminal.
#   fail2ban: Scans logs and bans IP addresses that repeatedly fail SSH password logins.
#   git: Source control software to clone our Excalidraw repo.
#   jq: Command-line JSON processor for reading Docker/AWS configs.
#   ufw: Uncomplicated Firewall command-line frontend.

# 3. Create 2 GB Swap File (CRITICAL FOR t2.micro)
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

> **Why Swap File is Mandatory on t2.micro**:  
> Since our `t2.micro` server has only **1 GB of physical RAM**, running Nginx, Docker Engine, Certbot, and Excalidraw simultaneously can push RAM usage above 1,024 MB.  
> **Swap** creates virtual memory on the hard drive (EBS SSD). When physical RAM fills up, Linux temporarily moves inactive memory pages to disk space instead of crashing the server with an OOM error!

```bash
# 4. Configure UFW Firewall
ufw default deny incoming  # Block everything by default
ufw default allow outgoing # Allow server to talk to internet
ufw allow 22/tcp          # Allow SSH admin port
ufw allow 80/tcp          # Allow HTTP port
ufw allow 443/tcp         # Allow HTTPS port
ufw --force enable        # Turn firewall on
```

---

## 🔒 Chapter 2 Mini-Quiz

1. **Why does an SSH client reject a private key file (`key.pem`) if permissions are set to `777` (`-rwxrwxrwx`)?**
   - A) Because 777 makes the key file run as a virus
   - B) SSH enforces strict security rules requiring private keys to be unreadable by other system users (permission `400`)
   - C) Ubuntu 24.04 cannot read files with 7s
   - D) 777 deletes the key file automatically

2. **What critical role does a 2 GB Swap file play on an AWS `t2.micro` instance?**
   - A) It speeds up CPU calculations by 200%
   - B) It provides emergency virtual RAM on the hard drive to prevent Out-Of-Memory (OOM) crashes when physical RAM (1 GB) fills up
   - C) It stores SSL certificates safely
   - D) It bypasses UFW firewall rules

3. **In the Linux directory hierarchy, why was `/opt/excalidraw/` chosen as our application directory rather than `/home/ubuntu/`?**
   - A) Linux forbids creating directories in `/home`
   - B) According to Linux FHS standards, `/opt` is dedicated to system-wide standalone third-party software packages and services
   - C) `/opt` has faster hard drives than `/home`
   - D) Docker containers can only read files inside `/opt`

*(Answers: 1-B, 2-B, 3-B)*

---

Next Step: Proceed to **[03-git-docker.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/03-git-docker.md)** to master Git source control and Docker containerization!
