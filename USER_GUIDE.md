# MLX Code - User Guide

**Version:** 1.0.11
**Platform:** macOS 13.0+
**Date:** November 18, 2025

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Interface Overview](#interface-overview)
3. [Working with Models](#working-with-models)
4. [Chat Interface](#chat-interface)
5. [Templates](#templates)
6. [File Operations](#file-operations)
7. [Git Integration](#git-integration)
8. [Xcode Integration](#xcode-integration)
9. [Settings](#settings)
10. [Keyboard Shortcuts](#keyboard-shortcuts)
11. [Tips & Tricks](#tips--tricks)
12. [Troubleshooting](#troubleshooting)

---

## Getting Started

### System Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon (M1/M2/M3) or Intel Mac
- 8GB RAM minimum (16GB recommended)
- 10GB free disk space for models

### First Launch

1. **Launch MLX Code**
   - Open MLX Code from Applications

2. **Download a Model**
   - Click the model selector in the toolbar
   - Choose "Download Model"
   - Select a model (e.g., "Llama 3.2 3B")
   - Wait for download to complete

3. **Start Chatting**
   - Type your first message
   - Press ⌘↩ or click Send
   - Wait for the model's response

---

## Interface Overview

### Main Window

```
┌────────────────────────────────────────────────────────────┐
│  MLX Code                                  [Model Selector] │
├─────────────────┬──────────────────────────────────────────┤
│                 │  Chat View                               │
│  Conversations  │  ┌────────────────────────────────────┐  │
│                 │  │ User: Hello                        │  │
│  [+] New       │  │ Assistant: Hi! How can I help?     │  │
│                 │  └────────────────────────────────────┘  │
│  ▸ Conversation │                                          │
│  ▸ Python Help  │  ┌────────────────────────────────────┐  │
│  ▸ Code Review  │  │ Type a message...          [Send]  │  │
│                 │  └────────────────────────────────────┘  │
├─────────────────┴──────────────────────────────────────────┤
│  Status: Model loaded: Llama 3.2 3B                        │
└────────────────────────────────────────────────────────────┘
```

### Toolbar

- **Model Selector:** Choose and manage models
- **New Conversation:** Start a fresh chat (⌘N)
- **Templates:** Quick access to prompt templates
- **Settings:** Application preferences (⌘,)

### Sidebar

- **Conversations List:** All your saved conversations
- **Search:** Filter conversations
- **New Button:** Create new conversation
- **Context Menu:** Right-click for options

---

## Working with Models

### Downloading Models

1. **From Model Selector:**
   ```
   Click Model Selector → Select undownloaded model → Download
   ```

2. **From Settings:**
   ```
   Settings (⌘,) → Models → Click Download next to model
   ```

3. **Progress Tracking:**
   - Download progress shown in real-time
   - Model automatically loads after download

### Available Models

#### Llama 3.2 3B
- **Size:** ~3.2 GB
- **Best for:** General conversation, code assistance
- **Speed:** Fast
- **Quality:** Good

#### Qwen 2.5 7B
- **Size:** ~7.5 GB
- **Best for:** Multilingual tasks, reasoning
- **Speed:** Medium
- **Quality:** Excellent

#### Mistral 7B
- **Size:** ~7.2 GB
- **Best for:** Code generation, technical writing
- **Speed:** Medium
- **Quality:** Excellent

#### Phi-3.5 Mini
- **Size:** ~3.8 GB
- **Best for:** Quick responses, simple tasks
- **Speed:** Very Fast
- **Quality:** Good

### Model Management

**Loading a Model:**
```
Model Selector → Choose model → Automatically loads
```

**Unloading a Model:**
```
Model Selector → Select "No Model Selected"
```

**Deleting a Model:**
```
Settings → Models → Click Delete button → Confirm
```

**Custom Model Paths:**
```
Settings → Paths → Models Path → Set custom directory
```

---

## Chat Interface

### Sending Messages

**Method 1: Keyboard**
1. Type your message
2. Press ⌘↩ (Command + Return)

**Method 2: Mouse**
1. Type your message
2. Click "Send" button

**Method 3: Return Key**
- Single Return: New line
- ⌘↩: Send message

### Message Types

**Regular Questions:**
```
What is Swift?
Explain async/await in Swift
```

**Code Requests:**
```
Write a function to sort an array
Show me how to use Combine
```

**File Operations:**
```
Read the file at ~/Documents/notes.txt
Write "Hello" to ~/output.txt
Find all .swift files in ~/Projects
```

**Git Operations:**
```
Show git status for ~/Projects/MyApp
Create a commit with message "Fix bug"
Generate a commit message
```

### Streaming Responses

- Responses stream in real-time
- See tokens as they're generated
- Stop generation anytime with Stop button

### Message Context

- All messages in conversation are sent as context
- Model remembers previous messages
- Clear conversation to reset context

---

## Templates

### Using Templates

**Access Templates:**
```
Toolbar → Templates icon → Select template
```

**Apply Template:**
1. Choose template from menu
2. Template inserts into input field
3. Fill in placeholder variables
4. Send message

### Default Templates

#### Code Review
```
Please review this code for:
- Logic errors
- Performance issues
- Security vulnerabilities
- Best practices

[Your code here]
```

#### Explain Code
```
Explain what this code does:

[Your code here]

Include:
- High-level overview
- Line-by-line explanation
- Potential improvements
```

#### Git Commit
```
Analyze these changes and generate a commit message:

[Paste git diff here]

Follow conventional commits format.
```

#### Debug Help
```
I'm getting this error:

[Error message]

In this code:

[Code snippet]

Help me debug it.
```

### Creating Custom Templates

1. **Open Templates:**
   ```
   Toolbar → Templates → Manage Templates
   ```

2. **Create New:**
   ```
   Click "+" → Enter name → Enter content → Save
   ```

3. **Variables:**
   Use `{{variable}}` for placeholders:
   ```
   Explain {{concept}} in {{language}}
   ```

4. **Export/Import:**
   ```
   Settings → Paths → Templates Path
   Templates saved as JSON files
   ```

---

## File Operations

### Reading Files

**Syntax:**
```
Read ~/Documents/file.txt
Read /path/to/file
```

**Example:**
```
User: Read ~/Projects/README.md
Assistant: [File contents displayed]
```

### Writing Files

**Syntax:**
```
Write [content] to ~/output.txt
Save this to ~/file.txt: [content]
```

**Example:**
```
User: Write "Hello, World!" to ~/test.txt
Assistant: File written successfully
```

### Finding Files

**Syntax:**
```
Find all *.swift files in ~/Projects
Glob **/*.py in ~/Code
```

**Example:**
```
User: Find all .swift files in ~/MyApp
Assistant: Found 42 files:
- ~/MyApp/Sources/Main.swift
- ~/MyApp/Sources/Views/ContentView.swift
...
```

### Searching in Files

**Syntax:**
```
Search for "TODO" in ~/Projects/*.swift
Grep "func.*Error" in ~/Code
```

**Example:**
```
User: Search for "FIXME" in ~/Project
Assistant: Found 3 matches:
- file.swift:42: // FIXME: Handle edge case
...
```

---

## Git Integration

### Git Status

**Syntax:**
```
Show git status for ~/Projects/MyApp
Git status in ~/Code/Project
```

**Response:**
```
Branch: main
Modified files:
- README.md
- Sources/Main.swift

Untracked files:
- Tests/NewTest.swift
```

### Git Diff

**Syntax:**
```
Show staged changes in ~/Project
Show unstaged changes
```

### Git Commit

**Manual Commit:**
```
Create commit in ~/Project with message "Add feature"
```

**AI-Generated Message:**
```
Generate commit message for ~/Project
```

**Example Generated Message:**
```
feat: Add user authentication

- Implement login/logout functionality
- Add JWT token handling
- Create user session management

🤖 Generated with MLX Code
```

### Git Log

**Syntax:**
```
Show git log for ~/Project
Show last 5 commits
```

**Response:**
```
abc1234: feat: Add dark mode
def5678: fix: Resolve memory leak
ghi9012: docs: Update README
```

### Creating Branches

**Syntax:**
```
Create branch feature/new-ui in ~/Project
Create and checkout branch fix/bug-123
```

---

## Xcode Integration

### Build Error Parsing

**Copy Xcode Build Log:**
1. Build fails in Xcode
2. Select all build output
3. Copy (⌘C)
4. Paste into MLX Code

**Automatic Parsing:**
```
User: [Paste build log]
Assistant: Found 3 errors:

1. ViewController.swift:42
   - Error: Cannot convert String to Int
   - Fix: Use Int(string) or string conversion

2. ...
```

### Project Analysis

**Syntax:**
```
Analyze Xcode project at ~/Projects/MyApp
Review build settings
```

### Code Suggestions

**Context-Aware:**
```
User: I'm working on ~/Projects/MyApp/ViewController.swift
      How do I add a table view?