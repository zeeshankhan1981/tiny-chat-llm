import SwiftUI
import CoreData

struct EnhancedChatView: View {
    @EnvironmentObject var aiChatModel: AIChatModel
    @Environment(\.managedObjectContext) private var viewContext
    
    // Optional binding to a chat entity
    var chatEntity: Chat?
    
    // Binding to chat title for backward compatibility
    @Binding var chat_title: String?
    
    @State var placeholderString: String = "Message"
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var reload_button_icon: String = "arrow.counterclockwise.circle"
    @State private var toggleEditChat = false
    @State private var clearChatAlert = false
    @State private var showingPerformanceStats = false
    
    @FocusState private var isInputFieldFocused: Bool
    @Namespace var bottomID
    
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
    
    // Component for date separators
    struct DateSeparator: View {
        let date: String
        
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
        }
    }
    
    private func groupMessagesByDate(_ messages: [Message]) -> [MessageGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: messages) { message in
            calendar.startOfDay(for: message.timestamp)
        }
        
        return grouped.map { (date, messages) in
            MessageGroup(date: date, messages: messages)
        }.sorted { $0.date < $1.date }
    }
    
    private func scrollToBottom(with_animation: Bool) {
        if with_animation {
            withAnimation {
                scrollProxy?.scrollTo("latest", anchor: .bottom)
            }
        } else {
            scrollProxy?.scrollTo("latest", anchor: .bottom)
        }
    }
    
    private func reload() {
        // If we're using CoreData, reload from the chat entity
        if let chat = aiChatModel.currentChat {
            aiChatModel.setCurrentChat(chat)
        } 
        // For backward compatibility
        else if let title = chat_title {
            aiChatModel.prepare(chat_title: title)
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
                        
                        // Empty text view at the bottom for scrolling reference
                        Text("")
                            .id("latest")
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.bottom, 4)
                    }
                    .listStyle(PlainListStyle())
                    .scrollContentBackground(.hidden)
                    .background(Theme.backgroundPrimary)
                    .onChange(of: aiChatModel.AI_typing) { _, _ in
                        scrollToBottom(with_animation: false)
                    }
                    .onAppear() {
                        scrollProxy = scrollView
                        scrollToBottom(with_animation: false)
                        
                        // Auto focus on the input field
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isInputFieldFocused = true
                        }
                    }
                }
                
                // Input area at bottom with message counter
                VStack(spacing: 0) {
                    // Performance metrics banner (conditionally shown)
                    if showingPerformanceStats, let lastMessage = aiChatModel.messages.last, 
                       lastMessage.tok_sec > 0 {
                        HStack {
                            Text("Last response: \(String(format: "%.1f", lastMessage.tok_sec)) tok/sec")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                            
                            Spacer()
                            
                            Button {
                                showingPerformanceStats.toggle()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption)
                                    .foregroundColor(Theme.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Theme.backgroundSecondary)
                    }
                    
                    // Text input area
                    LLMTextInput(messagePlaceholder: placeholderString)
                        .focused($isInputFieldFocused)
                }
                .background(Theme.backgroundSecondary)
            }
            .background(Theme.backgroundPrimary)
            .onChange(of: chat_title) { _, _ in
                Task {
                    self.reload()
                }
            }
            
            // Floating button for performance stats toggle
            Button {
                showingPerformanceStats.toggle()
            } label: {
                Image(systemName: showingPerformanceStats ? "gauge.with.dots.needle.bottom.50percent" : "gauge.with.dots.needle.bottom.50percent")
                    .foregroundColor(.white)
                    .padding(12)
                    .background(Theme.primary)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 80)
        }
        .navigationTitle(chat_title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        clearChatAlert = true
                    }) {
                        Label("Clear Conversation", systemImage: "trash")
                    }
                    
                    Button(action: {
                        reload()
                    }) {
                        Label("Reload Chat", systemImage: "arrow.clockwise")
                    }
                    
                    Toggle(isOn: $showingPerformanceStats) {
                        Label("Show Performance", systemImage: "gauge")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(Theme.primary)
                }
            }
        }
        .alert("Clear Conversation", isPresented: $clearChatAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearChat()
            }
        } message: {
            Text("Are you sure you want to clear this conversation? This cannot be undone.")
        }
        .onAppear {
            reload()
        }
    }
    
    private func clearChat() {
        // Clear chat history based on architecture
        if let chat = aiChatModel.currentChat {
            // Clear using CoreData
            if let messages = chat.messages as? Set<Message> {
                for message in messages {
                    viewContext.delete(message)
                }
                
                try? viewContext.save()
                aiChatModel.messages = []
            }
        } else {
            // Legacy clear
            if let title = chat_title {
                clear_chat_history(title)
                aiChatModel.messages = []
            }
        }
    }
}
