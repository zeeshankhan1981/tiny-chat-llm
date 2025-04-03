import SwiftUI
import CoreData

extension MessageEntity {
    func toMessage() -> Message {
        let sender: Message.Sender = self.isFromUser ? .user : .system
        var state: Message.State = .none
        
        switch self.state {
        case 0:
            state = .none
        case 1:
            state = .error
        case 2:
            state = .typed
        case 3:
            state = .predicting
        case 4:
            state = .predicted(totalSecond: 0)
        default:
            state = .none
        }
        
        var image: Image? = nil
        if let imageData = self.imageData, let uiImage = UIImage(data: imageData) {
            image = Image(uiImage: uiImage)
        }
        
        return Message(
            id: self.id ?? UUID(),
            sender: sender,
            state: state,
            text: self.content ?? "",
            tok_sec: self.tokensPerSecond,
            image: image,
            timestamp: self.timestamp ?? Date()
        )
    }
}
