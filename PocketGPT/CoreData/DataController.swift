import CoreData
import SwiftUI

class DataController: ObservableObject {
    let container = NSPersistentContainer(name: "ChatData")
    
    init() {
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
                return
            }
            
            // Enable auto-merging
            self.container.viewContext.automaticallyMergesChangesFromParent = true
            self.container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        }
    }
    
    // Helper to save context
    func save() {
        if container.viewContext.hasChanges {
            do {
                try container.viewContext.save()
            } catch {
                print("Error saving context: \(error.localizedDescription)")
            }
        }
    }
    
    // Create a new chat
    func createChat(title: String) {
        let chat = ChatItem(context: container.viewContext)
        chat.id = UUID()
        chat.title = title
        chat.createdAt = Date()
        chat.updatedAt = Date()
        
        save()
    }
    
    // Add message to a chat
    func addMessage(to chat: ChatItem, content: String, isFromUser: Bool) {
        let message = ChatMessage(context: container.viewContext)
        message.id = UUID()
        message.content = content
        message.isFromUser = isFromUser
        message.timestamp = Date()
        message.chat = chat
        
        chat.updatedAt = Date()
        
        save()
    }
}
