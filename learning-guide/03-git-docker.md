# Module 3: Git, GitHub & Docker Containerization

[Back to Index](file:///v:/projects/excalidraw/excalidraw/learning-guide/00-index.md)

---

## PART 6: Source Control with Git & GitHub

### 6.1 Why Git Exists & What GitHub Is

Imagine writing a 100-page research paper. Every time you make an edit, you save a new file:
- `paper_v1.docx`
- `paper_final.docx`
- `paper_final_REALLY_FINAL.docx`
- `paper_final_REALLY_FINAL_FIXED_EDIT.docx`

This is chaos. You lose track of what changed, when it changed, and why it changed.

**Git** is a distributed version control system created by Linus Torvalds (the creator of Linux). Git tracks every line change across every file in your project codebase over time, taking snapshot checkpoints called **commits**.

**GitHub** is a cloud platform that hosts Git repositories online, acting as a central source of truth where developers collaborate, review code, and trigger automated deployment pipelines.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        GIT VS GITHUB DISTINCTION                       │
│                                                                        │
│   Tool           What it is                   Where it runs            │
│   ──────────────────────────────────────────────────────────────────   │
│   Git            CLI Software / Engine        Locally on your laptop   │
│   GitHub         Cloud Website / Storage      Remote AWS Datacenters   │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 6.2 Key Git Concepts Defined

- **Repository (Repo)**: The master folder containing all source code files, assets, and the hidden `.git/` database tracking history.
- **Clone**: Downloading a full copy of a remote GitHub repository to your local laptop or EC2 server.
- **Commit**: A permanent, cryptographic snapshot of file changes at a specific point in time identified by a unique SHA hash (e.g., `abc1234`).
- **Branch**: An isolated parallel timeline of development (e.g., `main` for production code, `feature/dark-mode` for experimental code).
- **Origin / Remote**: The nickname pointing to the central remote server repository hosted on GitHub.
- **Pull**: Downloading and merging the newest commits from GitHub into your local directory.

---

### 6.3 Why We Cloned Excalidraw to `/opt/excalidraw/repo`

During server deployment, we ran:
```bash
sudo git clone https://github.com/YOUR_ORG/excalidraw.git /opt/excalidraw/repo
```

By cloning the codebase directly onto our EC2 instance, we placed all production configuration files (`docker-compose.ec2.yml`, `nginx-proxy.conf`, `setup.sh`, `deploy.sh`) right where the Linux operating system and Docker Engine can execute them locally.

---

## PART 7: Docker & Containerization Deep Dive

### 7.1 The "It Works on My Machine" Nightmare

Before Docker, software deployment was infamous for the **"It Works on My Machine"** syndrome:

1. A developer writes a Node.js web app on macOS using Node v20.4 and installs specific graphics libraries.
2. The developer sends the code to the Ops team to deploy on an Ubuntu Linux server.
3. The Ubuntu server has Node v16.1 installed, missing shared C++ libraries, and an older Nginx version.
4. **The application crashes instantly on the server.** The developer responds: *"Well, it worked fine on my laptop!"*

```
DEVELOPER'S MACBOOK                              PRODUCTION UBUNTU SERVER
┌─────────────────────────┐                      ┌─────────────────────────┐
│ Excalidraw Codebase     │                      │ Excalidraw Codebase     │
│ Node.js v20.4 (macOS)   │ ────── DEPLOY ────►  │ Node.js v16.1 (Linux)   │ ──► CRASH!
│ C++ Graphics Libs       │   (Different OS)     │ Missing C++ Libraries   │
└─────────────────────────┘                      └─────────────────────────┘
```

---

### 7.2 What is Docker & How Does it Solve This?

**Docker** solves this problem by packaging your code **together with its exact operating system runtime, environment variables, dependencies, and configuration files** into a standardized, self-contained unit called a **container**.

Whether a Docker container runs on macOS, Windows 11, Ubuntu 24.04, or an AWS server, it behaves **100% identically** because it carries its entire operating environment inside itself!

---

### 7.3 Virtual Machines vs Docker Containers

Beginners often confuse Docker containers with Virtual Machines (like AWS EC2 or VirtualBox).

```
   VIRTUAL MACHINES (VMs)                       DOCKER CONTAINERS
┌───────────────────────────┐                ┌───────────────────────────┐
│ App 1   │ App 2   │ App 3 │                │ App 1   │ App 2   │ App 3 │
├─────────┼─────────┼───────┤                ├─────────┼─────────┼───────┤
│ Guest OS│ Guest OS│GuestOS│                │ Bins/Libs│Bins/Libs│Bins/Libs│
├─────────┴─────────┴───────┤                ├─────────┴─────────┴───────┤
│    HYPERVISOR (Hardware)  │                │     DOCKER ENGINE         │
├───────────────────────────┤                ├───────────────────────────┤
│     HOST OS (Hardware)    │                │  HOST OS KERNEL (Shared)  │
└───────────────────────────┘                └───────────────────────────┘
```

- **Virtual Machines**: Every VM boots a full, heavy guest operating system (requiring 2+ GB RAM and gigabytes of disk space per VM). VMs take minutes to boot.
- **Docker Containers**: Containers share the underlying host Linux kernel. They only isolate user space processes, libraries, and binaries. They start in **seconds** and use as little as **15 MB of RAM**!

---

### 7.4 Core Docker Concepts

#### 1. Dockerfile — The Recipe
A text file containing step-by-step instructions on how to build a container image:
```dockerfile
FROM nginx:stable-alpine-slim
COPY build/ /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

#### 2. Docker Image — The Static Blueprint
An immutable, read-only template built from a Dockerfile containing layered file systems (e.g., base Alpine Linux + Nginx + compiled Excalidraw static JS files). Images are stored in registries like **AWS ECR**.

#### 3. Docker Container — The Living Process
A runnable instance of an image. If a Docker Image is a class definition in Java, a Docker Container is an instantiated Object living in RAM.

#### 4. Docker Engine — The Host Controller
The background service daemon (`dockerd`) running on Ubuntu that manages container lifecycles, creates virtual networks, and mounts volume storage.

---

### 7.5 Docker Compose Architecture (`docker-compose.ec2.yml`)

When running a real application, you rarely run just one container. Excalidraw requires four distinct services working together!

Instead of running long, complex `docker run` commands manually, we use **Docker Compose**: a tool that defines and runs multi-container Docker applications using a declarative YAML file (`docker-compose.ec2.yml`).

Let's examine our four containers defined in `docker-compose.ec2.yml`:

```
                             DOCKER ENGINE
┌────────────────────────────────────────────────────────────────────────┐
│  VIRTUAL BRIDGE NETWORK (excalidraw-net)                               │
│                                                                        │
│  ┌──────────────────────┐  (Ports 80/443)  ┌──────────────────────┐  │
│  │ nginx-proxy          │ ───────────────► │ Public Internet      │  │
│  │ (Reverse Proxy)      │                  └──────────────────────┘  │
│  └──────────┬───────────┘                                              │
│             │ HTTP (/ )                                                │
│             ▼                                                          │
│  ┌──────────────────────┐  WebSocket (/socket.io/)                       │
│  │ excalidraw-app       │ ──────────────────┐                          │
│  │ (SPA Static Server)  │                   │                          │
│  └──────────────────────┘                   ▼                          │
│                                ┌──────────────────────┐                │
│                                │ excalidraw-room      │                │
│                                │ (Socket.IO Relay)    │                │
│                                └──────────────────────┘                │
│  ┌──────────────────────┐                                              │
│  │ certbot              │ (Renews SSL certs into shared volumes)       │
│  └──────────────────────┘                                              │
└────────────────────────────────────────────────────────────────────────┘
```

#### Detailed Breakdown of the 4 Services:

1. **`nginx-proxy`**:
   - **Role**: The front door facing the public internet. Binds host ports `80` and `443`.
   - **Resource Limit**: Memory capped at `64M` RAM (critical for `t2.micro`).
   - **Healthcheck**: Periodically runs `wget -q -O /dev/null http://localhost/health` to verify proxy health.

2. **`excalidraw` (excalidraw-app)**:
   - **Role**: Serves the single-page React frontend application assets. Pulled from **AWS ECR**.
   - **Isolation**: Has **no host ports exposed**! Only accessible by `nginx-proxy` via the internal container network.

3. **`excalidraw-room`**:
   - **Role**: Node.js Socket.IO server enabling multi-user real-time whiteboard collaboration.
   - **Heap Limit**: `NODE_OPTIONS=--max-old-space-size=100` caps Node.js memory heap to 100 MB to prevent `t2.micro` memory crashes.

4. **`certbot`**:
   - **Role**: Let's Encrypt renewal agent. Wakes up every 12 hours, checks if TLS certs expire within 30 days, renews them via webroot, and sends `SIGHUP` signal to `nginx-proxy` to reload certs zero-downtime.

---

### 7.6 Docker Volumes & Networks Explained

#### Docker Volumes (Persistent Storage)
Containers are ephemeral: when a container is destroyed, any file created inside it vanishes forever!

To persist Let's Encrypt certificates across container restarts, we created **Docker Volumes**:
- `certbot-conf`: Stores `/etc/letsencrypt` keys and certificates on the host hard drive. Shared read-only with `nginx-proxy`.
- `certbot-www`: Stores ACME HTTP-01 challenge verification files.

#### Docker Networks (Internal Service Discovery)
We defined an internal driver network: `excalidraw-net`.

Docker automatically creates an internal DNS server for containers on this network. `nginx-proxy` can route traffic to `http://excalidraw:80` or `http://excalidraw-room:3002` using container names as domain names!

---

### 7.7 The Master Mental Model: The Apartment Building Analogy

To lock this in forever, use this mental model:

| Physical Real Estate Analogy | Cloud / Docker Tech Equivalent | Technical Function |
| :--- | :--- | :--- |
| **The Apartment Building** | **AWS EC2 Instance** | The overall physical box providing power, roof, and utility connections. |
| **Building Manager / Landlord** | **Docker Engine** | Manages room allocation, enforces noise/resource limits, handles security. |
| **Architectural Floor Plan Blueprint**| **Docker Image (ECR)** | Immutable paper drawing showing exact room layout; cannot be lived in directly. |
| **Constructed Furnished Unit** | **Docker Container** | A physical living space created from the blueprint where actual work happens. |
| **Building Reception Desk** | **Nginx Proxy Container** | Sits at front door, checks IDs, routes visitors to Unit 1 or Unit 2. |
| **Secure Intercom System** | **Docker Network (`excalidraw-net`)** | Allows internal rooms to call each other without opening doors to the street. |
| **Off-Site Storage Locker** | **Docker Volume (`certbot-conf`)** | Safe storage area outside the unit; contents remain intact even if unit is renovated. |

---

## 🔒 Chapter 3 Mini-Quiz

1. **Why does the `excalidraw-app` container have no `ports:` section mapped to the host in `docker-compose.ec2.yml`?**
   - A) Because static websites do not use ports
   - B) For security isolation: only `nginx-proxy` should receive internet traffic, routing requests internally over `excalidraw-net`
   - C) Because host ports were disabled by AWS
   - D) To save money on network data transfer

2. **What is the key difference between a Docker Image and a Docker Container?**
   - A) Images run on Windows; Containers run on Linux
   - B) Images are immutable read-only blueprints; Containers are running execution instances stored in RAM
   - C) Images require AWS ECR; Containers do not
   - D) Images consume RAM; Containers consume CPU

3. **What problem does `NODE_OPTIONS=--max-old-space-size=100` solve in the `excalidraw-room` container service definition?**
   - A) It speeds up WebSocket internet transfer rates
   - B) It restricts Node.js V8 garbage collection heap allocation to 100 MB, preventing Out-Of-Memory crashes on our 1 GB `t2.micro` EC2 instance
   - C) It allows 100 simultaneous room connections
   - D) It encrypts socket data with 100-bit keys

*(Answers: 1-B, 2-B, 3-B)*

---

Next Step: Proceed to **[04-nginx-dns-ssl.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/04-nginx-dns-ssl.md)** to learn Nginx reverse proxying, DNS resolution, and SSL/TLS encryption!
