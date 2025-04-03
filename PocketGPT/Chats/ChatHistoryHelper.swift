import Foundation
import SwiftUI

// Helper functions for chat history management
// These are used by both AIChatModel and our new MultiChatView

// Codable struct for message serialization
struct MessageData: Codable {
    let sender: String
    let state: Int
    let text: String
    let tokSec: Double
    let imageData: String?
    
    init(from message: Message) {
        self.sender = message.sender == .user ? "user" : "ai"
        self.state = message.state.rawValue
        self.text = message.text
        self.tokSec = message.tok_sec
        
        // Convert image to data if present
        if let image = message.image {
            let renderer = ImageRenderer(content: image.resizable().aspectRatio(contentMode: .fit).frame(width: 300, height: 300))
            if let uiImage = renderer.uiImage {
                self.imageData = uiImage.jpegData(compressionQuality: 0.8)?.base64EncodedString()
            } else {
                self.imageData = nil
            }
        } else {
            self.imageData = nil
        }
    }
    
    func toMessage() -> Message {
        let sender: MessageSender = (self.sender == "user") ? .user : .ai
        let state = MessageState(rawValue: self.state) ?? .typed
        
        var image: Image? = nil
        
        // Convert base64 image data back to an Image if present
        if let imageDataString = self.imageData,
           let imageData = Data(base64Encoded: imageDataString),
           let uiImage = UIImage(data: imageData) {
            image = Image(uiImage: uiImage)
        }
        
        return Message(sender: sender, state: state, text: self.text, tok_sec: self.tokSec, image: image)
    }
}

// Save chat history to a JSON file
func save_chat_history(_ messages: [Message], _ chat_name: String) {
    do {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let historyPath = documentsPath.appendingPathComponent("history")
        
        // Create history directory if it doesn't exist
        if !fileManager.fileExists(atPath: historyPath.path) {
            try fileManager.createDirectory(at: historyPath, withIntermediateDirectories: true)
        }
        
        let fileURL = historyPath.appendingPathComponent("\(chat_name).json")
        
        // Convert messages to serializable format
        let messageData = messages.map { MessageData(from: $0) }
        let jsonData = try JSONEncoder().encode(messageData)
        try jsonData.write(to: fileURL)
        
        print("Saved chat history to \(fileURL.path)")
    } catch {
        print("Error saving chat history: \(error.localizedDescription)")
    }
}

// Load chat history from a JSON file
func load_chat_history(_ chat_name: String) -> [Message]? {
    do {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let historyPath = documentsPath.appendingPathComponent("history")
        let fileURL = historyPath.appendingPathComponent("\(chat_name).json")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            let jsonData = try Data(contentsOf: fileURL)
            let messageData = try JSONDecoder().decode([MessageData].self, from: jsonData)
            return messageData.map { $0.toMessage() }
        }
    } catch {
        print("Error loading chat history: \(error.localizedDescription)")
    }
    
    return []
}

// Clear chat history (delete the file)
func clear_chat_history(_ chat_name: String) {
    do {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let historyPath = documentsPath.appendingPathComponent("history")
        let fileURL = historyPath.appendingPathComponent("\(chat_name).json")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
            print("Deleted chat history at \(fileURL.path)")
        }
    } catch {
        print("Error deleting chat history: \(error.localizedDescription)")
    }
}
