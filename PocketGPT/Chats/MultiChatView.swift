import SwiftUI

struct MultiChatView: View {
    @EnvironmentObject var aiChatModel: AIChatModel
    @State private var availableChats: [String] = []
    @State private var selectedChat: String?
    @State private var showNewChatSheet = false
    @State private var newChatTitle = ""
    @State private var isEditing = false
    @State private var chatToRename: String?
    @State private var renameText = ""
    
    var body: some View {
        NavigationSplitView {
            List {
                // Create New Chat Button
                Button(action: {
                    showNewChatSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.primary)
                        Text("New Chat")
                            .foregroundColor(Theme.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                }
                .listRowBackground(Color(uiColor: .systemBackground).opacity(0.8))
                
                // Chats Section
                Section(header: Text("Your Conversations")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 5)
                ) {
                    ForEach(availableChats, id: \.self) { chatTitle in
                        NavigationLink(
                            destination: ChatView(chat_title: .constant(chatTitle))
                                .environmentObject(aiChatModel)
                                .onAppear {
                                    aiChatModel.prepare(chat_title: chatTitle)
                                }
                        ) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(chatTitle)
                                        .fontWeight(.medium)
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    // Show modification date
                                    let modDate = SimpleChatManager.shared.getChatModificationDate(title: chatTitle)
                                    Text(formatDate(date: modDate))
                                        .font(.caption)
                                        .foregroundColor(Theme.textSecondary)
                                }
                                
                                Spacer()
                                
                                // Show timestamp
                                Text(timeAgo(date: SimpleChatManager.shared.getChatModificationDate(title: chatTitle)))
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .padding(.vertical, 5)
                        }
                        .contextMenu {
                            Button(action: {
                                chatToRename = chatTitle
                                renameText = chatTitle
                                isEditing = true
                            }) {
                                Label("Rename", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive, action: {
                                deleteChat(chatTitle)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("TinyChat")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showNewChatSheet = true
                    }) {
                        Image(systemName: "square.and.pencil")
                            .foregroundColor(Theme.primary)
                    }
                }
            }
            .sheet(isPresented: $showNewChatSheet) {
                newChatSheet
            }
            .alert("Rename Chat", isPresented: $isEditing) {
                TextField("Chat Name", text: $renameText)
                Button("Cancel", role: .cancel) { }
                Button("Rename") {
                    if let chat = chatToRename, !renameText.isEmpty {
                        renameChat(oldTitle: chat, newTitle: renameText)
                    }
                }
            }
            .onAppear {
                loadChats()
            }
        } detail: {
            // Default detail view when no chat is selected
            VStack {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 70))
                    .foregroundColor(Theme.primary.opacity(0.8))
                    .padding(.bottom, 16)
                
                Text("Select a chat or create a new one")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Your conversations will appear here")
                    .font(.body)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 8)
                
                Button(action: {
                    showNewChatSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("New Chat")
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.primary)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top, 24)
                .buttonStyle(PlainButtonStyle())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
        }
    }
    
    // New Chat Sheet
    private var newChatSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 50))
                    .foregroundColor(Theme.primary)
                    .padding(.top, 40)
                
                Text("Start a New Chat")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                
                TextField("Chat Name", text: $newChatTitle)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                
                Button(action: {
                    createNewChat()
                    showNewChatSheet = false
                }) {
                    Text("Create Chat")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.primary)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                .disabled(newChatTitle.isEmpty)
                .opacity(newChatTitle.isEmpty ? 0.6 : 1)
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("New Chat", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                showNewChatSheet = false
            })
        }
    }
    
    // Load available chats
    private func loadChats() {
        availableChats = SimpleChatManager.shared.getAvailableChats()
    }
    
    // Create a new chat
    private func createNewChat() {
        let title = SimpleChatManager.shared.createNewChat(title: newChatTitle)
        loadChats()
        selectedChat = title
        newChatTitle = ""
    }
    
    // Delete a chat
    private func deleteChat(_ title: String) {
        SimpleChatManager.shared.deleteChat(title: title)
        loadChats()
        
        // If the deleted chat was the current chat, reset
        if selectedChat == title {
            selectedChat = availableChats.first
        }
    }
    
    // Rename a chat
    private func renameChat(oldTitle: String, newTitle: String) {
        // Create a new chat with the new title
        SimpleChatManager.shared.createNewChat(title: newTitle)
        
        // Copy the messages from the old chat
        if let messages = load_chat_history(oldTitle) {
            save_chat_history(messages, newTitle)
        }
        
        // Delete the old chat
        SimpleChatManager.shared.deleteChat(title: oldTitle)
        
        loadChats()
        
        // Update selected chat if needed
        if selectedChat == oldTitle {
            selectedChat = newTitle
        }
    }
    
    // Format date for time ago display
    private func timeAgo(date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Format date for display
    private func formatDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
