//
//  ComparisonService.swift
//  OtokuChecker
//
//  Created by Claude on 2025/08/19.
//

import Foundation

class ComparisonService {
    static let shared = ComparisonService()
    
    private init() {}
    
    func compareProducts(_ productA: Product, _ productB: Product) -> ComparisonResult? {
        // 両商品が有効かチェック
        guard productA.isValid && productB.isValid else {
            return nil
        }
        
        // 単位の互換性チェック
        guard productA.unit.isConvertibleTo(productB.unit) else {
            return nil
        }
        
        let unitPriceA = productA.unitPrice
        let unitPriceB = productB.unitPrice
        
        // 勝者の決定
        let winner: ComparisonResult.Winner
        let priceDifference: Decimal
        let percentageDifference: Decimal
        
        if abs(unitPriceA - unitPriceB) < 0.01 {
            // 価格差が1円未満の場合は同じとする
            winner = .tie
            priceDifference = 0
            percentageDifference = 0
        } else if unitPriceA < unitPriceB {
            // 商品Aがお得
            winner = .productA
            priceDifference = unitPriceB - unitPriceA
            percentageDifference = calculatePercentageDifference(lower: unitPriceA, higher: unitPriceB)
        } else {
            // 商品Bがお得
            winner = .productB
            priceDifference = unitPriceA - unitPriceB
            percentageDifference = calculatePercentageDifference(lower: unitPriceB, higher: unitPriceA)
        }
        
        return ComparisonResult(
            productA: productA,
            productB: productB,
            winner: winner,
            priceDifference: priceDifference,
            percentageDifference: percentageDifference
        )
    }
    
    private func calculatePercentageDifference(lower: Decimal, higher: Decimal) -> Decimal {
        guard higher > 0 else { return 0 }
        let difference = higher - lower
        return (difference / higher) * 100
    }
    
    func validateProductForComparison(_ product: Product) -> [String] {
        var errors: [String] = []
        
        if product.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("商品名を入力してください")
        }
        
        if product.price <= 0 {
            errors.append("価格は0より大きい値を入力してください")
        }
        
        if product.quantity <= 0 {
            errors.append("容量は0より大きい値を入力してください")
        }
        
        return errors
    }
    
    func canCompareProducts(_ productA: Product, _ productB: Product) -> (canCompare: Bool, reason: String?) {
        let errorsA = validateProductForComparison(productA)
        let errorsB = validateProductForComparison(productB)
        
        if !errorsA.isEmpty {
            return (false, "商品A: \(errorsA.first!)")
        }
        
        if !errorsB.isEmpty {
            return (false, "商品B: \(errorsB.first!)")
        }
        
        if !productA.unit.isConvertibleTo(productB.unit) {
            return (false, "異なる種類の単位は比較できません（重量と容量など）")
        }
        
        return (true, nil)
    }
}