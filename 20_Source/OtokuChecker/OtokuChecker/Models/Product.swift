//
//  Product.swift
//  OtokuChecker
//
//  Created by Claude on 2025/08/19.
//

import Foundation

struct Product: Identifiable, Equatable {
    let id = UUID()
    var name: String = ""
    var price: Decimal = 0
    var quantity: Decimal = 0
    var unit: Unit = .gram
    
    // 計算されたプロパティ
    var unitPrice: Decimal {
        guard quantity > 0 else { return 0 }
        let baseQuantity = unit.convertToBaseUnit(quantity)
        return price / baseQuantity
    }
    
    var isValid: Bool {
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               price > 0 &&
               quantity > 0
    }
    
    var formattedUnitPrice: String {
        guard isValid else { return "---" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        
        let unitPriceNumber = NSDecimalNumber(decimal: unitPrice)
        let formattedPrice = formatter.string(from: unitPriceNumber) ?? "0"
        
        return "\(formattedPrice)円/\(unit.baseUnitForDisplay)"
    }
    
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let priceNumber = NSDecimalNumber(decimal: price)
        return formatter.string(from: priceNumber) ?? "0"
    }
    
    var formattedQuantity: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        let quantityNumber = NSDecimalNumber(decimal: quantity)
        return formatter.string(from: quantityNumber) ?? "0"
    }
}

// 比較結果を表すモデル
struct ComparisonResult {
    let productA: Product
    let productB: Product
    let winner: Winner
    let priceDifference: Decimal
    let percentageDifference: Decimal
    
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
    }
    
    var formattedPriceDifference: String {
        guard winner != .tie else { return "価格差なし" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        
        let diffNumber = NSDecimalNumber(decimal: priceDifference)
        let diffString = formatter.string(from: diffNumber) ?? "0"
        
        let percentNumber = NSDecimalNumber(decimal: percentageDifference)
        let percentString = formatter.string(from: percentNumber) ?? "0"
        
        let baseUnit = productA.unit.category == productB.unit.category ? 
                      productA.unit.baseUnitForDisplay : "単位"
        
        return "→ \(diffString)円/\(baseUnit) の差 (\(percentString)%お得)"
    }
}