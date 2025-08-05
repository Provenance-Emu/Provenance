# RetroAchievements CLI Tool Demo

The `ra-cli` tool provides a comprehensive command-line interface for testing and exploring the RetroAchievements API. Here's how to use it effectively:

## 🚀 Quick Start

### 1. Get Your Credentials

First, you'll need:
- Your RetroAchievements username
- Your web API key (found in your profile settings on retroachievements.org)

### 2. Basic Setup

```bash
# Build the CLI tool
swift build

# Test the help system
swift run ra-cli --help
```

## 📋 Usage Examples

### Basic Profile Information

```bash
# View your profile (default command)
swift run ra-cli -u your_username -k your_api_key

# Or explicitly specify the profile command
swift run ra-cli -u your_username -k your_api_key -c profile
```

**Example Output:**
```
🔐 Validating credentials...
✅ Credentials validated successfully!

👤 USER PROFILE
═══════════════
🎮 Username: MaxMilyin
📅 Member Since: 2020-01-15 10:30:00
🏆 Total Points: 125,847
🎯 Softcore Points: 45,230
💎 True Points: 138,592
🎮 Currently: Playing Super Mario Bros. (NES)
💭 Motto: "Gotta catch 'em all... achievements!"
👨‍💻 Contributions: 234
🔧 Permissions Level: 1
```

### User Awards and Achievements

```bash
# View detailed awards information
swift run ra-cli -u your_username -k your_api_key -c awards
```

**Example Output:**
```
🏅 USER AWARDS
══════════════
🏆 Total Awards: 87
👑 Mastery Awards: 12
🎯 Completion Awards: 23
💪 Hardcore Beat Awards: 8
😌 Softcore Beat Awards: 15
🎪 Event Awards: 2
🌟 Site Awards: 27

📋 Recent Awards:
   1. Super Mario Bros. Mastery (Game Mastery) - 2023-12-15 14:22:00
   2. Speed Demon (Site Award) - 2023-12-10 09:15:00
   3. Zelda Completion (Game Completion) - 2023-12-08 20:45:00
   ...
```

### Social Connections

```bash
# View social connections (following/followers)
swift run ra-cli -u your_username -k your_api_key -c social
```

**Example Output:**
```
👥 SOCIAL CONNECTIONS
════════════════════
📤 Following 15 users:
   1. RetroGamer123 - 95,230 points
   2. AchievementHunter - 145,670 points
   3. SpeedRunner99 - 87,421 points
   ...

📥 23 followers:
   1. GameCollector - 52,340 points
   2. CasualPlayer - 23,120 points
   3. RetroFan - 78,945 points
   ...
```

### Interactive Game Exploration

```bash
# Interactive game lookup
swift run ra-cli -u your_username -k your_api_key -c game
```

**Example Session:**
```
🎮 GAME INFORMATION
══════════════════
Enter a game ID to explore (e.g., 1 for Super Mario Bros.): 1

🎮 Game: Super Mario Bros.
🕹 Console: NES (ID: 7)
👨‍💻 Developer: Nintendo
🏢 Publisher: Nintendo
🎭 Genre: Platform
📅 Released: 1985
🏆 Total Achievements: 30
👥 Casual Players: 15,234
💪 Hardcore Players: 8,567

🏆 Sample Achievements:
   • World 1-1 (5 pts) - Complete World 1-1
   • First Life (10 pts) - Get your first 1up
   • Coin Collector (5 pts) - Collect 100 coins
   • Fire Flower (10 pts) - Get the Fire Flower power-up
   • World 1 Complete (25 pts) - Complete all of World 1
   ... and 25 more achievements
```

### Interactive Achievement Exploration

```bash
# Interactive achievement lookup
swift run ra-cli -u your_username -k your_api_key -c achievement
```

**Example Session:**
```
🏆 ACHIEVEMENT INFORMATION
═════════════════════════
Enter an achievement ID to explore: 12345

🏆 Achievement: Speed Demon
📝 Description: Complete World 1-1 in under 400 seconds
💎 Points: 25
🏅 True Ratio: 50
👨‍💻 Author: RetroAchievementDev
📅 Created: 2019-03-15 12:00:00
🔄 Modified: 2023-01-10 15:30:00
👥 Total Unlocks: 1,247
💪 Hardcore Unlocks: 892

📋 Recent Unlocks:
   1. SpeedRunner123 💪 - 2023-12-20 14:30:00
   2. QuickGamer 😌 - 2023-12-20 13:45:00
   3. FastPlayer 💪 - 2023-12-20 12:15:00
   ...

🎮 From Game: Super Mario Bros. (ID: 1)
🕹 Console: NES
```

### Complete Data Overview

```bash
# Get everything at once
swift run ra-cli -u your_username -k your_api_key -c all
```

This command shows:
- Complete user profile
- Awards summary
- Social connections
- Suggestions for interactive exploration

## 🔧 Environment Variables

For convenience, set up environment variables:

```bash
# Set up your credentials
export RA_USERNAME=your_username
export RA_API_KEY=your_api_key

# Now you can use shorter commands
swift run ra-cli -c profile
swift run ra-cli -c awards
swift run ra-cli -c social
swift run ra-cli -c all
```

## 📊 Available Commands

| Command | Alias | Description |
|---------|-------|-------------|
| `profile` | `p` | Show user profile information |
| `awards` | `a` | Show user awards and achievements |
| `social` | `s` | Show social connections |
| `game` | `g` | Interactive game exploration |
| `achievement` | `ach` | Interactive achievement exploration |
| `all` | - | Show profile, awards, and social info |

## 🛠 Development & Testing

### For Library Development

The CLI tool is perfect for:
- **Testing API changes** during development
- **Validating credentials** before integration
- **Exploring API responses** to understand data structure
- **Debugging authentication** issues
- **Performance testing** with real API calls

### For Integration Planning

Use the CLI to:
- **Understand data formats** before implementing in your app
- **Test edge cases** with real RetroAchievements data
- **Validate user stories** with actual user data
- **Plan UI layouts** based on real content lengths
- **Test error handling** with invalid inputs

## 🔍 Troubleshooting

### Common Issues

**Invalid Credentials:**
```
❌ Invalid credentials! Please check your username and API key.
```
- Double-check your username and API key
- Ensure you're using the web API key, not your password

**Network Errors:**
```
🌐 Network error: The Internet connection appears to be offline.
```
- Check your internet connection
- Verify RetroAchievements.org is accessible

**Rate Limiting:**
```
⏱ Rate limit exceeded - please wait before making more requests
```
- Wait a few moments before trying again
- The API has rate limits to prevent abuse

### Getting Help

```bash
# Always available help
swift run ra-cli --help

# Or just
swift run ra-cli -h
```

## 🎯 Integration with Provenance

The CLI tool demonstrates exactly how to integrate PVCheevos into the Provenance app:

1. **Authentication Flow** - See how credential validation works
2. **Data Structure** - Understand the response formats
3. **Error Handling** - Learn from the comprehensive error handling
4. **User Experience** - Get ideas for presenting achievement data
5. **Performance** - Test API response times with real data

This makes the CLI tool an invaluable resource for planning and implementing RetroAchievements support in Provenance! 🎮
