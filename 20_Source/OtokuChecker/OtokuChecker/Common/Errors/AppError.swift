//
//  AppError.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation

// MARK: - Main App Error Protocol

protocol AppErrorProtocol: LocalizedError {
    var errorCode: String { get }
    var errorTitle: String { get }
    var userMessage: String { get }
    var technicalDetails: String? { get }
    var recoveryAction: ErrorRecoveryAction? { get }
}

// MARK: - App Error Enum

enum AppError: AppErrorProtocol {
    
    // MARK: - Data Layer Errors
    case dataCorruption
    case storageUnavailable
    case migrationFailed
    case backupFailed
    
    // MARK: - Business Logic Errors
    case invalidProductData(String)
    case comparisonNotPossible(String)
    case unitConversionFailed(String)
    case calculationError(String)
    
    // MARK: - UI/UX Errors
    case invalidUserInput(String)
    case formValidationFailed([ValidationError])
    case navigationFailed
    case viewRenderingFailed
    
    // MARK: - System Errors
    case memoryLimitExceeded
    case permissionDenied(String)
    case networkUnavailable
    case deviceNotSupported
    
    // MARK: - Repository Errors
    case repositoryError(RepositoryError)
    case useCaseError(UseCaseError)
    
    // MARK: - Custom Error Types
    case shoppingContextError(ShoppingContextError)
    case japaneseMarketError(JapaneseMarketError)  
    case performanceError(PerformanceError)
    case dataIntegrityError(DataIntegrityError)
    
    // MARK: - Unknown Error
    case unknown(Error)
    
    // MARK: - AppErrorProtocol Implementation
    
    var errorCode: String {
        switch self {
        case .dataCorruption:
            return "DATA_CORRUPTION"
        case .storageUnavailable:
            return "STORAGE_UNAVAILABLE"
        case .migrationFailed:
            return "MIGRATION_FAILED"
        case .backupFailed:
            return "BACKUP_FAILED"
        case .invalidProductData:
            return "INVALID_PRODUCT_DATA"
        case .comparisonNotPossible:
            return "COMPARISON_NOT_POSSIBLE"
        case .unitConversionFailed:
            return "UNIT_CONVERSION_FAILED"
        case .calculationError:
            return "CALCULATION_ERROR"
        case .invalidUserInput:
            return "INVALID_USER_INPUT"
        case .formValidationFailed:
            return "FORM_VALIDATION_FAILED"
        case .navigationFailed:
            return "NAVIGATION_FAILED"
        case .viewRenderingFailed:
            return "VIEW_RENDERING_FAILED"
        case .memoryLimitExceeded:
            return "MEMORY_LIMIT_EXCEEDED"
        case .permissionDenied:
            return "PERMISSION_DENIED"
        case .networkUnavailable:
            return "NETWORK_UNAVAILABLE"
        case .deviceNotSupported:
            return "DEVICE_NOT_SUPPORTED"
        case .repositoryError(let error):
            return "REPOSITORY_\(error.localizedDescription.uppercased())"
        case .useCaseError(let error):
            return "USECASE_\(error.localizedDescription.uppercased())"
        case .shoppingContextError(let error):
            return "SHOPPING_\(String(describing: error).uppercased())"
        case .japaneseMarketError(let error):
            return "JAPANESE_MARKET_\(String(describing: error).uppercased())"
        case .performanceError(let error):
            return "PERFORMANCE_\(String(describing: error).uppercased())"
        case .dataIntegrityError(let error):
            return "DATA_INTEGRITY_\(String(describing: error).uppercased())"
        case .unknown:
            return "UNKNOWN_ERROR"
        }
    }
    
    var errorTitle: String {
        switch self {
        case .dataCorruption, .storageUnavailable, .migrationFailed, .backupFailed:
            return "データエラー"
        case .invalidProductData, .comparisonNotPossible, .unitConversionFailed, .calculationError:
            return "処理エラー"
        case .invalidUserInput, .formValidationFailed:
            return "入力エラー"
        case .navigationFailed, .viewRenderingFailed:
            return "画面エラー"
        case .memoryLimitExceeded, .deviceNotSupported:
            return "システムエラー"
        case .permissionDenied:
            return "権限エラー"
        case .networkUnavailable:
            return "ネットワークエラー"
        case .repositoryError, .useCaseError:
            return "アプリケーションエラー"
        case .shoppingContextError:
            return "買い物中エラー"
        case .japaneseMarketError:
            return "商品情報エラー"
        case .performanceError:
            return "パフォーマンスエラー"
        case .dataIntegrityError:
            return "データエラー"
        case .unknown:
            return "予期しないエラー"
        }
    }
    
