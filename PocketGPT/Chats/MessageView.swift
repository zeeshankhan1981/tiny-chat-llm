//
//  MessageView.swift
//  PocketGPT
//
//

import SwiftUI

struct MessageView: View {
    var message: Message

    private struct SenderView: View {
        var sender: Message.Sender
        var timestamp: Date
        var currentModel = "MobileVLM V2 3B"

        var body: some View {
            HStack(spacing: 8) {
                Text(sender == .user ? "You" : currentModel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Theme.primary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Theme.textSecondary.opacity(0.5))
                        .frame(width: 3, height: 3)

                    Text(formatTime(timestamp))
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.bottom, 2)
        }

        private func formatTime(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }

    private struct MessageContentView: View {
        var message: Message

        var body: some View {
            switch message.state {
            case .none:
                ProgressView()
                    .tint(Theme.primary)
            case .error:
                VStack(alignment: .leading, spacing: 6) {
                    Text(message.text)
                        .foregroundColor(Theme.primary)
                        .textSelection(.enabled)

                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundColor(Theme.primary)

                        Text("Error sending message")
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            case .typed:
                VStack(alignment: .leading, spacing: 8) {
                    if !message.header.isEmpty {
                        Text(message.header)
                            .font(.footnote)
                            .foregroundColor(Theme.textSecondary)
                    }

                    if let image = message.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    }

                    Text(message.text)
                        .foregroundColor(Theme.textPrimary)
                        .textSelection(.enabled)
                        .lineSpacing(4)
                }
            case .predicting:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(message.text)
                            .foregroundColor(Theme.textPrimary)
                            .textSelection(.enabled)
                            .lineSpacing(4)

                        ProgressView()
                            .tint(Theme.primary)
                            .scaleEffect(0.7)
                    }

                    Text("Thinking...")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                        .padding(.top, 2)
                }
            case .predicted(totalSecond: let totalSecond):
                VStack(alignment: .leading, spacing: 8) {
                    if let image = message.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    }

                    Text(message.text)
                        .foregroundColor(Theme.textPrimary)
                        .textSelection(.enabled)
                        .lineSpacing(4)

                    if totalSecond > 0 && message.tok_sec > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt")
                                .font(.caption2)
                                .foregroundColor(Theme.priority3)

                            Text(String(format: "%.1f tokens/sec", message.tok_sec))
                                .font(.caption2)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.top, 2)
                    }
                }
            }
        }
    }

    private var imageOperationView: some View {
        VStack {
            Spacer()

            Button(action: downloadImage) {
                Image(systemName: "arrow.down.circle")
                    .foregroundColor(Theme.primary)
                    .font(.system(size: 18))
                    .padding(4)
                    .background(Theme.backgroundPrimary)
                    .clipShape(Circle())
                    .shadow(color: Theme.shadowColor, radius: 1, x: 0, y: 1)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.sender == .user {
                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                SenderView(sender: message.sender, timestamp: message.timestamp)

                MessageContentView(message: message)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(message.sender == .user ? Theme.userMessageBackground : Theme.systemMessageBackground)
                    .cornerRadius(8)
                    .shadow(color: Theme.shadowColor, radius: Theme.shadowRadius, x: 0, y: Theme.shadowY)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Theme.divider, lineWidth: 0.5)
                    )
                    .overlay(
                        Group {
                            if message.sender == .user && message.state == .typed {
                                HStack {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.completedTask)
                                        .padding(4)
                                }
                                .padding(.trailing, 4)
                                .padding(.bottom, 4)
                            }
                        },
                        alignment: .bottomTrailing
                    )
            }
            .padding(.vertical, 4)

            if message.sender == .system && message.image != nil {
                imageOperationView
            }

            if message.sender == .system {
                Spacer()
            }
        }
        .contextMenu {
            Button(action: {
                UIPasteboard.general.string = message.text
            }) {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if message.sender == .system && message.image != nil {
                Button(action: downloadImage) {
                    Label("Save Image", systemImage: "arrow.down.circle")
                }
            }
        }
    }

    private func downloadImage() {
        DispatchQueue.main.async {
            guard let image = message.image else { return }
            let uiImage = image.asUIImage()
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
        }
    }
}
