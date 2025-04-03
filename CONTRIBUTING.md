# Contributing to TinyChat

Thank you for considering contributing to TinyChat! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

Please be respectful and considerate of others when contributing to this project. We aim to foster an inclusive and welcoming environment for everyone.

## How to Contribute

### Reporting Bugs

If you find a bug, please create an issue on GitHub with the following information:

- A clear, descriptive title
- Steps to reproduce the bug
- Expected behavior
- Actual behavior
- Screenshots (if applicable)
- Device information (iOS version, device model)
- Any additional context

### Feature Requests

If you'd like to suggest a new feature or enhancement:

1. Check if the feature has already been suggested in the issues
2. Create a new issue with a clear description of the feature
3. Explain why this feature would be useful to TinyChat users
4. Provide examples of how it might work (mockups are welcome!)

### Pull Requests

We welcome pull requests for bug fixes, features, and improvements. To submit a pull request:

1. Fork the repository
2. Create a new branch from `main` for your changes
3. Make your changes, following the coding guidelines below
4. Add tests if applicable
5. Update documentation to reflect your changes
6. Submit a pull request with a clear description of the changes

### Development Setup

1. Clone the repository
```bash
git clone https://github.com/zeeshankhan1981/tiny-chat-llm.git
cd tiny-chat-llm
```

2. Open the project in Xcode
```bash
open PocketGPT.xcodeproj
```

3. Make sure you have the required model files (see README.md)

## Coding Guidelines

### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use clear, descriptive variable and function names
- Add comments for complex logic
- Keep functions small and focused on a single task
- Use Swift's strong typing to avoid runtime errors

### UI Guidelines

- Maintain consistency with the Todoist-inspired design
- Keep the UI clean and minimalist
- Ensure accessibility features are properly implemented
- Test UI changes on different device sizes

### Performance

- Be mindful of memory usage, especially with ML models
- Optimize for battery life
- Consider lower-powered devices when implementing features
- Test performance impacts of changes

### Documentation

- Update documentation when changing functionality
- Document any new features or components
- Use clear, concise language in comments and documentation
- Keep the README and other docs up to date

## Review Process

Pull requests will be reviewed by project maintainers. We may suggest changes or improvements before merging.

## License

By contributing to TinyChat, you agree that your contributions will be licensed under the project's MIT License.

Thank you for helping improve TinyChat!
