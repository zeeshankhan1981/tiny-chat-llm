# TinyChat

A privacy-focused iOS app that runs Multimodal LLM, Stable Diffusion, and Whisper fully on-device. No data leaves your phone.

<p align="center">
  <img src="Screenshots/app_banner.png" alt="TinyChat Banner" width="800"/>
</p>

## Features

- **Text Chat**: Engage with a modern LLM entirely on your device
- **Image Understanding**: Show images to the AI and discuss them
- **Complete Privacy**: 100% on-device processing, no API keys or servers needed
- **Modern UI**: Clean, Todoist-inspired design with message grouping and formatting options
- **Context Menu**: Easily copy messages or save images
- **Date Separators**: Messages organized by day with "Today" and "Yesterday" headers
- **Performance Metrics**: See realtime tokens-per-second metrics

## Documentation

For developers interested in understanding or contributing to the project:

- [Technical Overview](TECHNICAL_OVERVIEW.md) - Architecture, components, and design
- [llamaforked Implementation](LLAMAFORKED_IMPLEMENTATION.md) - Details of the LLM implementation
- [Contributing Guidelines](CONTRIBUTING.md) - How to contribute to the project

## Getting Started

### Requirements

- iOS 16.0+
- Xcode 14.0+
- Device with 4GB+ RAM (8GB recommended)
- ~1GB free storage

### Installation

1. Clone the repository
```bash
git clone https://github.com/zeeshankhan1981/tiny-chat-llm.git
```

2. Open the project in Xcode
```bash
cd tiny-chat-llm
open PocketGPT.xcodeproj
```

3. Download models
   - MobileVLM V2 3B (4-bit quantized)
   - Whisper Base (English)
   - Place them in the appropriate folders (see TECHNICAL_OVERVIEW.md)

4. Build and run on your device
   - Select your device as the build target
   - Press Cmd+R to build and run

## How It Works

TinyChat uses optimized, quantized machine learning models to run entirely on your device:

1. **LLM Engine**: Uses [llamaforked](https://github.com/yyyoungman/llamaforked) (a fork of llama.cpp) to run language models on iOS
2. **Multimodal**: [MobileVLM](https://github.com/Meituan-AutoML/MobileVLM) model for understanding images and text
3. **Voice Recognition**: [Whisper](https://github.com/openai/whisper) for speech-to-text conversion

All processing happens on your device with no data sent to external servers.

## UI Features

The Todoist-inspired UI includes:

- **Message Timestamps**: See when each message was sent
- **Message Status**: Visual indicators show message state (sent, error)
- **Date Grouping**: Messages organized by date with intuitive headers
- **Formatting Toolbar**: Format text as bold, italic, or code blocks
- **Attachment Previews**: Enhanced image attachment controls
- **Context Menus**: Right-click/long-press options for messages
- **Performance Display**: See token generation speed metrics

## Credits

This app integrates several open-source projects and models:

### Code
- Inference engine: [llama.cpp](https://github.com/ggerganov/llama.cpp) ([forked](https://github.com/yyyoungman/llamaforked)) for language and audio models
- UI inspiration: [Todoist](https://todoist.com) for clean, task-focused design

### Models
- MLLM: [MobileVLM V2 3B](https://github.com/Meituan-AutoML/MobileVLM), quantized to 4 bits
- Audio: [Whisper Base](https://github.com/openai/whisper), English model

## Credits

TinyChat is based on the open-source structure of PocketGPT, available on the App Store. While PocketGPT offers a comprehensive suite of AI features, TinyChat focuses exclusively on LLM chat capabilities, with plans for ongoing enhancements and new features in the future.

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [llamaforked](https://github.com/yyyoungman/llamaforked) for the efficient LLM implementation
- [MobileVLM](https://github.com/Meituan-AutoML/MobileVLM) team for the mobile-optimized multimodal model
- [OpenAI](https://openai.com/) for the Whisper model
