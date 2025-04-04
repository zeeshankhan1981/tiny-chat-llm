# PocketGPT Development Guide

## Development Commands

- Build: `xcodebuild -project PocketGPT.xcodeproj -scheme PocketGPT -configuration Debug build`
- Test: `xcodebuild -project PocketGPT.xcodeproj -scheme PocketGPT -configuration Debug test`
- Lint: `swiftlint`

## Project Organization

- **PocketGPT/**: Main application code
  - **Chats/**: Chat interface and message handling
    - Simplified home screen UI focusing on chat functionality
    - Automatic MobileVLM model loading
  - **Model/**: LLM implementation and bridges
  - **CoreData/**: Data persistence layer
    - **PersistenceController.swift**: Single source of truth for CoreData access
    - **ChatConversation.xcdatamodeld**: Primary CoreData model for the app
  - **UI/**: Theme and UI components
    - **ModelLoadingView.swift**: UI components for async model loading and progress indicators

## Improvement Priorities

1. Async model loading with progress indicators (COMPLETED)
2. CoreData integration for efficient persistence (PARTIALLY COMPLETE)
3. Separation of concerns in AIChatModel (PARTIALLY COMPLETE)
4. Model switching at runtime (PENDING)
5. Enhanced chat history management (search, export) (PENDING)
6. UI/UX improvements (themes, accessibility) (PENDING)
7. Comprehensive testing suite (PENDING)

## Completed Tasks

### 1. Component Removal (COMPLETED)

Successfully removed the StableDiffusion and Whisper components from the codebase:

1. **Files Modified**:
   - `AIChatModel.swift`: 
     - Removed `sdPipeline` property
     - Removed `loadSDTurbo()` and `loadSD()` methods
     - Removed `sdGen()` method
     - Removed "SD_Turbo" and "Image Creation" cases from `initializeModel()`
     - Removed conditional logic for "Image Creation" in `send()`
     - Removed `getConversationPromptSD()` method
     - Removed `getVoiceAnswer()` method

   - `ChatListView.swift`:
     - Removed "Image Creation" filter from `get_chat_mode_list()`

2. **Files Removed**:
   - `VoiceView.swift` (complete file)

3. **Project File Cleanup Tasks** (COMPLETED):
   - Removed directories `/PocketGPT/StableDiffusion/` and `/PocketGPT/Whisper/` in Xcode
   - Removed SD/Whisper resources in Xcode project navigator
   - Removed references to SD/Whisper in documentation

### 2. CoreData Implementation Issues Resolution (PARTIALLY COMPLETED)

Successfully identified and resolved critical CoreData implementation issues:

1. **Duplicate PersistenceController Resolution**:
   - Identified two competing PersistenceController implementations:
     - One in `PersistenceController.swift` using "ChatConversation" model
     - Another in `ChatDataModel.swift` using "ChatModel" model
   - Removed the duplicate implementation from `ChatDataModel.swift`
   - Made `PersistenceController` and its `shared` instance public for access

2. **Direct CoreData Access Implementation**:
   - Implemented direct CoreData context access in `AIChatModel` to resolve scope issues
   - Created a computed property for viewContext that initializes its own container
   ```swift
   private var viewContext: NSManagedObjectContext {
       let container = NSPersistentContainer(name: "ChatConversation")
       container.loadPersistentStores { description, error in
           if let error = error {
               print("Error loading Core Data: \(error.localizedDescription)")
           }
       }
       return container.viewContext
   }
   ```
   - Updated `AIChatModelExtension` to use the same access pattern

3. **Remaining CoreData Issues**:
   - Multiple files still directly reference `PersistenceController.shared`
   - Each direct container initialization creates a new CoreData stack

### 3. Model Loading & Response Generation (COMPLETED)

Successfully fixed critical issues with model loading and response generation:

1. **Model Initialization Fix**:
   - Identified mismatch between model initialization and usage
   - Updated `loadLlama()` method to use `loadModelLlava()` instead of `loadModel()` for proper context initialization
   - Added logging to track model loading progress and success

2. **Array Safety Implementation**:
   - Added protective guards against array index out of range crashes
   - Implemented safety checks in both `AIChatModel.swift` and `AIChatModelExtension.swift`
   - Added explicit error logging for debugging purposes
   - Protected against race conditions in message array manipulation

3. **Model Response Debug**:
   - Fixed token generation issues in message handling
   - Verified proper model loading via debug logs
   - Confirmed proper CoreData integration in message flow

### 4. Home Screen Simplification (COMPLETED)

Simplified the home screen UI to focus on core chat functionality:

1. **Removed Model Selection**:
   - Removed "MobileVLM V2 3B" from default chat titles
   - Eliminated hardcoded model entry in chat list
   - Removed model selection UI from home screen

2. **Simplified Chat Creation**:
   - Home screen now only shows "New Chat" button
   - Model loading is automatic when creating new chat
   - Removed fallback to model selection in chat deletion

3. **UI Clean-up**:
   - Removed model-related UI elements from chat list
   - Simplified chat deletion and renaming logic
   - Updated NewChatSheetView to focus on chat name only

### 5. Documentation Update (COMPLETED)

Updated the documentation to reflect the recent changes to the home screen and model handling:

1. **Updated Home Screen Description**:
   - Removed references to model selection and hardcoded model entry
   - Added description of simplified chat creation process

2. **Updated Model Loading Description**:
   - Removed references to manual model loading and selection
   - Added description of automatic model loading during chat creation

3. **Updated UI Description**:
   - Removed references to model-related UI elements
   - Added description of simplified chat list and deletion logic

### 6. Async Model Loading Implementation (COMPLETED)

Successfully implemented async model loading with progress indicators:

1. **Model Loading State**:
   - Added `ModelLoadingState` enum with states: `.notLoaded`, `.loading(progress: Double)`, `.loaded`, `.error(String)`
   - Implemented progress tracking during model loading
   - Added error handling and retry functionality

2. **UI Components**:
   - Created `ModelLoadingView.swift` for loading overlay
   - Added progress indicators and error messages
   - Implemented disabled states for input controls during loading

3. **Error Handling**:
   - Added clear error messages for loading failures
   - Implemented retry functionality
   - Added user feedback for loading progress

## Development Roadmap (Updated April 2025)

### Phase 1: Critical Fixes & Stabilization (CURRENT - 1 week)

1. **Core Functionality Fixes** (PARTIALLY COMPLETE)
   - Resolve duplicate PersistenceController implementation (COMPLETED)
   - Fix model loading to properly initialize LlavaContext (COMPLETED)
   - Fix array index out of range crashes in message handling (COMPLETED)
   - Fix CoreData access patterns in AIChatModel (PARTIALLY COMPLETE)
   - Simplify home screen UI to focus on chat functionality (COMPLETED)
   - Apply consistent CoreData context access across remaining files (PENDING)
   - Verify all chat operations (create, read, update, delete) work with updated CoreData access (PENDING)

2. **Model Functionality Verification** (IN PROGRESS)
   - Ensure MobileVLM models load correctly (COMPLETED)
   - Fix token generation in chat responses (COMPLETED)
   - Validate chat message generation works end-to-end (PENDING)
   - Optimize prompt formats for better responses (PENDING)
   - Add proper error handling for model loading failures (PENDING)

3. **Project Cleanup** (PARTIALLY COMPLETE)
   - Remove Stable Diffusion and Whisper components from code (COMPLETED)
   - Update documentation to reflect simplified architecture (COMPLETED)
   - Simplify home screen UI to focus on chat functionality (COMPLETED)
   - Ensure consistent error handling throughout the app (PENDING)
   - Remove any unused dependencies from project file (PENDING)

### Phase 2: Architecture Refactoring (1-2 weeks)

1. **Implement Single CoreData Access Pattern** (0-3 days)
   - Create an Environment Injection pattern for consistent CoreData access
   - Update all files to use the same context access approach
   - Add proper background saving context for performance
   - Implement error recovery mechanisms

2. **Implement Proper Model Management** (3-4 days)
   - Create ModelManager class to handle model operations
   - Separate model loading from chat UI logic
   - Add progress tracking for model loading
   - Implement proper model switching capability

3. **Improve Storage Management** (3-4 days)
   - Create ChatStorageManager to unify file and CoreData operations
   - Implement migration utilities for existing chats
   - Add background saving context for performance
   - Create consistent chat history management

### Phase 3: UI Improvements (2-3 weeks)

1. **Improve Navigation Flow** (4-5 days)
   - Consolidate UI views into a coherent navigation structure
   - Implement tab-based navigation for iPhone
   - Create split-view navigation for iPad/Mac
   - Add consistent empty states and error views

2. **Enhance Chat Experience** (3-4 days)
   - Add proper typing indicators
   - Create message status indicators
   - Implement improved input controls
   - Add support for better multimodal display

3. **Add Model Selection UI** (3-4 days)
   - Create model browser with capabilities information
   - Add model configuration options
   - Implement model switching UI
   - Show loading and progress indicators

### Phase 4: Testing & Refinement (1-2 weeks)

1. **Implement Test Suite** (3-4 days)
   - Create unit tests for core functionality
   - Add UI tests for critical flows
   - Implement performance benchmarks
   - Create automated test scripts

2. **Performance Optimization** (3-4 days)
   - Optimize memory usage during model loading
   - Improve CoreData performance
   - Optimize image handling for multimodal inputs
   - Add caching for frequently accessed data

3. **Final Polish** (3-4 days)
   - Add accessibility improvements
   - Implement localization
   - Create onboarding experience
   - Prepare for App Store submission

## Testing Guidance

### 1. CoreData Validation Tests

After making CoreData-related changes, perform these validations:

1. **Basic CRUD Operations**:
   - Create a new chat 
   - Add messages to the chat 
   - Retrieve chats and messages 
   - Update chat title 
   - Delete a chat 

2. **Data Consistency Checks**:
   - Create chat, close app, verify chat persists on relaunch 
   - Send messages, verify they appear in correct order 
   - Switch between chats, verify correct messages load 
   - Verify chat title updates correctly 

3. **Edge Cases**:
   - Create chat with same name as existing chat 
   - Create very long chat names/messages 
   - Delete chat while sending a message 

### 2. Model Loading Tests

1. **Initialization**:
   - Verify model loads correctly on app start 
   - Check console for any model loading errors 

2. **Chat Response**:
   - Send a message and verify AI responds 
   - Check response quality and formatting 
   - Verify token count and timing information 

### 3. Error Handling Tests

1. **Array Safety**:
   - Test with empty message arrays
   - Test rapid message sending
   - Test concurrent access to message arrays

2. **Recovery**:
   - Force-quit during message send, verify app recovers 
   - Simulate disk full condition 
   - Test network connectivity changes 

### 4. UI Transition Tests

1. **View Transitions**:
   - Navigate between all major screens 
   - Verify animations are smooth 
   - Test orientation changes 
   - Test different device sizes 

2. **Interactive Elements**:
   - Verify all buttons and controls work 
   - Test keyboard interactions 
   - Verify scrolling behavior in chat history 

## Next Immediate Steps

1. Complete end-to-end testing of chat functionality with the fixed model loading
2. Implement consistent CoreData access pattern across all remaining files
3. Add error recovery for common failure scenarios
4. Begin design work on improved model management