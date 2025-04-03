import SwiftUI

// Simple theme structure with direct color definitions inspired by Todoist
struct Theme {
    // Primary colors
    static let primary = Color(red: 0.91, green: 0.30, blue: 0.24)
    static let secondary = Color(red: 0.95, green: 0.95, blue: 0.97)
    
    // Text colors
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    
    // Background colors
    static let backgroundPrimary = Color(UIColor.systemBackground)
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
    
    // Other UI elements
    static let divider = Color.gray.opacity(0.2)
    static let highlight = primary.opacity(0.1)
}
