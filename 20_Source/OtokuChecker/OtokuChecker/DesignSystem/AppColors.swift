//
//  AppColors.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/23.
//

import SwiftUI

/// アプリケーション全体で使用するカラーシステム
struct AppColors {
    
    // MARK: - Primary Colors
    
    /// メインブランドカラー（プライマリボタン、アクセントなど）
    static let primary = Color.blue
    
    /// セカンダリカラー（サブボタン、補助要素など）
    static let secondary = Color.gray
    
    // MARK: - Semantic Colors
    
    /// 成功状態（バリデーション成功、正常完了など）
    static let success = Color.green
    
    /// 警告状態（注意喚起、警告メッセージなど）
    static let warning = Color.orange
    
    /// エラー状態（バリデーション失敗、エラーメッセージなど）
    static let error = Color.red
    
    /// 情報表示（ヒント、補助情報など）
    static let info = Color.blue
    
    // MARK: - Background Colors
    
    /// カードや入力フィールドの背景色
    static let cardBackground = Color(.systemGray6)
    
    /// セクション区切りや軽い背景色
    static let lightBackground = Color(.systemGray5)
    
    /// メイン背景色
    static let background = Color(.systemBackground)
    
    /// セカンダリ背景色
    static let secondaryBackground = Color(.secondarySystemBackground)
    
    // MARK: - Text Colors
    
    /// プライマリテキスト色
    static let primaryText = Color.primary
    
    /// セカンダリテキスト色
    static let secondaryText = Color.secondary
    
    /// 無効化されたテキスト色
    static let disabledText = Color(.systemGray3)
    
    // MARK: - Border Colors
    
    /// 通常のボーダー色
    static let border = Color(.systemGray4)
    
    /// フォーカス時のボーダー色
    static let focusBorder = Color.blue
    
    /// エラー時のボーダー色
    static let errorBorder = Color.red
    
    /// 成功時のボーダー色
    static let successBorder = Color.green
    
    // MARK: - Button States
    
    /// 無効化されたボタンの背景色
    static let disabledButton = Color(.systemGray3)
    
    /// 無効化されたボタンのテキスト色
    static let disabledButtonText = Color(.systemGray)
}

// MARK: - Dynamic Color Support

extension AppColors {
    
    /// ライト/ダークモード対応のカスタムカラーを作成
    /// - Parameters:
    ///   - light: ライトモード時の色
    ///   - dark: ダークモード時の色
    /// - Returns: Dynamic Color
    static func dynamicColor(light: Color, dark: Color) -> Color {
        return Color(UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(dark)
            } else {
                return UIColor(light)
            }
        })
    }
}

// MARK: - Convenience Extensions

extension Color {
    
    /// AppColors の primary カラーへのショートカット
    static var appPrimary: Color { AppColors.primary }
    
    /// AppColors の secondary カラーへのショートカット
    static var appSecondary: Color { AppColors.secondary }
    
    /// AppColors の error カラーへのショートカット
    static var appError: Color { AppColors.error }
    
    /// AppColors の success カラーへのショートカット
    static var appSuccess: Color { AppColors.success }
    
    /// AppColors の warning カラーへのショートカット
    static var appWarning: Color { AppColors.warning }
}