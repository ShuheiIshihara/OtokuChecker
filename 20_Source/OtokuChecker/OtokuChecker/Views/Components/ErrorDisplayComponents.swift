//
//  ErrorDisplayComponents.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/22.
//

import SwiftUI

// MARK: - エラー表示コンポーネント

/// メインのエラーアラート表示
struct ErrorAlert: ViewModifier {
    @Binding var error: AppError?
    let onDismiss: (() -> Void)?
    
    init(error: Binding<AppError?>, onDismiss: (() -> Void)? = nil) {
        self._error = error
        self.onDismiss = onDismiss
    }
    
    func body(content: Content) -> some View {
        content
            .alert(
                error?.errorTitle ?? "エラー",
                isPresented: .constant(error != nil),
                presenting: error
            ) { presentedError in
                // エラーの重要度に応じたボタン配置
                ErrorAlertButtons(error: presentedError, onDismiss: dismissError)
            } message: { presentedError in
                Text(presentedError.userMessage)
                    .font(.body)
            }
    }
    
    private func dismissError() {
        onDismiss?()
        error = nil
        ErrorHandler.shared.dismissCurrentError()
    }
}

/// エラーアラートのボタン部分
struct ErrorAlertButtons: View {
    let error: AppError
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            if let recoveryAction = error.recoveryAction {
                // リカバリーアクションがある場合
                Button(recoveryAction.suggestion) {
                    performRecoveryAction(recoveryAction)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                
                Button("キャンセル", role: .cancel) {
                    onDismiss()
                }
            } else {
                // 標準の「OK」ボタン
                Button("OK") {
                    onDismiss()
                }
            }
        }
    }
    
    private func performRecoveryAction(_ action: ErrorRecoveryAction) {
        Task {
            switch action {
            case .restartApp:
                // アプリ再起動の案内
                break
            case .clearCache:
                await performCacheClearing()
            case .checkSettings:
                openSettings()
            default:
                break
            }
        }
    }
    
    private func performCacheClearing() async {
        // キャッシュクリア処理
    }
    
    private func openSettings() {
        // 設定画面へのナビゲーション
    }
}

/// インライン形式のエラー表示
struct InlineErrorView: View {
    let error: AppError?
    let showIcon: Bool
    
    init(_ error: AppError?, showIcon: Bool = true) {
        self.error = error
        self.showIcon = showIcon
    }
    
