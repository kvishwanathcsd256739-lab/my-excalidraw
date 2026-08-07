# Module 4: Nginx, DNS & SSL/TLS Encryption

[Back to Index](file:///v:/projects/excalidraw/excalidraw/learning-guide/00-index.md)

---

## PART 8: Nginx & Reverse Proxy Architecture

### 8.1 What is Nginx & Why Does it Exist?

In the early days of the web, web servers used a process-per-request model (like Apache HTTP Server). If 1,000 users connected simultaneously, the server spawned 1,000 separate heavy operating system processes. This caused the famous **C10K problem** (inability to handle 10,000 concurrent connections due to memory exhaustion).

**Nginx** (pronounced "Engine-X") was created in 2004 using an **asynchronous, event-driven, non-blocking architecture**. A single Nginx worker process can handle tens of thousands of concurrent connections using a tiny sliver of CPU and RAM (~30 MB).

---

### 8.2 What is a Reverse Proxy?

To understand a **Reverse Proxy**, let's contrast it with a **Forward Proxy**:

- **Forward Proxy (Protects Clients)**: Sits in front of client laptops (e.g., a corporate VPN proxy). The server outside only sees the proxy's IP address, hiding the client's identity.
- **Reverse Proxy (Protects Servers)**: Sits in front of backend servers. Clients on the internet only talk to Nginx (`nginx-proxy`). Nginx inspects incoming requests and routes them to internal containers (`excalidraw-app`, `excalidraw-room`).

```
FORWARD PROXY:
[Client Laptops] ──► [FORWARD PROXY] ──► [Public Internet / Web Servers]
 (Hides Client IPs)

REVERSE PROXY (OUR EXCALIDRAW SETUP):
[Public Internet] ──► [Nginx Reverse Proxy] ──┬──► [excalidraw-app container]
 (Hides Server IPs & Topology)               └──► [excalidraw-room container]
```

---

### 8.3 Deconstructing Our `deploy/nginx-proxy.conf`

Let's dissect the exact Nginx configuration running on our EC2 instance:

#### 1. HTTP Server Block (Port 80): ACME Challenge & Redirect
```nginx
server {
    listen 80;
    server_name _;

    # Allow Let's Encrypt ACME HTTP-01 challenge verification
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
        try_files $uri =404;
    }

    # Redirect all other plain HTTP traffic to secure HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}
```
- **What it does**: Port 80 handles ACME certificate validation requests from Let's Encrypt. Any user typing `http://draw.yourdomain.com` is automatically issued an `HTTP 301 Moved Permanently` redirect to `https://draw.yourdomain.com`.

#### 2. HTTPS Server Block (Port 443): SSL Termination & Upstream Routing
```nginx
server {
    listen 443 ssl;
    server_name draw.yourdomain.com;

    # SSL Certificate Keys mounted from volume
    ssl_certificate     /etc/letsencrypt/live/draw.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/draw.yourdomain.com/privkey.pem;

    # 1. Main Excalidraw SPA Frontend Proxy
    location / {
        proxy_pass http://excalidraw_app;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # 2. Socket.IO Real-Time Collaboration WebSocket Proxy
    location /socket.io/ {
        proxy_pass http://excalidraw_room;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400s;
    }
}
```

> **Why WebSocket Upgrade Headers Are Mandatory**:  
> Standard HTTP connections are short-lived request-response cycles. WebSockets require a persistent, two-way full-duplex TCP pipe.  
> The headers `Upgrade: $http_upgrade` and `Connection: "upgrade"` tell Nginx to switch the HTTP connection protocol to WebSocket format. Setting `proxy_read_timeout 86400s` prevents Nginx from severing idle whiteboard collaboration sessions for 24 hours.

---

## PART 9: The Domain Name System (DNS)

### 9.1 How Browsers Locate Servers

Computers communicate using numerical IP addresses (e.g., `54.210.45.12`). Humans remember text names (e.g., `draw.yourdomain.com`).

**DNS (Domain Name System)** is the decentralized global directory service that translates human-readable domain names into machine-routable IP addresses.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        DNS RESOLUTION SEQUENCE                         │
│                                                                        │
│ User types: "draw.yourdomain.com"                                      │
│                                                                        │
│ [Browser] ──1. Query DNS?──► [Recursive Resolver (1.1.1.1)]             │
│                                       │                                │
│                                       ├─2. Ask Root (.)                │
│                                       ├─3. Ask TLD (.com)              │
│                                       └─4. Ask Route 53 (draw=54.210...)│
│ [Browser] ◄──5. IP: 54.210.45.12──────┘                                │
│                                                                        │
│ [Browser] ──6. HTTP GET https://54.210.45.12:443 ──► [AWS EC2 Server]   │
└────────────────────────────────────────────────────────────────────────┘
```

---

### 9.2 Key DNS Record Types

When configuring AWS Route 53, Cloudflare, or GoDaddy, you create DNS records:

| Record Type | Full Name | Purpose | Example |
| :--- | :--- | :--- | :--- |
| **A Record** | Address Record | Maps a domain/subdomain directly to an **IPv4 Address**. | `draw.yourdomain.com → 54.210.45.12` |
| **AAAA Record** | IPv6 Address Record | Maps a domain directly to an **IPv6 Address**. | `draw.yourdomain.com → 2600:1f18::1` |
| **CNAME** | Canonical Name | Aliases one domain name to another domain name. | `www.yourdomain.com → yourdomain.com` |
| **TXT Record** | Text Record | Holds arbitrary plain text (used for verification & Let's Encrypt). | `v=spf1 include:_spf.google.com ~all` |

---

### 9.3 What is `nip.io` Wildcard DNS?

During testing, you might not own a custom domain yet. We use **`nip.io`**: a free wildcard DNS service.

When you query `54-210-45-12.nip.io`, the `nip.io` nameservers dynamically extract the IP address embedded in the hostname and instantly return `54.210.45.12`. This allows developers to test SSL certificates and domain setups on raw IP addresses instantly!

---

## PART 10: SSL/TLS Encryption & Let's Encrypt Certbot

### 10.1 HTTP vs HTTPS: Why Plain HTTP is Dangerous

- **HTTP (Port 80)**: Unencrypted cleartext transmission. Anyone sitting on your public Wi-Fi network (at Starbucks or a dorm) can use packet-sniffing software (like Wireshark) to view your passwords, drawn shapes, and personal data flowing through the air.
- **HTTPS (Port 443)**: HTTP over **TLS (Transport Layer Security)**. All payload data is cryptographically encrypted before leaving your browser. Interceptors see only unreadable garbled mathematical noise.

---

### 10.2 Asymmetric vs Symmetric Encryption

HTTPS uses a clever combination of two cryptographic techniques:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        TLS HANDSHAKE ENCRYPTION                        │
│                                                                        │
│ 1. Asymmetric (Handshake Phase):                                       │
│    Server sends Public Key ──► Client encrypts random secret.          │
│    Server decrypts with Private Key. Both share secret key.            │
│                                                                        │
│ 2. Symmetric (Data Transfer Phase):                                    │
│    Both sides use shared secret key for ultra-fast AES encryption.     │
└────────────────────────────────────────────────────────────────────────┘
```

1. **Asymmetric Encryption (Public/Private Keys)**:
   - **Public Key** (`fullchain.pem`): Shared openly with the world. Anyone can use it to *encrypt* a message.
   - **Private Key** (`privkey.pem`): Secret key kept locked inside the `/opt/excalidraw/certbot/conf/` server folder. Only this key can *decrypt* messages encrypted by the public key.
2. **Symmetric Encryption (Session Key)**:
   - Asymmetric math is slow. During the TLS handshake, the browser and server use asymmetric keys to negotiate a shared temporary **Symmetric Session Key** (AES-GCM), which encrypts subsequent web traffic at lightning speed.

---

### 10.3 How Let's Encrypt ACME HTTP-01 Validation Works

Historically, SSL certificates cost $200/year and took days of manual paperwork. **Let's Encrypt** is a free, automated Certificate Authority (CA).

Our script `deploy/certbot-init.sh` automates the **ACME HTTP-01 Challenge**:

```
[Certbot Client] ──1. Request Cert for draw.yourdomain.com ──► [Let's Encrypt CA]
                                                                      │
[Certbot Client] ◄──2. Here is Token 'XYZ123' ────────────────────────┘
       │
       ▼
 3. Writes Token to: /var/www/certbot/.well-known/acme-challenge/XYZ123
       │
       ▼
[Let's Encrypt CA] ──4. HTTP GET http://draw.yourdomain.com/.well-known/.../XYZ123
       │
       ▼  5. Validates token matches! Proves you control the server at that IP.
[Let's Encrypt CA] ──6. Issues Signed TLS Certificate (fullchain.pem + privkey.pem)
```

---

## 🔒 Chapter 4 Mini-Quiz

1. **What happens when Nginx receives an incoming request at path `/socket.io/`?**
   - A) It serves static HTML from disk
   - B) It evaluates ACME challenge tokens
   - C) It upgrades the HTTP connection to a full-duplex WebSocket pipe and proxies traffic to `http://excalidraw-room:3002`
   - D) It redirects the browser to Port 80

2. **Why MUST the SSL Private Key (`privkey.pem`) be kept strictly secret on the EC2 server?**
   - A) Because anyone with the private key can decrypt all captured HTTPS traffic and impersonate your domain server
   - B) Because AWS charges $100 if the key is leaked
   - C) Because Certbot deletes itself if the key is read
   - D) Because private keys expire after 5 minutes

3. **In the Let's Encrypt ACME HTTP-01 challenge, how does the Certificate Authority verify domain ownership?**
   - A) By calling the domain owner on the phone
   - B) By sending an HTTP GET request to `http://<domain>/.well-known/acme-challenge/<token>` and checking if the server returns the expected token
   - C) By logging into your AWS EC2 console
   - D) By checking your credit card details

*(Answers: 1-C, 2-A, 3-B)*

---

Next Step: Proceed to **[05-deployment-and-mistakes.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/05-deployment-and-mistakes.md)** for the complete deployment walkthrough and troubleshooting guide!
