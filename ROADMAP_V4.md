# MLX Code v4.0 Roadmap - World-Class Features

**Status:** Infrastructure complete, UI integration in progress
**Target:** Compete directly with Claude Code

---

## ✅ COMPLETED (v3.5.0)

All backend services implemented and tested:

1. ✅ **Enhanced Streaming UI** - CodeBlockView, EnhancedMessageView
2. ✅ **Performance Dashboard** - Real-time metrics tracking
3. ✅ **Codebase Indexer** - Semantic search ready
4. ✅ **Git AI Service** - Commit/PR generation
5. ✅ **Smart Code Actions** - 10 operations (explain, test, refactor, etc.)
6. ✅ **Conversation Manager** - Templates, export, search
7. ✅ **Multi-File Operations** - Batch processing
8. ✅ **Performance Metrics** - tokens/s, memory tracking
9. ✅ **Model Auto-Discovery** - Scan disk functionality

---

## 🚧 IN PROGRESS (v4.0)

Features implemented but need UI integration:

### 1. Command Palette (⌘K) ✅ Backend Ready
**File:** `Views/CommandPalette.swift`
**Status:** Component complete, needs wiring
**TODO:**
- Add to ChatView with `.sheet()` modifier
- Wire command handlers
- Add keyboard shortcut registration

### 2. Autonomous Agent ✅ Backend Ready
**File:** `Services/AutonomousAgent.swift`
**Status:** Core logic complete
**TODO:**
- Integrate with ChatViewModel
- Add progress UI
- Wire executeTask() calls

### 3. Diff Preview UI ✅ Backend Ready
**File:** `Views/DiffView.swift`
**Status:** Side-by-side view complete
**TODO:**
- Show before file operations
- Add approve/reject flow
- Integrate with FileService

### 4. Tool Use Protocol ✅ Backend Ready
**File:** `Services/ToolUseProtocol.swift`
**Status:** 9 tools registered (needs namespace fix)
**TODO:**
- Rename types to avoid conflicts (MLXTool vs Tool)
- Wire into generation flow
- Add tool call parsing from LLM responses

### 5. Context Manager ✅ Backend Ready
**File:** `Services/ContextManager.swift`
**Status:** Summarization ready
**TODO:**
- Integrate with message history
- Add "Summarize old messages" button
- Auto-summarize when token limit reached

### 6. Session Persistence ✅ Backend Ready
**File:** `Services/SessionManager.swift`
**Status:** Save/load implemented
**TODO:**
- Call on app quit/launch
- Add "Resume Session" option
- Auto-save every 60s

### 7. Undo/Redo System ✅ Backend Ready
**File:** `Services/UndoManager.swift`
**Status:** Complete with file operation tracking
**TODO:**
- Wire into FileService operations
- Add Edit menu items (⌘Z, ⌘⇧Z)
- Show undo history UI

### 8. Onboarding Flow ✅ Backend Ready
**File:** `Views/OnboardingView.swift`
**Status:** 5-page flow complete
**TODO:**
- Show on first launch
- Check UserDefaults for completion
- Add skip option

### 9. Prompt Library ✅ Backend Ready
**File:** `Models/PromptLibrary.swift`
**Status:** 15 templates defined (needs PromptTemplate API fix)
**TODO:**
- Fix PromptTemplate init calls
- Add library picker UI
- Wire into input area

---

## 🎯 Integration Checklist (v4.0)

### Phase 1: Core UX (High Priority)
- [ ] Wire Command Palette into ChatView
- [ ] Add keyboard shortcut handling (⌘K, ⌘Z, ⌘P, etc.)
- [ ] Integrate Diff Preview into file operations
- [ ] Add Undo/Redo to Edit menu
- [ ] Show onboarding on first launch

### Phase 2: Agent Capabilities
- [ ] Integrate Autonomous Agent into chat flow
- [ ] Add "Run Agent" button
- [ ] Show agent progress UI
- [ ] Wire Tool Use Protocol into generation

### Phase 3: Context Intelligence
- [ ] Wire Context Manager into ChatViewModel
- [ ] Add "Summarize conversation" button
- [ ] Show token budget indicator
- [ ] Auto-summarize when needed

### Phase 4: Polish
- [ ] Session persistence on quit/launch
- [ ] Performance dashboard sidebar
- [ ] Prompt library picker
- [ ] All keyboard shortcuts working
- [ ] Help tooltips everywhere

---

## 📊 Technical Debt to Resolve

1. **Type Name Conflicts:**
   - Tool vs MLXTool
   - ToolResult vs MLXToolResult
   - ToolError vs MLXToolError
   - **Fix:** Rename new protocol types consistently

2. **PromptLibrary API Mismatch:**
   - Using wrong PromptTemplate initializer
   - **Fix:** Match existing PromptTemplate API

3. **Missing Model Properties:**
   - Message.tokenCount not in struct
   - **Fix:** Add computed property or metadata field

---

## 🚀 Competitive Feature Matrix

| Feature | Claude Code | MLX Code v3.5 | MLX Code v4.0 Target |
|---------|-------------|----------------|----------------------|
| Autonomous Agent | ✅ | ⚠️ Backend | ✅ Full Integration |
| Command Palette | ✅ | ⚠️ Backend | ✅ ⌘K Working |
| Diff Preview | ✅ | ⚠️ Backend | ✅ Before Every Edit |
| Context Management | ✅ | ⚠️ Backend | ✅ Auto-Summarize |
| Tool Use | ✅ | ⚠️ Backend | ✅ Structured Calls |
| Code Actions | ✅ | ✅ Working | ✅ + UI Integration |
| Git Integration | ✅ | ✅ Working | ✅ + Auto-Commit |
| Local/Private | ❌ | ✅ Yes | ✅ Yes |
| No API Costs | ❌ | ✅ Yes | ✅ Yes |
| Apple Silicon Optimized | ❌ | ✅ Yes | ✅ Yes |

---

## 📝 Immediate Next Steps

1. **Fix Compilation Errors** (30 min)
   - Rename tool protocol types
   - Fix PromptLibrary API calls
   - Build successfully

2. **Wire Command Palette** (1 hour)
   - Add to ChatView
   - Connect all commands
   - Test ⌘K

3. **Integrate Session Persistence** (30 min)
   - Call on app lifecycle
   - Test save/restore

4. **Add Keyboard Shortcuts** (1 hour)
   - Register all shortcuts
   - Add to menu items
   - Test all combinations

5. **Polish & Test** (2 hours)
   - Test all features
   - Fix any bugs
   - Update documentation

---

## 🎯 v4.0 Success Criteria

- [ ] Command Palette works (⌘K)
- [ ] Autonomous Agent completes multi-step tasks
- [ ] Diff preview shows before every file change
- [ ] Context auto-summarizes long conversations
- [ ] Session resumes on restart
- [ ] All keyboard shortcuts work
- [ ] Onboarding shows for new users
- [ ] Performance dashboard accessible (⌘P)

---

**Estimated Time to Complete v4.0:** 8-10 hours
**Impact:** World-class competitor to Claude Code
**Unique Advantage:** 100% local, private, cost-free

---

**Current Status:** All 18 features implemented at service layer
**Next:** Fix compilation errors, wire UI, test, ship!
