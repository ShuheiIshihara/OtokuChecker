//
//  ViewModifiers.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/23.
//

import SwiftUI

// MARK: - Card Style Modifiers

/// カード風の背景スタイルを適用するModifier
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(AppColors.cardBackground)
            .cornerRadius(8)
    }
}

/// 軽いカード風の背景スタイルを適用するModifier
struct LightCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(AppColors.lightBackground)
            .cornerRadius(6)
    }
}

// MARK: - Button Style Modifiers

/// プライマリボタンのスタイルを適用するModifier
struct PrimaryButtonStyle: ViewModifier {
    let isEnabled: Bool
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(isEnabled ? AppColors.primary : AppColors.disabledButton)
            .cornerRadius(10)
    }
}

/// セカンダリボタンのスタイルを適用するModifier
struct SecondaryButtonStyle: ViewModifier {
    let isEnabled: Bool
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(isEnabled ? AppColors.primary : AppColors.disabledText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isEnabled ? AppColors.primary : AppColors.border, lineWidth: 1)
            )
    }
}

/// 小さなアクションボタンのスタイルを適用するModifier
struct SmallActionButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AppColors.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppColors.primary.opacity(0.1))
            .cornerRadius(6)
    }
}

// MARK: - Input Field Style Modifiers

/// 入力フィールドのスタイルを適用するModifier
struct InputFieldStyle: ViewModifier {
    let borderColor: Color
    let hasError: Bool
    
    init(borderColor: Color = AppColors.border, hasError: Bool = false) {
        self.borderColor = hasError ? AppColors.errorBorder : borderColor
        self.hasError = hasError
    }
    
    func body(content: Content) -> some View {
        content
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: hasError ? 2 : 1)
            )
    }
}

/// バリデーション付き入力フィールドのスタイルを適用するModifier
struct ValidatedInputStyle: ViewModifier {
    let isValid: Bool
    let hasError: Bool
    let isEmpty: Bool
    
    var borderColor: Color {
        if hasError {
            return AppColors.errorBorder
        } else if isValid && !isEmpty {
            return AppColors.successBorder
        } else {
            return AppColors.border
        }
    }
    
    func body(content: Content) -> some View {
        content
            .modifier(InputFieldStyle(borderColor: borderColor, hasError: hasError))
    }
}

// MARK: - Text Style Modifiers

/// セクションタイトルのスタイルを適用するModifier
struct SectionTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(AppColors.primaryText)
    }
}

/// フィールドラベルのスタイルを適用するModifier
struct FieldLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(AppColors.secondaryText)
    }
}

/// エラーメッセージのスタイルを適用するModifier
struct ErrorMessageStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundColor(AppColors.error)
            .multilineTextAlignment(.leading)
    }
}

/// 警告メッセージのスタイルを適用するModifier
struct WarningMessageStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundColor(AppColors.warning)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - Status Icon Modifiers

/// ステータスアイコンのスタイルを適用するModifier
struct StatusIconStyle: ViewModifier {
    let status: StatusType
    
    enum StatusType {
        case success, error, warning, info
        
        var color: Color {
            switch self {
            case .success: return AppColors.success
            case .error: return AppColors.error
            case .warning: return AppColors.warning
            case .info: return AppColors.info
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(status.color)
            .font(.caption)
    }
}

// MARK: - View Extensions

extension View {
    
    // MARK: - Card Styles
    
    /// カード風の背景スタイルを適用
    func cardStyle() -> some View {
        self.modifier(CardStyle())
    }
    
    /// 軽いカード風の背景スタイルを適用
    func lightCardStyle() -> some View {
        self.modifier(LightCardStyle())
    }
    
    // MARK: - Button Styles
    
    /// プライマリボタンのスタイルを適用
    func primaryButtonStyle(isEnabled: Bool = true) -> some View {
        self.modifier(PrimaryButtonStyle(isEnabled: isEnabled))
    }
    
    /// セカンダリボタンのスタイルを適用
    func secondaryButtonStyle(isEnabled: Bool = true) -> some View {
        self.modifier(SecondaryButtonStyle(isEnabled: isEnabled))
    }
    
    /// 小さなアクションボタンのスタイルを適用
    func smallActionButtonStyle() -> some View {
        self.modifier(SmallActionButtonStyle())
    }
    
    // MARK: - Input Field Styles
    
    /// 入力フィールドのスタイルを適用
    func inputFieldStyle(borderColor: Color = AppColors.border, hasError: Bool = false) -> some View {
        self.modifier(InputFieldStyle(borderColor: borderColor, hasError: hasError))
    }
    
    /// バリデーション付き入力フィールドのスタイルを適用
    func validatedInputStyle(isValid: Bool, hasError: Bool, isEmpty: Bool = false) -> some View {
        self.modifier(ValidatedInputStyle(isValid: isValid, hasError: hasError, isEmpty: isEmpty))
    }
    
    // MARK: - Text Styles
    
    /// セクションタイトルのスタイルを適用
    func sectionTitleStyle() -> some View {
        self.modifier(SectionTitleStyle())
    }
    
    /// フィールドラベルのスタイルを適用
    func fieldLabelStyle() -> some View {
        self.modifier(FieldLabelStyle())
    }
    
    /// エラーメッセージのスタイルを適用
    func errorMessageStyle() -> some View {
        self.modifier(ErrorMessageStyle())
    }
    
    /// 警告メッセージのスタイルを適用
    func warningMessageStyle() -> some View {
        self.modifier(WarningMessageStyle())
    }
    
    // MARK: - Status Icon Styles
    
    /// ステータスアイコンのスタイルを適用
    func statusIconStyle(_ status: StatusIconStyle.StatusType) -> some View {
        self.modifier(StatusIconStyle(status: status))
    }
}