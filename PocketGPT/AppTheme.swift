//
//  AppTheme.swift
//  PocketGPT
//
//

import SwiftUI

/// Theme implementation inspired by Todoist's design language
struct Theme {
    // Main Todoist-inspired colors
    static let primary = Color(red: 0.89, green: 0.27, blue: 0.20) // Todoist red (E84435)
    static let secondary = Color(red: 0.94, green: 0.94, blue: 0.94) // Light gray (F0F0F0)
    static let accent = Color(red: 0.95, green: 0.51, blue: 0.43) // Lighter red (F28275)
    
    // Text colors - Todoist uses stark contrast
    static let textPrimary = Color(red: 0.13, green: 0.13, blue: 0.13) // Almost black (202020)
    static let textSecondary = Color(red: 0.60, green: 0.60, blue: 0.60) // Medium gray (999999)
    
    // Background colors
    static let backgroundPrimary = Color.white // Todoist uses white background
    static let backgroundSecondary = Color(red: 0.98, green: 0.98, blue: 0.98) // Very light gray (FAFAFA)
    
    // Message colors - Adapting Todoist's task item styling
    static let userMessageBackground = Color(red: 0.96, green: 0.96, blue: 0.96) // Light gray (F5F5F5)
    static let systemMessageBackground = Color.white
    
    // Input field - Inspired by Todoist's task input
    static let inputBackground = Color.white
    static let inputBorder = Color(red: 0.90, green: 0.90, blue: 0.90) // Light border (E5E5E5)
    
    // Button colors
    static let buttonBackground = primary
    static let buttonText = Color.white
    
    // Additional Todoist-inspired elements
    static let completedTask = Color(red: 0.53, green: 0.73, blue: 0.38) // Green (88BB61)
    static let divider = Color(red: 0.93, green: 0.93, blue: 0.93) // Very light gray for separators (EEEEEE)
    
    // Priority colors from Todoist
    static let priority1 = Color(red: 0.89, green: 0.27, blue: 0.20) // Red - highest (E84435)
    static let priority2 = Color(red: 1.00, green: 0.64, blue: 0.16) // Orange (FF9D2A)
    static let priority3 = Color(red: 0.46, green: 0.69, blue: 0.95) // Blue (74B0F1)
    static let priority4 = Color(red: 0.60, green: 0.60, blue: 0.60) // Gray - lowest (999999)
    
    // Shadow
    static let shadowColor = Color.black.opacity(0.05)
    static let shadowRadius: CGFloat = 2
    static let shadowY: CGFloat = 1
}
