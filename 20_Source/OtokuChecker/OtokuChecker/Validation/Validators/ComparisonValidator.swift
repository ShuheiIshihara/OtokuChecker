//
//  ComparisonValidator.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/23.
//

import Foundation

/// 商品比較のバリデーションを行うstruct
struct ComparisonValidator {
    
    /// 比較用の商品情報
    struct ProductInfo {
        let name: String
        let price: Decimal
        let quantity: Decimal
        let unit: Unit
        
        /// 基本単位での単価を計算
        var unitPrice: Decimal {
            let baseQuantity = unit.convertToBaseUnit(quantity)
            return baseQuantity > 0 ? price / baseQuantity : 0
        }
        
        /// 基本単位での数量
        var baseQuantity: Decimal {
            return unit.convertToBaseUnit(quantity)
        }
    }
    
    /// 比較結果
    struct ComparisonResult {
        let productA: ProductInfo
        let productB: ProductInfo
        let isComparable: Bool
        let betterValue: ComparisonWinner
        let priceDifference: Decimal
        let percentageDifference: Decimal
        
        enum ComparisonWinner {
            case productA
            case productB
            case equal
        }
    }
    
    /// 2つの商品が比較可能かどうかをチェック
    /// - Parameters:
    ///   - unitA: 商品Aの単位
    ///   - unitB: 商品Bの単位
    /// - Returns: 比較可能な場合true
    static func areUnitsCompatible(_ unitA: Unit, _ unitB: Unit) -> Bool {
        // 同じカテゴリ内での比較のみ許可
        return unitA.category == unitB.category
    }
    
    /// 商品比較を実行する
    /// - Parameters:
    ///   - nameA: 商品Aの名前
    ///   - priceA: 商品Aの価格
    ///   - quantityA: 商品Aの数量
    ///   - unitA: 商品Aの単位
    ///   - nameB: 商品Bの名前
    ///   - priceB: 商品Bの価格
    ///   - quantityB: 商品Bの数量
    ///   - unitB: 商品Bの単位
    /// - Returns: バリデーション結果（成功時はComparisonResult）
    static func validateAndCompare(
        nameA: String, priceA: String, quantityA: String, unitA: Unit,
        nameB: String, priceB: String, quantityB: String, unitB: Unit
    ) -> ValidationResult<ComparisonResult> {
        
        // 各項目のバリデーション
        let nameResultA = ProductNameValidator.validate(nameA)
        let priceResultA = PriceValidator.validate(priceA)
        let quantityResultA = QuantityValidator.validate(quantityA, unit: unitA)
        
        let nameResultB = ProductNameValidator.validate(nameB)
        let priceResultB = PriceValidator.validate(priceB)
        let quantityResultB = QuantityValidator.validate(quantityB, unit: unitB)
        
        // バリデーションエラーがある場合は最初のエラーを返す
        if case .failure(let error) = nameResultA { return .failure(error) }
        if case .failure(let error) = priceResultA { return .failure(error) }
        if case .failure(let error) = quantityResultA { return .failure(error) }
        if case .failure(let error) = nameResultB { return .failure(error) }
        if case .failure(let error) = priceResultB { return .failure(error) }
        if case .failure(let error) = quantityResultB { return .failure(error) }
        
        // 単位互換性チェック
        guard areUnitsCompatible(unitA, unitB) else {
            return .failure(.comparison(.incompatibleUnits))
        }
        
        // 成功時の値を取得
        guard let validNameA = nameResultA.value,
              let validPriceA = priceResultA.value,
              let validQuantityA = quantityResultA.value,
              let validNameB = nameResultB.value,
              let validPriceB = priceResultB.value,
              let validQuantityB = quantityResultB.value else {
            return .failure(.comparison(.invalidProducts))
        }
        
        // 商品情報を作成
        let productA = ProductInfo(
            name: validNameA,
            price: validPriceA,
            quantity: validQuantityA,
            unit: unitA
        )
        
        let productB = ProductInfo(
            name: validNameB,
            price: validPriceB,
            quantity: validQuantityB,
            unit: unitB
        )
        
        // 比較を実行
        let comparison = performComparison(productA: productA, productB: productB)
        
        return .success(comparison)
    }
    
