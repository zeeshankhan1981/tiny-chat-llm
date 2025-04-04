import SwiftUI
import CoreData

/// A unified chat list view that combines the best features from:
/// - ChatListView: Traditional NavigationView with file-based storage
/// - NewChatListView: CoreData-based storage with NavigationSplitView
/// - MultiChatView: File-based with NavigationSplitView
struct UnifiedChatListView: View {
    // MARK: - Environment and State
    @EnvironmentObject var aiChatModel: AIChatModel
    
    // CoreData fetch request for chats
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Chat.updatedAt, ascending: false)],
        animation: .default
    ) private var coreDataChats: FetchedResults<Chat>
    
    // File-based chat storage (legacy support)
    @State private var fileBasedChats: [Dictionary<String, String>] = []
    @State private var chatTitles: [String] = []
    @State private var selectedChatTitle: String? = nil
    
    // UI state
    @State private var showNewChatSheet = false
    @State private var newChatTitle = ""
    @State private var isEditingChat = false
    @State private var renameText = ""
    @State private var chatToRename: Chat?
    @State private var fileBasedChatToRename: String?
    @State private var searchText = ""
    @State private var showingCoreData = false
    
    // Environment values
    @Environment(\.colorScheme) private var colorScheme
    
    // MARK: - Computed Properties
    
    /// Determines if we should use CoreData or file-based storage
    private var usesCoreData: Bool {
        // Check if there are any CoreData chats
        return showingCoreData || !coreDataChats.isEmpty
    }
    
    /// Filtered chats based on search text
    private var filteredCoreDataChats: [Chat] {
        if searchText.isEmpty {
            return Array(coreDataChats)
        } else {
            return coreDataChats.filter { chat in
                guard let title = chat.title else { return false }
                return title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    /// Filtered file-based chats
    private var filteredFileChats: [Dictionary<String, String>] {
        if searchText.isEmpty {
            return fileBasedChats
        } else {
            return fileBasedChats.filter { chat in
                guard let title = chat["title"] else { return false }
                return title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Storage toggle for debug/development
                #if DEBUG
                Toggle("Use CoreData", isOn: $showingCoreData)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Theme.backgroundSecondary)
                #endif
                
                // Search field
                SearchBarView(text: $searchText)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // Create new chat button
                Button(action: {
                    showNewChatSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Theme.primary)
                        Text("New Chat")
                            .foregroundColor(Theme.textPrimary)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(colorScheme == .dark ? 
                                  Color.black.opacity(0.2) : 
                                  Color.white.opacity(0.7))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Divider()
                
                // Chat list
                if usesCoreData {
                    CoreDataChatList(
                        chats: filteredCoreDataChats,
                        selectedChatTitle: $selectedChatTitle,
                        onDeleteChat: deleteChat,
                        onRenameChat: prepareRenameChat
                    )
                } else {
                    FileBasedChatList(
                        chats: filteredFileChats,
                        selectedChatTitle: $selectedChatTitle,
                        onDeleteChat: deleteFileBasedChat,
                        onRenameChat: prepareRenameFileBasedChat
                    )
                }
            }
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
            .onAppear {
                refreshChatLists()
            }
            .sheet(isPresented: $showNewChatSheet) {
                NewChatSheetView(
                    newChatTitle: $newChatTitle,
                    onCreateChat: createNewChat,
                    onDismiss: { showNewChatSheet = false }
                )
            }
            .alert("Rename Chat", isPresented: $isEditingChat) {
                TextField("Chat Name", text: $renameText)
                Button("Cancel", role: .cancel) { }
                Button("Rename") {
                    if let chat = chatToRename {
                        renameCoreDataChat(chat, newName: renameText)
                    } else if let title = fileBasedChatToRename {
                        renameFileBasedChat(title, newName: renameText)
                    }
                }
            }
            .withLoadingOverlay(aiChatModel: aiChatModel)
        } detail: {
            // Default detail view when no chat is selected
            if let selectedTitle = selectedChatTitle {
                if usesCoreData,
                   let selectedChat = coreDataChats.first(where: { $0.title == selectedTitle }) {
                    EnhancedChatView(
                        chatEntity: selectedChat,
                        chat_title: $selectedChatTitle
                    )
                    .onAppear {
                        aiChatModel.setCurrentChat(selectedChat)
                    }
                    .withLoadingOverlay(aiChatModel: aiChatModel)
                } else {
                    // Use traditional chat view for file-based storage
                    ChatView(chat_title: $selectedChatTitle)
                        .onAppear {
                            aiChatModel.prepare(chat_title: selectedTitle)
                        }
                        .withLoadingOverlay(aiChatModel: aiChatModel)
                }
            } else {
                // Welcome view when no chat is selected
                WelcomeView(onCreateNewChat: { showNewChatSheet = true })
                    .withLoadingOverlay(aiChatModel: aiChatModel)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    /// Refresh both CoreData and file-based chat lists
    private func refreshChatLists() {
        // For file-based storage
        if let chatsList = get_chat_mode_list() {
            self.fileBasedChats = chatsList
            self.chatTitles = chatsList.compactMap { $0["title"] }
        }
    }
    
    /// Get chat mode list from file-based storage
    private func get_chat_mode_list() -> [Dictionary<String, String>]? {
        var result: [Dictionary<String, String>] = []
        
        // Get other chats
        if let chatList = get_chats_list() {
            for chat in chatList {
                if let title = chat["title"], title != "Image Creation" && title != "MobileVLM V2 3B" {
                    result.append(chat)
                }
            }
        }
        
        return result
    }
    
    // MARK: - CoreData Operations
    
    /// Create a new chat
    private func createNewChat() {
        let title = newChatTitle.isEmpty ? "New Chat" : newChatTitle
        
        if usesCoreData {
            // Create CoreData chat
            aiChatModel.createNewChat(title: title)
            
            // Set as selected chat
            if let newChat = coreDataChats.first(where: { $0.title == title }) {
                selectedChatTitle = title
                aiChatModel.setCurrentChat(newChat)
            }
        } else {
            // Create file-based chat
            let chatInfo: [String: Any] = [
                "title": title,
                "inference": "llava",
                "prompt_format": "llava",
                "temperature": 0.6,
                "max_tokens": 1024,
                "created_at": Date().timeIntervalSince1970
            ]
            
            if create_chat(chatInfo) {
                save_chat_history([], title)
                refreshChatLists()
                selectedChatTitle = title
                aiChatModel.prepare(chat_title: title)
            }
        }
        
        // Reset UI state
        newChatTitle = ""
    }
    
    /// Delete a CoreData chat
    private func deleteChat(_ chat: Chat) {
        let context = PersistenceController.shared.container.viewContext
        
        // If this is the selected chat, select another one
        if chat.title == selectedChatTitle {
            if let firstChat = coreDataChats.first(where: { $0.id != chat.id }) {
                selectedChatTitle = firstChat.title
                aiChatModel.setCurrentChat(firstChat)
            } else {
                // No selection when no chats exist
                selectedChatTitle = nil
                // Still prepare the model in the background
                aiChatModel.prepare(chat_title: "")
            }
        }
        
        context.delete(chat)
        try? context.save()
    }
    
    /// Prepare to rename a CoreData chat
    private func prepareRenameChat(_ chat: Chat) {
        chatToRename = chat
        fileBasedChatToRename = nil
        renameText = chat.title ?? ""
        isEditingChat = true
    }
    
    /// Rename a CoreData chat
    private func renameCoreDataChat(_ chat: Chat, newName: String) {
        // Update CoreData entity
        chat.title = newName
        chat.updatedAt = Date()
        try? PersistenceController.shared.container.viewContext.save()
        
        // Update AIChatModel if this is the current chat
        if chat.id == aiChatModel.currentChat?.id {
            aiChatModel.chat_name = newName
        }
        
        // Update selected chat title if needed
        if selectedChatTitle == chat.title {
            selectedChatTitle = newName
        }
    }
    
    // MARK: - File-based Operations
    
    /// Delete a file-based chat
    private func deleteFileBasedChat(_ chatTitle: String) {
        // Find the chat dictionary
        if let chat = fileBasedChats.first(where: { $0["title"] == chatTitle }) {
            if delete_chats([chat]) {
                // Update local state
                fileBasedChats.removeAll(where: { $0["title"] == chatTitle })
                chatTitles.removeAll(where: { $0 == chatTitle })
                
                // If this was the selected chat, select another one
                if selectedChatTitle == chatTitle {
                    selectedChatTitle = chatTitles.first
                    aiChatModel.prepare(chat_title: selectedChatTitle ?? "")
                }
            }
        }
    }
    
    /// Prepare to rename a file-based chat
    private func prepareRenameFileBasedChat(_ chatTitle: String) {
        chatToRename = nil
        fileBasedChatToRename = chatTitle
        renameText = chatTitle
        isEditingChat = true
    }
    
    /// Rename a file-based chat
    private func renameFileBasedChat(_ oldTitle: String, newName: String) {
        // For file-based chats, we need to:
        // 1. Create a new chat with the new name
        // 2. Copy the messages
        // 3. Delete the old chat
        
        // Create new chat
        let chatInfo: [String: Any] = [
            "title": newName,
            "inference": "llava",
            "prompt_format": "llava",
            "temperature": 0.6,
            "max_tokens": 1024,
            "created_at": Date().timeIntervalSince1970
        ]
        
        if create_chat(chatInfo) {
            // Copy messages
            if let messages = load_chat_history(oldTitle) {
                save_chat_history(messages, newName)
            }
            
            // Delete old chat
            if let chat = fileBasedChats.first(where: { $0["title"] == oldTitle }) {
                _ = delete_chats([chat])
            }
            
            // Update UI
            refreshChatLists()
            
            // Update selected chat
            if selectedChatTitle == oldTitle {
                selectedChatTitle = newName
                aiChatModel.prepare(chat_title: newName)
            }
        }
    }
}

// MARK: - Supporting Views

/// Search bar view
struct SearchBarView: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.textSecondary)
            
            TextField("Search chats", text: $text)
                .foregroundColor(Theme.textPrimary)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
        )
    }
}

/// CoreData-based chat list
struct CoreDataChatList: View {
    let chats: [Chat]
    @Binding var selectedChatTitle: String?
    var onDeleteChat: (Chat) -> Void
    var onRenameChat: (Chat) -> Void
    
    var body: some View {
        List {
            Section(header: Text("Your Conversations")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary)
                .padding(.top, 5)
            ) {
                ForEach(chats) { chat in
                    NavigationLink(
                        destination: EnhancedChatView(
                            chatEntity: chat,
                            chat_title: $selectedChatTitle
                        )
                    ) {
                        CoreDataChatCell(chat: chat)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            onDeleteChat(chat)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            onRenameChat(chat)
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(Theme.primary)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

/// CoreData chat cell
struct CoreDataChatCell: View {
    let chat: Chat
    
    var body: some View {
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
            
            // Show timestamp
            if let date = chat.updatedAt {
                Text(timeAgo(date: date))
                    .font(.caption2)
                    .foregroundColor(Theme.textSecondary)
            }
        }
        .padding(.vertical, 5)
    }
    
    private func formatDate(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func timeAgo(date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// File-based chat list
struct FileBasedChatList: View {
    let chats: [Dictionary<String, String>]
    @Binding var selectedChatTitle: String?
    var onDeleteChat: (String) -> Void
    var onRenameChat: (String) -> Void
    
    var body: some View {
        List {
            ForEach(chats, id: \.self) { chat in
                if let title = chat["title"] {
                    NavigationLink(
                        destination: ChatView(chat_title: $selectedChatTitle)
                    ) {
                        FileBasedChatCell(chat: chat)
                    }
                    .swipeActions(edge: .trailing) {
                        // Only show delete/rename for non-default chats
                        if title != "Image Creation" {
                            Button(role: .destructive) {
                                onDeleteChat(title)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            
                            Button {
                                onRenameChat(title)
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            .tint(Theme.primary)
                        }
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

/// File-based chat cell
struct FileBasedChatCell: View {
    let chat: Dictionary<String, String>
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chat["title"] ?? "Untitled Chat")
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                
                // Only show details for non-default chats
                if let title = chat["title"], 
                   title != "Image Creation",
                   let time = chat["time"] {
                    Text("Last updated: \(time)")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            Spacer()
            
            // Only show delete button for non-default chats in row view
            if let title = chat["title"], title != "Image Creation" {
                Button(action: {
                    // Handle deletion via parent view
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(Theme.primary)
                }
                .buttonStyle(BorderlessButtonStyle())
                .opacity(0) // Hidden since we use swipe actions
            }
        }
    }
}

/// New chat sheet view
struct NewChatSheetView: View {
    @Binding var newChatTitle: String
    var onCreateChat: () -> Void
    var onDismiss: () -> Void
    
    var body: some View {
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
                    onCreateChat()
                    onDismiss()
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
                onDismiss()
            })
        }
    }
}

/// Empty state welcome view
struct WelcomeView: View {
    var onCreateNewChat: () -> Void
    
    var body: some View {
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
            
            Button(action: onCreateNewChat) {
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