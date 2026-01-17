# Hytale Server Performance & Official Recommendations

This document outlines how this Docker setup follows [Hytale's official server recommendations](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual).

## ✅ Current Configuration (Following Official Guidelines)

### Hardware & Resources

| Component | Official Recommendation | Our Setup | Status |
|-----------|------------------------|-----------|--------|
| **RAM** | 8-12GB (10-30 players)<br>16GB+ (larger servers) | 16GB (8GB initial, 16GB max heap) | ✅ Meets recommendation |
| **CPU** | 4+ cores with strong single-thread performance | 4 CPUs max, 2 reserved | ✅ Meets recommendation |
| **Storage** | NVMe SSD preferred | Bind mount (depends on host) | ⚠️ Use NVMe if available |
| **Network** | UDP 5520, stable connection | UDP 5520 configured | ✅ Correct |

### Java Configuration

- ✅ **Java 25** (Temurin/Adoptium) - Official requirement
- ✅ **G1GC** (`-XX:+UseG1GC`) - Recommended garbage collector
- ✅ **AOT Cache** (`USE_AOT_CACHE=true`) - Reduces startup time
- ✅ **Heap settings** (`-Xms8G -Xmx16G`) - Appropriate for server size

### Performance Optimizations

- ✅ **Non-root user** - Security best practice
- ✅ **Health checks** - Monitoring server status
- ✅ **Resource limits** - Prevents resource exhaustion

## 📊 Performance Monitoring

Use the included monitoring script:
```bash
./monitor.sh
# Or watch continuously:
watch -n 2 ./monitor.sh
```

## 🔧 Additional Optimization Tips

Based on official recommendations:

### 1. Reduce View Distance (if experiencing lag)
Edit `config.json` in your server data directory:
```json
{
  "viewRadius": 10  // Default is often higher, reduce for better performance
}
```

### 2. Limit Active Entities
If you have many NPCs/entities, consider reducing spawn rates.

### 3. Pre-generate World (for large servers)
Explore areas before players join to reduce generation lag.

### 4. Storage Performance
For best performance, ensure host storage is:
- **NVMe SSD** (recommended)
- **Regular SSD** (acceptable)
- Avoid HDD for server storage

### 5. Network Considerations
- Ensure stable upload bandwidth for multiple players
- UDP port 5520 must be open and forwarded
- Consider DDoS protection for public servers

## 📚 Official Documentation

- [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)
- [Server Provider Authentication Guide](https://support.hytale.com/hc/en-us/articles/45328341414043-Server-Provider-Authentication-Guide)

## 🐛 Troubleshooting Lag Issues

If experiencing lag, check:

1. **CPU Usage** - Should stay under 80% under load
   ```bash
   docker stats hytale-server
   ```

2. **Memory Usage** - Should have headroom (not near 16GB limit)
   ```bash
   docker stats hytale-server
   ```

3. **Disk I/O** - High write operations can cause lag
   - Use NVMe storage if possible
   - Monitor with `iotop` or `iostat`

4. **Network** - Check bandwidth and latency
   - Ensure stable connection
   - Monitor network I/O in stats

5. **GC Pauses** - If memory is tight, Java GC can cause stuttering
   - Using G1GC as recommended by Hytale
   - Monitor with `-XX:+PrintGCDetails` if needed (add to JAVA_OPTS)

## 💡 Configuration Examples

### For 10-30 Players (Recommended Setup)
Current configuration is optimal for this player count.

### For Larger Servers (50+ Players)
Consider:
- Increasing CPU limit to 6-8 cores
- Increasing memory to 20-24GB
- Using dedicated NVMe storage
- Reducing view distance in config

### For Development/Testing
You can reduce resources:
- Memory: 4-8GB
- CPU: 2 cores
- Lower view distance
