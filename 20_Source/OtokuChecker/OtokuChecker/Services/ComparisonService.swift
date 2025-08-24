//
//  ComparisonService.swift
//  OtokuChecker
//
//  Created by Claude on 2025/08/19.
//

import Foundation

class ComparisonService {
    
    private let comparisonEngine: ComparisonEngine
    
    init(comparisonEngine: ComparisonEngine = ComparisonEngine()) {
        self.comparisonEngine = comparisonEngine
    }
    
    // MARK: - Main Comparison Methods
    
    func compare(productA: ComparisonProduct, productB: ComparisonProduct) throws -> ExtendedComparisonResult {
        return try comparisonEngine.compare(productA, productB)
    }
    
    // MARK: - Validation Methods
    
    func validateProductForComparison(_ product: ComparisonProduct) -> [String] {
        return product.validateInput().compactMap { $0.errorDescription }
    }
    
    func canCompareProducts(_ productA: ComparisonProduct, _ productB: ComparisonProduct) -> (canCompare: Bool, reason: String?) {
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
    
    // MARK: - Legacy Support Methods (for backward compatibility)
    
    @available(*, deprecated, message: "Use compare(productA:productB:) instead")
    func compareProducts(_ productA: Product, _ productB: Product) -> ComparisonResult? {
        // Convert Product to ComparisonProduct for backward compatibility
        let comparisonProductA = ComparisonProduct(
            name: productA.name,
            price: productA.price,
            quantity: productA.quantity,
            unit: productA.unit,
            taxIncluded: true, // デフォルトで税込
            taxRate: 0.10, // 10%税率
            origin: "domestic"
        )
        
        let comparisonProductB = ComparisonProduct(
            name: productB.name,
            price: productB.price,
            quantity: productB.quantity,
            unit: productB.unit,
            taxIncluded: true, // デフォルトで税込
            taxRate: 0.10, // 10%税率
            origin: "domestic"
        )
        
        do {
            let extendedResult = try compare(productA: comparisonProductA, productB: comparisonProductB)
            
            // Convert ExtendedComparisonResult to ComparisonResult
            let winner: ComparisonResult.Winner
            switch extendedResult.winner {
            case .productA:
                winner = .productA
            case .productB:
                winner = .productB
            case .tie:
                winner = .tie
            }
            
            return ComparisonResult(
                productA: productA,
                productB: productB,
                winner: winner,
                priceDifference: extendedResult.comparisonDetails.priceDifference,
                percentageDifference: extendedResult.comparisonDetails.percentageDifference
            )
        } catch {
            return nil
        }
    }
    
    @available(*, deprecated, message: "Use validateProductForComparison(_ product: ComparisonProduct) instead")
    func validateProductForComparison(_ product: Product) -> [String] {
        let comparisonProduct = ComparisonProduct(
            name: product.name,
            price: product.price,
            quantity: product.quantity,
            unit: product.unit,
            taxIncluded: true,
            taxRate: 0.10,
            origin: "domestic"
        )
        return validateProductForComparison(comparisonProduct)
    }
    
    @available(*, deprecated, message: "Use canCompareProducts(_ productA: ComparisonProduct, _ productB: ComparisonProduct) instead")
    func canCompareProducts(_ productA: Product, _ productB: Product) -> (canCompare: Bool, reason: String?) {
        let comparisonProductA = ComparisonProduct(
            name: productA.name,
            price: productA.price,
            quantity: productA.quantity,
            unit: productA.unit,
            taxIncluded: true,
            taxRate: 0.10,
            origin: ""
        )
        
        let comparisonProductB = ComparisonProduct(
            name: productB.name,
            price: productB.price,
            quantity: productB.quantity,
            unit: productB.unit,
            taxIncluded: true,
            taxRate: 0.10,
            origin: ""
        )
        
        return canCompareProducts(comparisonProductA, comparisonProductB)
    }
}
