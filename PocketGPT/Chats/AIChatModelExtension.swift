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
                PersistenceController.shared.container.viewContext.delete(message)
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
        if self.sdPipeline != nil {
            Task.detached {
                await self.sdPipeline?.unloadResources()
            }
        }
        
        // Load the appropriate model
        if chat.title == "MobileVLM V2 3B" || chat.title == "Chat" {
            loadLlava()
        }
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
            var prompt = ""
            if self.chat_name == "Chat" || self.chat_name == "MobileVLM V2 3B" {
                prompt = getConversationPromptLlava(messages: self.messages)
            } else if self.chat_name == "Image Creation" {
                prompt = getConversationPromptSD(messages: self.messages)
            }
            
            var message = Message(sender: .system, text: "", tok_sec: 0)
            self.messages.append(message)
            let messageIndex = self.messages.endIndex - 1
            
            // Save initial empty system message
            if let chat = currentChat {
                _ = ChatManager.shared.addMessage(to: chat, from: message)
            }
            
            if self.chat_name == "Chat" || self.chat_name == "MobileVLM V2 3B" {
                await llamaState.completeLlava(
                    text: prompt,
                    { str in
                        message.state = .predicting
                        message.text += str
                        
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
            } else if self.chat_name == "Image Creation" {
                let pr = prompt
                self.AI_typing += 1
                try await Task.sleep(nanoseconds: 1_000_000_00) // wait 0.1 second for UI to update
                let image = await self.sdGen(prompt: pr)
                message.image = image
                self.AI_typing += 1
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
