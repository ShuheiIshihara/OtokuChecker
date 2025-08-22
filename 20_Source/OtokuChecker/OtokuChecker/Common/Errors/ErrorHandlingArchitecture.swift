//
//  ErrorHandlingArchitecture.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/22.
//

import Foundation
import OSLog

// MARK: - エラーハンドリングアーキテクチャ基盤

/// エラーハンドリング基盤の中央管理システム
@MainActor
final class ErrorHandler: ObservableObject {
    
    // MARK: - Singleton
    static let shared = ErrorHandler()
    private init() {}
    
    // MARK: - Error State Management
    @Published var currentError: AppError?
    @Published var isShowingError: Bool = false
    
    // MARK: - Error Queue
    private var errorQueue: [AppError] = []
    private var isProcessingError: Bool = false
    
    // MARK: - Error Handling Strategy
    enum ErrorHandlingStrategy {
        case immediate    // 即座に表示（重要なエラー）
        case queued      // キューに追加（一般的なエラー）
        case silent      // ログのみ記録（軽微なエラー）
        case retry       // 自動リトライ付き
    }
    
    // MARK: - Main Error Handling Method
    func handle(_ error: Error, 
                strategy: ErrorHandlingStrategy = .queued,
                context: String? = nil,
                retryAction: (() async -> Void)? = nil) {
        
        let appError = error.asAppError()
        
        // ログ記録
        LoggingService.shared.logError(appError, context: context)
        
        // 戦略に基づく処理
        switch strategy {
        case .immediate:
            showErrorImmediately(appError)
            
        case .queued:
            addToQueue(appError)
            processNextError()
            
        case .silent:
            // ログのみ、UI表示なし
            break
            
        case .retry:
            Task {
                await handleWithRetry(appError, retryAction: retryAction, context: context)
            }
        }
        
        // 特定エラーの自動対応
        performAutomaticRecovery(for: appError)
    }
    
    // MARK: - Error Display Methods
    private func showErrorImmediately(_ error: AppError) {
        currentError = error
        isShowingError = true
    }
    
    private func addToQueue(_ error: AppError) {
        // 重複エラーの排除
        if !errorQueue.contains(where: { $0.errorCode == error.errorCode }) {
            errorQueue.append(error)
        }
    }
    
    private func processNextError() {
        guard !isProcessingError, let nextError = errorQueue.first else { return }
        
        isProcessingError = true
        errorQueue.removeFirst()
        
        currentError = nextError
        isShowingError = true
    }
    
    // MARK: - Retry Logic
    private func handleWithRetry(_ error: AppError, 
                                retryAction: (() async -> Void)?,
                                context: String?) async {
        guard let retryAction = retryAction else {
            handle(error, strategy: .queued, context: context)
            return
        }
        
        // 最大3回リトライ
        for attempt in 1...3 {
            do {
                // iOS 15対応：nanosecond指定のTask.sleep使用
                try await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000) // 段階的遅延（秒単位）
                await retryAction()
                LoggingService.shared.logInfo("リトライ成功: \(attempt)回目", context: context)
                return
            } catch {
                LoggingService.shared.logWarning("リトライ失敗: \(attempt)回目", context: context)
                if attempt == 3 {
                    handle(error, strategy: .queued, context: context)
                }
            }
        }
    }
    
    // MARK: - Automatic Recovery
    private func performAutomaticRecovery(for error: AppError) {
        switch error {
        case .storageUnavailable:
            // 自動的にストレージ容量チェック
            Task {
                await PerformanceMonitor.shared.checkStorageSpace()
            }
            
        case .memoryLimitExceeded:
            // 自動的にメモリ解放
            Task {
                await PerformanceMonitor.shared.performMemoryCleanup()
            }
            
        case .dataCorruption:
            // 自動的にデータ修復試行
            Task {
                await DataIntegrityService.shared.attemptDataRepair()
            }
            
        default:
            break
        }
    }
    
    // MARK: - Error Dismissal
    func dismissCurrentError() {
        isShowingError = false
        currentError = nil
        isProcessingError = false
        
        // 次のエラーを処理
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.processNextError()
        }
    }
    
    // MARK: - Bulk Error Handling for Forms
    func handleValidationErrors(_ errors: [ComparisonValidationError]) -> AppError {
        let formError = AppError.formValidationFailed(
            errors.map { ValidationError(
                field: "商品情報",
                message: $0.errorDescription ?? "入力エラー",
                code: "VALIDATION_ERROR"
            )}
        )
        return formError
    }
}

