//
//  ComparisonProduct.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation

/// 比較専用の商品構造体
/// 詳細設計書の仕様に準拠した高精度計算対応版
struct ComparisonProduct {
    let name: String              // 商品名（1-100文字）
    let price: Decimal           // 価格（0.01-999,999.99）
    let quantity: Decimal        // 数量（0.01-99,999.99）
    let unit: Unit               // 単位（enum）
    let taxIncluded: Bool        // 税込/税別フラグ
    let taxRate: Decimal         // 税率（0.00-1.00）
    
    /// 税込価格を計算
    var finalPrice: Decimal {
        return taxIncluded ? price : price * (1 + taxRate)
    }
    
    /// 基本単位での数量
    var baseQuantity: Decimal {
        return unit.convertToBaseUnit(quantity)
    }
    
    /// 単価計算（高精度）
    var unitPrice: Decimal {
        guard baseQuantity > 0 else { return 0 }
        return safeCalculateUnitPrice(price: finalPrice, quantity: baseQuantity) ?? 0
    }
    
    /// 入力値の妥当性検証
    var isValid: Bool {
        return validateInput().isEmpty
    }
    
    /// 入力値検証の詳細結果
    func validateInput() -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // 商品名検証
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errors.append(.emptyProductName("商品"))
        } else if trimmedName.count > 100 {
            errors.append(.productNameTooLong("商品", trimmedName.count))
        }
        
        // 価格検証
        if price <= 0 {
            errors.append(.invalidPrice("商品", price))
        } else if price > 999_999.99 {
            errors.append(.priceOutOfRange("商品", price))
        }
        
        // 数量検証
        if quantity <= 0 {
            errors.append(.invalidQuantity("商品", quantity))
        } else if quantity > 99_999.99 {
            errors.append(.quantityOutOfRange("商品", quantity))
        }
        
        // 税率検証
        if taxRate < 0 || taxRate > 1 {
            errors.append(.invalidTaxRate("商品", taxRate))
        }
        
        return errors
    }
    
    /// 安全な単価計算
    private func safeCalculateUnitPrice(price: Decimal, quantity: Decimal) -> Decimal? {
        guard quantity > 0 else { return nil }
        
        let priceNumber = NSDecimalNumber(decimal: price)
        let quantityNumber = NSDecimalNumber(decimal: quantity)
        
        let handler = NSDecimalNumberHandler(
            roundingMode: .bankers,
            scale: 2,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        
        let result = priceNumber.dividing(by: quantityNumber, withBehavior: handler)
        
        guard result != NSDecimalNumber.notANumber else { return nil }
        
        return result.decimalValue
    }
}

// MARK: - Factory Methods

extension ComparisonProduct {
    /// 既存のProduct構造体から変換
    static func from(_ product: Product, taxIncluded: Bool = true, taxRate: Decimal = 0.1) -> ComparisonProduct {
        return ComparisonProduct(
            name: product.name,
            price: product.price,
            quantity: product.quantity,
            unit: product.unit,
            taxIncluded: taxIncluded,
            taxRate: taxRate
        )
    }
    
    /// テスト用のサンプルデータ
    static func sample(
        name: String = "サンプル商品",
        price: Decimal = 100,
        quantity: Decimal = 1,
        unit: Unit = .gram,
        taxIncluded: Bool = true,
        taxRate: Decimal = 0.1
    ) -> ComparisonProduct {
        return ComparisonProduct(
            name: name,
            price: price,
            quantity: quantity,
            unit: unit,
            taxIncluded: taxIncluded,
            taxRate: taxRate
        )
    }
}

// MARK: - Display Formatting

extension ComparisonProduct {
    /// フォーマットされた価格表示
    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let priceNumber = NSDecimalNumber(decimal: price)
        let taxLabel = taxIncluded ? "(税込)" : "(税別)"
        return (formatter.string(from: priceNumber) ?? "0") + "円" + taxLabel
    }
    
    /// フォーマットされた税込価格表示
    var formattedFinalPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let finalPriceNumber = NSDecimalNumber(decimal: finalPrice)
        return (formatter.string(from: finalPriceNumber) ?? "0") + "円"
    }
    
    /// フォーマットされた単価表示
    var formattedUnitPrice: String {
        guard isValid else { return "---" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        
        let unitPriceNumber = NSDecimalNumber(decimal: unitPrice)
        let formattedPrice = formatter.string(from: unitPriceNumber) ?? "0"
        
        return "\(formattedPrice)円/\(unit.baseUnitForDisplay)"
    }
    
    /// フォーマットされた数量表示
    var formattedQuantity: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        let quantityNumber = NSDecimalNumber(decimal: quantity)
        let quantityString = formatter.string(from: quantityNumber) ?? "0"
        return "\(quantityString)\(unit.rawValue)"
    }
}

// MARK: - Equatable & Identifiable

extension ComparisonProduct: Equatable, Identifiable {
    var id: String {
        return "\(name)-\(price)-\(quantity)-\(unit.rawValue)-\(taxIncluded)-\(taxRate)"
    }
    
    static func == (lhs: ComparisonProduct, rhs: ComparisonProduct) -> Bool {
        return lhs.name == rhs.name &&
               lhs.price == rhs.price &&
               lhs.quantity == rhs.quantity &&
               lhs.unit == rhs.unit &&
               lhs.taxIncluded == rhs.taxIncluded &&
               lhs.taxRate == rhs.taxRate
    }
}