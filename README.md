<div align="center">
  <img src="assets/Hytale-Logo-Illustrated.png" alt="Hytale Docker">
  
  # Hytale Docker Server
  
  ⚡ **Production-ready Docker container for Hytale dedicated servers**
  
  <p>Automated authentication, auto-updates, and secure by default. One command from setup to gameplay.</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/sivert-io/hytale-docker/blob/main/LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](compose/docker-compose.yml)
[![Java](https://img.shields.io/badge/Java-25-ED8B00?logo=openjdk&logoColor=white)](https://adoptium.net)

**📚 <a href="#-quick-start" target="_blank">Quick Start</a>** • <a href="./docs/PERFORMANCE.md" target="_blank">Performance</a> • <a href="./docs/TROUBLESHOOTING.md" target="_blank">Troubleshooting</a> • <a href="https://github.com/sivert-io/hytale-docker/issues" target="_blank">💬 Issues & Support</a>

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
🛠️ **Script Auto-Sync** — Scripts automatically update from image on container start

---

## ⚙️ Requirements

- **Docker** and **Docker Compose** ([Install Docker](https://docs.docker.com/engine/install/))
- **Hytale account** for server authentication
- **16GB RAM** recommended (8GB minimum)
- **4 CPU cores** recommended (2 cores minimum)
- **UDP port 5520** open and forwarded on your firewall/router

---

## 🚀 Quick Start

Get up and running in minutes:

```bash
# Clone the repository
git clone https://github.com/sivert-io/hytale-docker.git
cd hytale-docker/compose

# Start the server
docker compose up -d

# Watch for authentication prompt
docker compose logs -f
```

On first run, you'll see a device authorization prompt. Visit the URL, enter the code, and authorize. The server starts automatically.

Connect to your server at `your-ip:5520` using the Hytale client.

> **Note:** Hytale uses **QUIC over UDP** (not TCP). Forward UDP port 5520 on your firewall.

---

## 📦 Volume Options

This repository provides two docker-compose configurations:

- **`compose/docker-compose.yml`** (Default) - Uses a bind mount to `~/docker/hytale-docker/data/`
  - Direct file access on the host
  - Data is easily accessible and manageable
  - Recommended for most users

- **`compose/docker-compose.volume.yml`** - Uses a named Docker volume (`hytale-data`)
  - Use this if you prefer Docker-managed volumes
  - Docker automatically initializes the volume with scripts from the image
  - To use: `cd compose && docker compose -f docker-compose.volume.yml up -d`

---

## 🛑 Stopping the Server

**Important:** Always use the graceful shutdown script to ensure the server saves properly:

```bash
# From compose directory
cd compose
./docker-compose-down.sh

# Or from project root
./compose/docker-compose-down.sh
```

This sends `/stop` to the server first, then brings down containers. Using `docker compose down` directly may not give the server time to save recent changes.

---

## 📖 Documentation

### Project Documentation

📊 **[docs/PERFORMANCE.md](./docs/PERFORMANCE.md)** — Performance guide following [Hytale's official recommendations](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)

🔧 **[docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)** — Common errors and warnings explained

### Official Hytale Documentation

- **[Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)** — Official server setup guide
- **[Server Provider Authentication Guide](https://support.hytale.com/hc/en-us/articles/45328341414043-Server-Provider-Authentication-Guide)** — Authentication setup

---

## 🤝 Contributing

Contributions are welcome! Whether you're fixing bugs, adding features, improving docs, or sharing ideas.

Feel free to open an [issue](https://github.com/sivert-io/hytale-docker/issues) or submit a pull request.

---

## 📜 License

MIT License - see [LICENSE](LICENSE) for details

---

<div align="center">
  <strong>Made with ❤️ for the Hytale community</strong>
</div>
