<div align="center">
  <img src="assets/Hytale-Logo-Illustrated.png" alt="Hytale Server">
  
  # Hytale Server
  
  ⚡ **Production-ready Hytale dedicated server with Native Java (recommended) or Docker support**
  
  <p>Automated authentication, auto-updates, and secure by default. Native for best performance, Docker for isolation.</p>

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://github.com/sivert-io/hytale-docker/blob/main/LICENSE)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED?logo=docker&logoColor=white)](compose/docker-compose.yml)
[![Java](https://img.shields.io/badge/Java-25-ED8B00?logo=openjdk&logoColor=white)](https://adoptium.net)

**📚 <a href="#-quick-start" target="_blank">Quick Start</a>** • <a href="./docs/PERFORMANCE.md" target="_blank">Performance</a> • <a href="./docs/TROUBLESHOOTING.md" target="_blank">Troubleshooting</a> • <a href="https://github.com/sivert-io/hytale-docker/issues" target="_blank">💬 Issues & Support</a>

</div>

---

## ✨ Features

⚡ **Native Java (Recommended)** — Best performance with lower CPU and memory usage  
🐳 **Docker Support** — Containerized option with isolation and deployment automation  
🚀 **One-Command Startup** — Just `./tools/run-native.sh` or `./tools/compose-up.sh`  
🔐 **OAuth2 Authentication** — Single device code flow for both downloader and server  
🔄 **Auto-Refresh Tokens** — Background daemon keeps tokens valid (30-day refresh tokens)  
📦 **Auto-Updates** — Downloads and updates server files automatically on every start  
⚡ **Fast Boot** — AOT cache support for quicker server startup  
💾 **Persistent Data** — Worlds, tokens, and logs survive restarts  
📊 **Performance Optimized** — Follows official Hytale server recommendations (16GB RAM, 4 CPU cores)  
🔧 **Easy Java Setup** — Automatically installs Java 25 if missing (via Eclipse Temurin)

---

## ⚙️ Requirements

- **Java 25+** (auto-installed by `run-native.sh` if missing) OR **Docker + Docker Compose** for Docker option
- **Hytale account** for server authentication
- **16GB RAM** recommended (8GB minimum)
- **4 CPU cores** recommended (2 cores minimum)
- **UDP port 5520** open and forwarded on your firewall/router

> **Recommendation:** Use Native Java for better performance (~6% less CPU, ~3% less memory). Docker is available as an alternative if you prefer containerization.

---

## 🚀 Quick Start

Two ways to run your Hytale server: **Native (Recommended)** or **Docker**. Native is faster, uses fewer resources, and has better performance. Docker is useful for isolation and deployment automation.

### ⚡ Option 1: Native Java (Recommended - Best Performance)

**Why Native?** Better performance (~25% less CPU, ~3% less memory), faster startup, no Docker overhead. This is the recommended option for most users.

```bash
# Clone the repository
git clone https://github.com/sivert-io/hytale-docker.git
cd hytale-docker

# Start the server natively (automatically installs Java 25 if needed)
./tools/run-native.sh

# The server will start and prompt for authentication on first run
```

On first run, you'll see a device authorization prompt. Visit the URL, enter the code, and authorize. The server starts automatically.

Connect to your server at `your-ip:5520` using the Hytale client.

### 🐳 Option 2: Docker (Alternative - Better Isolation)

Use Docker if you prefer containerization, want better isolation, or need Docker-specific deployment features.

```bash
# Clone the repository
git clone https://github.com/sivert-io/hytale-docker.git
cd hytale-docker

# Start the server with Docker
./tools/compose-up.sh

# Watch for authentication prompt
cd compose
docker compose logs -f
```

> **Note:** Hytale uses **QUIC over UDP** (not TCP). Forward UDP port 5520 on your firewall.

### 📊 Performance Comparison

Based on real-world benchmarks:
- **Native**: ~18% CPU, ~11,150MB memory (8.8% of system) - **Recommended**
- **Docker**: ~25% CPU, ~11,500MB memory (9.1% of system) - More overhead

Native is **more efficient** with lower resource usage and better performance.

---

**Requirements:**
- **Java 25+** (auto-installed by script if missing) - Eclipse Temurin via Adoptium
- **Server files** in the `data/` directory (you can get these by running the Docker setup once, or manually)

### Usage

```bash
# Run natively from project root
./tools/run-native.sh

# With custom memory settings
JAVA_OPTS="-Xms8G -Xmx16G" ./tools/run-native.sh

# With custom port
SERVER_PORT="5520" ./tools/run-native.sh
```

**Features:**
- ✅ **Auto-installs Java 25** if needed (Eclipse Temurin via Adoptium)
- ✅ **Verifies server files** exist in `data/`
- ✅ **Same configuration** as Docker version (JAVA_OPTS, AOT cache, etc.)
- ✅ **Shared data directory** - worlds and settings work with both methods

**Note:** You can switch between Native and Docker - they share the same `data/` directory, so your worlds and settings persist.

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

### Native Java

Press `Ctrl+C` in the terminal, or if running in background:

```bash
pkill -f "HytaleServer.jar"
```

### Docker

**Important:** Always use the graceful shutdown script to ensure the server saves properly:

```bash
# Use the helper script from project root
./tools/compose-down.sh
```

This sends `/stop` to the server first, then brings down containers. Using `docker compose down` directly may not give the server time to save recent changes.

---

## 🔄 Restarting the Server

### Native Java

Just run the script again - it will start fresh:

```bash
./tools/run-native.sh
```

### Docker

Use the helper scripts:

```bash
# Start the server (from project root)
./tools/compose-up.sh              # Normal start (builds if needed)
./tools/compose-up.sh --recreate   # Force recreate (picks up new env vars)
./tools/compose-up.sh --rebuild    # Force rebuild image (no cache)
./tools/compose-up.sh --no-build   # Skip building (use existing image)

# Restart the server (stop then start)
./tools/compose-restart.sh         # Normal restart
./tools/compose-restart.sh --rebuild  # Restart with rebuild option
```

**When to use each option:**
- **Normal start**: Builds the image from the local Dockerfile if needed, then starts the container
- **`--recreate`**: You changed environment variables in `docker-compose.yml` and need them applied
- **`--rebuild`**: You modified the Dockerfile or scripts and want to rebuild the image from scratch
- **`--no-build`**: Skip building and use an existing image (faster if image is already built)

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
