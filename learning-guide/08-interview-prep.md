# Module 8: Cloud & DevOps Technical Interview Preparation

[Back to Index](file:///v:/projects/excalidraw/excalidraw/learning-guide/00-index.md)

---

## PART 17: 60 Targeted Technical Interview Questions & Answers

This chapter prepares you for cloud engineering, DevOps, and systems administration job interviews. Questions are divided into **Beginner (1–25)**, **Intermediate (26–50)**, and **Scenario-Based (51–60)**.

---

### Section 1: Beginner Questions (1–25)

#### Q1: What is the difference between an IP address and a domain name?
**Answer**: An IP address is a unique numerical address (e.g. `54.210.45.12`) used by computers to route data packets across networks. A domain name (e.g. `draw.example.com`) is a human-readable alias mapped to an IP address via DNS.

#### Q2: What is AWS EC2?
**Answer**: AWS Elastic Compute Cloud (EC2) is a cloud web service providing resizable virtual machines (virtual servers) on demand.

#### Q3: What is the role of an Operating System Kernel?
**Answer**: The kernel is the core component of an OS that acts as a bridge between running applications and the physical hardware (CPU, RAM, Disks, Network interfaces).

#### Q4: Why do we use SSH on Port 22?
**Answer**: SSH (Secure Shell) provides an encrypted cryptographic channel for remote terminal administration over unsecured networks.

#### Q5: What is the difference between `root` and a standard Linux user?
**Answer**: The `root` account is the ultimate administrator with unrestricted access to all system files and commands. A standard user has restricted permissions to protect system files.

#### Q6: What does the `sudo` command do?
**Answer**: `sudo` (SuperUser DO) allows authorized unprivileged users to execute a single command with root administrative privileges.

#### Q7: What is Docker?
**Answer**: Docker is an open-source platform that packages software and all its runtime dependencies into standardized, lightweight, isolated units called containers.

#### Q8: What is the difference between a Virtual Machine and a Docker Container?
**Answer**: Virtual Machines bundle a full guest operating system and virtualized hardware via a hypervisor. Docker containers share the host operating system kernel and isolate only user-space processes, making them faster and lighter.

#### Q9: What is a Docker Image?
**Answer**: A Docker Image is an immutable, read-only template containing application code, libraries, dependencies, and configuration used to instantiate containers.

#### Q10: What is Docker Compose?
**Answer**: Docker Compose is an orchestration tool used to define, configure, and run multi-container Docker applications using a single declarative YAML file.

#### Q11: What is a Reverse Proxy?
**Answer**: A reverse proxy sits in front of backend servers, receiving incoming public client requests and routing them to appropriate internal backend services.

#### Q12: Why do we use Nginx in front of web applications?
**Answer**: Nginx handles high-concurrency requests, terminates TLS/SSL encryption, serves static assets efficiently, enforces rate limiting, and proxies requests to backend containers.

#### Q13: What is the difference between HTTP and HTTPS?
**Answer**: HTTP (Port 80) transmits payload data in unencrypted cleartext. HTTPS (Port 443) encrypts payloads using TLS/SSL encryption to prevent tampering and eavesdropping.

#### Q14: What is an SSL/TLS Certificate?
**Answer**: A digital cryptographic document issued by a Certificate Authority (CA) that binds a public encryption key to a domain identity.

#### Q15: What is Let's Encrypt?
**Answer**: A free, automated, open Certificate Authority that issues trusted TLS certificates via automated protocols like ACME.

#### Q16: What is DNS?
**Answer**: The Domain Name System (DNS) is the internet's decentralized phonebook that translates hostnames into IP addresses.

#### Q17: What is an A Record in DNS?
**Answer**: A DNS record type that maps a domain name directly to an IPv4 address.

#### Q18: What is Git?
**Answer**: A distributed version control system that tracks changes in source code files over time.

#### Q19: What is the difference between Git and GitHub?
**Answer**: Git is the local CLI tool that tracks code history. GitHub is an online cloud platform that hosts Git repositories for team collaboration.

#### Q20: What does `git clone` do?
**Answer**: It downloads a full copy of a remote Git repository to your local computer.

#### Q21: What is a Swap file in Linux?
**Answer**: A file on the hard drive used as virtual RAM when physical system RAM becomes fully saturated.

#### Q22: What is AWS ECR?
**Answer**: Amazon Elastic Container Registry (ECR) is a managed Docker container registry service for storing and pulling container images securely.

#### Q23: What is an Elastic IP in AWS?
**Answer**: A permanent, static public IPv4 address allocated to your AWS account that remains constant even when EC2 instances are stopped and restarted.

#### Q24: What is an AWS Security Group?
**Answer**: A virtual firewall regulating inbound and outbound network traffic rules for EC2 instances.

#### Q25: What is the purpose of UFW in Ubuntu?
**Answer**: Uncomplicated Firewall (UFW) is a user-friendly CLI frontend for managing Linux `iptables` packet filtering rules.

---

### Section 2: Intermediate Questions (26–50)

#### Q26: Explain the Linux file permission `chmod 755 script.sh`.
**Answer**:
- `7` (Owner): Read (4) + Write (2) + Execute (1) = Full access.
- `5` (Group): Read (4) + Execute (1) = Read and run only.
- `5` (Others): Read (4) + Execute (1) = Read and run only.

#### Q27: How does Nginx handle WebSockets proxying differently than standard HTTP?
**Answer**: Standard HTTP connections close after each request. WebSockets require persistent full-duplex TCP pipes. Nginx requires explicit protocol upgrade headers (`Upgrade: $http_upgrade`, `Connection: "upgrade"`) and long timeout settings (`proxy_read_timeout`) to prevent dropping active WebSocket sessions.

#### Q28: How does the Let's Encrypt ACME HTTP-01 challenge work?
**Answer**: Let's Encrypt gives Certbot a cryptographic token. Certbot places it at `http://domain/.well-known/acme-challenge/token`. The Let's Encrypt CA makes an HTTP GET request to that URL. If the token matches, domain ownership is verified and the certificate is issued.

#### Q29: What happens when an EC2 instance experiences an Out-Of-Memory (OOM) condition?
**Answer**: If physical RAM and Swap space are completely exhausted, the Linux kernel invokes the OOM Killer process, which selects and forcefully terminates (`SIGKILL`) the process consuming the most RAM to prevent a kernel crash.

#### Q30: What is the difference between asymmetric and symmetric encryption in TLS?
**Answer**: Asymmetric encryption uses a Public key to encrypt and a Private key to decrypt during the initial TLS handshake (slow). Symmetric encryption uses a single shared secret key negotiated during the handshake to encrypt data rapidly during the session.

#### Q31: How do Docker volume mounts differ from bind mounts?
**Answer**: Volumes are managed entirely by Docker inside `/var/lib/docker/volumes/` on the host, isolated from host filesystem clutter. Bind mounts map any arbitrary host directory (e.g. `/opt/excalidraw/logs`) directly into a container.

#### Q32: Why did we run `newgrp docker` after adding the `ubuntu` user to the `docker` group?
**Answer**: Adding a user to a group in `/etc/group` does not update existing active shell sessions. `newgrp docker` recalculates the current session's group permissions without requiring an SSH logout/login cycle.

#### Q33: What is the purpose of `ssl_dhparam` in Nginx configuration?
**Answer**: Diffie-Hellman parameters strengthen Perfect Forward Secrecy (PFS) during TLS key exchanges, ensuring that compromised private keys cannot retroactively decrypt past recorded traffic sessions.

#### Q34: What is the difference between Docker `ports:` mapping and `expose:`?
**Answer**: `ports:` binds a container port to a physical host network port (making it accessible externally). `expose:` documents ports for inter-container communication on internal Docker networks without opening them to the host network.

#### Q35: What is the purpose of AWS IAM Roles for EC2?
**Answer**: IAM Roles allow EC2 instances to authenticate securely to AWS services (like ECR or S3) using temporary AWS STS credentials automatically rotated by the instance profile, eliminating hardcoded secret keys on disk.

#### Q36: How does Docker Compose handle service DNS resolution?
**Answer**: Docker Compose creates an embedded DNS server on user-defined networks (`excalidraw-net`). Containers resolve other container service names (e.g., `http://excalidraw:80`) directly to their internal container IP addresses.

#### Q37: What is the function of `docker-entrypoint.sh` scripts in production containers?
**Answer**: Entrypoint scripts run as PID 1 inside containers on startup to perform runtime initialization—such as injecting dynamic environment variables into static HTML files—before starting the main application server process.

#### Q38: Why should you avoid using `0.0.0.0/0` as the source for Port 22 in a Security Group?
**Answer**: Exposing SSH globally invites automated malicious botnets to continuously scan and brute-force password/key vulnerabilities. Restricting SSH to your specific IP blocks external unauthorized connection attempts.

#### Q39: What is the purpose of `fail2ban`?
**Answer**: `fail2ban` dynamically monitors log files (e.g., `/var/log/auth.log`) for repeated failed login patterns and updates firewall rules (`iptables`/`ufw`) to temporarily or permanently ban offending IP addresses.

#### Q40: What is the difference between `docker stop` and `docker kill`?
**Answer**: `docker stop` sends a `SIGTERM` signal, allowing the container process a grace period (default 10s) to clean up state before shutting down. `docker kill` sends an immediate `SIGKILL` signal, instantly stopping the container.

#### Q41: What is the purpose of OCSP Stapling in Nginx?
**Answer**: OCSP Stapling allows Nginx to query the CA for certificate revocation status and append (staple) the timestamped proof directly into the TLS handshake, saving the client an extra DNS/HTTP lookup round-trip.

#### Q42: What is the difference between standard Docker logs and log rotation drivers?
**Answer**: Standard Docker logging writes stdout/stderr to JSON files indefinitely, which can fill up server disk space. The `json-file` driver with `max-size` and `max-file` options automatically caps log file sizes and rotates old log files out.

#### Q43: What does the `--build-arg` flag do in `docker build`?
**Answer**: It passes environment variables into the Dockerfile execution scope specifically for use during the image build process (e.g., passing Git SHA tags).

#### Q44: What is the function of `ssl_tokens off;` in Nginx?
**Answer**: It hides Nginx version numbers from HTTP server response headers and error pages, preventing attackers from identifying specific vulnerable Nginx version releases.

#### Q45: How does Linux handle process management with `systemd`?
**Answer**: `systemd` is the init process (PID 1) that boots the system, spawns background services (daemons), manages service dependencies, and automatically restarts failed background services.

#### Q46: What is a Git SHA commit hash?
**Answer**: A unique 40-character SHA-1 checksum generated from the exact contents, metadata, parent, and timestamp of a commit snapshot.

#### Q47: Why do we use multi-stage Docker builds for single-page applications?
**Answer**: Multi-stage builds compile source code in a heavy build environment (e.g., Node.js with devDependencies), then copy only final compiled static assets into a tiny production server image (e.g., Nginx Alpine), reducing final image size by 90%+.

#### Q48: What is the difference between `curl` and `wget`?
**Answer**: Both fetch data over networks. `curl` is a versatile tool supporting multiple protocols (HTTP/FTP/SCP) printing output to stdout by default. `wget` is optimized for downloading files recursively.

#### Q49: What is the difference between `127.0.0.1` and `0.0.0.0`?
**Answer**: `127.0.0.1` (loopback) refers exclusively to the local computer itself. `0.0.0.0` is a wildcard address meaning "listen on all available network interface addresses on this machine."

#### Q50: What is the purpose of `healthcheck:` blocks in Docker Compose?
**Answer**: Healthchecks run periodic test commands inside containers to verify application functionality. Compose uses health status to defer dependent service launches until upstream services report healthy status.

---

### Section 3: Scenario-Based Architecture Questions (51–60)

#### Q51: Scenario: Your website `draw.example.com` shows "502 Bad Gateway" when visited in a browser. How do you diagnose and fix this step-by-step?
**Answer**:
1. **Understand 502**: Nginx (`nginx-proxy`) is online, but it cannot connect to the upstream container (`excalidraw-app`).
2. **Step 1 — Check Containers**: Run `docker compose ps` on EC2 to see if `excalidraw-app` is running or crashed.
3. **Step 2 — Check Logs**: Run `docker logs excalidraw-app` to see application error tracebacks.
4. **Step 3 — Inspect Proxy Logs**: Run `docker logs excalidraw-proxy` to check upstream network connection errors.
5. **Step 4 — Verify Network**: Ensure both containers are attached to `excalidraw-net` and `excalidraw-app` listens on Port 80 internally.

#### Q52: Scenario: Your EC2 instance becomes completely unresponsive to SSH connections. What are your diagnostic steps?
**Answer**:
1. Check AWS Console instance status checks (System Status Check vs Instance Status Check).
2. Verify Security Group rules haven't accidentally modified Port 22 permissions.
3. Use **AWS EC2 Instance Connect** or **SSM Session Manager** from the AWS Console browser to open a serial emergency shell.
4. Check if the system ran out of RAM/Swap (`free -h` / `dmesg | grep oom`) causing system lockup.
5. Reboot the instance from AWS Console if unresponsive.

#### Q53: Scenario: Let's Encrypt certificate renewal fails automatically after 60 days. How do you troubleshoot?
**Answer**:
1. Inspect Certbot container logs: `docker logs excalidraw-certbot`.
2. Check if Port 80 is open and accessible from the public internet (`curl -I http://draw.example.com/.well-known/acme-challenge/test`).
3. Verify DNS A-record hasn't changed or expired.
4. Execute manual renewal dry-run test: `docker run --rm -v ... certbot/certbot renew --dry-run`.

#### Q54: Scenario: Real-time whiteboard updates work locally, but fail to sync between two users on the deployed EC2 server. Why?
**Answer**:
1. Check browser console network tab for WebSocket connection failures on `/socket.io/`.
2. Verify `nginx-proxy.conf` includes WebSocket upgrade headers (`Upgrade` and `Connection`).
3. Check `excalidraw-room` container logs (`docker logs excalidraw-room`).
4. Ensure `VITE_APP_WS_SERVER_URL` in `.env.production` points to `https://draw.example.com` rather than `localhost`.

#### Q55: Scenario: Your Docker image build fails on EC2 due to `No space left on device`. How do you recover?
**Answer**:
1. Check disk usage: `df -h`.
2. Clean up dangling Docker images, unused containers, and build cache: `docker system prune -a --volumes`.
3. Check log file sizes in `/var/log/` and `/var/lib/docker/containers/`.
4. If storage is permanently full, modify the EBS volume size in AWS Console from 30 GB to 40 GB and resize the filesystem using `sudo resize2fs /dev/xvda`.

#### Q56: Scenario: You modify code on your local laptop, push it to ECR, but running `deploy.sh` on EC2 does not load your new changes. Why?
**Answer**:
1. You deployed using the `:latest` tag, but Docker cached the previous `:latest` image locally on EC2 and didn't pull new layers.
2. **Fix**: Explicitly run `docker pull ${ECR_REGISTRY}/excalidraw:latest` before `docker compose up -d`, or tag images with unique Git SHAs (`:abc1234`) instead of static tags.

#### Q57: Scenario: A developer committed their `.env.production` file containing secret Firebase credentials to a public GitHub repo. What steps must be taken immediately?
**Answer**:
1. **Revoke Credentials Instantly**: Log into Firebase/AWS console and revoke the exposed API keys and secrets.
2. **Purge Git History**: Use `git-filter-repo` or BFG Repo-Cleaner to strip the secret file completely from all past Git commit history.
3. **Force Push**: Push sanitized history to GitHub (`git push origin --force --all`).
4. **Issue New Credentials**: Generate brand new secret keys and add `.env.production` to `.gitignore`.

#### Q58: Scenario: Traffic to your site increases from 10 users to 10,000 users overnight. Your `t2.micro` server crashes due to 100% CPU usage. What is your scaling strategy?
**Answer**:
1. **Vertical Scale (Immediate)**: Change EC2 instance type from `t2.micro` to `t3.medium` (2 vCPUs, 4 GB RAM) in AWS Console.
2. **Horizontal Scale (Architecture)**:
   - Move static assets to AWS CloudFront CDN / S3 bucket.
   - Deploy an AWS Application Load Balancer (ALB) in front of multiple EC2 instances.
   - Run `excalidraw-room` across multiple nodes backed by a Redis adapter for Socket.IO state synchronization.

#### Q59: Scenario: Running `bash deploy/setup.sh` hangs indefinitely at `apt-get update`. What is the issue?
**Answer**:
1. Another `apt` background process (like unattended security upgrades) holds the dpkg lock file `/var/lib/dpkg/lock-frontend`.
2. **Fix**: Wait for unattended upgrades to complete, or check running processes (`ps aux | grep apt`) and safely kill stalled instances before clearing the lock file.

#### Q60: Scenario: Users report that visiting `http://draw.example.com` shows a blank page, but `https://draw.example.com` works perfectly. What is wrong?
**Answer**:
1. Nginx Port 80 server block is serving static files instead of executing an HTTP 301 redirect to HTTPS.
2. **Fix**: Update Nginx Port 80 configuration block to enforce `return 301 https://$host$request_uri;` for all routes except `/.well-known/acme-challenge/`.

---

Next Step: Proceed to **[09-industry-and-reflection.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/09-industry-and-reflection.md)** to compare our deployment against industry architectures and read the final reflection!
