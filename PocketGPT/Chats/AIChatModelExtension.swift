import Foundation
import SwiftUI
import CoreData

// Extension to add CoreData support to existing AIChatModel
extension AIChatModel {
    // Set the current chat and load its messages
    func setCurrentChat(_ chat: ChatEntity) {
        self.currentChat = chat
        self.chat_name = chat.title ?? "Chat"
        
        // Load messages from CoreData
        loadMessagesFromCoreData()
        
        // Initialize the appropriate model based on chat title
        prepareModelForChat()
    }
    
    // Create a new chat
    func createNewChat(title: String = "New Chat") {
        let newChat = ChatManager.shared.createChat(title: title)
        setCurrentChat(newChat)
    }
    
    // Save current messages to CoreData
    private func saveMessagesToCoreData() {
        guard let chat = currentChat else { return }
        
        // Clear existing messages for this chat
        if let existingMessages = chat.messages as? Set<MessageEntity> {
            for message in existingMessages {
                // Use the same viewContext approach as in the main class
                viewContext.delete(message)
            }
        }
        
        // Add current messages to CoreData
        for message in messages {
            _ = ChatManager.shared.addMessage(to: chat, from: message)
        }
    }
    
    // Load messages from CoreData
    private func loadMessagesFromCoreData() {
        guard let chat = currentChat, let messagesSet = chat.messages as? Set<MessageEntity> else {
            self.messages = []
            return
        }
        
        // Sort messages by timestamp
        let sortedMessages = messagesSet.sorted { 
            ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast) 
        }
        
        // Convert MessageEntity objects to Message objects
        self.messages = sortedMessages.map { 
            ChatManager.shared.convertToMessage($0)
        }
    }
    
    // Initialize the model based on the chat title
    private func prepareModelForChat() {
        guard let chat = currentChat else { return }
        
        // Reset typing state
        self.AI_typing = -Int.random(in: 0..<100000)
        
        // Reset model state
        self.llamaState = LlamaState()
        
        // Load the appropriate model - only MobileVLM is supported now
        loadLlava()
    }
    
    // Override the send function to save messages to CoreData
    func sendAndSaveToCoreData(message text: String, image: Image? = nil) {
        let requestMessage = Message(sender: .user, state: .typed, text: text, tok_sec: 0, image: image)
        self.messages.append(requestMessage)
        
        // Save the user message to CoreData
        if let chat = currentChat {
            _ = ChatManager.shared.addMessage(to: chat, from: requestMessage)
        }
        
        // Continue with normal sending process
        self.AI_typing += 1
        self.numberOfTokens = 0
        self.total_sec = 0.0
        self.start_predicting_time = DispatchTime.now()
        
        Task {
            // For all chat types, use Llava now
            let prompt = getConversationPromptLlava(messages: self.messages)
            
            var message = Message(sender: .system, text: "", tok_sec: 0)
            self.messages.append(message)
            
            // Guard against array access errors
            guard !self.messages.isEmpty, self.messages.count > 1 else {
                print("Error: messages array is empty or has insufficient elements")
                return
            }
            
            let messageIndex = self.messages.endIndex - 1
            
            // Save initial empty system message
            if let chat = currentChat {
                _ = ChatManager.shared.addMessage(to: chat, from: message)
            }
            
            // Process with Llava
            await llamaState.completeLlava(
                text: prompt,
                { str in
                    message.state = .predicting
                    message.text += str
                    
                    // Guard against race conditions by checking array bounds
                    guard messageIndex < self.messages.count else {
                        print("Error: messageIndex out of bounds")
                        return
                    }
                    
                    var updatedMessages = self.messages
                    updatedMessages[messageIndex] = message
                    self.messages = updatedMessages
                    
                    // Update the message in CoreData periodically (not every token to avoid performance issues)
                    if self.numberOfTokens % 10 == 0, let chat = self.currentChat {
                        Task {
                            _ = ChatManager.shared.addMessage(to: chat, from: message)
                        }
                    }
                    
                    self.AI_typing += 1
                    self.numberOfTokens += 1
                }
            )
            self.total_sec = Double((DispatchTime.now().uptimeNanoseconds - self.start_predicting_time.uptimeNanoseconds)) / 1_000_000_000
            message.tok_sec = Double(self.numberOfTokens)/self.total_sec
            print("number of tokens: \(self.numberOfTokens), total time: \(self.total_sec), token/sec: \(message.tok_sec)")
            
            // Guard against another potential array bounds issue
            guard messageIndex < self.messages.count else {
                print("Error: messageIndex out of bounds when finalizing message")
                return
            }
            
            // Final update to CoreData
            if let chat = currentChat {
                _ = ChatManager.shared.addMessage(to: chat, from: message)
            }
            
            message.state = .predicted(totalSecond:0)
            self.messages[messageIndex] = message
            llamaState.answer = ""
            self.AI_typing = 0
        }
    }
}