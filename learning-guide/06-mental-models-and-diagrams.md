# Module 6: Intuitive Mental Models & Architectural Diagrams

[Back to Index](file:///v:/projects/excalidraw/excalidraw/learning-guide/00-index.md)

---

## PART 13: The Complete Real-World Mental Model Matrix

Cloud engineering can feel abstract because you cannot touch a virtual server or hold a network packet. To build an intuitive understanding, we map every component of our Excalidraw deployment to a consistent real-world analogy: **The Apartment Complex**.

```
┌────────────────────────────────────────────────────────────────────────┐
│                    THE APARTMENT COMPLEX MENTAL MODEL                  │
│                                                                        │
│  AWS Cloud              ──►  The Gated City Neighborhood                │
│  EC2 Instance           ──►  Rented Apartment Suite                    │
│  Ubuntu OS              ──►  Interior Walls & Utilities                │
│  Docker Engine          ──►  Building Property Manager                 │
│  Docker Image           ──►  Architectural Floor Plan Blueprint         │
│  Docker Container       ──►  Furnished Living Room                     │
│  Docker Volume          ──►  Locked Basement Storage Locker            │
│  Docker Network         ──►  Building Intercom Wiring                  │
│  Nginx Proxy            ──►  Front Desk Receptionist Concierge         │
│  DNS (Route 53)         ──►  GPS Address Navigation System             │
│  SSL Certificate (TLS)  ──►  Security Guard Armored Briefcase          │
└────────────────────────────────────────────────────────────────────────┘
```

---

### Deep Dive Analogy Mapping

| Component | Analogy Element | How It Explains The Technology |
| :--- | :--- | :--- |
| **AWS Cloud** | **The Gated City Neighborhood** | AWS owns land, electrical infrastructure, roads, and security. You rent space within their city. |
| **EC2 Instance** | **Rented Apartment Suite** | An empty space rented by the hour. You choose size (`t2.micro`), but hardware maintenance is handled by the landlord. |
| **Ubuntu 24.04** | **Interior Layout & Utilities** | Provides basic plumbing, floors, and electrical sockets so tools can function inside the suite. |
| **Docker Engine** | **Property Manager** | Ensures rooms stay clean, enforces noise limits (RAM caps), and restarts rooms if something breaks. |
| **Docker Image** | **Architectural Blueprint** | Stored in a library (ECR). Shows where furniture goes, but you can't sleep inside a paper drawing. |
| **Docker Container** | **Constructed Living Room** | Built directly from the blueprint. Multiple rooms can be built from one drawing instantly. |
| **Docker Volume** | **Basement Storage Locker** | Located outside the apartment room. If the room burns down (container destroyed), items in the storage locker remain intact. |
| **Docker Network** | **Internal Intercom System** | Wire between Room 1 and Room 2. Allows occupants to talk internally without opening front doors. |
| **Nginx Proxy** | **Front Desk Concierge** | Stands at the building entrance. Greets visitors, checks credentials (SSL), and routes people to Room 1 (SPA) or Room 2 (Sockets). |
| **DNS (Route 53)** | **GPS Address Book** | Converts "Excalidraw Headquarters" into exact latitude/longitude numerical coordinates (`54.210.45.12`). |
| **SSL / TLS** | **Armored Briefcase Security** | Encrypts messages passed between visitors and concierge so spies in the lobby can't read them. |

---

## PART 14: Visual Architecture & Flow Diagrams

### Diagram 1: Comprehensive System Architecture

This Mermaid diagram illustrates the exact production stack deployed on AWS:

```mermaid
flowchart TD
    subgraph ClientLayer ["Client Layer"]
        UserBrowser["User Web Browser (Chrome / Firefox)"]
    end

    subgraph ExternalServices ["External Edge Services"]
        DNS["Route 53 / DNS Resolver (draw.yourdomain.com -> 54.210.45.12)"]
        LECA["Let's Encrypt Certificate Authority (ACME Protocol)"]
        ECR["AWS ECR (Container Image Registry)"]
    end

    subgraph AWSCloud ["AWS Cloud (us-east-1)"]
        subgraph EC2Instance ["EC2 Instance (t2.micro - Ubuntu 24.04 LTS)"]
            subgraph SecurityGroup ["Security Group Firewall (excalidraw-sg)"]
                Port22["Port 22 (SSH - Admin Only)"]
                Port80["Port 80 (HTTP - Public)"]
                Port443["Port 443 (HTTPS - Public)"]
            end

            subgraph DockerEngine ["Docker Engine & Compose Runtime"]
                subgraph ProxyContainer ["nginx-proxy Container (:80, :443)"]
                    NginxCore["Nginx Core Process"]
                end

                subgraph InternalNet ["Docker Network (excalidraw-net)"]
                    AppContainer["excalidraw-app Container (:80) Static React SPA"]
                    RoomContainer["excalidraw-room Container (:3002) Socket.IO Collaboration"]
                end

                subgraph CertbotContainer ["certbot Container"]
                    CertbotTask["Certbot Renewal Task (Every 12h)"]
                end

                subgraph StorageVolumes ["Persistent Volumes"]
                    CertConf["certbot-conf (/etc/letsencrypt)"]
                    CertWWW["certbot-www (/var/www/certbot)"]
                end
            end
        end
    end

    %% User Flow
    UserBrowser -->|"1. Resolve Domain"| DNS
    UserBrowser -->|"2. HTTPS Request :443"| Port443
    Port443 --> NginxCore

    %% Proxy Internal Routing
    NginxCore -->|"3a. Proxy HTTP GET /"| AppContainer
    NginxCore -->|"3b. Proxy WS /socket.io/"| RoomContainer

    %% SSL & Volumes
    CertbotTask -->|"Renew Certs"| CertConf
    NginxCore -.->|"Read Certs (ro)"| CertConf
    LECA <-->|"ACME HTTP-01 Challenge"| Port80
    Port80 --> CertWWW
    CertbotTask --> CertWWW

    %% Image Pull
    AppContainer -.->|"Pull Container Image"| ECR
```

---

### Diagram 2: User Request Sequence Flow

This sequence diagram traces a user opening Excalidraw and collaborating in real-time:

```mermaid
sequenceDiagram
    autonumber
    actor User as User Browser
    participant DNS as Route 53 DNS
    participant Nginx as Nginx Proxy (:443)
    participant App as excalidraw-app (:80)
    participant Room as excalidraw-room (:3002)

    %% Step 1: DNS
    User->>DNS: Resolve draw.yourdomain.com
    DNS-->>User: Return 54.210.45.12

    %% Step 2: TLS Handshake
    User->>Nginx: Client Hello (TCP Port 443)
    Nginx-->>User: Server Hello + SSL Certificate (fullchain.pem)
    Note over User,Nginx: Negotiate Symmetric AES-GCM Session Key

    %% Step 3: Serve SPA Static Assets
    User->>Nginx: GET / (Encrypted HTTPS)
    Nginx->>App: Proxy GET http://excalidraw:80/
    App-->>Nginx: Return index.html + Compiled JS/CSS Bundles
    Nginx-->>User: Deliver Encrypted React App Bundle

    %% Step 4: WebSockets Collaboration
    Note over User: User opens whiteboard room
    User->>Nginx: GET /socket.io/?EIO=4 (Upgrade: websocket)
    Nginx->>Room: Proxy HTTP Upgrade Request to http://excalidraw-room:3002
    Room-->>Nginx: HTTP 101 Switching Protocols
    Nginx-->>User: HTTP 101 Switching Protocols (Full-Duplex WS Established)

    loop Real-Time Collaboration
        User->>Nginx: Send Encrypted Draw Delta Event
        Nginx->>Room: Forward WS Frame
        Room-->>Nginx: Broadcast Delta to Room Peer Containers
        Nginx-->>User: Broadcast Encrypted Delta to Peer Browsers
    end
```

---

### Diagram 3: Chronological Deployment Sequence

This sequence diagram details the full lifecycle of setting up the deployment:

```mermaid
sequenceDiagram
    autonumber
    actor Dev as Developer Laptop
    participant AWS as AWS Console / CLI
    participant ECR as AWS ECR
    participant EC2 as AWS EC2 Server
    participant LE as Let's Encrypt CA

    Dev->>AWS: 1. Create ECR Repo + Launch EC2 t2.micro
    AWS-->>Dev: EC2 Instance Ready (Public IP: 54.210.45.12)
    Dev->>ECR: 2. docker build & docker push excalidraw:latest
    ECR-->>Dev: Image Pushed Successfully

    Dev->>EC2: 3. SSH into EC2 & run setup.sh
    Note over EC2: Install Docker, UFW, create 2GB Swap file

    Dev->>EC2: 4. Execute certbot-init.sh
    EC2->>LE: Request ACME HTTP-01 Challenge for Domain
    LE->>EC2: Fetch http://domain/.well-known/acme-challenge/token
    EC2-->>LE: Return Valid Token
    LE-->>EC2: Issue Signed TLS Certificate (fullchain.pem)

    Dev->>EC2: 5. Execute deploy.sh
    EC2->>ECR: Pull excalidraw:latest container image
    Note over EC2: Launch docker compose stack (4 containers)
    EC2-->>Dev: Deployment Successful! HTTPS OK (200)
```

---

## 🔒 Chapter 6 Mini-Quiz

1. **In our apartment building mental model, what component corresponds to the Front Desk Receptionist Concierge?**
   - A) AWS EC2
   - B) Nginx Reverse Proxy Container
   - C) Docker Volume
   - D) Git Commit

2. **In Diagram 2 (Request Sequence Flow), why does Nginx return `HTTP 101 Switching Protocols` when proxying `/socket.io/`?**
   - A) To report a server crash
   - B) To confirm that the HTTP connection has been upgraded to a persistent, full-duplex WebSocket connection
   - C) To redirect traffic from HTTP to HTTPS
   - D) To request a new password

3. **What happens to data stored in a Docker Volume when a Docker Container is deleted and recreated?**
   - A) The volume data is deleted instantly
   - B) The volume data remains completely intact on the host storage filesystem
   - C) The volume data is uploaded to GitHub
   - D) The volume is converted into an AMI

*(Answers: 1-B, 2-B, 3-B)*

---

Next Step: Proceed to **[07-roadmap-and-vocabulary.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/07-roadmap-and-vocabulary.md)** to explore the Cloud Career Roadmap and deployment Vocabulary Dictionary!
