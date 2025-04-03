//
//  ChatListView.swift
//  PocketGPT
//
//

import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var aiChatModel: AIChatModel
    
    @State var searchText: String = ""
    @Binding var chat_titles: [String]
    @Binding var chat_title: String?
    @State var chats_previews:[Dictionary<String, String>] = []
    @State var current_detail_view_name:String? = "MobileVLM V2 3B"
    @State private var toggleSettings = false
    @State private var toggleAddChat = false
    @State private var newChatName: String = ""
    
    @State private var onStartup = true
    
    func get_chat_mode_list() -> [Dictionary<String, String>]?{
        var res: [Dictionary<String, String>] = []
        res.append(["title":"MobileVLM V2 3B","icon":"", "message":"", "time": "10:30 AM","model":"","chat":""])
        
        // Get other chats
        if let chatList = get_chats_list() {
            for chat in chatList {
                if let title = chat["title"], title != "MobileVLM V2 3B" && title != "Image Creation" {
                    res.append(chat)
                }
            }
        }
        
        return res
    }
    
    func refresh_chat_list(){
        self.chats_previews = get_chat_mode_list()!
        
        // Update chat titles
        var titles: [String] = []
        for chat in chats_previews {
            if let title = chat["title"] {
                titles.append(title)
            }
        }
        self.chat_titles = titles
    }
    
    func delete(at offsets: IndexSet) {
        let chatsToDelete = offsets.map { self.chats_previews[$0] }
        _ = delete_chats(chatsToDelete)
        
        // Force UI update immediately
        self.chats_previews.remove(atOffsets: offsets)
        refresh_chat_list()
        
        // Reset to default chat if needed
        if self.chat_titles.isEmpty || !self.chat_titles.contains(chat_title ?? "") {
            chat_title = "MobileVLM V2 3B"
            aiChatModel.prepare(chat_title: "MobileVLM V2 3B")
        }
    }
    
    func delete(at elem:Dictionary<String, String>){
        if delete_chats([elem]) {
            // Immediately remove from chat list
            self.chats_previews.removeAll(where: { $0["title"] == elem["title"] })
            refresh_chat_list()
            
            // Reset to default chat if needed
            if self.chat_titles.isEmpty || (chat_title == elem["title"]) {
                chat_title = "MobileVLM V2 3B"
                aiChatModel.prepare(chat_title: "MobileVLM V2 3B")
            }
        }
    }

    func duplicate(at elem:Dictionary<String, String>){
        _ = duplicate_chat(elem)
        refresh_chat_list()
    }
    
    func createNewChat() {
        if !newChatName.isEmpty {
            // Create a new chat with detailed settings that match the default model
            let chatInfo: [String: Any] = [
                "title": newChatName,
                "model": "MobileVLM V2 3B", // Use the same model as the default chat
                "inference": "llava",
                "prompt_format": "llava",
                "temperature": 0.6,
                "max_tokens": 1024,
                "created_at": Date().timeIntervalSince1970
            ]
            
            if create_chat(chatInfo) {
                // Initialize an empty chat history file for the new chat
                save_chat_history([], newChatName)
                
                // Update the UI
                refresh_chat_list()
                
                // Switch to the new chat and force model initialization
                chat_title = newChatName
                aiChatModel.modelType = "MobileVLM V2 3B" // Explicitly set model type
                aiChatModel.prepare(chat_title: newChatName)
                
                toggleAddChat = false
                newChatName = ""
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 5){
                // Add new chat button with Todoist-inspired design
                Button(action: {
                    toggleAddChat = true
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
                    .padding(.vertical, 10)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Chat List with Todoist-inspired styling
                VStack(){
                    List {
                        ForEach(chat_titles, id: \.self) { title in
                            // Use the traditional NavigationLink with destination view directly
                            NavigationLink(destination: ChatView(chat_title: .constant(title))
                                .environmentObject(aiChatModel)
                                .onAppear {
                                    chat_title = title
                                    aiChatModel.prepare(chat_title: title)
                                }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(title)
                                            .foregroundColor(Theme.textPrimary)
                                            .fontWeight(.medium)
                                        
                                        // Only show details for non-default chats
                                        if title != "MobileVLM V2 3B" {
                                            if let chat = chats_previews.first(where: { $0["title"] == title }),
                                               let time = chat["time"] {
                                                Text("Last updated: \(time)")
                                                    .font(.caption)
                                                    .foregroundColor(Theme.textSecondary)
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Only show delete button for non-default chats
                                    if title != "MobileVLM V2 3B" {
                                        Button(action: {
                                            if let chat = chats_previews.first(where: { $0["title"] == title }) {
                                                delete(at: chat)
                                            }
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(Theme.primary)
                                        }
                                        .buttonStyle(BorderlessButtonStyle())
                                    }
                                }
                            }
                        }
                        .onDelete(perform: delete)
                    }
                    .frame(maxHeight: .infinity)
                    .listStyle(InsetListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Theme.backgroundPrimary.opacity(0.1))
                }
                .background(.opacity(0))
                
            }
            .task {
                refresh_chat_list()
            }
            .navigationTitle("TinyChat")
            .foregroundColor(Theme.primary)
            .onAppear() {
                if onStartup {
                    chat_title = "MobileVLM V2 3B"
                    onStartup = false
                }
            }
            // Add Chat Alert
            .alert("New Chat", isPresented: $toggleAddChat) {
                TextField("Chat Name", text: $newChatName)
                Button("Cancel", role: .cancel) { newChatName = "" }
                Button("Create") { createNewChat() }
            } message: {
                Text("Enter a name for your new chat")
            }
        }
    }
}
