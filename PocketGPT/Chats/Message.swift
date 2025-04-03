//
//  Message.swift
//  PocketGPT
//
//

import SwiftUI

struct Message: Identifiable {
    enum State: Equatable, RawRepresentable {
        case none
        case error
        case typed
        case predicting
        case predicted(totalSecond: Double)
        
        // Added for serialization
        var rawValue: Int {
            switch self {
            case .none: return 0
            case .error: return 1
            case .typed: return 2
            case .predicting: return 3
            case .predicted: return 4
            }
        }
        
        // Initialize from raw value
        init?(rawValue: Int) {
            switch rawValue {
            case 0: self = .none
            case 1: self = .error
            case 2: self = .typed
            case 3: self = .predicting
            case 4: self = .predicted(totalSecond: 0)
            default: return nil
            }
        }
    }

    enum Sender: String {
        case user = "user"
        case system = "ai"
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
