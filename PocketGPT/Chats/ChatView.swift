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
    
    // Group messages by date
    private func groupMessagesByDate(_ messages: [Message]) -> [MessageGroup] {
        let calendar = Calendar.current
        
        // Group messages by day
        let grouped = Dictionary(grouping: messages) { message in
            calendar.startOfDay(for: message.timestamp)
        }
        
        // Convert to MessageGroup array and sort by date
        return grouped.map { (date, messages) in
            MessageGroup(date: date, messages: messages.sorted { $0.timestamp < $1.timestamp })
        }.sorted { $0.date < $1.date }
    }
    
    func scrollToBottom(with_animation: Bool = false) {
        var scroll_bug = true
#if os(macOS)
        scroll_bug = false
#else
        if #available(iOS 16.4, *){
            scroll_bug = false
        }
#endif
        if scroll_bug {
            return
        }
        let last_msg = aiChatModel.messages.last
        if last_msg != nil && last_msg?.id != nil && scrollProxy != nil {
            if with_animation {
                withAnimation {
                    scrollProxy?.scrollTo("latest")
                }
            } else {
                scrollProxy?.scrollTo("latest")
            }
        }
    }
    
    func reload() {
        guard let chat_title else {
            return
        }
        print("\nreload\n")
        if chat_title == "Chat" || chat_title == "MobileVLM V2 3B" {
            placeholderString = "Message"
        } else if chat_title == "Image Creation" {
            placeholderString = "Describe the image"
        }
        aiChatModel.prepare(chat_title: chat_title)
    }
    
    private func delayIconChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            reload_button_icon = "arrow.counterclockwise.circle"
        }
    }
    
    private var scrollToBottomButton: some View {
        Button {
            Task {
                scrollToBottom(with_animation: true)
            }
        } label: {
            Image(systemName: "arrow.down.circle.fill")
                .resizable()
                .foregroundColor(Theme.primary)
                .frame(width: 32, height: 32)
                .background(Theme.backgroundPrimary)
                .clipShape(Circle())
                .shadow(color: Theme.shadowColor, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(BorderlessButtonStyle())
        .padding(.bottom, 8)
    }
    
    // Custom date separator similar to Todoist's style
    private struct DateSeparator: View {
        var date: String
        
        var body: some View {
            HStack {
                VStack { Divider().background(Theme.divider) }
                Text(date)
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 8)
                VStack { Divider().background(Theme.divider) }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
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
    }
}
