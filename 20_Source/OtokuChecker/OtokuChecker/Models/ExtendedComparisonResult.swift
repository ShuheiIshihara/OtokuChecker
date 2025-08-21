//
//  ExtendedComparisonResult.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation

/// 詳細な比較結果構造体
/// 詳細設計書準拠の拡張版比較結果
struct ExtendedComparisonResult {
    let productA: ComparisonProduct
    let productB: ComparisonProduct
    let winner: Winner
    let comparisonDetails: ComparisonDetails
    let recommendations: [String]
    let calculationTrace: CalculationTrace?
    
    enum Winner {
        case productA
        case productB
        case tie
        
        var displayText: String {
            switch self {
            case .productA: return "商品A がお得！"
            case .productB: return "商品B がお得！"
            case .tie: return "同じ価格です"
            }
        }
        
        var emoji: String {
            switch self {
            case .productA, .productB: return "🏆"
            case .tie: return "🤝"
            }
        }
        
        var winnerProduct: ComparisonProduct? {
            // この値はExtendedComparisonResult内で設定される
            return nil
        }
    }
    
    /// 勝者の商品を取得
    var winnerProduct: ComparisonProduct? {
        switch winner {
        case .productA: return productA
        case .productB: return productB
        case .tie: return nil
        }
    }
    
    /// 敗者の商品を取得
    var loserProduct: ComparisonProduct? {
        switch winner {
        case .productA: return productB
        case .productB: return productA
        case .tie: return nil
        }
    }
}

/// 詳細な比較情報
struct ComparisonDetails {
    // 基本情報
    let unitPriceA: Decimal
    let unitPriceB: Decimal
    let priceDifference: Decimal
    let percentageDifference: Decimal
    
    // 税込価格情報
    let finalPriceA: Decimal
    let finalPriceB: Decimal
    let taxAdjustmentA: Decimal
    let taxAdjustmentB: Decimal
    
    // 単位変換情報
    let baseQuantityA: Decimal
    let baseQuantityB: Decimal
    let conversionFactorA: Decimal
    let conversionFactorB: Decimal
    
    // 判定情報
    let threshold: Decimal
    let isTie: Bool
    
    /// フォーマットされた価格差表示
    var formattedPriceDifference: String {
        guard !isTie else { return "価格差なし" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        
        let diffNumber = NSDecimalNumber(decimal: priceDifference)
        let diffString = formatter.string(from: diffNumber) ?? "0"
        
        let percentNumber = NSDecimalNumber(decimal: percentageDifference)
        let percentString = formatter.string(from: percentNumber) ?? "0"
        
        return "\(diffString)円の差 (\(percentString)%お得)"
    }
    
    /// 詳細な比較レポート
    var detailedReport: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        
        var report = "【比較詳細】\n"
        
        // 単価情報
        report += "単価A: \(formatter.string(from: NSDecimalNumber(decimal: unitPriceA)) ?? "0")円\n"
        report += "単価B: \(formatter.string(from: NSDecimalNumber(decimal: unitPriceB)) ?? "0")円\n"
        
        // 税込価格情報
        if finalPriceA != unitPriceA * baseQuantityA || finalPriceB != unitPriceB * baseQuantityB {
            report += "\n【税込価格】\n"
            report += "商品A: \(formatter.string(from: NSDecimalNumber(decimal: finalPriceA)) ?? "0")円\n"
            report += "商品B: \(formatter.string(from: NSDecimalNumber(decimal: finalPriceB)) ?? "0")円\n"
        }
        
        // 単位変換情報
        if conversionFactorA != 1 || conversionFactorB != 1 {
            report += "\n【単位変換】\n"
            report += "商品A基本量: \(formatter.string(from: NSDecimalNumber(decimal: baseQuantityA)) ?? "0")\n"
            report += "商品B基本量: \(formatter.string(from: NSDecimalNumber(decimal: baseQuantityB)) ?? "0")\n"
        }
        
        return report
    }
}

/// 計算過程のトレース情報
struct CalculationTrace {
    let steps: [CalculationStep]
    let totalDuration: TimeInterval
    let precision: Int
    
    struct CalculationStep {
        let stepNumber: Int
        let operation: String
        let input: String
        let output: String
        let duration: TimeInterval
    }
    
    /// 計算過程の要約
    var summary: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        
        var summary = "【計算過程】\n"
        summary += "処理ステップ数: \(steps.count)\n"
        summary += "総処理時間: \(formatter.string(from: NSNumber(value: totalDuration * 1000)) ?? "0")ms\n"
        summary += "計算精度: 小数点第\(precision)位\n"
        
        return summary
    }
}

// MARK: - 推奨事項生成

extension ExtendedComparisonResult {
    
    /// 推奨事項を生成
    static func generateRecommendations(
        productA: ComparisonProduct,
        productB: ComparisonProduct,
        details: ComparisonDetails
    ) -> [String] {
        var recommendations: [String] = []
        
        // 基本推奨事項
        if details.isTie {
            recommendations.append("価格は同じです。品質や好みで選んでください。")
        } else {
            let winnerName = details.unitPriceA < details.unitPriceB ? "商品A" : "商品B"
            recommendations.append("\(winnerName)がお得です！")
        }
        
        // 価格差による推奨事項
        if details.percentageDifference > 50 {
            recommendations.append("価格差が大きいです。お得な商品を選ぶことを強くお勧めします。")
        } else if details.percentageDifference > 20 {
            recommendations.append("まずまずの価格差があります。")
        } else if details.percentageDifference > 5 {
            recommendations.append("小さな価格差ですが、積み重ねると節約になります。")
        }
        
        // 税込/税別による推奨事項
        if productA.taxIncluded != productB.taxIncluded {
            recommendations.append("一方は税別価格です。最終的な支払額をご確認ください。")
        }
        
        // 単位変換による推奨事項
        if details.conversionFactorA != 1 || details.conversionFactorB != 1 {
            recommendations.append("異なる単位での比較を行いました。単位の確認をお勧めします。")
        }
        
        // 数量による推奨事項
        let quantityRatio = max(productA.quantity / productB.quantity, productB.quantity / productA.quantity)
        if quantityRatio > 2 {
            recommendations.append("数量に大きな違いがあります。必要な分量を考慮してください。")
        }
        
        return recommendations
    }
}

// MARK: - 互換性用エイリアス

/// 既存のComparisonResultとの互換性を保つためのエイリアス
typealias LegacyComparisonResult = ComparisonResult

/// ExtendedComparisonResultから既存のComparisonResultに変換
extension ExtendedComparisonResult {
    
    /// 既存のComparisonResult形式に変換
    func toLegacyResult() -> ComparisonResult {
        let legacyWinner: ComparisonResult.Winner
        switch winner {
        case .productA: legacyWinner = .productA
        case .productB: legacyWinner = .productB
        case .tie: legacyWinner = .tie
        }
        
        // ComparisonProductをProductに変換（簡易版）
        var legacyProductA = Product()
        legacyProductA.name = productA.name
        legacyProductA.price = productA.price
        legacyProductA.quantity = productA.quantity
        legacyProductA.unit = productA.unit
        
        var legacyProductB = Product()
        legacyProductB.name = productB.name
        legacyProductB.price = productB.price
        legacyProductB.quantity = productB.quantity
        legacyProductB.unit = productB.unit
        
        return ComparisonResult(
            productA: legacyProductA,
            productB: legacyProductB,
            winner: legacyWinner,
            priceDifference: comparisonDetails.priceDifference,
            percentageDifference: comparisonDetails.percentageDifference
        )
    }
}

