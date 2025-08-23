//
//  ProductNameValidator.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/23.
//

import Foundation

/// 商品名のバリデーションを行うstruct
struct ProductNameValidator {
    
    /// 商品名の最大文字数
    static let maxLength = 50
    
    /// 商品名をバリデーションする
    /// - Parameter name: バリデーション対象の商品名
    /// - Returns: バリデーション結果
    static func validate(_ name: String) -> ValidationResult<String> {
        // 前後の空白文字を除去
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 空文字チェック
        if trimmed.isEmpty {
            return .failure(.productName(.empty))
        }
        
        // 長さチェック（日常商品名は50文字以内で十分）
        if trimmed.count > maxLength {
            return .failure(.productName(.tooLong))
        }
        
        return .success(trimmed)
    }
    
    /// 商品名の文字数をチェック（リアルタイム表示用）
    /// - Parameter name: チェック対象の商品名
    /// - Returns: (現在の文字数, 最大文字数, 文字数オーバーフラグ)
    static func checkLength(_ name: String) -> (current: Int, max: Int, isOverLimit: Bool) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentLength = trimmed.count
        let isOverLimit = currentLength > maxLength
        
        return (current: currentLength, max: maxLength, isOverLimit: isOverLimit)
    }
    
    /// 商品名を正規化する（表示・検索用）
    /// - Parameter name: 正規化対象の商品名
    /// - Returns: 正規化された商品名
    static func normalize(_ name: String) -> String {
        var normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 連続する空白を単一の空白に置換
        normalized = normalized.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        
        // 日本語の正規化（ひらがな→カタカナ、全角→半角数字など）
        normalized = normalizeJapaneseText(normalized)
        
        return normalized
    }
    
    /// 商品名の候補を生成する（入力支援用）
    /// - Parameter partialName: 部分的な商品名
    /// - Returns: 候補商品名の配列
    static func generateSuggestions(for partialName: String) -> [String] {
        let trimmed = partialName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 空の場合は一般的な商品名を返す
        guard !trimmed.isEmpty else {
            return commonProductNames
        }
        
        // 部分マッチする商品名を返す
        return commonProductNames.filter { productName in
            productName.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

// MARK: - Private Helper Methods

private extension ProductNameValidator {
    
    /// 日本語テキストを正規化する
    /// - Parameter text: 正規化対象のテキスト
    /// - Returns: 正規化されたテキスト
    static func normalizeJapaneseText(_ text: String) -> String {
        var normalized = text
        
        // 全角数字を半角に変換
        let fullWidthNumbers = "０１２３４５６７８９"
        let halfWidthNumbers = "0123456789"
        
        for (fullWidth, halfWidth) in zip(fullWidthNumbers, halfWidthNumbers) {
            normalized = normalized.replacingOccurrences(of: String(fullWidth), with: String(halfWidth))
        }
        
        // 全角アルファベットを半角に変換
        let fullWidthAlphabets = "ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ"
        let halfWidthAlphabets = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
        
        for (fullWidth, halfWidth) in zip(fullWidthAlphabets, halfWidthAlphabets) {
            normalized = normalized.replacingOccurrences(of: String(fullWidth), with: String(halfWidth))
        }
        
        return normalized
    }
    
    /// よく使われる商品名の配列
    static var commonProductNames: [String] {
        return [
            "牛乳", "卵", "パン", "米", "醤油", "味噌", "砂糖", "塩", "油",
            "りんご", "バナナ", "オレンジ", "キャベツ", "玉ねぎ", "にんじん",
            "豚肉", "鶏肉", "牛肉", "魚", "豆腐", "納豆", "ヨーグルト",
            "ティッシュ", "トイレットペーパー", "洗剤", "シャンプー", "石鹸",
            "水", "お茶", "コーヒー", "ジュース", "ビール", "ワイン"
        ]
    }
}