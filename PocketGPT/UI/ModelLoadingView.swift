import SwiftUI

/// A view that displays the model loading progress
struct ModelLoadingView: View {
    /// The current model loading state
    let loadingState: ModelLoadingState
    
    /// Optional message to display when loading fails
    var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            switch loadingState {
            case .notStarted:
                Text("Preparing model...")
                    .font(.headline)
                
            case .loading(let progress):
                Text("Loading MobileVLM model...")
                    .font(.headline)
                
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 8)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                
                Text("\(Int(progress * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
            case .loaded:
                Text("Model loaded successfully")
                    .font(.headline)
                    .foregroundColor(.green)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.green)
                
            case .failed(let error):
                Text("Failed to load model")
                    .font(.headline)
                    .foregroundColor(.red)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.red)
                
                if let customMessage = errorMessage {
                    Text(customMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Button(action: {
                    // Notify the AIChatModel to retry loading
                    NotificationCenter.default.post(
                        name: Notification.Name("RetryModelLoading"),
                        object: nil
                    )
                }) {
                    Text("Retry")
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .padding()
    }
}

/// A loading overlay that can be added to any view
struct LoadingOverlay: ViewModifier {
    @ObservedObject var aiChatModel: AIChatModel
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .blur(radius: aiChatModel.modelLoadingState.isLoading ? 3 : 0)
                .disabled(aiChatModel.modelLoadingState.isLoading)
            
            if case .loading = aiChatModel.modelLoadingState {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                
                ModelLoadingView(loadingState: aiChatModel.modelLoadingState)
                    .padding(.horizontal, 20)
            }
            
            if case .failed = aiChatModel.modelLoadingState {
                ModelLoadingView(
                    loadingState: aiChatModel.modelLoadingState,
                    errorMessage: "The model failed to load. This could be due to memory constraints or missing model files. Please retry or restart the app."
                )
                .padding(.horizontal, 20)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RetryModelLoading"))) { _ in
            // Retry loading the model
            Task {
                await aiChatModel.loadLlamaAsync()
            }
        }
    }
}

extension View {
    /// Apply a loading overlay to any view
    func withLoadingOverlay(aiChatModel: AIChatModel) -> some View {
        self.modifier(LoadingOverlay(aiChatModel: aiChatModel))
    }
}

#Preview {
    VStack {
        ModelLoadingView(loadingState: .notStarted)
        ModelLoadingView(loadingState: .loading(progress: 0.35))
        ModelLoadingView(loadingState: .loaded)
        ModelLoadingView(loadingState: .failed(error: "Model file not found"))
    }
    .padding()
}
