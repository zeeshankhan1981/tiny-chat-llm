# llamaforked Implementation in TinyChat

This document provides a detailed explanation of how TinyChat uses llamaforked (a fork of llama.cpp) to run LLMs, multimodal models, and audio processing entirely on iOS devices.

## Overview of llamaforked

llamaforked is a custom fork of [llama.cpp](https://github.com/ggerganov/llama.cpp) created by [yyyoungman](https://github.com/yyyoungman/llamaforked) specifically optimized for mobile deployment. It provides:

1. Efficient inference of quantized LLMs on mobile devices
2. Multimodal capabilities through llava implementation
3. Audio processing with Whisper integration
4. Metal optimizations for Apple Silicon
5. Memory efficiency improvements for constrained devices

## Integration Architecture

### C++ to Swift Bridging

TinyChat bridges the C++ implementation with Swift through wrapper classes:

1. **LibLlama.swift**: Bridges to core llama.cpp functionality
2. **LibLlava.swift**: Bridges to llava multimodal extensions
3. **LibWhisper.swift**: Bridges to Whisper speech recognition

The bridge uses `LlamaContext` and `LlavaContext` classes that manage:
- Context creation and token management
- Prompt processing and completion generation
- Resource cleanup and memory management

### Model Loading Process

```
┌────────────────┐      ┌─────────────────┐      ┌──────────────────┐
│ Swift UI Layer │──┬──▶│ LlamaState.swift │──┬──▶│ LibLlama C Bridge│
└────────────────┘  │   └─────────────────┘  │   └──────────────────┘
                    │                        │             │
                    │                        │             ▼
                    │                        │   ┌──────────────────┐
                    │                        │   │   llamaforked    │
                    │                        │   │  (C++ library)   │
                    │                        │   └──────────────────┘
                    │                        │             ▲
                    │                        │             │
                    │   ┌─────────────────┐  │   ┌──────────────────┐
                    └──▶│ AIChatModel     │──┴──▶│GGUF Model Files  │
                        └─────────────────┘      └──────────────────┘
```

## Key Components & Implementation Details

### 1. LlamaContext (LibLlama.swift)

Core class that handles interaction with llamaforked:

```swift
class LlamaContext {
    private var ctx: OpaquePointer? // C pointer to llamaforked context
    private var model: OpaquePointer? // C pointer to loaded model

    // Creates a new context from a model path
    static func create_context(path: String) throws -> LlamaContext { ... }
    
    // Sets up a prompt for completion
    func completion_init(text: String) async { ... }
    
    // Runs a single inference step and returns new tokens
    func completion_loop(prompt: String, _ callback: ((String) -> Bool)? = nil) -> String {
        // ... (context and processing setup)
        
        let start_time = DispatchTime.now()
        var token_count: Int32 = 0
        
        while !completion_finished {
            // Token generation logic
            token_count += 1
            
            // Calculate and report performance metrics
            let seconds = Double(DispatchTime.now().uptimeNanoseconds - start_time.uptimeNanoseconds) / 1_000_000_000
            let tokens_per_second = Double(token_count) / seconds
            
            // Report to UI via callback
            // ...
        }
        
        return result
    }
    
    // Releases resources
    func clear() async { ... }
    
    // Gets model information
    func model_info() async -> String { ... }
    
    // Benchmarks model performance
    func bench(pp: Int32, tg: Int32, pl: Int32, nr: Int32 = 1) async -> String { ... }
}

### 2. LlavaContext (LibLlava.swift)

Extends LlamaContext to support multimodal inputs:

```swift
class LlavaContext {
    private var ctx: OpaquePointer? // C pointer to llamaforked context
    private var model: OpaquePointer? // C pointer to loaded model
    private var mmproj: OpaquePointer? // C pointer to image projection model

    // Creates a new multimodal context
    static func create_context(model_path: String, mmproj_path: String) throws -> LlavaContext { ... }
    
    // Sets image input from base64 encoding
    func set_image(base64: String) async { ... }
    
    // Multimodal completion with image context
    func completion_loop(prompt: String) async -> String { ... }
}

### 3. WhisperState (LibWhisper.swift)

Handles audio transcription with Whisper:

```swift
class WhisperState: ObservableObject {
    @Published var messageLog = ""
    @Published var isRecording = false
    
    private var recorder: Recorder?
    private var whisperContext: OpaquePointer?
    
    // Initializes Whisper model
    func initWhisper() { ... }
    
    // Toggles audio recording
    func toggleRecord() async { ... }
    
    // Transcribes recorded audio
    func transcribe() async -> String { ... }
}

## Performance Metrics and UI Integration

The TinyChat UI provides important performance metrics to users through the integration with llamaforked:

### Token Generation Metrics

The `LlamaContext` class provides token generation speed via the completion callback:

These metrics are captured by the `AIChatModel` and displayed in the UI through the `MessageView` component, which shows:

1. Total tokens generated
2. Tokens per second rate
3. Total generation time

This gives users immediate feedback on the performance of different models and helps diagnose potential issues with model loading or generation.

### User Experience Enhancements

To improve the user experience during token generation:

1. The UI shows "Thinking..." status in real-time
2. Progress indicators adapt to the token generation state
3. Performance metrics are displayed upon completion
4. Message grouping by date maintains context even in long conversations
5. Conversation history is persisted between app sessions

These integrations create a seamless experience between the low-level C++ implementation and the Swift UI layer.

## Model Quantization & Performance

TinyChat uses GGUF format models with specific quantization to balance performance and quality:

| Model | Quantization | Size | Performance |
|-------|--------------|------|-------------|
| MobileVLM V2 | Q4_K | 1.48 GB | ~15 tokens/sec |
| MobileVLM mmproj | F16 | 610 MB | N/A |
| Whisper Base | Q5_0 | 57 MB | ~1.2x realtime |

### Key Optimizations:

1. **Context Management**: Efficient reuse of allocated context
2. **Batched Inference**: Processing multiple tokens at once
3. **Metal Acceleration**: Using Apple's Metal API for computation
4. **Memory Mapping**: Reducing RAM usage for large models
5. **Prompt Caching**: Reusing computation for repeated prompts

## Prompt Engineering

TinyChat uses specific prompt templates for different interaction modes:

### Text Chat Prompt Format
```
A chat between a curious human and an artificial intelligence assistant. The assistant gives helpful, detailed, and polite answers to the human's questions.

USER: {user_message}
ASSISTANT: 
```

### Multimodal (Image) Prompt Format
```
A chat between a curious human and an artificial intelligence assistant. The assistant gives helpful, detailed, and polite answers to the human's questions.

USER: <image> {user_message}
ASSISTANT:
```

## Implementation Challenges & Solutions

### Memory Management
**Challenge**: iOS has strict memory limits that can cause app termination.
**Solution**: 
- Load and unload models as needed
- Use low-bit quantization (Q4_K, Q5_0)
- Implement proper resource cleanup

### Inference Speed
**Challenge**: LLM inference can be slow on mobile devices.
**Solution**:
- Optimized batch sizes (4-8 tokens)
- Metal acceleration
- Sentence-based output buffering for responsive UI

### UI Responsiveness
**Challenge**: Long-running inference can freeze the UI.
**Solution**:
- All model operations run on background threads
- Token-by-token streaming to UI
- Cancelable operations

### Model Size vs. Quality
**Challenge**: Balancing model size and performance against quality.
**Solution**:
- Selected MobileVLM: optimized specifically for mobile
- Custom quantization methods to reduce size
- Pruned unnecessary model components

## Building and Extending llamaforked

For developers looking to modify the llamaforked implementation:

1. Clone the llamaforked repository: `git clone https://github.com/yyyoungman/llamaforked`
2. Compile for your target platform (iOS requires specific build flags)
3. Replace the compiled libraries in the TinyChat project
4. Update the C bridge headers if necessary

Refer to the CMake configuration in the llamaforked repository for specific build options and optimizations.

## Future Improvements

The llamaforked implementation in TinyChat can be extended in several ways:

1. **Support for newer LLM architectures** (Phi, Mistral, etc.)
2. **Further quantization optimizations** (3-bit, mixed precision)
3. **Hardware-specific optimizations** for newer Apple devices
4. **Support for longer context windows** through optimized attention mechanisms
5. **Improved multimodal capabilities** with higher-resolution image inputs
6. **Fine-tuning capabilities** for personalizing models on-device
