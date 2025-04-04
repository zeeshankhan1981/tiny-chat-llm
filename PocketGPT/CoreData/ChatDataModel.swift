import Foundation
import CoreData
import SwiftUI

// MARK: - Core Data Models

// Chat model
class Chat: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var messages: NSSet?
    
    // Get last message in the chat
    var lastMessage: Message? {
        guard let messages = messages as? Set<Message> else { return nil }
        return messages.sorted { 
            ($0.timestamp ?? Date.distantPast) > ($1.timestamp ?? Date.distantPast)
        }.first
    }
    
    // Get all messages in chronological order
    var orderedMessages: [Message] {
        guard let messages = messages as? Set<Message> else { return [] }
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
}

// Message model
class Message: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID?
    @NSManaged public var content: String?
    @NSManaged public var isUserMessage: Bool
    @NSManaged public var timestamp: Date?
    @NSManaged public var imageData: Data?
    @NSManaged public var tokensPerSecond: Double
    @NSManaged public var state: Int16
    @NSManaged public var chat: Chat?
    
    // Convert to app's Message model
    func toUIMessage() -> PocketGPT.Message {
        let sender: PocketGPT.Message.Sender = isUserMessage ? .user : .system
        var state = intToUIMessageState(Int(self.state))
        
        var image: Image? = nil
        if let imageData = imageData, let uiImage = UIImage(data: imageData) {
            image = Image(uiImage: uiImage)
        }
        
        return PocketGPT.Message(
            id: id ?? UUID(),
            sender: sender,
            state: state,
            text: content ?? "",
            tok_sec: tokensPerSecond,
            image: image,
            timestamp: timestamp ?? Date()
        )
    }
    
    // Helper to convert Int to Message.State
    private func intToUIMessageState(_ value: Int) -> PocketGPT.Message.State {
        switch value {
        case 0:
            return .none
        case 1:
            return .error
        case 2:
            return .typed
        case 3:
            return .predicting
        case 4:
            return .predicted(totalSecond: 0)
        default:
            return .none
        }
    }
}

// MARK: - CoreData Access
// Use the standard PersistenceController from PersistenceController.swift
