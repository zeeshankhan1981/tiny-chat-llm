//
//  LLMTextInput.swift
//  PocketGPT
//
//

import SwiftUI
import PhotosUI

struct MessageInputViewHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension View {
    func messageInputViewHeight(_ value: CGFloat) -> some View {
        self.preference(key: MessageInputViewHeightKey.self, value: value)
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct LLMTextInput: View {
    private let messagePlaceholder: String
    @EnvironmentObject var aiChatModel: AIChatModel
    @State private var input_text: String = ""

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: Image?
    
    // States for animation
    @State private var isFocused = false
    @State private var showFormatBar = false
    @FocusState private var textFieldFocused: Bool
    
    // Quick action states
    @State private var isTextBold = false
    @State private var isTextItalic = false
    @State private var isTextCode = false
    
    // Computed property to check if model is loaded and ready
    var isModelReady: Bool {
        if case .loaded = aiChatModel.modelLoadingState {
            return true
        }
        return false
    }
    
    // Computed property to check if model is still loading
    var isModelLoading: Bool {
        if case .loading = aiChatModel.modelLoadingState {
            return true
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Quick format bar
            if showFormatBar && !input_text.isEmpty {
                HStack(spacing: 16) {
                    FormatButton(isActive: $isTextBold, icon: "bold", tooltip: "Bold")
                    FormatButton(isActive: $isTextItalic, icon: "italic", tooltip: "Italic")
                    FormatButton(isActive: $isTextCode, icon: "chevron.left.forwardslash.chevron.right", tooltip: "Code")
                    
                    Spacer()
                    
                    Button {
                        input_text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.textSecondary)
                            .font(.system(size: 16))
                    }
                    .buttonStyle(.plain)
                    .opacity(input_text.isEmpty ? 0 : 1)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
                .background(Theme.backgroundSecondary)
            }
            
            Divider()
                .background(Theme.divider)
            
            // Model loading status indicator
            if isModelLoading {
                HStack(spacing: 4) {
                    Text("Model loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ProgressView()
                        .scaleEffect(0.7)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
            
            // Image preview with controls
            if selectedImage != nil {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Attachment")
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                        
                        Spacer()
                        
                        Button {
                            selectedImage = nil
                            aiChatModel.resetLlavaImage()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Theme.textSecondary)
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack {
                        selectedImage?
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(8)
                            .frame(height: 100)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                // Image picker button
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "photo.circle")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.primary)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
                .disabled(!isModelReady)
                .opacity(isModelReady ? 1.0 : 0.6)
                
                // Text field with dynamic height
                ZStack(alignment: .leading) {
                    // Empty container to measure height
                    Text(input_text.isEmpty ? " " : input_text)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.clear)
                        .opacity(0)
                    
                    TextEditor(text: $input_text)
                        .frame(minHeight: 36, maxHeight: 120)
                        .cornerRadius(20)
                        .font(.body)
                        .padding(.horizontal, 6)
                        .padding(.vertical, -2)
                        .background(Theme.backgroundSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isFocused ? Theme.primary : Color.clear, lineWidth: 1.5)
                        )
                        .overlay(
                            HStack {
                                Text(messagePlaceholder)
                                    .foregroundColor(Theme.textSecondary)
                                    .font(.body)
                                    .padding(.leading, 10)
                                    .opacity(input_text.isEmpty && !textFieldFocused ? 1 : 0)
                                Spacer()
                            }
                        )
                        .focused($textFieldFocused)
                        .disabled(!isModelReady)
                        .opacity(isModelReady ? 1.0 : 0.6)
                        .onChange(of: textFieldFocused) { newValue in
                            isFocused = newValue
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showFormatBar = newValue
                            }
                        }
                }
                
                // Send button
                Button {
                    if !input_text.isEmpty {
                        var image: Image? = nil
                        if let selectedImage = selectedImage {
                            image = selectedImage
                        }
                        
                        aiChatModel.send(message: input_text, image: image)
                        input_text = ""
                        selectedImage = nil
                        hideKeyboard()
                    }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(isModelReady && !input_text.isEmpty ? Theme.primary : Color.gray.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
                .disabled(!isModelReady || input_text.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onChange(of: selectedItem) { _ in 
            Task {
                if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                    if let uiImage = UIImage(data: data) {
                        let base64 = uiImage.jpegData(compressionQuality: 1)?.base64EncodedString() ?? ""
                        
                        // Load image into model
                        aiChatModel.loadLlavaImage(base64: base64)
                        selectedImage = Image(uiImage: uiImage)
                    }
                }
                selectedItem = nil
            }
        }
    }
    
    // Format button component for the quick format bar
    private struct FormatButton: View {
        @Binding var isActive: Bool
        let icon: String
        let tooltip: String
        
        var body: some View {
            Button {
                isActive.toggle()
            } label: {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: isActive ? .bold : .regular))
                    .foregroundColor(isActive ? Theme.primary : Theme.textPrimary)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isActive ? Theme.primary.opacity(0.1) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    init(messagePlaceholder: String? = nil) {
        self.messagePlaceholder = messagePlaceholder ?? "Message"
    }
    
    private func sendMessageButtonPressed() {
        Task {
            if !input_text.isEmpty {
                // Apply formatting
                var formattedText = input_text
                if isTextBold {
                    formattedText = "**\(formattedText)**"
                }
                if isTextItalic {
                    formattedText = "_\(formattedText)_"
                }
                if isTextCode {
                    formattedText = "`\(formattedText)`"
                }
                
                aiChatModel.send(message: formattedText, image: selectedImage)
                
                // Reset states
                input_text = ""
                selectedImage = nil
                isTextBold = false
                isTextItalic = false
                isTextCode = false
                showFormatBar = false
            }
        }
    }
}

#Preview {
    LLMTextInput(messagePlaceholder: "Message")
        .environmentObject(AIChatModel())
        .previewLayout(.sizeThatFits)
        .padding()
}
