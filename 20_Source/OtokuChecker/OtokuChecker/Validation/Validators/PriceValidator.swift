//
//  PriceValidator.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/23.
//

import Foundation

/// 価格のバリデーションを行うstruct
struct PriceValidator {
    
    /// 価格の最大値（日常商品は10万円以内で十分）
    static let maxValue: Decimal = 99_999
    
    /// 価格をバリデーションする
    /// - Parameter input: バリデーション対象の価格文字列
    /// - Returns: バリデーション結果（成功時はDecimal値）
    static func validate(_ input: String) -> ValidationResult<Decimal> {
        // 空文字チェック
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failure(.price(.empty))
        }
        
        // 基本的なクリーンアップ（円記号・カンマ除去）
        let cleaned = cleanPriceString(trimmed)
        
        // 数値変換
        guard let decimal = Decimal(string: cleaned) else {
            return .failure(.price(.invalidFormat))
        }
        
        // 基本的な範囲チェック
        if decimal <= 0 {
            return .failure(.price(.negativeOrZero))
        }
        
        if decimal > maxValue {
            return .failure(.price(.tooLarge))
        }
        
        return .success(decimal)
    }
    
    /// 価格文字列をクリーンアップする
    /// - Parameter input: 入力された価格文字列
    /// - Returns: クリーンアップされた価格文字列
    static func cleanPriceString(_ input: String) -> String {
        var cleaned = input
        
        // 円記号を除去
        cleaned = cleaned.replacingOccurrences(of: "¥", with: "")
        cleaned = cleaned.replacingOccurrences(of: "円", with: "")
        
        // カンマを除去
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        
        // 全角数字を半角に変換
        cleaned = normalizeNumberString(cleaned)
        
        // 前後の空白を除去
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    /// 価格をフォーマットして表示用文字列に変換する
    /// - Parameter price: フォーマット対象の価格
    /// - Returns: フォーマットされた価格文字列（例: "1,980円"）
    static func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        
        let priceString = formatter.string(from: price as NSDecimalNumber) ?? "\(price)"
        return "\(priceString)円"
    }
    
    /// 価格を税込み価格に変換する
    /// - Parameters:
    ///   - price: 税抜き価格
    ///   - taxRate: 税率（例: 10.0 = 10%）
    /// - Returns: 税込み価格
    static func includeTax(price: Decimal, taxRate: Decimal) -> Decimal {
        return price * (1 + taxRate / 100)
    }
    
    /// 価格を税抜き価格に変換する
    /// - Parameters:
    ///   - taxIncludedPrice: 税込み価格
    ///   - taxRate: 税率（例: 10.0 = 10%）
    /// - Returns: 税抜き価格
    static func excludeTax(taxIncludedPrice: Decimal, taxRate: Decimal) -> Decimal {
        return taxIncludedPrice / (1 + taxRate / 100)
    }
    
    /// 価格入力のプレースホルダー例を生成する
    /// - Returns: プレースホルダー文字列
    static func getPlaceholderExample() -> String {
        return "例: 198, 1980"
    }
    
    /// 価格の妥当性をリアルタイムでチェック（UI表示用）
    /// - Parameter input: チェック対象の価格文字列
    /// - Returns: (クリーンアップされた値, エラー, 警告)
    static func checkRealtime(_ input: String) -> (cleaned: String?, error: ValidationInputError?, warning: String?) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 空の場合は何もしない
        guard !trimmed.isEmpty else {
            return (cleaned: nil, error: nil, warning: nil)
        }
        
        let cleaned = cleanPriceString(trimmed)
        
        // 数値に変換できない場合
        guard let decimal = Decimal(string: cleaned) else {
            return (cleaned: nil, error: .price(.invalidFormat), warning: nil)
        }
        
        // 負数や0の場合
        if decimal <= 0 {
            return (cleaned: cleaned, error: .price(.negativeOrZero), warning: nil)
        }
        
        // 最大値を超える場合
        if decimal > maxValue {
            return (cleaned: cleaned, error: .price(.tooLarge), warning: nil)
        }
        
        // 高額商品の警告
        var warning: String?
        if decimal > 10000 {
            warning = "高額商品です。価格をご確認ください。"
        }
        
        return (cleaned: cleaned, error: nil, warning: warning)
    }
}

// MARK: - Private Helper Methods

private extension PriceValidator {
    
    /// 全角数字を半角数字に変換する
    /// - Parameter input: 変換対象の文字列
    /// - Returns: 変換された文字列
    static func normalizeNumberString(_ input: String) -> String {
        var normalized = input
        
        // 全角数字と記号を半角に変換
        let fullWidthChars = "０１２３４５６７８９．，"
        let halfWidthChars = "0123456789.,"
        
        for (fullWidth, halfWidth) in zip(fullWidthChars, halfWidthChars) {
            normalized = normalized.replacingOccurrences(of: String(fullWidth), with: String(halfWidth))
        }
        
        return normalized
    }
}

// MARK: - Decimal Extensions

extension Decimal {
    /// 小数点以下を指定桁数で丸める
    /// - Parameter scale: 小数点以下の桁数
    /// - Returns: 丸められたDecimal値
    func rounded(to scale: Int) -> Decimal {
        var result = self
        var rounded = result
        NSDecimalRound(&rounded, &result, scale, .plain)
        return rounded
    }
}
