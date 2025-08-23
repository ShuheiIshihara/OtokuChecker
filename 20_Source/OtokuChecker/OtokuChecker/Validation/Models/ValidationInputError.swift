//
//  ValidationInputError.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/23.
//

import Foundation

/// バリデーションエラーを表現するenum型
enum ValidationInputError: LocalizedError {
    case productName(ProductNameError)
    case price(PriceError)
    case quantity(QuantityError)
    case comparison(ComparisonError)
    
    /// 商品名のエラー種別
    enum ProductNameError {
        case empty
        case tooLong
    }
    
    /// 価格のエラー種別
    enum PriceError {
        case empty
        case invalidFormat
        case negativeOrZero
        case tooLarge
    }
    
    /// 数量のエラー種別
    enum QuantityError {
        case empty
        case invalidFormat
        case negativeOrZero
        case tooLarge
        case mustBeInteger
    }
    
    /// 比較のエラー種別
    enum ComparisonError {
        case incompatibleUnits
        case invalidProducts
    }
    
    /// LocalizedError準拠：エラーメッセージを返す
    var errorDescription: String? {
        switch self {
        // 商品名エラー
        case .productName(.empty):
            return "商品名を入力してください"
        case .productName(.tooLong):
            return "商品名は50文字以内で入力してください"
            
        // 価格エラー
        case .price(.empty):
            return "価格を入力してください"
        case .price(.invalidFormat):
            return "正しい数値を入力してください"
        case .price(.negativeOrZero):
            return "価格は0より大きい値を入力してください"
        case .price(.tooLarge):
            return "価格は99,999円以下で入力してください"
            
        // 数量エラー
        case .quantity(.empty):
            return "数量を入力してください"
        case .quantity(.invalidFormat):
            return "正しい数値を入力してください"
        case .quantity(.negativeOrZero):
            return "数量は0より大きい値を入力してください"
        case .quantity(.tooLarge):
            return "数量は99,999以下で入力してください"
        case .quantity(.mustBeInteger):
            return "個数は整数で入力してください"
            
        // 比較エラー
        case .comparison(.incompatibleUnits):
            return "異なる種類の単位は比較できません"
        case .comparison(.invalidProducts):
            return "商品情報に不備があります"
        }
    }
    
    /// エラーの種別を返す
    var failureReason: String? {
        switch self {
        case .productName:
            return "商品名の入力エラー"
        case .price:
            return "価格の入力エラー"
        case .quantity:
            return "数量の入力エラー"
        case .comparison:
            return "商品比較エラー"
        }
    }
    
    /// ユーザーへの修正提案を返す
    var recoverySuggestion: String? {
        switch self {
        case .productName(.empty):
            return "例: 牛乳、りんご、パン"
        case .productName(.tooLong):
            return "商品名を短縮してください"
            
        case .price(.invalidFormat):
            return "例: 198、1280.50"
        case .price(.negativeOrZero):
            return "0円より高い価格を入力してください"
        case .price(.tooLarge):
            return "現実的な価格を入力してください"
            
        case .quantity(.invalidFormat):
            return "例: 500、1.5、12"
        case .quantity(.negativeOrZero):
            return "0より大きい数量を入力してください"
        case .quantity(.tooLarge):
            return "現実的な数量を入力してください"
        case .quantity(.mustBeInteger):
            return "例: 1、2、12（小数点以下は入力できません）"
            
        case .comparison(.incompatibleUnits):
            return "同じ種類の単位を選択してください（重量、容量、個数など）"
        case .comparison(.invalidProducts):
            return "すべての項目を正しく入力してください"
        default:
            // 想定していないので何も表示しない
            return nil
        }
    }
}

// MARK: - Convenience Methods

extension ValidationInputError {
    
    /// エラーが重大かどうかを判定
    var isCritical: Bool {
        switch self {
        case .productName(.empty), .price(.empty), .quantity(.empty):
            return true  // 必須項目の未入力は重大
        case .comparison(.invalidProducts):
            return true  // 比較に必要な情報の不備は重大
        default:
            return false // その他は入力形式の問題なので重大ではない
        }
    }
    
    /// フィールド名を返す（UI表示用）
    var fieldName: String {
        switch self {
        case .productName:
            return "商品名"
        case .price:
            return "価格"
        case .quantity:
            return "数量"
        case .comparison:
            return "商品比較"
        }
    }
}
