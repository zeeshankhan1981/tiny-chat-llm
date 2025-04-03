# PocketGPT Development Guide

## Development Commands

- Build: `xcodebuild -project PocketGPT.xcodeproj -scheme PocketGPT -configuration Debug build`
- Test: `xcodebuild -project PocketGPT.xcodeproj -scheme PocketGPT -configuration Debug test`
- Lint: `swiftlint`

## Project Organization

- **PocketGPT/**: Main application code
  - **Chats/**: Chat interface and message handling
  - **Model/**: LLM implementation and bridges
  - **CoreData/**: Data persistence layer
  - **StableDiffusion/**: Image generation components
  - **Whisper/**: Speech-to-text functionality
  - **UI/**: Theme and UI components

## Improvement Priorities

1. Async model loading with progress indicators
2. CoreData integration for efficient persistence
3. Separation of concerns in AIChatModel
4. Model switching at runtime
5. Enhanced chat history management (search, export)
6. UI/UX improvements (themes, accessibility)
7. Comprehensive testing suite

## Component Removal Plan

### Stable Diffusion Removal

1. **Files to Modify**:
   - `AIChatModel.swift`: 
     - Remove `sdPipeline` property (line 29)
     - Remove `loadSDTurbo()` and `loadSD()` methods (lines 119-164)
     - Remove `sdGen()` method (lines 268-301)
     - Remove "SD_Turbo" and "Image Creation" cases from `initializeModel()` (lines 108-111) 
     - Remove conditional logic for "Image Creation" in `send()` (lines 318-320, 359-369)
     - Remove conditional logic for "Image Creation" in `reload()` (lines 103-104)
     - Remove `getConversationPromptSD()` method (lines 249-253)

   - `ChatListView.swift`:
     - Update filter in `get_chat_mode_list()` (line 30) to remove "Image Creation" filter

2. **Directories to Remove**:
   - `/PocketGPT/StableDiffusion/` (entire directory with all 25 files)
   - SD resources in `/PocketGPT/Resources/sd_turbo/`

3. **Project File Updates**:
   - Remove SD model references from project.pbxproj
   - Remove CoreML framework dependency if not used elsewhere

### Whisper Removal

1. **Files to Remove**:
   - `VoiceView.swift` (complete file)

2. **Files to Modify**:
   - `AIChatModel.swift`:
     - Remove `getVoiceAnswer()` method (lines 380-412)
     - Remove other voice-related methods if present

3. **Directories to Remove**:
   - `/PocketGPT/Whisper/` (entire directory)
   - Whisper resources in `/PocketGPT/Resources/whisper/`

4. **Project File Updates**:
   - Remove Whisper references from project.pbxproj
   - Remove AVFoundation dependency if not used elsewhere
   - Remove microphone permission if not needed elsewhere

### Implementation Steps

1. Backup the project
2. Remove directories first to avoid compilation errors
3. Update AIChatModel.swift to remove SD and Whisper functionality
4. Remove "Image Creation" references from ChatListView.swift
5. Remove VoiceView.swift completely
6. Update Info.plist to remove unneeded permissions
7. Test core chat functionality after removal
8. Clean build and test again

## CoreData Implementation Notes

### Current Issues
- Multiple data models (ChatData, ChatModel, ChatConversation) causing inconsistency
- Duplicate controllers (PersistenceController, DataController)
- Incomplete migration from file-based to CoreData storage
- Poor error handling with `fatalError()` in production code
- Performance concerns with image conversion

### Integration Points
- AIChatModel bridges between file and CoreData storage
- SwiftUI views depend on in-memory Message objects converted from CoreData
- Dual storage systems (file-based and CoreData) operate in parallel
- NewChatListView/EnhancedChatView directly import CoreData for listings

### Implementation Requirements
- Preserve compatibility with existing UI components
- Maintain entity relationships that views depend on
- Keep consistent image data conversion and message ordering
- Provide clean migration path from dual storage systems
- Consolidate multiple data models into a single schema

## UX Improvement Plan

### Critical UX Issues

1. **Inconsistent Navigation Flow**
   - Multiple overlapping chat views: ChatListView, NewChatListView, MultiChatView with duplicated code
   - Confusing entry points: Users can "create new chat" both from home screen and direct model access
   - Fragmented UX patterns between file-based and CoreData-based workflows

2. **Model Selection & Management**
   - No clear model selection interface; model is tied to chat name in a non-intuitive way
   - Default selection of "MobileVLM V2 3B" hardcoded in multiple places
   - No visual indication of which model is active or loading state

3. **Chat Persistence Confusion**
   - Dual storage systems (file-based and CoreData) causing inconsistent UX
   - No clear way for users to understand or manage where their data is stored
   - Chat title used as primary identifier in both systems, causing potential conflicts

4. **Architectural UX Problems**
   - AIChatModel handles too many concerns (UI state, chat management, model loading)
   - Different chat views using different navigation patterns
   - Inconsistent state management between view reloads

## Comprehensive UX Improvement Plan

### Phase 1: Core Architecture Refactoring

1. **Separate Concerns in AIChatModel**
   - Create `ModelManager` class to handle model loading, selection, and state
   - Create `ChatStorageManager` to unify file-based and CoreData operations
   - Refactor `AIChatModel` to be UI-state focused and delegate storage/model operations
   - Estimated time: 3-4 days

2. **Consolidate Chat Views**
   - Identify the best features from each view implementation (ChatListView, NewChatListView, MultiChatView)
   - Create a single `UnifiedChatListView` that incorporates the best elements
   - Implement a shared chat cell component with consistent styling and actions
   - Estimated time: 2-3 days

### Phase 2: Storage and Model Management

1. **Complete CoreData Migration**
   - Finalize the single data model schema
   - Create migration utilities for existing file-based chats
   - Add background saving context for performance
   - Add proper error handling and recovery
   - Estimated time: 3-4 days

2. **Create Model Selection UI**
   - Design a model selection interface separate from chat creation
   - Implement model information cards showing capabilities
   - Create loading indicators for model initialization
   - Add model switcher in chat settings
   - Estimated time: 2-3 days

### Phase 3: UI Flow and Navigation Improvements

1. **Implement Clear Navigation Pattern**
   - Create a consistent three-panel navigation for iPad/Mac: 
     - Models panel
     - Chats list panel
     - Chat detail panel
   - For iPhone, use a tab-based navigation:
     - Models tab
     - Chats tab with drill-down to chat detail
     - Settings tab
   - Estimated time: 3-4 days

2. **Redesign Create Chat Experience**
   - Separate model selection from chat creation
   - Implement a stepwise flow:
     1. Select model
     2. Configure model settings (if applicable)
     3. Create chat with name/description
   - Add visual indication of selected model in chat list
   - Estimated time: 2 days

### Phase 4: Visual and Interaction Polish

1. **Feedback and State Indicators**
   - Add typing indicators for AI responses
   - Implement toast notifications for system events
   - Create consistent empty states
   - Add loading animations for model switching and initialization
   - Estimated time: 2-3 days

2. **Implement Consistent Interaction Patterns**
   - Add swipe actions to chat list and messages
   - Implement long-press context menus
   - Create standardized action buttons
   - Add haptic feedback for primary actions
   - Estimated time: 1-2 days

### Implementation Details

#### 1. AIChatModel Refactoring

```swift
// NEW: Create a ModelManager to handle model operations
class ModelManager: ObservableObject {
    @Published var availableModels: [ModelInfo] = []
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0
    @Published var currentModel: ModelInfo?
    
    func loadModel(_ modelInfo: ModelInfo) async throws { ... }
    func switchModel(for chat: Chat, to model: ModelInfo) async throws { ... }
    func getAvailableModels() -> [ModelInfo] { ... }
}

// NEW: Create a unified storage manager
class ChatStorageManager {
    static let shared = ChatStorageManager()
    
    // CoreData container
    let persistenceController = PersistenceController.shared
    
    // Create a chat
    func createChat(title: String, model: ModelInfo) -> Chat { ... }
    
    // Get all chats
    func getAllChats() -> [Chat] { ... }
    
    // Migration utilities
    func migrateFileBasedChatsToCoreData() async throws { ... }
}

// REFACTORED: Simplify AIChatModel to focus on UI state and delegate other responsibilities
@MainActor
final class AIChatModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var typingState: TypingState = .idle
    
    // Dependencies
    private let modelManager: ModelManager
    private let storageManager: ChatStorageManager
    
    // Current chat reference
    private(set) var currentChat: Chat?
    
    init(modelManager: ModelManager, storageManager: ChatStorageManager) {
        self.modelManager = modelManager
        self.storageManager = storageManager
    }
    
    func setCurrentChat(_ chat: Chat) { ... }
    func sendMessage(_ text: String) async { ... }
}
```

#### 2. Unified Chat List View

```swift
struct UnifiedChatListView: View {
    @EnvironmentObject var aiChatModel: AIChatModel
    @EnvironmentObject var modelManager: ModelManager
    
    @State private var showNewChatSheet = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationSplitView {
            VStack {
                // Create new chat button
                Button(action: { showNewChatSheet = true }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("New Chat")
                        Spacer()
                    }
                    .padding()
                    .background(Theme.backgroundSecondary)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Chat list with unified style
                ChatListContent(searchText: searchText)
            }
            .searchable(text: $searchText, prompt: "Search chats")
            .navigationTitle("Chats")
            .sheet(isPresented: $showNewChatSheet) {
                CreateChatView()
            }
        } detail: {
            WelcomeView()
        }
    }
}

// Reusable chat list component
struct ChatListContent: View {
    @EnvironmentObject var aiChatModel: AIChatModel
    @FetchRequest var chats: FetchedResults<Chat>
    
    var searchText: String
    
    init(searchText: String) {
        self.searchText = searchText
        
        // Configure fetch request with search if needed
        let request: NSFetchRequest<Chat> = Chat.fetchRequest()
        if !searchText.isEmpty {
            request.predicate = NSPredicate(format: "title CONTAINS[cd] %@", searchText)
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Chat.updatedAt, ascending: false)]
        
        self._chats = FetchRequest(fetchRequest: request, animation: .default)
    }
    
    var body: some View {
        List {
            ForEach(chats) { chat in
                NavigationLink(destination: ChatDetailView(chat: chat)) {
                    ChatListCell(chat: chat)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        deleteChat(chat)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    Button {
                        renameChat(chat)
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(Theme.primary)
                }
            }
        }
    }
}
```

#### 3. Model Selection UI

```swift
struct ModelSelectionView: View {
    @EnvironmentObject var modelManager: ModelManager
    @Binding var selectedModel: ModelInfo?
    
    var body: some View {
        VStack {
            Text("Select a Model")
                .font(.title)
                .padding()
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
                    ForEach(modelManager.availableModels) { model in
                        ModelCard(model: model, isSelected: selectedModel?.id == model.id)
                            .onTapGesture {
                                selectedModel = model
                            }
                    }
                }
                .padding()
            }
            
            Button("Continue") {
                // Navigate to next step
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding()
            .disabled(selectedModel == nil)
        }
    }
}

struct ModelCard: View {
    var model: ModelInfo
    var isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(model.name)
                    .font(.headline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.primary)
                }
            }
            
            Text(model.description)
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .padding(.vertical, 4)
            
            HStack {
                Label("\(model.parameters) parameters", systemImage: "cpu")
                Spacer()
                Label(model.sizeFormatted, systemImage: "externaldrive")
            }
            .font(.caption)
            .foregroundColor(Theme.textSecondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Theme.primary : Theme.divider, lineWidth: isSelected ? 2 : 1)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Theme.primary.opacity(0.1) : Theme.backgroundSecondary)
                )
        )
    }
}
```

### Testing Milestones

1. **Architecture Testing**
   - Verify model loading and initialization
   - Test chat creation and storage
   - Validate CoreData migration from file-based storage

2. **UI Flow Testing**
   - Validate navigation patterns on different devices
   - Test model selection and chat creation flow
   - Verify state persistence across app launches

3. **Performance Testing**
   - Measure chat loading speed with CoreData vs. file-based
   - Test UI responsiveness during model loading
   - Verify memory usage patterns

### Total Estimated Implementation Time: 3-4 weeks