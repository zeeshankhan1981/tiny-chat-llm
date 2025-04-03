//
//  Message.swift
//  PocketGPT
//
//

import SwiftUI

struct Message: Identifiable {
    enum State: Equatable {
        case none
        case error
        case typed
        case predicting
        case predicted(totalSecond: Double)
    }

    enum Sender {
        case user
        case system
    }

    var id = UUID()
    var sender: Sender
    var state: State = .none
    var text: String
    var tok_sec: Double
    var header: String = ""
    var image: Image?
    var timestamp: Date = Date() // Add timestamp field with current date as default
    
    // Format timestamp for display
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    // Format full date for grouping
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: timestamp)
    }
}
