//
//  PocketGPTApp.swift
//  PocketGPT
//
//

import SwiftUI
import StoreKit

let udkey_activeCount = "activeCount"

@main
struct PocketGPTApp: App {
    @StateObject var aiChatModel = AIChatModel()
   
    @State var isLandscape:Bool = false
    @State var tabIndex: Int = 0
    
    @State var chat_titles: [String] = ["MobileVLM V2 3B"] 
    @State var chat_title: String?

    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            // Use ChatListView directly with Todoist-inspired theme
            ChatListView(
                chat_titles: $chat_titles,
                chat_title: $chat_title
            )
            .environmentObject(aiChatModel)
            .background(.ultraThinMaterial)
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    print("App became active!")
                    let count = (UserDefaults.standard.object(forKey: udkey_activeCount) as? Int) ?? 0
                    UserDefaults.standard.set(count + 1, forKey: udkey_activeCount)
                    
                    if count == 15 {
                        // Show review request when user opens app 15 times
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            SKStoreReviewController.requestReview(in: windowScene)
                        }
                    }
                } else if newPhase == .background {
                    print("App goes to background")
                    // Save chat history before going to background
                    aiChatModel.save_history()
                }
            }
        }
    }
}
