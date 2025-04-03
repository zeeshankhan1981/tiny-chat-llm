import CoreData
import SwiftUI

class ChatManager {
    static let shared = ChatManager()
    
    private let viewContext = PersistenceController.shared.container.viewContext
    
    // Create a new chat
    func createChat(title: String, completion: ((ChatEntity) -> Void)? = nil) -> ChatEntity {
        let newChat = ChatEntity(context: viewContext)
        newChat.id = UUID()
        newChat.title = title
        newChat.createdAt = Date()
        newChat.updatedAt = Date()
        
        do {
            try viewContext.save()
            completion?(newChat)
            return newChat
        } catch {
            print("Error creating chat: \(error.localizedDescription)")
            viewContext.rollback()
            fatalError("Failed to create chat")
        }
    }
    
    // Delete a chat
    func deleteChat(_ chat: ChatEntity) {
        viewContext.delete(chat)
        saveContext()
    }
    
    // Update a chat
    func updateChat(_ chat: ChatEntity, title: String) {
        chat.title = title
        chat.updatedAt = Date()
        saveContext()
    }
    
    // Convert from current Message model to CoreData MessageEntity
    func addMessage(to chat: ChatEntity, from message: Message) -> MessageEntity {
        let newMessage = MessageEntity(context: viewContext)
        newMessage.id = message.id
        newMessage.content = message.text
        newMessage.isFromUser = message.sender == .user
        newMessage.timestamp = message.timestamp
        newMessage.state = Int16(stateToInt(message.state))
        newMessage.tokensPerSecond = message.tok_sec
        
        // Convert image to Data if it exists
        if let image = message.image {
            if let uiImage = convertImageToUIImage(image) {
                newMessage.imageData = uiImage.jpegData(compressionQuality: 0.8)
            }
        }
        
        newMessage.chat = chat
        chat.updatedAt = Date()
        
        saveContext()
        return newMessage
    }
    
    // Add a new message directly
    func createMessage(in chat: ChatEntity, content: String, isFromUser: Bool, image: Image? = nil) -> MessageEntity {
        let newMessage = MessageEntity(context: viewContext)
        newMessage.id = UUID()
        newMessage.content = content
        newMessage.isFromUser = isFromUser
        newMessage.timestamp = Date()
        newMessage.state = isFromUser ? 2 : 0 // Typed for user, None for system
        
        // Convert image to Data if it exists
        if let image = image {
            if let uiImage = convertImageToUIImage(image) {
                newMessage.imageData = uiImage.jpegData(compressionQuality: 0.8)
            }
        }
        
        newMessage.chat = chat
        chat.updatedAt = Date()
        
        saveContext()
        return newMessage
    }
    
    // Convert CoreData MessageEntity to App's Message model
    func convertToMessage(_ messageEntity: MessageEntity) -> Message {
        let sender: Message.Sender = messageEntity.isFromUser ? .user : .system
        let state = intToState(Int(messageEntity.state))
        
        var image: Image? = nil
        if let imageData = messageEntity.imageData, let uiImage = UIImage(data: imageData) {
            image = Image(uiImage: uiImage)
        }
        
        return Message(
            id: messageEntity.id ?? UUID(),
            sender: sender,
            state: state,
            text: messageEntity.content ?? "",
            tok_sec: messageEntity.tokensPerSecond,
            image: image,
            timestamp: messageEntity.timestamp ?? Date()
        )
    }
    
    // Helper to convert Message.State to Int for storage
    private func stateToInt(_ state: Message.State) -> Int {
        switch state {
        case .none:
            return 0
        case .error:
            return 1
        case .typed:
            return 2
        case .predicting:
            return 3
        case .predicted:
            return 4
        }
    }
    
    // Helper to convert Int back to Message.State
    private func intToState(_ value: Int) -> Message.State {
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
    
    // Helper to convert SwiftUI Image to UIImage
    private func convertImageToUIImage(_ image: Image) -> UIImage? {
        let renderer = ImageRenderer(content: image.resizable().aspectRatio(contentMode: .fit).frame(width: 300, height: 300))
        return renderer.uiImage
    }
    
    // Helper for saving context
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            print("Error saving context: \(error.localizedDescription)")
            viewContext.rollback()
        }
    }
    
    // Migration helper - converts existing file-based chats to CoreData
    func migrateExistingChats() {
        MigrationHelper.shared.migrateExistingFileBasedChats()
    }
}
