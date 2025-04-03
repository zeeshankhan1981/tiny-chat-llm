//
//  AIChatModel.swift
//  PocketGPT
//
//

import Foundation
import SwiftUI
import os
import CoreML

@MainActor
final class AIChatModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var AI_typing = 0
    
    public var chat_name = "MobileVLM V2 3B" // Default chat

    private var llamaState = LlamaState()
    private var filename: String = "tinyllama-1.1b-1t-openorca.Q4_0.gguf"
    
    public var numberOfTokens = 0
    public var total_sec = 0.0
    public var start_predicting_time = DispatchTime.now()

    var sdPipeline: StableDiffusionPipelineProtocol?

    private func getFileURL(filename: String) -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(filename)
    }
    
    init() {
        // Load default chat on startup
        self.messages = load_chat_history(self.chat_name) ?? []
    }
    
    // Save current chat history
    public func save_history() {
        save_chat_history(self.messages, chat_name)
    }
    
    // Set current chat and load its history
    public func setCurrentChat(_ chatTitle: String) {
        prepare(chat_title: chatTitle)
    }
    
    public func prepare(chat_title: String) {
        let new_chat_name = chat_title
        if new_chat_name != self.chat_name {
            // Save the previous chat history before loading a new one
            save_chat_history(self.messages, self.chat_name)
            
            self.chat_name = new_chat_name
            self.messages = []
            Task {
                // Load history for the new chat
                if let history = load_chat_history(new_chat_name) {
                    self.messages = history
                } else {
                    self.messages = []
                }
                self.AI_typing = -Int.random(in: 0..<100000)
                
                self.llamaState = LlamaState() // release old one, and create new one
                if self.sdPipeline != nil {
                    Task.detached() {
                        await self.sdPipeline?.unloadResources()
                    }
                }
                
                if self.chat_name == "Chat" || self.chat_name == "MobileVLM V2 3B" {
                    loadLlava()
                } else if self.chat_name == "SD_Turbo" || self.chat_name == "Image Creation" {
                    Task.detached {
                        await self.loadSDTurbo()
                    }
                }
            }
        }
    }
    
    public func loadSDTurbo() async {
        do {
            let resourceURL = Bundle.main.url(forResource: "sd_turbo", withExtension: nil)! // load from main bundle
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .cpuAndGPU
            // count loading time and print
            let start = DispatchTime.now()
            let sdPipeline = try StableDiffusionPipeline(resourcesAt: resourceURL,
                                                     controlNet: [],
                                                     configuration: configuration,
                                                     disableSafety: false,
                                                     reduceMemory: true)
            try sdPipeline.loadResources()
            print("sdPipeline loading time: \(Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000) seconds")
            await MainActor.run {
                self.sdPipeline = sdPipeline // assign to main actor's variable on main thread
            }
        } catch let err {
            print("SD loading Error: \(err.localizedDescription)")
        }
    }
    
    public func loadSD() {
        Task.detached() { // load on background thread, because it takes ~10 seconds
            // TODO: add task cancellation. https://stackoverflow.com/a/71876683
            do {
                let resourceURL = Bundle.main.url(forResource: "sd_turbo", withExtension: nil)! // load from main bundle
                let configuration = MLModelConfiguration()
                configuration.computeUnits = .cpuAndGPU
                // count loading time and print
                let start = DispatchTime.now()
                let sdPipeline = try StableDiffusionPipeline(resourcesAt: resourceURL,
                                                         controlNet: [],
                                                         configuration: configuration,
                                                         disableSafety: false,
                                                         reduceMemory: true)
                try sdPipeline.loadResources()
                print("sdPipeline loading time: \(Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000) seconds")
                Task { @MainActor in
                    self.sdPipeline = sdPipeline // assign to main actor's variable on main thread
                }
            } catch let err {
                print("SD loading Error: \(err.localizedDescription)")
            }
        }
    }
    
    public func loadLlava() {
        do {
            llamaState = LlamaState()
            try llamaState.loadModelLlava()
            self.messages = load_chat_history(self.chat_name) ?? []
            self.AI_typing = -Int.random(in: 0..<100000)
        } catch let err {
            print("llava loading Error: \(err.localizedDescription)")
        }
    }
        
    public func loadLlama() {
        print("Loading model \(filename)...")
        let fileURL = getFileURL(filename: filename)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            print("Error: \(fileURL.path) does not exist!")
            return
        }
        do {
            try llamaState.loadModel(modelUrl: fileURL)
            print("model loaded from \(fileURL.path)")
        } catch let err {
            print("Error: \(err.localizedDescription)")
        }
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
//        let message = messages[messages.count-1]
//        return message.text
        
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
    