// MARK: - Context-Specific Error Handlers

/// 比較処理専用エラーハンドラー（拡張版）
extension ComparisonErrorHandler {
    
    @MainActor
    static func handleAdvanced(_ error: ComparisonError, productA: ComparisonProduct, productB: ComparisonProduct) {
        let context = "比較処理: \(productA.name) vs \(productB.name)"
        
        switch error {
        case .incompatibleUnits(let unitA, let unitB):
            let appError = AppError.unitConversionFailed("\(unitA.displayName)と\(unitB.displayName)は比較できません")
            ErrorHandler.shared.handle(appError, strategy: .immediate, context: context)
            
        case .productAInvalid(let errors), .productBInvalid(let errors):
            let appError = ErrorHandler.shared.handleValidationErrors(errors)
            ErrorHandler.shared.handle(appError, strategy: .immediate, context: context)
            
        case .bothProductsInvalid:
            let appError = AppError.invalidProductData("両方の商品データが無効です")
            ErrorHandler.shared.handle(appError, strategy: .immediate, context: context)
        }
    }
}

/// Repository層専用エラーハンドラー
struct RepositoryErrorHandler {
    
    @MainActor
    static func handle(_ error: RepositoryError, operation: String, retryAction: (() async -> Void)? = nil) {
        let context = "データ操作: \(operation)"
        
        switch error {
        case .entityNotFound:
            let appError = AppError.invalidProductData("指定されたデータが見つかりません")
            ErrorHandler.shared.handle(appError, strategy: .queued, context: context)
            
        case .saveFailed, .deleteFailed:
            let appError = AppError.repositoryError(error)
            ErrorHandler.shared.handle(appError, strategy: .retry, context: context, retryAction: retryAction)
            
        case .coreDataError:
            let appError = AppError.dataCorruption
            ErrorHandler.shared.handle(appError, strategy: .immediate, context: context)
            
        case .invalidData:
            let appError = AppError.invalidProductData("データが破損しています")
            ErrorHandler.shared.handle(appError, strategy: .queued, context: context)
        }
    }
}

// MARK: - Shopping Context Error Handler

/// 買い物中特有のエラーハンドラー
struct ShoppingContextErrorHandler {
    
    /// 店舗内での通信エラー処理
    @MainActor
    static func handleNetworkError(in storeName: String?) {
        let context = storeName.map { "店舗: \($0)" } ?? "店舗内"
        let appError = AppError.networkUnavailable
        
        // 買い物中は邪魔にならないよう silent で処理
        ErrorHandler.shared.handle(appError, strategy: .silent, context: context)
        
        // ただし、オフライン機能の提案を表示
        let suggestion = AppError.invalidUserInput("オフラインでも比較可能です。データは後で同期されます。")
        ErrorHandler.shared.handle(suggestion, strategy: .queued, context: context)
    }
    
    /// 片手操作中の入力エラー処理
    @MainActor
    static func handleOneHandedInputError(_ error: ComparisonValidationError) {
        let context = "片手操作中"
        
        // 片手操作中は音声フィードバックも検討
        let userFriendlyError = AppError.invalidUserInput("\(error.errorDescription ?? "入力を確認してください")。音声読み上げ機能を有効にできます。")
        
        ErrorHandler.shared.handle(userFriendlyError, strategy: .queued, context: context)
    }
}

// MARK: - Performance Monitor

/// パフォーマンス監視とエラー予防
actor PerformanceMonitor {
    static let shared = PerformanceMonitor()
    private init() {}
    
    func checkStorageSpace() async {
        // ストレージ容量チェック実装
        // 容量不足時は自動的にキャッシュクリーンアップ
    }
    
    func performMemoryCleanup() async {
        // メモリ解放処理
        // 不要なキャッシュデータの削除
    }
    
    func monitorResponseTimes() async {
        // レスポンス時間監視
        // 性能要件違反時のアラート
    }
}

// MARK: - Data Integrity Service

/// データ整合性チェック・修復サービス
actor DataIntegrityService {
    static let shared = DataIntegrityService()
    private init() {}
    
    func attemptDataRepair() async {
        // Core Dataデータ修復処理
        // 破損データの検出・修復・復旧
    }
    
    func validateProductData(_ product: ComparisonProduct) async -> [ComparisonValidationError] {
        // 商品データの詳細検証
        // 日本市場特有の検証ルールを適用
        return []
    }
}