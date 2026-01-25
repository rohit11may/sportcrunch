//
//  AppTheme.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI

// MARK: - Color Palette
// Note: scPrimary and scPrimaryLight are auto-generated from the Asset Catalog
// via ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS

extension Color {
    // Additional brand colors (scPrimary is auto-generated from Asset Catalog)
    static let scSecondary = Color(hex: "0066FF") // Electric blue
    static let scAccent = Color(hex: "F7931E") // Warm amber accent

    // Sport-specific accents
    static let scTennis = Color(hex: "C8E038") // Vibrant tennis ball yellow-green
    static let scCricket = Color(hex: "E63946") // Cricket red

    // Backgrounds
    static let scBackground = Color(hex: "0D0D0F")
    static let scSurface = Color(hex: "1A1A1E")
    static let scSurfaceElevated = Color(hex: "252529")

    // Text
    static let scTextPrimary = Color(hex: "FFFFFF")
    static let scTextSecondary = Color(hex: "8E8E93")
    static let scTextTertiary = Color(hex: "636366")

    // Semantic
    static let scSuccess = Color(hex: "30D158")
    static let scWarning = Color(hex: "FF9F0A")
    static let scError = Color(hex: "FF453A")

    // Gradients
    static let scGradientStart = Color(hex: "FF6B35")
    static let scGradientEnd = Color(hex: "F7931E")
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Typography

struct AppFont {
    // Display - Large titles, hero text
    static func displayLarge() -> Font {
        .system(size: 34, weight: .bold, design: .rounded)
    }

    static func displayMedium() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }

    // Headlines
    static func headline() -> Font {
        .system(size: 22, weight: .semibold, design: .rounded)
    }

    static func subheadline() -> Font {
        .system(size: 17, weight: .semibold, design: .default)
    }

    // Body
    static func body() -> Font {
        .system(size: 17, weight: .regular, design: .default)
    }

    static func bodyBold() -> Font {
        .system(size: 17, weight: .semibold, design: .default)
    }

    // Callout & Caption
    static func callout() -> Font {
        .system(size: 15, weight: .medium, design: .default)
    }

    static func caption() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }

    static func captionBold() -> Font {
        .system(size: 13, weight: .semibold, design: .default)
    }

    // Stats - For time displays
    static func stats() -> Font {
        .system(size: 48, weight: .bold, design: .rounded)
    }

    static func statsMedium() -> Font {
        .system(size: 32, weight: .bold, design: .rounded)
    }
}

// MARK: - Spacing

struct Spacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner Radius

struct CornerRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xl: CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: - Shadows

extension View {
    func scShadow() -> some View {
        self.shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
    }

    func scShadowLight() -> some View {
        self.shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Gradients

struct AppGradient {
    static var primary: LinearGradient {
        LinearGradient(
            colors: [.scGradientStart, .scGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var tennis: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "C8E038"), Color(hex: "9BC53D")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cricket: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "E63946"), Color(hex: "C41E3A")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var backgroundMesh: LinearGradient {
        LinearGradient(
            colors: [
                Color(hex: "0D0D0F"),
                Color(hex: "1A1A1E"),
                Color(hex: "0D0D0F")
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
