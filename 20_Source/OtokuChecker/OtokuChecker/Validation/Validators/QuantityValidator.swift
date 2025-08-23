//
//  QuantityValidator.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/23.
//

import Foundation

/// 数量のバリデーションを行うstruct
struct QuantityValidator {
    
    /// 数量の最大値（日常商品の現実的な範囲）
    static let maxValue: Decimal = 99_999
    
    /// 数量をバリデーションする
    /// - Parameters:
    ///   - input: バリデーション対象の数量文字列
    ///   - unit: 対応する単位
    /// - Returns: バリデーション結果（成功時はDecimal値）
    static func validate(_ input: String, unit: Unit) -> ValidationResult<Decimal> {
        // 空文字チェック
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failure(.quantity(.empty))
        }
        
        // 基本的なクリーンアップ
        let cleaned = cleanQuantityString(trimmed)
        
        // 数値変換
        guard let decimal = Decimal(string: cleaned) else {
            return .failure(.quantity(.invalidFormat))
        }
        
        // 基本的な範囲チェック
        if decimal <= 0 {
            return .failure(.quantity(.negativeOrZero))
        }
        
        if decimal > maxValue {
            return .failure(.quantity(.tooLarge))
        }
        
        // 個数系単位の整数チェック
        if unit.category == .count {
            if NSDecimalNumber(decimal: decimal).doubleValue.truncatingRemainder(dividingBy: 1) != 0 {
                return .failure(.quantity(.mustBeInteger))
            }
        }
        
        return .success(decimal)
    }
    
    /// 数量文字列をクリーンアップする
    /// - Parameter input: 入力された数量文字列
    /// - Returns: クリーンアップされた数量文字列
    static func cleanQuantityString(_ input: String) -> String {
        var cleaned = input
        
        // カンマを除去
        cleaned = cleaned.replacingOccurrences(of: ",", with: "")
        
        // 全角数字を半角に変換
        cleaned = normalizeNumberString(cleaned)
        
        // 前後の空白を除去
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    /// 数量をフォーマットして表示用文字列に変換する
    /// - Parameters:
    ///   - quantity: フォーマット対象の数量
    ///   - unit: 単位
    /// - Returns: フォーマットされた数量文字列（例: "500g", "1.5L", "12個"）
    static func formatQuantity(_ quantity: Decimal, unit: Unit) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        // 個数系は整数表示、それ以外は小数点以下を適切に表示
        if unit.category == .count {
            formatter.maximumFractionDigits = 0
        } else {
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 0
        }
        
        let quantityString = formatter.string(from: quantity as NSDecimalNumber) ?? "\(quantity)"
        return "\(quantityString)\(unit.rawValue)"
    }
    
    /// 数量を基本単位に変換する
    /// - Parameters:
    ///   - quantity: 変換対象の数量
    ///   - unit: 現在の単位
    /// - Returns: 基本単位での数量
    static func convertToBaseUnit(_ quantity: Decimal, unit: Unit) -> Decimal {
        return unit.convertToBaseUnit(quantity)
    }
    
    /// 単価を計算する
    /// - Parameters:
    ///   - price: 価格
    ///   - quantity: 数量
    ///   - unit: 単位
    /// - Returns: 基本単位での単価
    static func calculateUnitPrice(price: Decimal, quantity: Decimal, unit: Unit) -> Decimal {
        let baseQuantity = convertToBaseUnit(quantity, unit: unit)
        return baseQuantity > 0 ? price / baseQuantity : 0
    }
    
    /// 数量入力のプレースホルダー例を生成する
    /// - Parameter unit: 対象の単位
    /// - Returns: プレースホルダー文字列
    static func getPlaceholderExample(for unit: Unit) -> String {
        switch unit.category {
        case .weight:
            return "例: 500, 1.2"
        case .volume:
            return "例: 1000, 1.5"
        case .count:
            return "例: 1, 12"
        }
    }
    
    /// 数量の妥当性をリアルタイムでチェック（UI表示用）
    /// - Parameters:
    ///   - input: チェック対象の数量文字列
    ///   - unit: 対象の単位
    /// - Returns: (クリーンアップされた値, エラー, 警告)
    static func checkRealtime(_ input: String, unit: Unit) -> (cleaned: String?, error: ValidationInputError?, warning: String?) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 空の場合は何もしない
        guard !trimmed.isEmpty else {
            return (cleaned: nil, error: nil, warning: nil)
        }
        
        let cleaned = cleanQuantityString(trimmed)
        
        // 数値に変換できない場合
        guard let decimal = Decimal(string: cleaned) else {
            return (cleaned: nil, error: .quantity(.invalidFormat), warning: nil)
        }
        
        // 負数や0の場合
        if decimal <= 0 {
            return (cleaned: cleaned, error: .quantity(.negativeOrZero), warning: nil)
        }
        
        // 最大値を超える場合
        if decimal > maxValue {
            return (cleaned: cleaned, error: .quantity(.tooLarge), warning: nil)
        }
        
        // 個数系の整数チェック
        if unit.category == .count && NSDecimalNumber(decimal: decimal).doubleValue.truncatingRemainder(dividingBy: 1) != 0 {
            return (cleaned: cleaned, error: .quantity(.mustBeInteger), warning: nil)
        }
        
        // 現実的でない値の警告
        var warning: String?
        if isUnrealisticValue(decimal, for: unit) {
            warning = "\(unit.displayName)としては現実的でない値です。"
        }
        
        return (cleaned: cleaned, error: nil, warning: warning)
    }
    
    /// 単位に対して現実的でない値かどうかをチェック
    /// - Parameters:
    ///   - quantity: チェック対象の数量
    ///   - unit: 単位
    /// - Returns: 現実的でない値の場合true
    static func isUnrealisticValue(_ quantity: Decimal, for unit: Unit) -> Bool {
        switch unit {
        // 重量系
        case .gram:
            return quantity > 10000  // 10kg以上は一般的でない
        case .kilogram:
            return quantity > 50     // 50kg以上は一般的でない
            
        // 容量系
        case .milliliter:
            return quantity > 5000   // 5L以上は一般的でない
        case .liter:
            return quantity > 20     // 20L以上は一般的でない
        case .cup, .gou:
            return quantity > 20     // 20カップ/合以上は一般的でない
            
        // 個数系
        case .piece:
            return quantity > 1000   // 1000個以上は一般的でない
        case .pack:
            return quantity > 100    // 100パック以上は一般的でない
        case .bottle:
            return quantity > 100    // 100本以上は一般的でない
        case .bag:
            return quantity > 50     // 50袋以上は一般的でない
        case .sheet:
            return quantity > 1000   // 1000枚以上は一般的でない
        case .slice:
            return quantity > 100    // 100切れ以上は一般的でない
        }
    }
}

// MARK: - Private Helper Methods

private extension QuantityValidator {
    
    /// 全角数字を半角数字に変換する
    /// - Parameter input: 変換対象の文字列
    /// - Returns: 変換された文字列
    static func normalizeNumberString(_ input: String) -> String {
        var normalized = input
        
        // 全角数字と小数点を半角に変換
        let fullWidthChars = "０１２３４５６７８９．"
        let halfWidthChars = "0123456789."
        
        for (fullWidth, halfWidth) in zip(fullWidthChars, halfWidthChars) {
            normalized = normalized.replacingOccurrences(of: String(fullWidth), with: String(halfWidth))
        }
        
        return normalized
    }
}
