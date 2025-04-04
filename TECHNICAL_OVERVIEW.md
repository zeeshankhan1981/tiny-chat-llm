# TinyChat Technical Overview

TinyChat is an iOS application that runs multimodal language models fully on-device with no data sent to external servers, ensuring complete privacy.

## Architecture Overview

TinyChat is built with a clean, modular architecture that separates concerns between:

1. **UI Layer** - SwiftUI views with Todoist-inspired design
2. **Model Layer** - Interface with on-device ML models
3. **State Management** - Observable objects for reactive UI updates
4. **Utility Components** - Helpers for file management, image processing, etc.

## Core Components

### LlamaState (`LlamaState.swift`)

Central component managing LLM inference through llamaforked (forked llama.cpp):

- Handles context creation and management
- Manages prompt completion and token generation
- Provides methods for text completion, multimodal inputs, and benchmarking
- Maintains model loading/unloading life cycle

### AIChatModel (`AIChatModel.swift`)

Main state container that:

- Manages conversation history with `Message` objects
- Handles loading appropriate models based on chat type
- Coordinates file persistence for chat history
- Formats prompts for different model types (text, multimodal)
- Manages real-time UI updates during inference

### UI Components

- **ChatView** - Main conversation interface with date-grouped messages
- **ChatListView** - Navigation/selection between different chat modes
- **MessageView** - Individual message rendering with timestamps, status indicators, and context menus
- **LLMTextInput** - Rich text input with formatting tools and image upload capabilities

### Enhanced Message System

The app uses a sophisticated message handling system:

- **MessageGroup**: Groups messages by date for better conversation organization
- **DateSeparator**: Visual separators with "Today", "Yesterday", and date headers
- **Status Indicators**: Visual feedback for message states (sent, error, typing)
- **Context Menus**: Right-click/long-press options for common actions (copy, save)
- **Performance Metrics**: Real-time display of tokens per second
- **Model Loading**: Asynchronous model loading with progress indicators
- **Error Handling**: Graceful error handling with retry options

### Rich Text Input

The text input system offers several enhancements:

- **Formatting Toolbar**: Options for bold, italic, and code formatting
- **Attachment Preview**: Enhanced image attachment with preview and remove functionality
- **Focus States**: Visual feedback for input field focus
- **Adaptive Buttons**: Context-aware action buttons that adapt to content

### Theme System (`AppTheme.swift`)

Centralized theme definitions using Todoist-inspired colors and styling:

- Consistent color palette across the app
- Typography and spacing guidelines
- Component-specific styling properties
- Shadow and depth for visual hierarchy

## On-Device ML Implementation

### 1. LLM Text Generation (llamaforked)

TinyChat uses a forked version of llama.cpp (llamaforked) to run large language models directly on iOS devices:

- **Model**: MobileVLM text model
- **Quantization**: 4-bit quantization for efficient on-device performance
- **Integration**: Swift bridging to C++ implementation
- **Prompt Handling**: Efficiently manages context window and prompt formatting

### 2. Model Management

- **Async Loading**: Models load asynchronously with progress tracking
- **State Management**: Comprehensive ModelLoadingState enum for tracking loading status
- **Error Recovery**: Built-in error handling and retry functionality
- **Resource Management**: Efficient memory usage during loading

### 3. Multimodal Capabilities (image + text)

- **Model**: MobileVLM-V2-3B
- **Components**: 
  - Text model: `MobileVLM_V2-3B-ggml-model-q4_k.gguf`
  - Image projection: `MobileVLM_V2-3B-mmproj-model-f16.gguf`
- **Implementation**: Custom LlavaContext to handle multimodal inputs

## File Structure

```
TinyChat/
├── Model/                  # ML model interfaces
│   ├── LibLlama.swift      # C++ bridge to llama.cpp
│   └── LlamaState.swift    # Swift wrapper for model management
├── Chats/                  # Chat UI and management
│   ├── AIChatModel.swift   # Core chat state management
│   ├── ChatView.swift      # Main chat interface
│   ├── ChatListView.swift  # Chat selection interface
│   ├── MessageView.swift   # Individual message UI
│   ├── LLMTextInput.swift  # Text input component
│   ├── Message.swift       # Message data structure
│   └── FileHelper.swift    # File persistence utilities
├── Resources/              # Bundled models and assets
│   ├── llm/                # LLM model files
│   └── 
├── Assets.xcassets/        # App images and assets
└── AppTheme.swift          # Global theming system
```

## Performance Considerations

1. **Memory Management**
   - Models are loaded only when needed
   - Resources are properly released when not in use
   - CoreML optimizations for Apple Silicon

2. **Battery Efficiency**
   - Inference batch sizes optimized for mobile devices
   - Progress callbacks allow cancellation of long-running operations
   - Proper threading to prevent UI freezing

3. **Storage Management**
   - Models bundled with the app (no downloads required)
   - Chat history uses efficient serialization

## Privacy Features

- **100% On-Device Processing**: No data leaves the user's device
- **No API Keys**: No external services or API calls
- **No Analytics**: No usage tracking or metrics collection
- **Local File Storage**: All chat history stored only on device

## Build & Run Requirements

- iOS 16.0 or later
- Xcode 14.0 or later
- Minimum 4GB RAM on device (8GB recommended)
- ~1GB storage for app and models