    /// 商品比較を実行する（内部メソッド）
    /// - Parameters:
    ///   - productA: 商品A
    ///   - productB: 商品B
    /// - Returns: 比較結果
    static func performComparison(productA: ProductInfo, productB: ProductInfo) -> ComparisonResult {
        let unitPriceA = productA.unitPrice
        let unitPriceB = productB.unitPrice
        
        // 単価の差を計算
        let priceDifference = abs(unitPriceA - unitPriceB)
        
        // パーセンテージ差を計算
        let maxPrice = max(unitPriceA, unitPriceB)
        let percentageDifference = maxPrice > 0 ? (priceDifference / maxPrice) * 100 : 0
        
        // どちらがお得かを判定
        let winner: ComparisonResult.ComparisonWinner
        if unitPriceA < unitPriceB {
            winner = .productA
        } else if unitPriceA > unitPriceB {
            winner = .productB
        } else {
            winner = .equal
        }
        
        return ComparisonResult(
            productA: productA,
            productB: productB,
            isComparable: true,
            betterValue: winner,
            priceDifference: priceDifference,
            percentageDifference: percentageDifference
        )
    }
    
    /// 比較結果を文字列で説明する
    /// - Parameter result: 比較結果
    /// - Returns: 比較結果の説明文
    static func formatComparisonResult(_ result: ComparisonResult) -> String {
        let productAUnitPrice = result.productA.unitPrice
        let productBUnitPrice = result.productB.unitPrice
        let baseUnit = result.productA.unit.baseUnitForDisplay
        
        let formattedPriceA = PriceValidator.formatPrice(productAUnitPrice)
        let formattedPriceB = PriceValidator.formatPrice(productBUnitPrice)
        
        switch result.betterValue {
        case .productA:
            let savings = result.percentageDifference.rounded(to: 1)
            return "\(result.productA.name)の方がお得です\n単価: \(formattedPriceA)/\(baseUnit) vs \(formattedPriceB)/\(baseUnit)\n約\(savings)%安いです"
            
        case .productB:
            let savings = result.percentageDifference.rounded(to: 1)
            return "\(result.productB.name)の方がお得です\n単価: \(formattedPriceA)/\(baseUnit) vs \(formattedPriceB)/\(baseUnit)\n約\(savings)%安いです"
            
        case .equal:
            return "両方とも同じ単価です\n単価: \(formattedPriceA)/\(baseUnit)"
        }
    }
    
    /// 単位互換性エラーの詳細メッセージを生成
    /// - Parameters:
    ///   - unitA: 商品Aの単位
    ///   - unitB: 商品Bの単位
    /// - Returns: エラーメッセージ
    static func getIncompatibilityMessage(unitA: Unit, unitB: Unit) -> String {
        return "\(unitA.category.displayName)(\(unitA.displayName))と\(unitB.category.displayName)(\(unitB.displayName))は比較できません。\n同じ種類の単位を選択してください。"
    }
    
    /// 商品名の類似度をチェック（重複商品の警告用）
    /// - Parameters:
    ///   - nameA: 商品Aの名前
    ///   - nameB: 商品Bの名前
    /// - Returns: 類似している場合のメッセージ
    static func checkSimilarProducts(_ nameA: String, _ nameB: String) -> String? {
        let normalizedA = ProductNameValidator.normalize(nameA).lowercased()
        let normalizedB = ProductNameValidator.normalize(nameB).lowercased()
        
        // 完全一致の場合
        if normalizedA == normalizedB {
            return "同じ商品を比較している可能性があります"
        }
        
        // 部分一致の場合（一方が他方を含む）
        if normalizedA.contains(normalizedB) || normalizedB.contains(normalizedA) {
            return "似た商品名です。同じ商品でないか確認してください"
        }
        
        return nil
    }
}

// MARK: - Extensions

extension ComparisonValidator.ProductInfo: Equatable {
    static func == (lhs: ComparisonValidator.ProductInfo, rhs: ComparisonValidator.ProductInfo) -> Bool {
        return lhs.name == rhs.name &&
               lhs.price == rhs.price &&
               lhs.quantity == rhs.quantity &&
               lhs.unit == rhs.unit
    }
}

extension ComparisonValidator.ComparisonResult: Equatable {
    static func == (lhs: ComparisonValidator.ComparisonResult, rhs: ComparisonValidator.ComparisonResult) -> Bool {
        return lhs.productA == rhs.productA &&
               lhs.productB == rhs.productB &&
               lhs.betterValue == rhs.betterValue
    }
}

extension ComparisonValidator.ComparisonResult.ComparisonWinner: Equatable {
    // Equatable は自動生成される
}