# Troubleshooting Common Errors and Warnings

This document explains common errors/warnings in Hytale server logs and what can be done about them.

## ✅ Fixable Issues

### 1. jq Parse Errors (Script Issue)

**Error:**
```
jq: parse error: Invalid numeric literal at line 1, column 8
```

**Cause:** The session refresh script tries to parse non-JSON responses.

**Fix:** ✅ **Fixed** - The script now validates JSON before parsing. This should eliminate these errors.

### 2. Chunk Loading Performance (SEVERE)

**Error:**
```
[World|default] Took too long to run pre-load process hook for chunk: 56ms > TICK_STEP
```

**Cause:** Chunk loading is taking longer than the server's tick step (usually ~16-20ms), causing lag.

**Fixes Applied:**
- ✅ **Using G1GC** (`-XX:+UseG1GC`) - Recommended garbage collector from Hytale's official setup guide

**Additional Recommendations:**
- Reduce view distance in `config.json` (if available):
  ```json
  {
    "viewRadius": 10  // Lower = fewer chunks loaded = less lag
  }
  ```
- Ensure you're using NVMe SSD storage (not HDD)
- Pre-generate world areas before players explore

### 3. GC Runs During Chunk Processing

**Error:**
```
Took too long to run pre-load process hook for chunk: ... Has GC Run: true
```

**Fix:** Using G1GC as recommended by Hytale's official setup guide. GC pauses during chunk loading are normal but can cause lag if excessive.

## ⚠️ Game-Side Issues (Cannot Fix)

These are bugs/limitations in the Hytale game itself, not server configuration issues:

### 1. Missing Interactions/Animations

**Warnings:**
```
Missing replacement interactions for interaction: **Goblin_Scrapper_Swing_Right_Selector...
Missing animation 'Eat' for Model 'Lizard_Sand'
```

**Cause:** Game content issues - missing or incomplete game assets.

**Action:** None - These are game bugs that will be fixed in future Hytale updates.

### 2. NPC Overpopulation

**Warning:**
```
Removing NPC of type Boar due to overpopulation (expected: 11.321176, actual: 21)
```

**Cause:** Game mechanics - NPCs spawning faster than expected.

**Action:** None - This is normal game behavior, the server automatically corrects it.

### 3. Interaction Chain Errors

**Error:**
```
Trying to remove out of order
InteractionChain: Attempted to store sync data at X. Offset: Y, Size: Z
```

**Cause:** 
- Game logic bugs in entity interaction handling
- **Dynamic TPS changes** - If you have a mod that changes TPS (ticks per second) dynamically, this can cause the interaction queue to desynchronize, leading to out-of-order removals

**Action:** 
- If you have a mod that changes TPS dynamically, try stabilizing the TPS or making changes more gradual
- The server handles these errors gracefully by removing problematic interactions and disconnecting affected players
- Consider using a fixed TPS instead of dynamic changes during active gameplay

### 4. Processing Bench Warnings

**Warning:**
```
No FuelDropItemId defined for Furnace fuel value of 0.0 will be lost!
```

**Cause:** Game configuration - missing item definitions for certain fuel types.

**Action:** None - Cosmetic warning, doesn't affect gameplay.

### 5. BreakBlockInteraction Warnings

**Info:**
```
BreakBlockInteraction requires a Player but was used for: Ref{...}
```

**Cause:** Game logic - blocks being broken by non-player entities (NPCs, etc.).

**Action:** None - This is informational, not an error.

## 📊 Performance Monitoring

Monitor your server performance:

```bash
# Check resource usage
./monitor.sh

# Watch logs for performance issues
docker compose logs -f | grep -E "SEVERE|Took too long"
```

## 🔧 Configuration Tuning

If you're still experiencing lag after the optimizations:

1. **Reduce View Distance** (if configurable):
   - Edit `config.json` in your server data directory
   - Lower `viewRadius` to reduce chunk loading

2. **Increase CPU Allocation**:
   - Edit `docker-compose.yml`
   - Increase `cpus: '4.0'` to `cpus: '6.0'` or higher

3. **Check Storage Performance**:
   ```bash
   # Test disk I/O
   iostat -x 1 5
   # Use NVMe SSD if possible
   ```

4. **Monitor GC Activity** (if needed):
   - Add `-XX:+PrintGCDetails` to JAVA_OPTS temporarily
   - Check logs for frequent GC pauses

## 📝 Summary

- ✅ **Fixed:** jq parse errors
- ⚠️ **Game bugs:** Missing interactions, NPC overpopulation, interaction chain errors
- 💡 **Configuration:** Using G1GC as recommended by Hytale's official setup guide

The game-side warnings are normal and don't affect server stability. Chunk loading delays may occur during heavy world generation but should improve as chunks are pre-loaded.