    var userMessage: String {
        switch self {
        case .dataCorruption:
            return "データが破損しています。アプリを再起動してください。"
        case .storageUnavailable:
            return "データの保存ができません。ストレージ容量を確認してください。"
        case .migrationFailed:
            return "データの移行に失敗しました。アプリを再インストールが必要な場合があります。"
        case .backupFailed:
            return "データのバックアップに失敗しました。"
        case .invalidProductData(let details):
            return "商品データが無効です：\(details)"
        case .comparisonNotPossible(let reason):
            return "比較できません：\(reason)"
        case .unitConversionFailed(let unit):
            return "単位「\(unit)」の変換に失敗しました。"
        case .calculationError(let operation):
            return "\(operation)の計算中にエラーが発生しました。"
        case .invalidUserInput(let field):
            return "\(field)の入力が正しくありません。"
        case .formValidationFailed(let errors):
            let messages = errors.map { $0.message }
            return "入力エラー：\(messages.joined(separator: "、"))"
        case .navigationFailed:
            return "画面の遷移に失敗しました。"
        case .viewRenderingFailed:
            return "画面の表示に失敗しました。"
        case .memoryLimitExceeded:
            return "メモリが不足しています。アプリを再起動してください。"
        case .permissionDenied(let permission):
            return "\(permission)の権限が拒否されました。設定で許可してください。"
        case .networkUnavailable:
            return "ネットワークに接続できません。"
        case .deviceNotSupported:
            return "お使いのデバイスはサポートされていません。"
        case .repositoryError(let error):
            return "データアクセスエラー：\(error.localizedDescription)"
        case .useCaseError(let error):
            return "処理エラー：\(error.localizedDescription)"
        case .shoppingContextError(let error):
            return error.localizedDescription
        case .japaneseMarketError(let error):
            return error.localizedDescription
        case .performanceError(let error):
            return error.localizedDescription
        case .dataIntegrityError(let error):
            return error.localizedDescription
        case .unknown(let error):
            return "予期しないエラーが発生しました：\(error.localizedDescription)"
        }
    }
    
    var technicalDetails: String? {
        switch self {
        case .repositoryError(let error):
            return "Repository Error: \(error)"
        case .useCaseError(let error):
            return "UseCase Error: \(error)"
        case .shoppingContextError(let error):
            return "Shopping Context: \(error)"
        case .japaneseMarketError(let error):
            return "Japanese Market: \(error)"
        case .performanceError(let error):
            return "Performance: \(error)"
        case .dataIntegrityError(let error):
            return "Data Integrity: \(error)"
        case .unknown(let error):
            return "Underlying Error: \(error)"
        default:
            return nil
        }
    }
    
    var recoveryAction: ErrorRecoveryAction? {
        switch self {
        case .dataCorruption, .migrationFailed:
            return .restartApp
        case .storageUnavailable:
            return .checkStorage
        case .invalidUserInput, .formValidationFailed:
            return .retryInput
        case .comparisonNotPossible, .unitConversionFailed:
            return .checkInput
        case .navigationFailed, .viewRenderingFailed:
            return .restartApp
        case .memoryLimitExceeded:
            return .restartApp
        case .permissionDenied:
            return .checkSettings
        case .networkUnavailable:
            return .checkNetwork
        case .deviceNotSupported:
            return .upgradeDevice
        case .shoppingContextError(let error):
            return mapShoppingContextRecoveryAction(error)
        case .japaneseMarketError(let error):
            return mapJapaneseMarketRecoveryAction(error)
        case .performanceError(let error):
            return mapPerformanceRecoveryAction(error)
        case .dataIntegrityError(let error):
            return mapDataIntegrityRecoveryAction(error)
        default:
            return .contactSupport
        }
    }
    
    // MARK: - LocalizedError Implementation
    
    var errorDescription: String? {
        return userMessage
    }
    
    var failureReason: String? {
        return technicalDetails
    }
    
    var recoverySuggestion: String? {
        return recoveryAction?.suggestion
    }
    
    // MARK: - Custom Error Recovery Action Mapping
    
    private func mapShoppingContextRecoveryAction(_ error: ShoppingContextError) -> ErrorRecoveryAction {
        switch error {
        case .weakSignalInStore, .backgroundAppInterruption:
            return .restartApp
        case .batteryLowWarning:
            return .checkSettings
        case .oneHandedInputMistake, .cartCollisionInput:
            return .retryInput
        case .timeConstraintViolation:
            return .restartApp
        case .storeDataConflict, .priceVolatilityDetected:
            return .checkInput
        }
    }
    
