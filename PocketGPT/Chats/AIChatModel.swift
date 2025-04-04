//
//  AIChatModel.swift
//  PocketGPT
//
//

import Foundation
import SwiftUI
import os
import CoreData

// Model loading state enum
enum ModelLoadingState {
    case notStarted
    case loading(progress: Double)
    case loaded
    case failed(error: String)
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
}

@MainActor
final class AIChatModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var AI_typing = 0
    
    public var chat_name = "MobileVLM V2 3B" // Default chat
    
    // Track the model type for the current chat
    public var modelType: String = "MobileVLM V2 3B"
    
    // Track model loading state
    @Published var modelLoadingState: ModelLoadingState = .notStarted

    private var llamaState = LlamaState()
    private var filename: String = "MobileVLM_V2-3B-ggml-model-q4_k.gguf"
    
    public var numberOfTokens = 0
    public var total_sec = 0.0
    public var start_predicting_time = DispatchTime.now()

    // Use NSManagedObject instead of the specific type to avoid build errors
    public var currentChat: NSManagedObject?
    
    // Direct access to the Core Data context to avoid PersistenceController reference issues
    private var viewContext: NSManagedObjectContext {
        let container = NSPersistentContainer(name: "ChatConversation")
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Error loading Core Data: \(error.localizedDescription)")
            }
        }
        return container.viewContext
    }

    private func getFileURL(filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
    }
    
    init() {
        // Load default chat on startup
        self.messages = load_chat_history(self.chat_name) ?? []
        // Initialize the default model asynchronously
        Task {
            await loadLlamaAsync()
        }
    }
    
    // Save current chat history
    public func save_history() {
        save_chat_history(self.messages, chat_name)
    }
    
    // Set current chat and load its history
    public func setCurrentChat(_ chatTitle: String) {
        prepare(chat_title: chatTitle)
    }
    
    // Set current chat entity (for CoreData)
    public func setCurrentChat(_ chat: NSManagedObject) {
        self.currentChat = chat
        if let title = chat.value(forKey: "title") as? String {
            prepare(chat_title: title)
        }
    }
    
    // Create a new chat in CoreData
    public func createNewChat(title: String) {
        // Access the CoreData context
        let context = viewContext
        
        guard let entity = NSEntityDescription.entity(forEntityName: "ChatEntity", in: context) else {
            print("Failed to create ChatEntity description")
            return
        }
        
        let newChat = NSManagedObject(entity: entity, insertInto: context)
        newChat.setValue(UUID(), forKey: "id")
        newChat.setValue(title, forKey: "title")
        newChat.setValue(Date(), forKey: "createdAt")
        newChat.setValue(Date(), forKey: "updatedAt")
        newChat.setValue("MobileVLM V2 3B", forKey: "modelType")
        
        do {
            try context.save()
            // Set as current chat
            currentChat = newChat
            chat_name = title
            modelType = "MobileVLM V2 3B"
            messages = []
            save_history()
        } catch {
            print("Failed to save new chat: \(error.localizedDescription)")
        }
    }
    
    // Set current chat and load its history
    public func prepare(chat_title: String) {
        let new_chat_name = chat_title
        if new_chat_name != self.chat_name {
            // Save the previous chat history before loading a new one
            save_chat_history(self.messages, self.chat_name)
            
            self.chat_name = new_chat_name
            
            // Load history for the new chat
            if let history = load_chat_history(new_chat_name) {
                self.messages = history
            } else {
                self.messages = []
            }
            
            // Reset UI state
            self.AI_typing = -Int.random(in: 0..<100000)
            
            // Get the model type from chat configuration
            if let chatInfo = getChatConfiguration(new_chat_name) {
                if let modelName = chatInfo["model"] as? String {
                    self.modelType = modelName
                } else {
                    self.modelType = "MobileVLM V2 3B" // Default model
                }
            } else {
                self.modelType = "MobileVLM V2 3B" // Default if no config found
            }
            
            // Properly clean up old resources
            _ = self.llamaState
            self.llamaState = LlamaState()
            
            // Initialize the appropriate model based on model type asynchronously
            Task {
                await initializeModelAsync()
            }
        }
    }
    
    // Get chat configuration if available
    private func getChatConfiguration(_ chatName: String) -> [String: Any]? {
        return get_chat_config(chatName)
    }
    
    // Initialize the model based on the current modelType (async version)
    private func initializeModelAsync() async {
        // Only have MobileVLM model now - SD and Whisper were removed
        await loadLlamaAsync()
    }
    
    // Deprecated synchronous method - will be removed in future
    public func loadLlama() {
        print("Loading MobileVLM models...")
        
        // Look specifically for the MobileVLM models in the Resources/llm directory
        let modelPath = "MobileVLM_V2-3B-ggml-model-q4_k"
        
        // Try to load from Resources/llm directory
        if let modelURL = Bundle.main.url(forResource: "llm/\(modelPath)", withExtension: "gguf") {
            do {
                // Load the Llava model instead of the regular Llama model
                try llamaState.loadModelLlava()
                print("MobileVLM model loaded successfully from: \(modelURL.path)")
                return
            } catch let err {
                print("Error loading MobileVLM model: \(err.localizedDescription)")
            }
        } else {
            print("Could not find MobileVLM model files in Resources/llm directory")
            
            // List all .gguf files in the bundle for debugging
            print("Available .gguf files in bundle:")
            let bundles = Bundle.main.paths(forResourcesOfType: "gguf", inDirectory: nil)
            for bundle in bundles {
                print("Found model: \(bundle)")
            }
        }
    }
    
    // New asynchronous model loading method with progress tracking
    public func loadLlamaAsync() async {
        print("Loading MobileVLM models asynchronously...")
        
        // Update loading state
        self.modelLoadingState = .loading(progress: 0.0)
        
        // Look specifically for the MobileVLM models in the Resources/llm directory
        let modelPath = "MobileVLM_V2-3B-ggml-model-q4_k"
        
        // Try to load from Resources/llm directory
        if let modelURL = Bundle.main.url(forResource: "llm/\(modelPath)", withExtension: "gguf") {
            do {
                // Simulate progressive loading (in a real implementation, the C++ bridge would need to be modified to report progress)
                for progress in stride(from: 0.1, through: 0.9, by: 0.1) {
                    // Update progress state
                    self.modelLoadingState = .loading(progress: progress)
                    
                    // Simulate some work being done
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                    
                    // Check for cancellation
                    try Task.checkCancellation()
                }
                
                // Do the actual model loading
                try llamaState.loadModelLlava()
                
                // Update state on success
                self.modelLoadingState = .loaded
                print("MobileVLM model loaded successfully from: \(modelURL.path)")
            } catch let err {
                // Update state on failure
                self.modelLoadingState = .failed(error: err.localizedDescription)
                print("Error loading MobileVLM model: \(err.localizedDescription)")
            }
        } else {
            // Update state on failure
            self.modelLoadingState = .failed(error: "Missing model files")
            print("Could not find MobileVLM model files in Resources/llm directory")
            
            // List all .gguf files in the bundle for debugging
            print("Available .gguf files in bundle:")
            let bundles = Bundle.main.paths(forResourcesOfType: "gguf", inDirectory: nil)
            for bundle in bundles {
                print("Found model: \(bundle)")
            }
        }
    }
    
    public func loadLlava() {
        do {
            llamaState = LlamaState()
            
            // Verify model files exist before attempting to load
            let modelPath = "MobileVLM_V2-3B-ggml-model-q4_k"
            let _ = "MobileVLM_V2-3B-mmproj-model-f16"  // Using underscore to indicate unused
            
            // Check if we have the model files in the bundle
            guard let modelURL = Bundle.main.url(forResource: "llm/\(modelPath)", withExtension: "gguf") else {
                print("ERROR: Could not find MobileVLM model files in Resources/llm directory")
                
                // List all resources for debugging
                print("Available resources in bundle:")
                let bundles = Bundle.main.paths(forResourcesOfType: "gguf", inDirectory: nil)
                if bundles.isEmpty {
                    print("No .gguf files found in bundle")
                } else {
                    for bundle in bundles {
                        print("Found model: \(bundle)")
                    }
                }
                return
            }
            
            // Files exist, try to load the model
            print("Loading MobileVLM model from: \(modelURL.path)")
            try llamaState.loadModelLlava()
            print("MobileVLM model loaded successfully")
            
            // Load chat history if available
            self.messages = load_chat_history(self.chat_name) ?? []
            self.AI_typing = -Int.random(in: 0..<100000)
        } catch let err {
            print("ERROR loading MobileVLM model: \(err.localizedDescription)")
        }
    }
        
    public func loadLlavaImage(base64: String) {
        Task {
            await llamaState.loadLlavaImage(base64: base64)
        }
    }
    
    public func resetLlavaImage() {
        Task {
            // Reset any image-related state in LlamaState
            await llamaState.loadLlavaImage(base64: "")
        }
    }
    
    public func send(message in_text: String, image: Image? = nil)  {
        // Check if model is loaded before sending
        guard case .loaded = modelLoadingState else {
            print("Cannot send message - model is not loaded")
            return
        }
        
        let requestMessage = Message(sender: .user, state: .typed, text: in_text, tok_sec: 0, image: image)
        self.messages.append(requestMessage)
        self.AI_typing += 1
        self.numberOfTokens = 0
        self.total_sec = 0.0
        self.start_predicting_time = DispatchTime.now()
        
        // Save the chat history when a new message is sent
        save_history()
        
        Task {
            // For all chat types, use Llava now
            let prompt = getConversationPromptLlava(messages: self.messages)
            
            var message = Message(sender: .system, text: "", tok_sec: 0)
            self.messages.append(message)
            
            // Guard against array access errors
            guard !self.messages.isEmpty, self.messages.count > 1 else {
                print("Error: messages array is empty or has insufficient elements")
                return
            }
            
            let messageIndex = self.messages.endIndex - 1
            
            // Process with Llava
            await llamaState.completeLlava(
                text: prompt,
                { str in
                    message.state = .predicting
                    message.text += str
                    
                    // Guard against race conditions by checking array bounds
                    guard messageIndex < self.messages.count else {
                        print("Error: messageIndex out of bounds")
                        return
                    }
                    
                    var updatedMessages = self.messages
                    updatedMessages[messageIndex] = message
                    self.messages = updatedMessages
                    self.AI_typing += 1
                    self.numberOfTokens += 1
                }
            )
            self.total_sec = Double((DispatchTime.now().uptimeNanoseconds - self.start_predicting_time.uptimeNanoseconds)) / 1_000_000_000
            message.tok_sec = Double(self.numberOfTokens)/self.total_sec
            print("number of tokens: \(self.numberOfTokens), total time: \(self.total_sec), token/sec: \(message.tok_sec)")
            
            // Guard against another potential array bounds issue
            guard messageIndex < self.messages.count else {
                print("Error: messageIndex out of bounds when saving chat history")
                return
            }
            
            save_chat_history([requestMessage, message], self.chat_name)

            message.state = .predicted(totalSecond:0)
            self.messages[messageIndex] = message
            llamaState.answer = ""
            self.AI_typing = 0
        }
    }

    public func stopPredicting() {
        llamaState.stopPredicting()
    }

    // Method to add new message to the current chat
    public func addMessage(_ message: Message) {
        messages.append(message)
        save_history() // Save after each new message
    }
    
    private func getConversationPromptLlama(messages: [Message]) -> String
    {
        // generate prompt from the last n messages
        let contextLength = 2
        let numChats = contextLength * 2 + 1
        var prompt = "The following is a friendly conversation between a human and an AI. You are a helpful chatbot that answers questions. Chat history:\n"
        let start = max(0, messages.count - numChats)
        for i in start..<messages.count-1 {
            let message = messages[i]
            if message.sender == .user {
                prompt += "user: " + message.text + "\n"
            } else if message.sender == .system {
                prompt += "assistant:" + message.text + "\n"
            }
        }
        prompt += "\nassistant:\n"
        let message = messages[messages.count-1]
        if message.sender == .user {
            prompt += "user: " + message.text + "\nassistant:\n"
        }
        return prompt
    }
    
    private func getConversationPromptLlava(messages: [Message]) -> String
    {
        // generate prompt from the last n messages
        let contextLength = 2 // # rounds
        let numChats = contextLength * 2 + 1
        var prompt = "A chat between a curious human and an artificial intelligence assistant. The assistant gives helpful, detailed, and polite answers to the human's questions.\n"
        let start = max(0, messages.count - numChats)
        for i in start..<messages.count-1 {
            let message = messages[i]
            if message.sender == .user {
                prompt += "USER: " + message.text + "\n"
            } else if message.sender == .system {
                prompt += "ASSISTANT: " + message.text + "\n"
            }
        }
        let message = messages[messages.count-1]
        if message.sender == .user {
            prompt += "USER: <image> " + message.text + "\n"
        }
        prompt += "ASSISTANT: "
        return prompt
    }
}
