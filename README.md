<div align="center">

<img src="docs/public/logo.png" alt="Hytale Docker" width="128" />

# Hytale Docker Server

**Production-ready Docker container for Hytale dedicated servers**

[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](https://hub.docker.com/r/rxmarin/hytale-docker)
[![Java](https://img.shields.io/badge/Java-25-ED8B00?logo=openjdk&logoColor=white)](https://adoptium.net)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Docs](https://img.shields.io/badge/Docs-hytale.romarin.dev-blue)](https://hytale.romarin.dev)

*Automated authentication • Auto-updates • Secure by default*

</div>

---

## ✨ Features

- 🚀 **One-command startup** — Just `docker compose up`, authenticate once, play forever
- 🔐 **OAuth2 Authentication** — Single device code flow for both downloader and server
- 🔄 **Auto-refresh tokens** — Background daemon keeps tokens valid (30-day refresh tokens)
- 📦 **Auto-updates** — Downloads and updates server files automatically
- 🔒 **Secure by default** — Non-root user, dropped capabilities, hardened container
- ⚡ **Fast boot** — AOT cache support for quicker server startup
- 💾 **Persistent data** — Worlds, tokens, and logs survive container restarts

---

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/sivert-io/hytale-docker.git
cd hytale-docker

# Start the server (uses bind mount by default)
docker compose up -d

# Watch for authentication prompt
docker compose logs -f
```

### Volume Options

This repository provides two docker-compose configurations:

- **`docker-compose.yml`** (Default) - Uses a bind mount to `~/docker/hytale-docker/data/`
  - Direct file access on the host (similar to enshrouded setup)
  - Data is easily accessible and manageable
  - Recommended for most users

- **`docker-compose.volume.yml`** - Uses a named Docker volume (`hytale-data`)
  - Use this if you prefer Docker-managed volumes
  - Docker automatically initializes the volume with scripts from the image
  - Data is stored in Docker's volume location (`/var/lib/docker/volumes/`)
  - To use: `docker compose -f docker-compose.volume.yml up -d`

On first run, you'll see a device authorization prompt. Visit the URL, enter the code, and authorize. The server starts automatically.

Connect to your server at `your-ip:5520` using the Hytale client.

> **Note:** Hytale uses **QUIC over UDP** (not TCP). Forward UDP port 5520 on your firewall.

---

## 📖 Documentation

📚 **[hytale.romarin.dev](https://hytale.romarin.dev)** — Full documentation

Topics covered:
- [Quick Start Guide](https://hytale.romarin.dev/docs/quick-start)
- [Configuration](https://hytale.romarin.dev/docs/configuration)
- [Authentication](https://hytale.romarin.dev/docs/authentication)
- [Network Setup](https://hytale.romarin.dev/docs/network-setup)
- [Security](https://hytale.romarin.dev/docs/security)
- [Troubleshooting](https://hytale.romarin.dev/docs/troubleshooting)

---

## 🏗️ Development

```bash
# Build the image locally
docker build -t hytale-server:latest .

# Run the documentation site
cd docs
npm install
npm run dev
```

---

## 📚 References

- [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)
- [Server Provider Authentication Guide](https://support.hytale.com/hc/en-us/articles/45328341414043-Server-Provider-Authentication-Guide)

---

<div align="center">

**Forked from [romarin.dev](https://romarin.dev)** • **Maintained by [sivert-io](https://github.com/sivert-io)**

[Original Documentation](https://hytale.romarin.dev) •
[Report Bug](https://github.com/sivert-io/hytale-docker/issues) •
[Request Feature](https://github.com/sivert-io/hytale-docker/issues)

</div>