    private func mapJapaneseMarketRecoveryAction(_ error: JapaneseMarketError) -> ErrorRecoveryAction {
        switch error {
        case .taxRateAmbiguity, .includedTaxMismatch:
            return .checkSettings
        case .traditionalUnitConversion, .kanjiNumeralConversion:
            return .retryInput
        case .fullWidthHalfWidthMixing, .hiraganaKatakanaMismatch:
            return .checkInput
        case .brandNameVariation, .productNameTooComplex:
            return .retryInput
        case .regionalPricingConflict:
            return .checkInput
        case .storeChainDetection, .regionalDialectInStoreName:
            return .checkInput
        }
    }
    
    private func mapPerformanceRecoveryAction(_ error: PerformanceError) -> ErrorRecoveryAction {
        switch error {
        case .comparisonTimeout, .searchTimeout, .dataLoadTimeout:
            return .restartApp
        case .memoryPressureHigh, .tooManyRecordsLoaded:
            return .restartApp
        case .cacheOverflow:
            return .clearCache
        case .calculationComplexity, .backgroundProcessingDelay:
            return .retryInput
        }
    }
    
    private func mapDataIntegrityRecoveryAction(_ error: DataIntegrityError) -> ErrorRecoveryAction {
        switch error {
        case .duplicateProductDetected:
            return .mergeData
        case .priceOutlierDetected:
            return .checkInput
        case .categoryMismatch:
            return .fixCategory
        case .incompleteProductData, .suspiciousDataEntry:
            return .retryInput
        case .dataVersionMismatch:
            return .updateApp
        case .orphanedRecord, .brokenRelationship:
            return .repairData
        }
    }
}

// MARK: - Error Recovery Actions

enum ErrorRecoveryAction {
    case retryInput
    case checkInput
    case checkStorage
    case checkNetwork
    case checkSettings
    case restartApp
    case upgradeDevice
    case contactSupport
    
    // 新しいカスタムリカバリーアクション
    case clearCache
    case mergeData
    case fixCategory
    case updateApp
    case repairData
    
    var suggestion: String {
        switch self {
        case .retryInput:
            return "入力内容を確認して、もう一度お試しください。"
        case .checkInput:
            return "入力データを確認してください。"
        case .checkStorage:
            return "ストレージ容量を確認し、不要なファイルを削除してください。"
        case .checkNetwork:
            return "インターネット接続を確認してください。"
        case .checkSettings:
            return "設定画面で権限を確認してください。"
        case .restartApp:
            return "アプリを再起動してください。"
        case .upgradeDevice:
            return "お使いのデバイスをアップデートするか、新しいデバイスをご利用ください。"
        case .contactSupport:
            return "問題が解決しない場合は、サポートまでお問い合わせください。"
        case .clearCache:
            return "キャッシュをクリアしてください。"
        case .mergeData:
            return "重複データを統合してください。"
        case .fixCategory:
            return "カテゴリを修正してください。"
        case .updateApp:
            return "アプリを最新版に更新してください。"
        case .repairData:
            return "データの修復を実行してください。"
        }
    }
}

// MARK: - Validation Error

struct ValidationError {
    let field: String
    let message: String
    let code: String
}

// MARK: - Error Extension for Easy Conversion

extension Error {
    func asAppError() -> AppError {
        if let appError = self as? AppError {
            return appError
        } else if let repositoryError = self as? RepositoryError {
            return AppError.repositoryError(repositoryError)
        } else if let useCaseError = self as? UseCaseError {
            return AppError.useCaseError(useCaseError)
        } else if let shoppingError = self as? ShoppingContextError {
            return AppError.shoppingContextError(shoppingError)
        } else if let marketError = self as? JapaneseMarketError {
            return AppError.japaneseMarketError(marketError)
        } else if let performanceError = self as? PerformanceError {
            return AppError.performanceError(performanceError)
        } else if let dataError = self as? DataIntegrityError {
            return AppError.dataIntegrityError(dataError)
        } else if let comparisonError = self as? ComparisonError {
            return AppError.comparisonNotPossible(comparisonError.localizedDescription)
        } else if let calculationError = self as? CalculationError {
            return AppError.calculationError(calculationError.localizedDescription)
        } else {
            return AppError.unknown(self)
        }
    }
}

// MARK: - Error Logging Helper

struct ErrorLogger {
    static func log(_ error: AppErrorProtocol, context: String? = nil) {
        let contextString = context.map { " [Context: \($0)]" } ?? ""
        print("🚨 [\(error.errorCode)] \(error.errorTitle): \(error.userMessage)\(contextString)")
        
        if let technical = error.technicalDetails {
            print("   Technical: \(technical)")
        }
    }
    
    static func log(_ error: Error, context: String? = nil) {
        log(error.asAppError(), context: context)
    }
}