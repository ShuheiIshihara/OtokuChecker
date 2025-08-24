//
//  ComparisonEngine.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation

/// 高精度な比較エンジン
/// 詳細設計書準拠の比較処理を実行
class ComparisonEngine {
    
    // MARK: - Constants
    
    /// 同価格と判定する価格差の閾値（1円未満）
    private static let priceThreshold: Decimal = 0.01
    
    /// 計算精度（小数点以下の桁数）
    private static let calculationPrecision: Int = 2
    
    /// 高精度計算用のNSDecimalNumberHandler
    private static let precisionHandler = NSDecimalNumberHandler(
        roundingMode: .bankers,
        scale: Int16(calculationPrecision),
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: false
    )
    
    // MARK: - Public Methods
    
    /// メインの比較処理
    /// - Parameters:
    ///   - productA: 比較対象商品A
    ///   - productB: 比較対象商品B
    /// - Returns: 詳細な比較結果
    /// - Throws: 比較処理エラー
    func compare(
        _ productA: ComparisonProduct,
        _ productB: ComparisonProduct
    ) throws -> ExtendedComparisonResult {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var calculationSteps: [CalculationTrace.CalculationStep] = []
        
        // 1. 入力値検証
        try validateInputs(productA, productB)
        calculationSteps.append(createCalculationStep(1, "入力値検証", "商品A, 商品B", "検証完了"))
        
        // 2. 単位互換性確認
        try validateUnitCompatibility(productA.unit, productB.unit)
        calculationSteps.append(createCalculationStep(2, "単位互換性確認", "\(productA.unit.rawValue), \(productB.unit.rawValue)", "互換性あり"))
        
        // 3. 価格正規化（税込計算）
        let finalPriceA = normalizePrice(productA)
        let finalPriceB = normalizePrice(productB)
        calculationSteps.append(createCalculationStep(3, "価格正規化", "税込価格計算", "完了"))
        
        // 4. 基本単位変換
        let baseQuantityA = convertToBaseUnit(productA.quantity, unit: productA.unit)
        let baseQuantityB = convertToBaseUnit(productB.quantity, unit: productB.unit)
        calculationSteps.append(createCalculationStep(4, "単位変換", "基本単位変換", "完了"))
        
        // 5. 単価計算
        let unitPriceA = try calculateUnitPrice(price: finalPriceA, quantity: baseQuantityA, context: "商品A")
        let unitPriceB = try calculateUnitPrice(price: finalPriceB, quantity: baseQuantityB, context: "商品B")
        calculationSteps.append(createCalculationStep(5, "単価計算", "高精度計算", "完了"))
        
        // 6. 表示用単位の決定と単価統一
        let displayUnit = Unit.getLargerUnit(productA.unit, productB.unit)
        let displayUnitPriceA = productA.unit.convertValue(finalPriceA / productA.quantity, to: displayUnit)
        let displayUnitPriceB = productB.unit.convertValue(finalPriceB / productB.quantity, to: displayUnit)
        calculationSteps.append(createCalculationStep(6, "表示用単位統一", "\(displayUnit.rawValue)単位", "完了"))
        
        // 7. 比較判定
        let comparisonResult = performComparison(unitPriceA: displayUnitPriceA, unitPriceB: displayUnitPriceB)
        calculationSteps.append(createCalculationStep(7, "比較判定", "勝者決定", comparisonResult.winner.displayText))
        
        // 8. 詳細情報作成
        let comparisonDetails = createComparisonDetails(
            productA: productA,
            productB: productB,
            unitPriceA: displayUnitPriceA,
            unitPriceB: displayUnitPriceB,
            finalPriceA: finalPriceA,
            finalPriceB: finalPriceB,
            baseQuantityA: baseQuantityA,
            baseQuantityB: baseQuantityB,
            comparisonResult: comparisonResult,
            displayUnit: displayUnit
        )
        
        // 8. 推奨事項生成
        let recommendations = ExtendedComparisonResult.generateRecommendations(
            productA: productA,
            productB: productB,
            details: comparisonDetails
        )
        
        // 9. 計算トレース作成
        let endTime = CFAbsoluteTimeGetCurrent()
        let calculationTrace = CalculationTrace(
            steps: calculationSteps,
            totalDuration: endTime - startTime,
            precision: Self.calculationPrecision
        )
        
        return ExtendedComparisonResult(
            productA: productA,
            productB: productB,
            winner: comparisonResult.winner,
            comparisonDetails: comparisonDetails,
            recommendations: recommendations,
            calculationTrace: calculationTrace
        )
    }
    
    // MARK: - Private Methods - Validation
    
    private func validateInputs(
        _ productA: ComparisonProduct,
        _ productB: ComparisonProduct
    ) throws {
        let errorsA = productA.validateInput()
        let errorsB = productB.validateInput()
        
        if !errorsA.isEmpty && !errorsB.isEmpty {
            throw ComparisonError.bothProductsInvalid
        } else if !errorsA.isEmpty {
            throw ComparisonError.productAInvalid(errorsA)
        } else if !errorsB.isEmpty {
            throw ComparisonError.productBInvalid(errorsB)
        }
    }
    
    private func validateUnitCompatibility(_ unitA: Unit, _ unitB: Unit) throws {
        guard unitA.isConvertibleTo(unitB) else {
            throw ComparisonError.incompatibleUnits(unitA, unitB)
        }
    }
    