//    private func getConversationPromptLlava(text: String) -> String
//    {
//        var prompt = "A chat between a curious human and an artificial intelligence assistant. The assistant gives helpful, detailed, and polite answers to the human's questions.\n"
//        prompt += "USER: " + text + "\n"
//        prompt += "ASSISTANT: "
//        return prompt
//    }
    
    private func getConversationPromptSD(messages: [Message]) -> String
    {
        let message = messages[messages.count-1]
        return message.text
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
    
    private func sdGen(prompt: String) async -> Image? {
        var config = StableDiffusionPipeline.Configuration(prompt: prompt)
//        config.negativePrompt = negativePrompt
        config.stepCount = 2
        config.seed = UInt32.random(in: 1...UInt32.max)
//        config.guidanceScale = guidanceScale
        // config.guidanceScale = 0.1
//        config.disableSafety = disableSafety
        config.schedulerType = .dpmSolverMultistepScheduler
        // config.schedulerType =  StableDiffusionScheduler.pndmScheduler.asStableDiffusionScheduler()
        config.useDenoisedIntermediates = true
        
        var ret: Image? = nil
        do {
            // wait for the pipeline to be loaded
            while sdPipeline == nil {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                print("waiting for sd pipeline to finish loading")
            }
            let start = DispatchTime.now()
            let images = try sdPipeline!.generateImages(configuration: config) { progress in
                return true
            }
            print("sdPipeline generateImages time: \(Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000) seconds")
            let image = images.compactMap({ $0 }).first
            guard let image else {
                return nil
            }
            ret = Image(uiImage: UIImage(cgImage: image))
        } catch let err {
            print("Error: \(err.localizedDescription)")
        }
        return ret
    }
    
    public func send(message in_text: String, image: Image? = nil)  {
        let requestMessage = Message(sender: .user, state: .typed, text: in_text, tok_sec: 0, image: image)
        self.messages.append(requestMessage)
        self.AI_typing += 1
        self.numberOfTokens = 0
        self.total_sec = 0.0
        self.start_predicting_time = DispatchTime.now()
        
        // Save the chat history when a new message is sent
        save_history()
        
        Task {
            var prompt = ""
            if self.chat_name == "Chat" || self.chat_name == "MobileVLM V2 3B" {
                prompt = getConversationPromptLlava(messages: self.messages)
            } else if self.chat_name == "Image Creation" {
                prompt = getConversationPromptSD(messages: self.messages)
            }
            
            var message = Message(sender: .system, text: "", tok_sec: 0)
            self.messages.append(message)
            let messageIndex = self.messages.endIndex - 1
            
            
            if self.chat_name == "Chat" || self.chat_name == "MobileVLM V2 3B" {
                // 1. llama
    //            await llamaState.complete(
    //                text: prompt,
    //                { str in
    //                    message.state = .predicting
    //                    message.text += str
    //
    //                    var updatedMessages = self.messages
    //                    updatedMessages[messageIndex] = message
    //                    self.messages = updatedMessages
    //                    self.AI_typing += 1
    //                }
    //            )
                
                // 2. llava
                await llamaState.completeLlava(
                    text: prompt,
                    { str in
                        message.state = .predicting
                        message.text += str
                        
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
            } else if self.chat_name == "Image Creation" {
                let pr = prompt
//                Task.detached() {
//                    print("start sleeping 10")
//                    sleep(10)
//                    print("end sleeping 10")
                self.AI_typing += 1
                try await Task.sleep(nanoseconds: 1_000_000_00) // wait 0.1 second for UI to update
                    let image = await self.sdGen(prompt: pr)
                message.image = image
                self.AI_typing += 1
            }
            save_chat_history([requestMessage, message], self.chat_name)

            message.state = .predicted(totalSecond:0)
            self.messages[messageIndex] = message
            llamaState.answer = ""
            self.AI_typing = 0
        }
    }

    public func getVoiceAnswer(text_in: String, messages: [Message], _ tokenCallback: ((String)  -> ())?) async -> [Message] {
        print("getVoiceAnswer: \(text_in)")
        var messages_in = messages
        let requestMessage = Message(sender: .user, state: .typed, text: text_in, tok_sec: 0, image: nil)
        messages_in.append(requestMessage)
        
        var prompt = ""
        prompt = getConversationPromptLlava(messages: messages_in)
//        print("[prompt into llm]", prompt)
        
        var message = Message(sender: .system, text: "", tok_sec: 0)
        messages_in.append(message)
        let messageIndex = messages_in.endIndex - 1
 
        await llamaState.completeLlavaSentence(
            text: prompt,
            { str in
                message.state = .predicting
                message.text += str
                
                var updatedMessages = messages_in
                updatedMessages[messageIndex] = message
                messages_in = updatedMessages

                tokenCallback?(str)
            }
        )
        
        message.state = .predicted(totalSecond:0)
        messages_in[messageIndex] = message
        llamaState.answer = ""
        return messages_in
    }

    public func stopPredicting() {
        llamaState.stopPredicting()
    }

    // Method to add new message to the current chat
    public func addMessage(_ message: Message) {
        messages.append(message)
        save_history() // Save after each new message
    }
}
