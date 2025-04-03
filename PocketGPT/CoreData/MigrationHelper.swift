import Foundation
import CoreData
import SwiftUI

class MigrationHelper {
    static let shared = MigrationHelper()
    
    private init() {}
    
    func migrateExistingFileBasedChats() {
        // Get existing chat titles
        let chatManager = ChatManager.shared
        let existingChatTitles = getExistingChatTitles()
        
        // Log migration start
        print("Starting migration of \(existingChatTitles.count) file-based chats")
        
        // Create CoreData entries for each existing chat
        for chatTitle in existingChatTitles {
            if let messages = load_chat_history(chatTitle) {
                print("Migrating chat: \(chatTitle) with \(messages.count) messages")
                
                // Create new chat entity
                let newChat = chatManager.createChat(title: chatTitle)
                
                // Add all messages to the chat
                for message in messages {
                    chatManager.addMessage(to: newChat, from: message)
                }
            }
        }
        
        print("Migration complete!")
    }
    
    private func getExistingChatTitles() -> [String] {
        // Default chats we know exist
        var chatTitles = ["MobileVLM V2 3B"]
        
        // Check file system for any other chat history files
        do {
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let historyPath = documentsPath.appendingPathComponent("history")
            
            if fileManager.fileExists(atPath: historyPath.path) {
                let files = try fileManager.contentsOfDirectory(at: historyPath, includingPropertiesForKeys: nil)
                for file in files {
                    if file.pathExtension == "json" {
                        let chatName = file.deletingPathExtension().lastPathComponent
                        if !chatTitles.contains(chatName) {
                            chatTitles.append(chatName)
                        }
                    }
                }
            }
        } catch {
            print("Error finding existing chats: \(error.localizedDescription)")
        }
        
        return chatTitles
    }
}
