<div align="center">
  <img src="https://hytale.com/static/images/logo.png" alt="Hytale Docker" width="140">
  
  # Hytale Docker Server
  
  ⚡ **Production-ready Docker container for Hytale dedicated servers**
  
  <p>Automated authentication, auto-updates, and secure by default. One command from setup to gameplay.</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](docker-compose.yml)
[![Java](https://img.shields.io/badge/Java-25-ED8B00?logo=openjdk&logoColor=white)](https://adoptium.net)

**📚 <a href="https://hytale.romarin.dev" target="_blank">Full Documentation</a>** • <a href="https://hytale.romarin.dev/docs/quick-start" target="_blank">Quick Start</a> • <a href="https://hytale.romarin.dev/docs/configuration" target="_blank">Configuration</a> • <a href="./PERFORMANCE.md" target="_blank">Performance Guide</a> • <a href="https://github.com/sivert-io/hytale-docker/issues" target="_blank">💬 Issues & Support</a>

</div>

---

## ✨ Features

🚀 **One-Command Startup** — Just `docker compose up`, authenticate once, play forever  
🔐 **OAuth2 Authentication** — Single device code flow for both downloader and server  
🔄 **Auto-Refresh Tokens** — Background daemon keeps tokens valid (30-day refresh tokens)  
📦 **Auto-Updates** — Downloads and updates server files automatically on every start  
🔒 **Secure by Default** — Non-root user, dropped capabilities, hardened container  
⚡ **Fast Boot** — AOT cache support for quicker server startup  
💾 **Persistent Data** — Worlds, tokens, and logs survive container restarts  
📊 **Performance Optimized** — Follows official Hytale server recommendations (16GB RAM, 4 CPU cores)

---

## ⚙️ Requirements

- **Docker** and **Docker Compose** ([Install Docker](https://docs.docker.com/engine/install/))
- **Hytale account** for server authentication
- **16GB RAM** recommended (8GB minimum)
- **4 CPU cores** recommended (2 cores minimum)
- **UDP port 5520** open and forwarded on your firewall/router

---

## 🚀 Quick Start

Get up and running in minutes with Docker:

```bash
# Clone the repository
git clone https://github.com/sivert-io/hytale-docker.git
cd hytale-docker

# Start the server (uses bind mount by default)
docker compose up -d

# Watch for authentication prompt
docker compose logs -f
```

On first run, you'll see a device authorization prompt. Visit the URL, enter the code, and authorize. The server starts automatically.

Connect to your server at `your-ip:5520` using the Hytale client.

### Stopping the Server

**Important:** Always use the graceful shutdown script to ensure the server saves properly:

```bash
# Graceful shutdown (recommended)
./docker-compose-down.sh

# This sends /stop to the server first, then brings down containers
```

If you use `docker compose down` directly, the server may not have time to save recent changes before shutdown.

### Volume Options

This repository provides two docker-compose configurations:

- **`docker-compose.yml`** (Default) - Uses a bind mount to `~/docker/hytale-docker/data/`
  - Direct file access on the host
  - Data is easily accessible and manageable
  - Recommended for most users

- **`docker-compose.volume.yml`** - Uses a named Docker volume (`hytale-data`)
  - Use this if you prefer Docker-managed volumes
  - Docker automatically initializes the volume with scripts from the image
  - To use: `docker compose -f docker-compose.volume.yml up -d`

> **Note:** Hytale uses **QUIC over UDP** (not TCP). Forward UDP port 5520 on your firewall.

---

## 📖 Documentation

### Official Hytale Documentation

- **[Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)** — Official server setup guide
- **[Server Provider Authentication Guide](https://support.hytale.com/hc/en-us/articles/45328341414043-Server-Provider-Authentication-Guide)** — Authentication setup

### Project Documentation

📚 **[hytale.romarin.dev](https://hytale.romarin.dev)** — Full Docker documentation

Topics covered:
- [Quick Start Guide](https://hytale.romarin.dev/docs/quick-start)
- [Configuration](https://hytale.romarin.dev/docs/configuration)
- [Authentication](https://hytale.romarin.dev/docs/authentication)
- [Network Setup](https://hytale.romarin.dev/docs/network-setup)
- [Security](https://hytale.romarin.dev/docs/security)
- [Troubleshooting](https://hytale.romarin.dev/docs/troubleshooting)

📊 **[PERFORMANCE.md](./PERFORMANCE.md)** — Performance guide following [Hytale's official recommendations](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)

🔧 **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** — Common errors and warnings explained

---

## 🏗️ Development

### Building the Docker Image

```bash
# Build the image locally (single architecture)
docker build -t hytale-server:latest .

# Build and push multi-architecture image to Docker Hub
./build-and-push.sh

# Custom image name and tag
DOCKER_IMAGE="your-username/hytale-docker" DOCKER_TAG="v1.0.0" ./build-and-push.sh
```

The build script automatically:
- Builds for multiple architectures (linux/amd64, linux/arm64)
- Creates a buildx builder if needed
- Pushes to Docker Hub
- Tags both `:latest` and the specified tag

### Running the Documentation Site

```bash
cd docs
npm install
npm run dev
```

---

## 🤝 Contributing

Contributions are welcome! Whether you're fixing bugs, adding features, improving docs, or sharing ideas.

Feel free to open an [issue](https://github.com/sivert-io/hytale-docker/issues) or submit a pull request.

---

## 📜 License

MIT License - see [LICENSE](LICENSE) for details

**Credits:** <a href="https://github.com/romariin/hytale-docker" target="_blank">romariin/hytale-docker</a> (original project) • <a href="https://github.com/rxmarin/hytale-docker" target="_blank">rxmarin/hytale-docker</a> (Docker image)

---

<div align="center">
  <strong>Made with ❤️ for the Hytale community</strong>
  
  <p><em>Forked from <a href="https://romarin.dev" target="_blank">romarin.dev</a> • Maintained by <a href="https://github.com/sivert-io" target="_blank">sivert-io</a></em></p>
</div>
