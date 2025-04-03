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
                            .scaledToFit()
                            .frame(height: 80)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Theme.divider, lineWidth: 0.5)
                            )
                            .shadow(color: Theme.shadowColor, radius: 1, x: 0, y: 1)
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .background(Theme.backgroundSecondary)
            }
            
            HStack(alignment: .bottom, spacing: 12) {
                // Quick actions
                HStack(spacing: 14) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Image(systemName: "photo")
                            .foregroundColor(Theme.primary)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
                
                // Text input field with animated focus state
                TextField(messagePlaceholder, text: $input_text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textPrimary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused ? Theme.primary.opacity(0.7) : Theme.inputBorder, lineWidth: isFocused ? 1.5 : 1)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Theme.inputBackground)
                            )
                    )
                    .lineLimit(1...5)
                    .focused($textFieldFocused)
                    .onChange(of: textFieldFocused) { newValue in
                        isFocused = newValue
                        showFormatBar = newValue && !input_text.isEmpty
                    }
                
                // Send button
                sendButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.backgroundSecondary)
            .onChange(of: selectedItem) { _ in 
                Task {
                    if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            let base64 = uiImage.jpegData(compressionQuality: 1)?.base64EncodedString() ?? ""
                            selectedImage = Image(uiImage: uiImage)
                            aiChatModel.loadLlavaImage(base64: base64)
                            textFieldFocused = true // Focus text field after selecting image
                        }
                    }
                }
            }
            .onChange(of: input_text) { newText in
                if textFieldFocused {
                    showFormatBar = !newText.isEmpty
                }
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
                    .foregroundColor(isActive ? Theme.primary : Theme.textSecondary)
                    .font(.system(size: 16, weight: isActive ? .semibold : .regular))
                    .padding(6)
                    .background(
                        isActive ? 
                            RoundedRectangle(cornerRadius: 4)
                            .fill(Theme.primary.opacity(0.1)) : nil
                    )
            }
            .buttonStyle(.plain)
        }
    }
    
    private var sendButton: some View {
        Button {
            sendMessageButtonPressed()
            hideKeyboard()
        } label: {
            Image(systemName: "paperplane.fill")
                .foregroundColor(Theme.primary)
                .font(.system(size: 20))
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Theme.primary.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
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
    LLMTextInput()
        .environmentObject(AIChatModel())
}
