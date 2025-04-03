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