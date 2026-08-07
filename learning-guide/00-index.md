# Excalidraw-on-AWS: Complete Cloud Engineering Curriculum

Welcome to the comprehensive, university-level Cloud Engineering Learning Guide based on the actual deployment of **Excalidraw** on **Amazon Web Services (AWS)** using EC2, Ubuntu 24.04 LTS, Docker, Nginx reverse proxying, Let's Encrypt TLS certificates, and AWS ECR.

---

## 🎯 Curriculum Goal

This guide is written for a first-year Computer Science student with basic programming knowledge and **zero** prior experience in Linux system administration, AWS cloud infrastructure, networking, Docker containerization, or SSL/TLS security.

After completing this curriculum, you will be able to explain **every component**, **command**, **configuration**, and **troubleshooting step** of a production web application deployment to anyone—without needing AI assistance.

---

## 📚 Curriculum Navigation

| Module File | Chapter / Scope | Core Topics Covered |
| :--- | :--- | :--- |
| **[00-index.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/00-index.md)** | **Course Overview** | Table of Contents, Prerequisites, How to Use This Curriculum |
| **[01-big-picture-and-aws.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/01-big-picture-and-aws.md)** | **Parts 1 & 2** | The Big Picture of Cloud Engineering, History of Web Hosting, What is AWS, Cloud vs On-Premises |
| **[02-servers-ec2-linux.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/02-servers-ec2-linux.md)** | **Parts 3, 4 & 5** | Physical vs Cloud Servers, AWS EC2 (`t2.micro`), Ubuntu 24.04 LTS, Terminal, SSH, File Permissions & Linux Commands |
| **[03-git-docker.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/03-git-docker.md)** | **Parts 6 & 7** | Git & GitHub Version Control, Docker Engine, Containers vs VMs, Docker Compose, Networks, Volumes & Health Checks |
| **[04-nginx-dns-ssl.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/04-nginx-dns-ssl.md)** | **Parts 8, 9 & 10** | Nginx Reverse Proxy, WebSockets, Domain Names, DNS A-records, HTTPS, TLS & Let's Encrypt Certbot |
| **[05-deployment-and-mistakes.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/05-deployment-and-mistakes.md)** | **Parts 11 & 12** | Chronological Deployment Walkthrough (`setup.sh`, `certbot-init.sh`, `deploy.sh`) & Root-Cause Troubleshooting Guide |
| **[06-mental-models-and-diagrams.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/06-mental-models-and-diagrams.md)** | **Parts 13 & 14** | Extended Real-World Analogy (The Apartment Building) & Mermaid Architectural / Request Flow Diagrams |
| **[07-roadmap-and-vocabulary.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/07-roadmap-and-vocabulary.md)** | **Parts 15 & 16** | Zero-to-Hero Cloud Engineering Career Roadmap & 120+ Deployment Vocabulary Dictionary |
| **[08-interview-prep.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/08-interview-prep.md)** | **Part 17** | 60 Deep Technical Interview Questions & Answers (25 Beginner, 25 Intermediate, 10 Scenario-Based) |
| **[09-industry-and-reflection.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/09-industry-and-reflection.md)** | **Parts 18, 19 & 20** | Industry Architectures (Netflix, Uber, GitHub), Personal Self-Reflection, & Transformation Story |

---

## 🛠️ The Deployment Architecture at a Glance

The curriculum explains this exact production architecture built during our deployment:

```
Internet Users (HTTPS:443 / HTTP:80)
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│ AWS EC2 Instance (t2.micro — Ubuntu 24.04 LTS)          │
│ Public Elastic IP: static A-record                      │
│ Firewall (UFW): Ports 22 (SSH), 80 (HTTP), 443 (HTTPS)   │
│                                                         │
│ ┌─────────────────────────────────────────────────────┐ │
│ │ Docker Engine & Docker Compose                      │ │
│ │                                                     │ │
│ │  ┌─────────────────┐       ┌─────────────────────┐  │ │
│ │  │  nginx-proxy    │ ────► │  excalidraw-app     │  │ │
│ │  │  (:80, :443)    │       │  (ECR SPA container)│  │ │
│ │  └────────┬────────┘       └─────────────────────┘  │ │
│ │           │                                         │ │
│ │           └──────────────► ┌─────────────────────┐  │ │
│ │                            │ excalidraw-room     │  │ │
│ │                            │ (WebSocket relay)   │  │ │
│ │                            └─────────────────────┘  │ │
│ │  ┌─────────────────┐                                │ │
│ │  │ certbot renew   │ (Auto-renews certs every 12h)  │ │
│ │  └─────────────────┘                                │ │
│ └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

---

## 💡 Key Pedagogical Principles

1. **Why Before How**: We never teach a tool or command until you understand the exact problem it exists to solve.
2. **Zero Assumptions**: Every jargon term is defined immediately upon first use.
3. **Empirical Grounding**: Every command, file path, error message, and fix matches the real deployment scripts (`deploy/setup.sh`, `deploy/certbot-init.sh`, `deploy/deploy.sh`, `deploy/docker-compose.ec2.yml`, `deploy/nginx-proxy.conf`).
4. **Active Recall**: Every module ends with a mini-quiz and practical exercises to lock in your understanding.

Let's begin! Head over to **[01-big-picture-and-aws.md](file:///v:/projects/excalidraw/excalidraw/learning-guide/01-big-picture-and-aws.md)** to start Part 1.
