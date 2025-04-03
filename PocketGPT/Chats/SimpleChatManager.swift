import Foundation
import SwiftUI

// A simple manager for handling multiple chats using the existing file-based system
class SimpleChatManager {
    static let shared = SimpleChatManager()
    
    // Get list of available chats
    func getAvailableChats() -> [String] {
        var chatTitles = ["MobileVLM V2 3B"] // Default chat
        
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
            print("Error finding chat files: \(error.localizedDescription)")
        }
        
        return chatTitles
    }
    
    // Create a new chat with default empty content
    func createNewChat(title: String) -> String {
        let newTitle = title.isEmpty ? "New Chat \(Date().timeIntervalSince1970)" : title
        
        // Create an empty chat history file
        let emptyMessages: [Message] = []
        save_chat_history(emptyMessages, newTitle)
        
        return newTitle
    }
    
    // Delete a chat by title
    func deleteChat(title: String) {
        clear_chat_history(title)
    }
    
    // Get timestamp for a chat (from its file)
    func getChatModificationDate(title: String) -> Date {
        do {
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let historyPath = documentsPath.appendingPathComponent("history")
            let chatFile = historyPath.appendingPathComponent("\(title).json")
            
            if fileManager.fileExists(atPath: chatFile.path) {
                let attributes = try fileManager.attributesOfItem(atPath: chatFile.path)
                if let modDate = attributes[.modificationDate] as? Date {
                    return modDate
                }
            }
        } catch {
            print("Error getting chat modification date: \(error.localizedDescription)")
        }
        
        return Date()
    }
}
