import Foundation
import CoreData
import SwiftUI

extension ChatEntity {
    // Get last message in the chat
    var lastMessage: MessageEntity? {
        guard let messages = messages as? Set<MessageEntity> else { return nil }
        return messages.sorted { 
            ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast)
        }.first
    }
    
    // Get all messages in chronological order
    var orderedMessages: [MessageEntity] {
        guard let messages = messages as? Set<MessageEntity> else { return [] }
        return messages.sorted {
            ($0.timestamp ?? Date.distantPast) < ($1.timestamp ?? Date.distantPast)
        }
    }
    
    // Get preview text for the chat (from last message)
    var previewText: String {
        if let content = lastMessage?.content, !content.isEmpty {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return "New conversation"
        }
    }
    
    // Get formatted timestamp for last message
    var formattedLastActivityTime: String {
        if let date = lastMessage?.timestamp ?? updatedAt {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        return ""
    }
    
    // Get message count
    var messageCount: Int {
        guard let messages = messages as? Set<MessageEntity> else { return 0 }
        return messages.count
    }
    
    // Convert all messages to [Message] array for the app
    func convertToMessageArray() -> [Message] {
        let messageEntities = orderedMessages
        return messageEntities.map { entity in
            entity.toMessage()
        }
    }
    
    // Add a new message to this chat
    func addMessage(content: String, isFromUser: Bool, image: Image? = nil) -> MessageEntity {
        let context = PersistenceController.shared.container.viewContext
        let newMessage = MessageEntity(context: context)
        
        newMessage.id = UUID()
        newMessage.content = content
        newMessage.isFromUser = isFromUser
        newMessage.timestamp = Date()
        newMessage.chat = self
        
        // Convert SwiftUI Image to data if it exists
        if let image = image {
            let renderer = ImageRenderer(content: image.resizable().aspectRatio(contentMode: .fit).frame(width: 300, height: 300))
            if let uiImage = renderer.uiImage {
                newMessage.imageData = uiImage.jpegData(compressionQuality: 0.8)
            }
        }
        
        // Update chat's updated timestamp
        self.updatedAt = Date()
        
        // Save context
        do {
            try context.save()
        } catch {
            print("Error saving message: \(error)")
        }
        
        return newMessage
    }
}
