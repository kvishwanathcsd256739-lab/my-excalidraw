# Module 7: Cloud Engineering Roadmap & Deployment Vocabulary Dictionary

[Back to Index](file:///v:/projects/excalidraw/excalidraw/learning-guide/00-index.md)

---

## PART 15: The Zero-to-Hero Cloud Engineering Roadmap

To become a professional Cloud Engineer or DevOps Architect, you must build skills in a logical, cumulative order. Attempting to learn advanced tools like Kubernetes or Terraform without first understanding Linux and Networking is like trying to build a skyscraper on soft mud.

Here is the recommended 10-step career learning path:

```
┌────────────────────────────────────────────────────────────────────────┐
│                      CLOUD ENGINEERING LEARNING PATH                   │
│                                                                        │
│ [1. Linux] ──► [2. Networking] ──► [3. Git] ──► [4. Docker] ──► [5. AWS]│
│                                                                        │
│ [10. Security] ◄── [9. Monitor] ◄── [8. CI/CD] ◄── [7. K8s] ◄── [6. IaC]│
└────────────────────────────────────────────────────────────────────────┘
```

---

### Step-by-Step Learning Order Rationale

| Step | Subject Area | Core Technologies | Why It Comes In This Specific Order |
| :--- | :--- | :--- | :--- |
| **1** | **Linux Systems** | Ubuntu, Bash, Systemd, SSH, FHS, `chmod`, `cron` | **The Foundation**: 90%+ of cloud servers run Linux. You cannot manage servers if you don't know how to navigate the command line. |
| **2** | **Networking** | TCP/IP, Ports, DNS, HTTP/S, Subnets, Firewalls | **The Piping**: Cloud computing *is* networked computing. You must understand how data packets move before connecting cloud servers. |
| **3** | **Git & Source Control** | Git, GitHub, Branching, Commits, Pull Requests | **Collaboration & History**: Every configuration file, script, and infrastructure template must be version-controlled in Git. |
| **4** | **Containerization** | Docker Engine, Dockerfiles, Compose, Volumes | **Packaging**: Before deploying applications to the cloud, you must package them into deterministic container images. |
| **5** | **Cloud Core (AWS)** | EC2, VPC, IAM, S3, ECR, Elastic IP, Security Groups | **Cloud Foundations**: Mastering basic cloud primitives (Compute, Storage, Networking, Identity) on AWS. |
| **6** | **Infrastructure as Code** | Terraform, OpenTofu, AWS CloudFormation | **Automation**: Replacing manual AWS Console point-and-clicking with code files that provision infrastructure automatically. |
| **7** | **Container Orchestration**| Kubernetes (K8s), AWS EKS, Helm | **Scale**: Managing hundreds of Docker containers across clusters of virtual servers with auto-healing and auto-scaling. |
| **8** | **CI/CD Pipelines** | GitHub Actions, GitLab CI, ArgoCD | **Deployment Automation**: Automatically building, testing, and deploying code to AWS every time a developer git-pushes. |
| **9** | **Observability** | Prometheus, Grafana, Datadog, ELK Stack | **Visibility**: Monitoring CPU/RAM usage, collecting application logs, and setting up pager alerts for when production crashes. |
| **10**| **Cloud Security** | DevSecOps, Vault, IAM Least Privilege, SAST | **Hardening**: Encrypting data at rest and in transit, auditing access, and scanning for vulnerabilities. |

---

## PART 16: Deployment Vocabulary Dictionary

Below are 120+ technical terms encountered during our Excalidraw AWS deployment, defined simply with deployment examples:

### 1. Cloud & Infrastructure (AWS)
1. **AMI (Amazon Machine Image)**: A pre-configured operating system template used to launch EC2 instances. *Example: We selected `Ubuntu 24.04 LTS` as our AMI.*
2. **AWS (Amazon Web Services)**: On-demand cloud computing platform provided by Amazon. *Example: We used AWS to host our server and container registry.*
3. **AWS CLI**: Command-line interface to interact with AWS services via terminal scripts. *Example: Executed `aws ecr get-login-password` to log in.*
4. **CapEx (Capital Expenditure)**: Upfront money spent on physical assets. *Example: Buying physical servers on-prem is CapEx; renting EC2 is OpEx.*
5. **EBS (Elastic Block Store)**: Network-attached persistent block storage for EC2. *Example: We attached a 30 GB `gp3` EBS volume to our instance.*
6. **EC2 (Elastic Compute Cloud)**: Virtual server running in AWS data centers. *Example: Launched an `excalidraw-prod` EC2 instance.*
7. **ECR (Elastic Container Registry)**: Private Docker container image registry in AWS. *Example: Pushed `excalidraw:latest` to ECR.*
8. **Elastic IP**: Permanent static public IPv4 address reserved for your AWS account. *Example: Bound Elastic IP `54.210.45.12` to our instance.*
9. **Free Tier**: AWS discount program offering 750 free hours/month of `t2.micro` for 12 months. *Example: Our deployment ran at $0 cost.*
10. **IAM (Identity & Access Management)**: AWS service managing access permissions. *Example: Created `excalidraw-ec2-role` to grant ECR read access.*
11. **IAM Role**: An IAM identity with specific permissions attached to AWS resources. *Example: Attached ECR read role to our EC2 instance profile.*
12. **Instance Type**: Hardware allocation specification for EC2. *Example: `t2.micro` provides 1 vCPU and 1 GiB RAM.*
13. **Key Pair**: Public/Private cryptographic keys used to secure SSH access. *Example: Downloaded `excalidraw-key.pem` to log in via terminal.*
14. **OpEx (Operational Expenditure)**: Ongoing operational expenses paid over time. *Example: Paying $0.0116/hour for an EC2 server is OpEx.*
15. **Region**: Geographical location containing multiple data centers. *Example: Deployed in `us-east-1` (N. Virginia).*
16. **Security Group**: Virtual firewall controlling network traffic to an EC2 instance. *Example: `excalidraw-sg` allowed ports 22, 80, and 443.*
17. **t2.micro**: Low-cost burstable EC2 instance tier eligible for free usage. *Example: Our single server ran on `t2.micro`.*
18. **vCPU**: Virtual Central Processing Unit core allocated by hypervisor. *Example: `t2.micro` features 1 vCPU.*
19. **VPC (Virtual Private Cloud)**: Isolated virtual network within AWS. *Example: EC2 instance launched inside default VPC.*

---

### 2. Operating System & Linux
20. **APT (Advanced Package Tool)**: Package management utility for Debian/Ubuntu Linux. *Example: `apt-get install docker-ce`.*
21. **Bash**: Default Unix shell command language interpreter. *Example: Wrote installation instructions in `setup.sh`.*
22. **chmod**: Command to change file access permissions. *Example: `chmod 400 key.pem`.*
23. **chown**: Command to change file ownership user and group. *Example: `chown -R ubuntu:ubuntu /opt/excalidraw`.*
24. **CLI (Command Line Interface)**: Text-based interface used to manage software. *Example: Configured Ubuntu using the SSH terminal CLI.*
25. **cron**: Time-based job scheduler in Unix OS. *Example: Scheduled automatic TLS certificate check every 12 hours.*
26. **fail2ban**: Intrusion prevention software blocking brute-force IP attacks. *Example: Banned IPs with 5 failed SSH password attempts.*
27. **FHS (Filesystem Hierarchy Standard)**: Standardized directory structure layout for Linux. *Example: Placed app files in `/opt/excalidraw` per FHS.*
28. **fallocate**: Command to allocate space for a file instantly. *Example: Created 2 GB swap file using `fallocate -l 2G /swapfile`.*
29. **Kernel**: Core program of an OS managing CPU, RAM, and hardware devices. *Example: Docker containers share the host Linux kernel.*
30. **OOM (Out Of Memory)**: Condition when system runs out of physical RAM. *Example: High memory usage triggered the OOM killer on `t2.micro`.*
31. **OOM Killer**: Linux kernel mechanism that terminates memory-heavy processes. *Example: Killed Node process when RAM exceeded 100%.*
32. **root**: Superuser account with unlimited system privileges. *Example: Executed `setup.sh` with `sudo` root rights.*
33. **SSH (Secure Shell)**: Encrypted protocol operating on Port 22 for remote administration. *Example: `ssh -i key.pem ubuntu@ip`.*
34. **sudo**: Executing commands with superuser privileges. *Example: `sudo apt-get update`.*
35. **Swap File**: Disk file used as virtual RAM when physical RAM fills up. *Example: Configured 2 GB swap to prevent server crashes.*
36. **systemd**: System and service manager for Linux OS. *Example: Managed `excalidraw.service` autostart daemon.*
37. **systemctl**: Command-line tool to control `systemd` services. *Example: `systemctl status docker`.*
38. **Ubuntu**: Popular open-source Debian-based Linux distribution. *Example: Used Ubuntu 24.04 LTS as server OS.*
39. **UFW (Uncomplicated Firewall)**: Friendly CLI interface to manage iptables firewall. *Example: `ufw allow 443/tcp`.*
40. **journalctl**: Query tool to view systemd journal logs. *Example: `journalctl -u excalidraw -f`.*

---

### 3. Containerization & Docker
41. **Alpine Linux**: Ultra-lightweight 5 MB security-oriented Linux distribution. *Example: Used `nginx:stable-alpine-slim` base image.*
42. **Base Image**: Starting template image in a Dockerfile. *Example: `FROM node:20-alpine`.*
43. **Build Arguments**: Variables passed to Docker at image build time. *Example: Passed `--build-arg GIT_SHA=abc1234`.*
44. **Container**: Lightweight runnable execution instance of a Docker image. *Example: `excalidraw-app` container running in RAM.*
45. **Docker**: Platform for developing, shipping, and running applications in containers. *Example: Wrapped Excalidraw into Docker containers.*
46. **Docker Compose**: Tool for defining and running multi-container applications. *Example: Managed stack via `docker-compose.ec2.yml`.*
47. **Docker Daemon**: Background service (`dockerd`) managing containers and networks. *Example: Daemon started containers on boot.*
48. **Docker Engine**: Core software suite containing Daemon, API, and CLI. *Example: Installed official Docker Engine from Docker APT repo.*
49. **Dockerfile**: Text document containing commands to assemble a Docker image. *Example: Dockerfile compiled Vite build into static assets.*
50. **Docker Image**: Read-only template containing application code and libraries. *Example: Pulled Excalidraw image from ECR.*
51. **Docker Network**: Isolated virtual network allowing inter-container communication. *Example: Connected services via `excalidraw-net`.*
52. **Docker Volume**: Persistent data directory stored outside container filesystem. *Example: Mounted `certbot-conf` volume for SSL keys.*
53. **Entrypoint**: Script or command executed when a container boots up. *Example: `docker-entrypoint.sh` injected runtime env variables.*
54. **Environment Variables**: Dynamic values passed into containers at runtime. *Example: Injected `VITE_APP_WS_SERVER_URL` into container.*
55. **Ephemeral**: Short-lived or non-persistent. *Example: Containers are ephemeral; data lost unless saved to volumes.*
56. **Healthcheck**: Automated test command verifying if container process is healthy. *Example: Checked `wget http://localhost/health` every 30s.*
57. **Hypervisor**: Software running virtual machines on physical hardware. *Example: AWS Nitro Hypervisor sliced server into EC2 instances.*
58. **Layer**: Immutable filesystem change in a Docker image. *Example: Each Dockerfile command creates a cached image layer.*
59. **Multi-Stage Build**: Docker build technique minimizing final image size. *Example: Built React code in Node stage, copied static files to Nginx.*
60. **Port Mapping**: Binding container internal ports to host system ports. *Example: Mapped `"80:80"` and `"443:443"` on host.*
61. **Registry**: Server storage repository for container images. *Example: AWS ECR and Docker Hub are container registries.*
62. **Restart Policy**: Rule instructing Docker when to restart crashed containers. *Example: `restart: unless-stopped`.*
63. **Tag**: Version label assigned to a container image. *Example: Tagged image as `excalidraw:latest` and `excalidraw:abc1234`.*

---

### 4. Web Servers, Networking & Protocols
64. **A Record**: DNS record mapping a domain name to an IPv4 address. *Example: Mapped `draw.yourdomain.com → 54.210.45.12`.*
65. **ACME Protocol**: Automated Certificate Management Environment protocol. *Example: Certbot used ACME to request certs from Let's Encrypt.*
66. **C10K Problem**: Challenge of handling 10,000 concurrent web connections. *Example: Nginx solved C10K via asynchronous event loops.*
67. **Certbot**: Free open-source software tool to request and renew Let's Encrypt certs. *Example: Managed SSL certs using Certbot container.*
68. **CNAME**: DNS record aliasing one domain to another domain. *Example: Pointed `www.example.com` to `example.com`.*
69. **DH Parameters**: Diffie-Hellman parameters strengthening key exchange security. *Example: Generated `ssl-dhparams.pem` for Nginx.*
70. **dig**: Command-line DNS lookup utility tool. *Example: Verified DNS resolution using `dig +short draw.yourdomain.com`.*
71. **DNS (Domain Name System)**: Internet directory converting domain names to IP addresses. *Example: DNS resolved hostname to server IP.*
72. **Domain Name**: Human-readable web address. *Example: `draw.yourdomain.com`.*
73. **Forward Proxy**: Proxy server routing outbound requests for client devices. *Example: Corporate VPN proxy hiding user IPs.*
74. **FQD (Fully Qualified Domain Name)**: Complete exact domain address specification. *Example: `draw.yourdomain.com.`*
75. **Gzip**: File compression format reducing asset transfer sizes over HTTP. *Example: Enabled Nginx `gzip on` for JS/CSS files.*
76. **HTTP (Hypertext Transfer Protocol)**: Unencrypted web communication protocol operating on Port 80. *Example: Plain HTTP redirected to HTTPS.*
77. **HTTP 301**: Permanent HTTP redirect response status code. *Example: Nginx returned 301 redirect from HTTP to HTTPS.*
78. **HTTPS**: Encrypted HTTP over TLS operating on Port 443. *Example: Secured Excalidraw with HTTPS encryption.*
79. **IP Address**: Numerical label assigned to devices connected to a computer network. *Example: `54.210.45.12`.*
80. **Let's Encrypt**: Free automated public Certificate Authority. *Example: Issued signed TLS certificate for our domain.*
81. **Load Balancing**: Distributing incoming network traffic across multiple servers. *Example: Nginx load-balanced backend requests.*
82. **Nginx**: High-performance HTTP server and reverse proxy. *Example: Used Nginx as `nginx-proxy` container.*
83. **nip.io**: Wildcard DNS service mapping IP addresses to hostnames. *Example: Used `54-210-45-12.nip.io` during testing.*
84. **OCSP Stapling**: Performance optimization for checking SSL certificate validity. *Example: Configured `ssl_stapling on` in Nginx.*
85. **Port 22**: Default network port for SSH administration. *Example: Restricted Port 22 access to admin IP only.*
86. **Port 80**: Default network port for unencrypted HTTP traffic. *Example: Port 80 handled ACME challenges.*
87. **Port 443**: Default network port for encrypted HTTPS traffic. *Example: Port 443 served secure Excalidraw traffic.*
88. **Port 3002**: Internal network port for Socket.IO collaboration server. *Example: Nginx proxied `/socket.io/` to internal port 3002.*
89. **Private IP**: Non-routable internal network IP address. *Example: Server private IP was `172.31.16.4`.*
90. **Public IP**: Globally unique internet-routable IP address. *Example: Elastic IP `54.210.45.12`.*
91. **Rate Limiting**: Restricting maximum incoming request rate per IP. *Example: Nginx capped requests to 20 req/s to prevent DDoS.*
92. **Reverse Proxy**: Server proxying inbound public requests to internal services. *Example: Nginx proxied traffic to Excalidraw containers.*
93. **Socket.IO**: Real-time bidirectional event-based communication library. *Example: Handled multi-user whiteboard sync in `excalidraw-room`.*
94. **SSL (Secure Sockets Layer)**: Legacy encryption protocol predecessor to TLS. *Example: Commonly referred to as SSL/TLS certificates.*
95. **SSL Termination**: Decrypting HTTPS traffic at proxy level before passing to backend. *Example: Nginx handled SSL termination on Port 443.*
96. **TLS (Transport Layer Security)**: Modern cryptographic protocol securing internet communications. *Example: Enforced TLS 1.2 and 1.3.*
97. **TTL (Time To Live)**: Expiration timer setting for cached DNS records. *Example: Set DNS record TTL to 300 seconds.*
98. **WebSockets**: Persistent full-duplex TCP communication protocol over web connections. *Example: Proxied WebSockets via Nginx Upgrade headers.*

---

### 5. Source Control, Build & Development
99. **Branch**: Independent line of development in Git. *Example: Merged feature branch into `main`.*
100. **Clone**: Downloading a local copy of a remote Git repository. *Example: Cloned repository to `/opt/excalidraw/repo`.*
101. **Commit**: Saved snapshot checkpoint of changes in Git history. *Example: Identified image deployment via Git SHA `abc1234`.*
102. **DOS2UNIX**: Utility tool converting Windows CRLF line endings to Unix LF. *Example: Converted `setup.sh` line endings.*
103. **Firebase**: Backend-as-a-Service platform providing Firestore database and storage. *Example: Excalidraw stored drawing files in Firebase.*
104. **Git**: Distributed version control system tracking code changes. *Example: Tracked deployment script updates in Git.*
105. **GitHub**: Cloud hosting platform for Git repositories. *Example: Cloned Excalidraw source code from GitHub.*
106. **Git SHA**: Unique 40-character SHA-1 hash identifying a specific commit. *Example: Tagged Docker container image with short SHA `abc1234`.*
107. **Node.js**: Asynchronous event-driven JavaScript runtime engine. *Example: Ran `excalidraw-room` collaboration server on Node.js.*
108. **Origin**: Default remote repository nickname in Git. *Example: Pulled latest code from `origin main`.*
109. **React**: Frontend JavaScript library for building component-based UIs. *Example: Excalidraw user interface was built using React.*
110. **Repository**: Main project directory tracked by Git version control. *Example: Cloned project repository to server.*
111. **Single Page Application (SPA)**: Web app loading a single HTML page dynamically. *Example: Excalidraw compiled into static SPA assets.*
112. **Vite**: Ultra-fast modern frontend build tool and development server. *Example: Vite bundled Excalidraw React source code into static JS.*
113. **Webroot**: Root file directory on web server serving public web files. *Example: Certbot wrote ACME tokens to `/var/www/certbot`.*

---

## 🔒 Chapter 7 Mini-Quiz

1. **Why is learning Linux Administration listed as Step 1 in the Cloud Engineering Roadmap?**
   - A) Because Linux is owned by Amazon
   - B) Because 90%+ of cloud infrastructure runs Linux, making command-line navigation and file management foundational prerequisites
   - C) Because Docker cannot run without Windows
   - D) Because Linux is required to register domain names

2. **In our vocabulary dictionary, what is the exact function of an **A Record** in DNS?**
   - A) It encrypts passwords with 256-bit keys
   - B) It maps a human-readable domain name directly to an IPv4 address
   - C) It allocates an EC2 instance in AWS
   - D) It restarts crashed Docker containers

3. **What is the difference between CapEx and OpEx in cloud finance?**
   - A) CapEx is paid to Google; OpEx is paid to AWS
   - B) CapEx is upfront capital purchase of hardware; OpEx is ongoing pay-as-you-go operational expenses
   - C) CapEx applies to software; OpEx applies to memory
   - D) There is no difference

*(Answers: 1-B, 2-B, 3-B)*

---

Next Step: Proceed to **[08-interview-prep.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/08-interview-prep.md)** to practice 60 technical interview questions and answers!
