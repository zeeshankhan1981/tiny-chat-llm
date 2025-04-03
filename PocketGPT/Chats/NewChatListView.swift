import SwiftUI
import CoreData

struct NewChatListView: View {
    @EnvironmentObject var aiChatModel: AIChatModel
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Chat.updatedAt, ascending: false)],
        animation: .default
    ) var chats: FetchedResults<Chat>
    
    @State private var showNewChatSheet = false
    @State private var newChatTitle = ""
    @State private var isEditing = false
    @State private var chatToRename: Chat?
    @State private var renameText = ""
    
    // Environment value to get color scheme
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationSplitView {
            List {
                // MARK: - Create New Chat Button
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
                .listRowBackground(colorScheme == .dark ? 
                    Color.black.opacity(0.2) : 
                    Color.white.opacity(0.7))
                
                // MARK: - Section for Chats
                Section(header: Text("Your Conversations")
                    .font(.subheadline)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, 5)
                ) {
                    ForEach(chats) { chat in
                        NavigationLink(
                            destination: EnhancedChatView(chatEntity: chat, chat_title: .constant(chat.title ?? "Chat"))
                                .onAppear {
                                    aiChatModel.setCurrentChat(chat)
                                }
                        ) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(chat.title ?? "Untitled Chat")
                                        .fontWeight(.medium)
                                        .foregroundColor(Theme.textPrimary)
                                    
                                    // Show last message preview or date if no messages
                                    if let messages = chat.messages as? Set<Message>, 
                                       let lastMessage = messages.sorted(by: { 
                                            ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast) 
                                        }).first {
                                        Text(lastMessage.content ?? "")
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                            .lineLimit(1)
                                    } else {
                                        Text(formatDate(date: chat.createdAt ?? Date()))
                                            .font(.caption)
                                            .foregroundColor(Theme.textSecondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // Show timestamp or message count badge
                                if let date = chat.updatedAt {
                                    Text(timeAgo(date: date))
                                        .font(.caption2)
                                        .foregroundColor(Theme.textSecondary)
                                }
                            }
                            .padding(.vertical, 5)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteChat(chat)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                chatToRename = chat
                                renameText = chat.title ?? ""
                                isEditing = true
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(Theme.primary)
                        }
                    }
                    .onDelete(perform: deleteChats)
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
                    if let chat = chatToRename {
                        renameChat(chat, newName: renameText)
                    }
                }
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
            .background(Theme.backgroundPrimary)
        }
    }
    
    // MARK: - New Chat Sheet
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
                            .stroke(Theme.inputBorder, lineWidth: 1)
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
    
    // MARK: - Helper Functions
    
    private func createNewChat() {
        aiChatModel.createNewChat(title: newChatTitle.isEmpty ? "New Chat" : newChatTitle)
        
        // Reset the text field
        newChatTitle = ""
    }
    
    private func deleteChat(_ chat: Chat) {
        let context = PersistenceController.shared.container.viewContext
        context.delete(chat)
        try? context.save()
        
        // If the deleted chat was the current chat, set a new one
        if chat.id == aiChatModel.currentChat?.id, let firstChat = chats.first(where: { $0.id != chat.id }) {
            aiChatModel.setCurrentChat(firstChat)
        }
    }
    
    private func deleteChats(at offsets: IndexSet) {
        for index in offsets {
            let chat = chats[index]
            deleteChat(chat)
        }
    }
    
    private func renameChat(_ chat: Chat, newName: String) {
        chat.title = newName
        chat.updatedAt = Date()
        try? PersistenceController.shared.container.viewContext.save()
        
        // Update the AIChatModel if this is the current chat
        if chat.id == aiChatModel.currentChat?.id {
            aiChatModel.chat_name = newName
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
