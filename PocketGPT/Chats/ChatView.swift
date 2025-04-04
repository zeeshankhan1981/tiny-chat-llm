//
//  ChatView.swift
//  PocketGPT
//
//

import SwiftUI

struct ChatView: View {
    
    @EnvironmentObject var aiChatModel: AIChatModel
    
    @State var placeholderString: String = "Message"
    
    enum FocusedField {
        case firstName, lastName
    }
    
    @Binding var chat_title: String?
    @State private var reload_button_icon: String = "arrow.counterclockwise.circle"
    
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    @State private var scrollTarget: Int?
    @State private var toggleEditChat = false
    @State private var clearChatAlert = false

    @FocusState private var focusedField: FocusedField?
    
    @Namespace var bottomID
    
    @FocusState
    private var isInputFieldFocused: Bool
    
    // Structure to group messages by date
    private struct MessageGroup: Identifiable {
        var id = UUID()
        var date: Date
        var messages: [Message]
        
        // Format date for section header
        func formattedDate() -> String {
            let formatter = DateFormatter()
            
            // Check if date is today, yesterday, or within the last week
            if Calendar.current.isDateInToday(date) {
                return "Today"
            } else if Calendar.current.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                formatter.dateFormat = "EEEE, MMM d"
                return formatter.string(from: date)
            }
        }
    }
    
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
    
    private var scrollToBottomButton: some View {
        Button(action: {
            scrollToBottom()
        }) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(Theme.primary)
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
                .background(Color.white.opacity(0.8))
                .clipShape(Circle())
        }
    }
    
    private func reload() {
        let title = chat_title ?? ""
        
        if chat_title == "Chat" || chat_title == "MobileVLM V2 3B" {
            aiChatModel.messages = []
        } else {
            aiChatModel.chat_name = title
            
#if !targetEnvironment(simulator)
            let last_msg_count = aiChatModel.messages.count
#endif
            if let history = load_chat_history(title) {
                aiChatModel.messages = history
            }
        }
        
        self.scrollToBottom(with_animation: false)
    }
    
    func scrollToBottom(with_animation: Bool = true) {
#if targetEnvironment(simulator)
        let scroll_bug = false
#else
        let scroll_bug = true
#endif
        if scroll_bug {
            return
        }
        let last_msg = aiChatModel.messages.last
        if let scrollProxy = scrollProxy {
            if with_animation {
                withAnimation {
                    scrollProxy.scrollTo("latest")
                }
            } else {
                scrollProxy.scrollTo("latest")
            }
        }
    }
    
    // This method needs to be private since it uses the private MessageGroup type
    private func groupMessagesByDate(_ messages: [Message]) -> [MessageGroup] {
        var groups: [MessageGroup] = []
        let calendar = Calendar.current
        
        for message in messages {
            // Use a default date if timestamp is missing
            let messageDate = message.timestamp ?? Date()
            let dateComponents = calendar.dateComponents([.day, .month, .year], from: messageDate)
            let dateOnly = calendar.date(from: dateComponents) ?? messageDate
            
            if let index = groups.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: dateOnly) }) {
                // Add to existing group
                groups[index].messages.append(message)
            } else {
                // Create new group
                let newGroup = MessageGroup(date: dateOnly, messages: [message])
                groups.append(newGroup)
            }
        }
        
        // Sort groups by date (oldest first)
        return groups.sorted { $0.date < $1.date }
    }
    
    // Date separator view for chat sections
    struct DateSeparator: View {
        let date: String
        
        var body: some View {
            HStack {
                VStack { Divider() }
                Text(date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                VStack { Divider() }
            }
            .padding(.vertical, 8)
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                ScrollViewReader { scrollView in
                    List {
                        // Group messages by date and display with separators
                        ForEach(groupMessagesByDate(aiChatModel.messages)) { group in
                            Section {
                                DateSeparator(date: group.formattedDate())
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.clear)
                                
                                ForEach(group.messages) { message in
                                    MessageView(message: message)
                                        .id(message.id)
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .padding(.horizontal, 4)
                                }
                            }
                        }
                        
                        Text("")
                            .id("latest")
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.bottom, 4)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Theme.backgroundPrimary)
                    .onChange(of: aiChatModel.AI_typing) { ai_typing in
                        scrollToBottom(with_animation: false)
                    }
                    .onAppear() {
                        scrollProxy = scrollView
                        scrollToBottom(with_animation: false)
                        focusedField = .firstName
                    }
                }
                
                // Input area at bottom
                LLMTextInput(messagePlaceholder: placeholderString)
                    .focused($focusedField, equals: .firstName)
                    .environmentObject(aiChatModel)
            }
            .background(Theme.backgroundPrimary)
            .onChange(of: chat_title) { chat_name in
                Task {
                    self.reload()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            clearChatAlert = true
                        }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(Theme.primary)
                            .font(.system(size: 16, weight: .regular))
                    }
                    .alert("Delete Conversation", isPresented: $clearChatAlert) {
                        Button("Cancel", role: .cancel) { }
                        Button("Delete", role: .destructive) {
                            aiChatModel.messages = []
                            clear_chat_history(aiChatModel.chat_name)
                        }
                    } message: {
                        Text("Conversation history will be permanently deleted.")
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    if let title = chat_title {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            
            // Scroll to bottom button
            if aiChatModel.messages.count > 5 {
                scrollToBottomButton
                    .padding(.trailing, 16)
                    .padding(.bottom, 80)
            }
        }
        .overlay(
            VStack {
                if isModelLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading model...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    )
                    .padding(.top, 20)
                }
                Spacer()
            }
        )
    }
}