    var body: some View {
        if let error = error {
            HStack(spacing: 8) {
                if showIcon {
                    Image(systemName: errorIcon(for: error))
                        .foregroundColor(errorColor(for: error))
                        .accessibilityHidden(true)
                }
                
                Text(error.userMessage)
                    .font(.caption)
                    .foregroundColor(errorColor(for: error))
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(errorColor(for: error).opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(errorColor(for: error).opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private func errorIcon(for error: AppError) -> String {
        switch error {
        case .shoppingContextError:
            return "cart.badge.questionmark"
        case .japaneseMarketError:
            return "textformat"
        case .performanceError:
            return "gauge.badge.minus"
        case .dataIntegrityError:
            return "externaldrive.badge.exclamationmark"
        case .invalidUserInput, .formValidationFailed:
            return "exclamationmark.triangle"
        case .networkUnavailable:
            return "wifi.slash"
        case .dataCorruption:
            return "exclamationmark.octagon"
        default:
            return "exclamationmark.circle"
        }
    }
    
    private func errorColor(for error: AppError) -> Color {
        let severity = ErrorSeverity.severity(for: error)
        
        switch severity {
        case .low:
            return .secondary
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }
}

/// トースト形式のエラー表示
struct ErrorToast: View {
    let error: AppError
    @State private var isVisible: Bool = true
    let onDismiss: () -> Void
    
    var body: some View {
        if isVisible {
            VStack {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(error.errorTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text(error.userMessage)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Button(action: dismiss) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(toastBackgroundColor(for: error))
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                )
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                // 自動消去タイマー
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    dismiss()
                }
            }
        }
    }
    
    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
    
    private func toastBackgroundColor(for error: AppError) -> Color {
        let severity = ErrorSeverity.severity(for: error)
        
        switch severity {
        case .low:
            return .gray
        case .medium:
            return .orange
        case .high:
            return .red
        case .critical:
            return .purple
        }
    }
}

/// 買い物中特化のエラー表示
struct ShoppingErrorView: View {
    let error: ShoppingContextError
    let onRetry: (() -> Void)?
    let onContinue: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            // エラーアイコンとタイトル
            VStack(spacing: 8) {
                Image(systemName: shoppingErrorIcon(for: error))
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                
                Text("買い物中のエラー")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            // エラーメッセージ
            Text(error.localizedDescription)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // 回復提案
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // アクションボタン
            VStack(spacing: 12) {
                if let onRetry = onRetry {
                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("もう一度試す")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                
                if let onContinue = onContinue {
                    Button(action: onContinue) {
                        HStack {
                            Image(systemName: "arrow.right")
                            Text("続行する")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
        )
        .padding(.horizontal, 32)
    }
    
    private func shoppingErrorIcon(for error: ShoppingContextError) -> String {
        switch error {
        case .weakSignalInStore:
            return "wifi.slash"
        case .backgroundAppInterruption:
            return "app.badge"
        case .batteryLowWarning:
            return "battery.25"
        case .oneHandedInputMistake, .cartCollisionInput:
            return "hand.tap"
        case .timeConstraintViolation:
            return "clock.badge.exclamationmark"
        case .storeDataConflict, .priceVolatilityDetected:
            return "chart.line.uptrend.xyaxis"
        }
    }
}

/// フォーム検証エラーの表示
struct FormValidationErrorView: View {
    let errors: [ComparisonValidationError]
    
    var body: some View {
        if !errors.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text("入力内容を確認してください")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                }
                
                ForEach(errors.indices, id: \.self) { index in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        
                        Text(errors[index].localizedDescription)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.orange.opacity(0.1))
            )
        }
    }
}

// MARK: - View Extensions

extension View {
    /// エラーアラート表示を追加
    func errorAlert(error: Binding<AppError?>, onDismiss: (() -> Void)? = nil) -> some View {
        self.modifier(ErrorAlert(error: error, onDismiss: onDismiss))
    }
    
    /// エラーハンドラーとの統合
    func withErrorHandling() -> some View {
        self.environmentObject(ErrorHandler.shared)
            .errorAlert(error: .constant(ErrorHandler.shared.currentError)) {
                ErrorHandler.shared.dismissCurrentError()
            }
    }
}

// MARK: - エラー表示管理用ViewModel

@MainActor
final class ErrorDisplayViewModel: ObservableObject {
    @Published var showingToast: Bool = false
    @Published var currentToastError: AppError?
    
    private var toastQueue: [AppError] = []
    
    func showToast(for error: AppError) {
        if showingToast {
            toastQueue.append(error)
        } else {
            currentToastError = error
            showingToast = true
        }
    }
    
    func dismissToast() {
        showingToast = false
        currentToastError = nil
        
        // キューの次のエラーを表示
        if !toastQueue.isEmpty {
            let nextError = toastQueue.removeFirst()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showToast(for: nextError)
            }
        }
    }
}

// MARK: - プレビュー用

#if DEBUG
struct ErrorDisplayComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // インラインエラーのプレビュー
            InlineErrorView(
                AppError.invalidUserInput("商品名が入力されていません")
            )
            
            // フォーム検証エラーのプレビュー
            FormValidationErrorView(errors: [
                .emptyProductName("商品A"),
                .invalidPrice("商品A", 0)
            ])
            
            // 買い物中エラーのプレビュー
            ShoppingErrorView(
                error: .batteryLowWarning(15),
                onRetry: {},
                onContinue: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .previewDisplayName("エラー表示コンポーネント")
    }
}
#endif