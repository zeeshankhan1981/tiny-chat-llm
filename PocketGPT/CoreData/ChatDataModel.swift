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

// MARK: - Persistence Controller

class PersistenceController {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        // Use NSInMemoryStoreType for testing
        container = NSPersistentContainer(name: "ChatModel")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Error loading Core Data: \(error.localizedDescription)")
            }
        }
        
        // Setup auto-merging of contexts
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func saveContext() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error.localizedDescription)")
            }
        }
    }
    
    // Helper function to create the Core Data model programmatically
    func createCoreDataModel() {
        let modelURL = Bundle.main.url(forResource: "ChatModel", withExtension: "momd")!
        let model = NSManagedObjectModel(contentsOf: modelURL)!
        
        // Define Chat entity
        let chatEntity = NSEntityDescription()
        chatEntity.name = "Chat"
        chatEntity.managedObjectClassName = "Chat"
        
        // Define Message entity
        let messageEntity = NSEntityDescription()
        messageEntity.name = "Message"
        messageEntity.managedObjectClassName = "Message"
        
        // Define Chat attributes
        let chatIDAttr = NSAttributeDescription()
        chatIDAttr.name = "id"
        chatIDAttr.attributeType = .UUIDAttributeType
        
        let chatTitleAttr = NSAttributeDescription()
        chatTitleAttr.name = "title"
        chatTitleAttr.attributeType = .stringAttributeType
        
        let chatCreatedAtAttr = NSAttributeDescription()
        chatCreatedAtAttr.name = "createdAt"
        chatCreatedAtAttr.attributeType = .dateAttributeType
        
        let chatUpdatedAtAttr = NSAttributeDescription()
        chatUpdatedAtAttr.name = "updatedAt"
        chatUpdatedAtAttr.attributeType = .dateAttributeType
        
        chatEntity.properties = [chatIDAttr, chatTitleAttr, chatCreatedAtAttr, chatUpdatedAtAttr]
        
        // Define Message attributes
        let messageIDAttr = NSAttributeDescription()
        messageIDAttr.name = "id"
        messageIDAttr.attributeType = .UUIDAttributeType
        
        let messageContentAttr = NSAttributeDescription()
        messageContentAttr.name = "content"
        messageContentAttr.attributeType = .stringAttributeType
        
        let messageIsUserMessageAttr = NSAttributeDescription()
        messageIsUserMessageAttr.name = "isUserMessage"
        messageIsUserMessageAttr.attributeType = .booleanAttributeType
        
        let messageTimestampAttr = NSAttributeDescription()
        messageTimestampAttr.name = "timestamp"
        messageTimestampAttr.attributeType = .dateAttributeType
        
        let messageImageDataAttr = NSAttributeDescription()
        messageImageDataAttr.name = "imageData"
        messageImageDataAttr.attributeType = .binaryDataAttributeType
        messageImageDataAttr.isOptional = true
        
        let messageTokensPerSecondAttr = NSAttributeDescription()
        messageTokensPerSecondAttr.name = "tokensPerSecond"
        messageTokensPerSecondAttr.attributeType = .doubleAttributeType
        
        let messageStateAttr = NSAttributeDescription()
        messageStateAttr.name = "state"
        messageStateAttr.attributeType = .integer16AttributeType
        
        messageEntity.properties = [messageIDAttr, messageContentAttr, messageIsUserMessageAttr, 
                                   messageTimestampAttr, messageImageDataAttr, messageTokensPerSecondAttr,
                                   messageStateAttr]
        
        // Define relationships
        let chatToMessagesRel = NSRelationshipDescription()
        chatToMessagesRel.name = "messages"
        chatToMessagesRel.destinationEntity = messageEntity
        chatToMessagesRel.minCount = 0
        chatToMessagesRel.maxCount = 0 // To-many relationship
        chatToMessagesRel.deleteRule = .cascadeDeleteRule
        
        let messageToChatRel = NSRelationshipDescription()
        messageToChatRel.name = "chat"
        messageToChatRel.destinationEntity = chatEntity
        messageToChatRel.minCount = 1
        messageToChatRel.maxCount = 1 // To-one relationship
        messageToChatRel.deleteRule = .nullifyDeleteRule
        
        // Set inverse relationships
        chatToMessagesRel.inverseRelationship = messageToChatRel
        messageToChatRel.inverseRelationship = chatToMessagesRel
        
        // Add relationships to entities
        chatEntity.properties.append(chatToMessagesRel)
        messageEntity.properties.append(messageToChatRel)
        
        // Set entities on model
        model.entities = [chatEntity, messageEntity]
        
        // Create store coordinator with this model
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        
        do {
            let url = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                .appendingPathComponent("CoreDataChat.sqlite")
            
            try coordinator.addPersistentStore(type: NSSQLiteStoreType, configuration: nil, at: url, options: nil)
        } catch {
            print("Failed to create persistent store: \(error)")
        }
    }
}
