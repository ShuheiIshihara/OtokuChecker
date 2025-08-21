//
//  ComparisonErrors.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation

// MARK: - 入力検証エラー

/// 入力値検証時のエラー
enum ComparisonValidationError: LocalizedError, Equatable {
    // 商品名エラー
    case emptyProductName(String)
    case productNameTooLong(String, Int)
    
    // 価格エラー
    case invalidPrice(String, Decimal)
    case priceOutOfRange(String, Decimal)
    
    // 数量エラー
    case invalidQuantity(String, Decimal)
    case quantityOutOfRange(String, Decimal)
    
    // 税率エラー
    case invalidTaxRate(String, Decimal)
    
    var errorDescription: String? {
        switch self {
        case .emptyProductName(let productName):
            return "\(productName)の商品名を入力してください"
            
        case .productNameTooLong(let productName, let length):
            return "\(productName)の商品名が長すぎます（\(length)文字、最大100文字）"
            
        case .invalidPrice(let productName, let price):
            return "\(productName)の価格が無効です（\(price)円）。0円より大きい値を入力してください"
            
        case .priceOutOfRange(let productName, let price):
            return "\(productName)の価格が範囲外です（\(price)円）。999,999.99円以下で入力してください"
            
        case .invalidQuantity(let productName, let quantity):
            return "\(productName)の数量が無効です（\(quantity)）。0より大きい値を入力してください"
            
        case .quantityOutOfRange(let productName, let quantity):
            return "\(productName)の数量が範囲外です（\(quantity)）。99,999.99以下で入力してください"
            
        case .invalidTaxRate(let productName, let rate):
            return "\(productName)の税率が無効です（\(rate)）。0.00-1.00の範囲で入力してください"
        }
    }
    
    var failureReason: String? {
        return errorDescription
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptyProductName:
            return "商品名を入力してください"
        case .productNameTooLong:
            return "商品名を100文字以下に短縮してください"
        case .invalidPrice:
            return "価格に正の数値を入力してください"
        case .priceOutOfRange:
            return "価格を999,999.99円以下で入力してください"
        case .invalidQuantity:
            return "数量に正の数値を入力してください"
        case .quantityOutOfRange:
            return "数量を99,999.99以下で入力してください"
        case .invalidTaxRate:
            return "税率を0%〜100%の範囲で入力してください"
        }
    }
}

// MARK: - 比較処理エラー

/// 比較処理時のエラー
enum ComparisonError: LocalizedError, Equatable {
    case incompatibleUnits(Unit, Unit)
    case bothProductsInvalid
    case productAInvalid([ComparisonValidationError])
    case productBInvalid([ComparisonValidationError])
    
    var errorDescription: String? {
        switch self {
        case .incompatibleUnits(let unitA, let unitB):
            return "異なる種類の単位は比較できません（\(unitA.displayName) と \(unitB.displayName)）"
            
        case .bothProductsInvalid:
            return "両方の商品データが無効です"
            
        case .productAInvalid(let errors):
            return "商品Aが無効です: \(errors.first?.errorDescription ?? "不明なエラー")"
            
        case .productBInvalid(let errors):
            return "商品Bが無効です: \(errors.first?.errorDescription ?? "不明なエラー")"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .incompatibleUnits:
            return "単位の種類が異なるため比較できません"
        case .bothProductsInvalid:
            return "入力された商品データに問題があります"
        case .productAInvalid:
            return "商品Aの入力データに問題があります"
        case .productBInvalid:
            return "商品Bの入力データに問題があります"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .incompatibleUnits:
            return "同じ種類の単位（重量同士、容量同士、個数同士）で比較してください"
        case .bothProductsInvalid:
            return "両方の商品の入力内容を確認してください"
        case .productAInvalid:
            return "商品Aの入力内容を確認してください"
        case .productBInvalid:
            return "商品Bの入力内容を確認してください"
        }
    }
}

// MARK: - 計算エラー

/// 計算処理時のエラー
enum CalculationError: LocalizedError, Equatable {
    case calculationOverflow(String)
    case divisionByZero(String)
    case precisionLoss(String)
    case invalidResult(String)
    
    var errorDescription: String? {
        switch self {
        case .calculationOverflow(let context):
            return "計算でオーバーフローが発生しました（\(context)）"
            
        case .divisionByZero(let context):
            return "ゼロ除算エラーが発生しました（\(context)）"
            
        case .precisionLoss(let context):
            return "計算精度の低下が発生しました（\(context)）"
            
        case .invalidResult(let context):
            return "計算結果が無効です（\(context)）"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .calculationOverflow:
            return "数値が大きすぎるため計算できません"
        case .divisionByZero:
            return "ゼロで割ろうとしました"
        case .precisionLoss:
            return "小数点以下の精度が失われました"
        case .invalidResult:
            return "計算結果が数値として無効です"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .calculationOverflow:
            return "より小さな数値で計算してください"
        case .divisionByZero:
            return "数量にゼロ以外の値を入力してください"
        case .precisionLoss:
            return "より小さな数値で計算してください"
        case .invalidResult:
            return "入力値を確認して再度計算してください"
        }
    }
}

// MARK: - エラーユーティリティ

/// エラーハンドリングのユーティリティ
struct ComparisonErrorHandler {
    
    /// 複数の検証エラーを統合して表示用メッセージを生成
    static func formatValidationErrors(_ errors: [ComparisonValidationError]) -> String {
        guard !errors.isEmpty else { return "" }
        
        if errors.count == 1 {
            return errors.first?.errorDescription ?? "入力エラーが発生しました"
        } else {
            let errorMessages = errors.compactMap { $0.errorDescription }
            return errorMessages.joined(separator: "\n")
        }
    }
    
    /// エラーの重要度を判定
    static func errorSeverity(_ error: Error) -> ErrorSeverity {
        switch error {
        case is ComparisonValidationError:
            return .medium
        case is ComparisonError:
            return .high
        case is CalculationError:
            return .critical
        default:
            return .low
        }
    }
    
    /// ユーザーフレンドリーなエラーメッセージを生成
    static func userFriendlyMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError {
            return localized.errorDescription ?? "エラーが発生しました"
        }
        return "予期しないエラーが発生しました"
    }
}

/// エラーの重要度
enum ErrorSeverity {
    case low        // 警告レベル
    case medium     // 注意レベル
    case high       // エラーレベル
    case critical   // 致命的エラー
    
    var displayColor: String {
        switch self {
        case .low: return "gray"
        case .medium: return "orange"
        case .high: return "red"
        case .critical: return "purple"
        }
    }
}