    // MARK: - Private Methods - Price Calculation
    
    private func normalizePrice(_ product: ComparisonProduct) -> Decimal {
        if product.taxIncluded {
            return product.price
        } else {
            let taxMultiplier = NSDecimalNumber(decimal: 1 + product.taxRate)
            let price = NSDecimalNumber(decimal: product.price)
            return price.multiplying(by: taxMultiplier, withBehavior: Self.precisionHandler).decimalValue
        }
    }
    
    private func convertToBaseUnit(_ quantity: Decimal, unit: Unit) -> Decimal {
        let quantityNumber = NSDecimalNumber(decimal: quantity)
        let conversionFactor = NSDecimalNumber(decimal: unit.baseUnitConversionFactor)
        return quantityNumber.multiplying(by: conversionFactor, withBehavior: Self.precisionHandler).decimalValue
    }
    
    private func calculateUnitPrice(price: Decimal, quantity: Decimal, context: String) throws -> Decimal {
        guard quantity > 0 else {
            throw CalculationError.divisionByZero("単価計算 - \(context)")
        }
        
        let priceNumber = NSDecimalNumber(decimal: price)
        let quantityNumber = NSDecimalNumber(decimal: quantity)
        
        let result = priceNumber.dividing(by: quantityNumber, withBehavior: Self.precisionHandler)
        
        // 結果の妥当性チェック
        guard result != NSDecimalNumber.notANumber else {
            throw CalculationError.invalidResult("単価計算 - \(context)")
        }
        
        guard !result.decimalValue.isNaN && result.decimalValue.isFinite else {
            throw CalculationError.calculationOverflow("単価計算 - \(context)")
        }
        
        return result.decimalValue
    }
    
    // MARK: - Private Methods - Comparison Logic
    
    private func performComparison(unitPriceA: Decimal, unitPriceB: Decimal) -> (winner: ExtendedComparisonResult.Winner, priceDifference: Decimal, percentageDifference: Decimal) {
        
        let priceDifferenceAbs = abs(unitPriceA - unitPriceB)
        
        // 同価格判定
        if priceDifferenceAbs < Self.priceThreshold {
            return (.tie, 0, 0)
        }
        
        // 勝者判定
        let winner: ExtendedComparisonResult.Winner
        let priceDifference: Decimal
        let percentageDifference: Decimal
        
        if unitPriceA < unitPriceB {
            winner = .productA
            priceDifference = unitPriceB - unitPriceA
            percentageDifference = calculatePercentageDifference(lower: unitPriceA, higher: unitPriceB)
        } else {
            winner = .productB
            priceDifference = unitPriceA - unitPriceB
            percentageDifference = calculatePercentageDifference(lower: unitPriceB, higher: unitPriceA)
        }
        
        return (winner, priceDifference, percentageDifference)
    }
    
    private func calculatePercentageDifference(lower: Decimal, higher: Decimal) -> Decimal {
        guard higher > 0 else { return 0 }
        
        let difference = higher - lower
        let differenceNumber = NSDecimalNumber(decimal: difference)
        let higherNumber = NSDecimalNumber(decimal: higher)
        let hundred = NSDecimalNumber(decimal: 100)
        
        let percentage = differenceNumber
            .dividing(by: higherNumber, withBehavior: Self.precisionHandler)
            .multiplying(by: hundred, withBehavior: Self.precisionHandler)
        
        return percentage.decimalValue
    }
    
    // MARK: - Private Methods - Detail Creation
    
    private func createComparisonDetails(
        productA: ComparisonProduct,
        productB: ComparisonProduct,
        unitPriceA: Decimal,
        unitPriceB: Decimal,
        finalPriceA: Decimal,
        finalPriceB: Decimal,
        baseQuantityA: Decimal,
        baseQuantityB: Decimal,
        comparisonResult: (winner: ExtendedComparisonResult.Winner, priceDifference: Decimal, percentageDifference: Decimal),
        displayUnit: Unit
    ) -> ComparisonDetails {
        
        return ComparisonDetails(
            unitPriceA: unitPriceA,
            unitPriceB: unitPriceB,
            priceDifference: comparisonResult.priceDifference,
            percentageDifference: comparisonResult.percentageDifference,
            finalPriceA: finalPriceA,
            finalPriceB: finalPriceB,
            taxAdjustmentA: finalPriceA - productA.price,
            taxAdjustmentB: finalPriceB - productB.price,
            baseQuantityA: baseQuantityA,
            baseQuantityB: baseQuantityB,
            conversionFactorA: productA.unit.baseUnitConversionFactor,
            conversionFactorB: productB.unit.baseUnitConversionFactor,
            threshold: Self.priceThreshold,
            isTie: comparisonResult.winner == .tie,
            displayUnit: displayUnit
        )
    }
    
    private func createCalculationStep(
        _ stepNumber: Int,
        _ operation: String,
        _ input: String,
        _ output: String
    ) -> CalculationTrace.CalculationStep {
        return CalculationTrace.CalculationStep(
            stepNumber: stepNumber,
            operation: operation,
            input: input,
            output: output,
            duration: 0.001 // 実際の実装では正確な時間を計測
        )
    }
}

// MARK: - Decimal Extensions

extension Decimal {
    var isFinite: Bool {
        return !isNaN && self != Decimal.greatestFiniteMagnitude && self != -Decimal.greatestFiniteMagnitude
    }
}