//
//  ComparisonEngineTests.swift
//  OtokuCheckerTests
//
//  Created by Claude Code on 2025/08/21.
//

import XCTest
@testable import OtokuChecker

final class ComparisonEngineTests: XCTestCase {
    
    var comparisonEngine: ComparisonEngine!
    
    override func setUpWithError() throws {
        comparisonEngine = ComparisonEngine()
    }
    
    override func tearDownWithError() throws {
        comparisonEngine = nil
    }
    
    // MARK: - 正常系テスト
    
    func testBasicComparison() throws {
        // 基本的な比較機能テスト
        let productA = ComparisonProduct.sample(
            name: "商品A",
            price: 100,
            quantity: 1,
            unit: .gram,
            taxIncluded: true
        )
        let productB = ComparisonProduct.sample(
            name: "商品B",
            price: 150,
            quantity: 1,
            unit: .gram,
            taxIncluded: true
        )
        
        let result = try comparisonEngine.compare(productA, productB)
        
        XCTAssertEqual(result.winner, .productA, "商品Aがお得であるべき")
        XCTAssertEqual(result.comparisonDetails.unitPriceA, 100, "商品Aの単価は100円/g")
        XCTAssertEqual(result.comparisonDetails.unitPriceB, 150, "商品Bの単価は150円/g")
        XCTAssertEqual(result.comparisonDetails.priceDifference, 50, "価格差は50円")
        XCTAssertFalse(result.recommendations.isEmpty, "推奨事項が生成されるべき")
    }
    
    func testTieComparison() throws {
        // 同価格比較テスト
        let productA = ComparisonProduct.sample(
            name: "商品A",
            price: 100,
            quantity: 1,
            unit: .gram
        )
        let productB = ComparisonProduct.sample(
            name: "商品B",
            price: 100,
            quantity: 1,
            unit: .gram
        )
        
        let result = try comparisonEngine.compare(productA, productB)
        
        XCTAssertEqual(result.winner, .tie, "同価格判定されるべき")
        XCTAssertEqual(result.comparisonDetails.priceDifference, 0, "価格差は0")
        XCTAssertEqual(result.comparisonDetails.percentageDifference, 0, "パーセンテージ差は0")
        XCTAssertTrue(result.comparisonDetails.isTie, "同価格フラグが立つべき")
    }
    
    func testUnitConversion() throws {
        // 単位変換テスト
        let productA = ComparisonProduct.sample(
            name: "商品A(g)",
            price: 1000,
            quantity: 500,
            unit: .gram
        )
        let productB = ComparisonProduct.sample(
            name: "商品B(kg)",
            price: 2000,
            quantity: 1,
            unit: .kilogram
        )
        
        let result = try comparisonEngine.compare(productA, productB)
        
        // 単価計算: A=1000/500=2円/g, B=2000/1000=2円/g
        XCTAssertEqual(result.winner, .tie, "単位変換後は同価格")
        XCTAssertEqual(result.comparisonDetails.unitPriceA, 2, accuracy: 0.01, "商品Aの単価は2円/g")
        XCTAssertEqual(result.comparisonDetails.unitPriceB, 2, accuracy: 0.01, "商品Bの単価は2円/g")
    }
    
    func testTaxCalculation() throws {
        // 税込/税別計算テスト
        let productA = ComparisonProduct.sample(
            name: "商品A(税別)",
            price: 100,
            quantity: 1,
            unit: .gram,
            taxIncluded: false,
            taxRate: 0.1
        )
        let productB = ComparisonProduct.sample(
            name: "商品B(税込)",
            price: 110,
            quantity: 1,
            unit: .gram,
            taxIncluded: true,
            taxRate: 0.1
        )
        
        let result = try comparisonEngine.compare(productA, productB)
        
        // 税込価格: A=100*1.1=110円, B=110円
        XCTAssertEqual(result.winner, .tie, "税込計算後は同価格")
        XCTAssertEqual(result.comparisonDetails.finalPriceA, 110, "商品Aの税込価格は110円")
        XCTAssertEqual(result.comparisonDetails.finalPriceB, 110, "商品Bの税込価格は110円")
        XCTAssertEqual(result.comparisonDetails.taxAdjustmentA, 10, "商品Aの税額は10円")
        XCTAssertEqual(result.comparisonDetails.taxAdjustmentB, 0, "商品Bの税額調整は0円")
    }
    
    // MARK: - 異常系テスト
    
    func testInvalidProductName() {
        // 商品名エラーテスト
        let invalidProduct = ComparisonProduct.sample(name: "", price: 100)
        let validProduct = ComparisonProduct.sample(name: "有効商品", price: 100)
        
        XCTAssertThrowsError(try comparisonEngine.compare(invalidProduct, validProduct)) { error in
            XCTAssertTrue(error is ComparisonError, "ComparisonErrorが投げられるべき")
            if case .productAInvalid(let validationErrors) = error as? ComparisonError {
                XCTAssertTrue(validationErrors.contains { error in
                    if case .emptyProductName = error { return true }
                    return false
                }, "空の商品名エラーが含まれるべき")
            }
        }
    }
    
    func testInvalidPrice() {
        // 価格エラーテスト
        let invalidProduct = ComparisonProduct.sample(price: -100)
        let validProduct = ComparisonProduct.sample(price: 100)
        
        XCTAssertThrowsError(try comparisonEngine.compare(invalidProduct, validProduct)) { error in
            XCTAssertTrue(error is ComparisonError, "ComparisonErrorが投げられるべき")
        }
    }
    
    func testIncompatibleUnits() {
        // 単位互換性エラーテスト
        let productA = ComparisonProduct.sample(unit: .gram)     // 重量
        let productB = ComparisonProduct.sample(unit: .milliliter) // 容量
        
        XCTAssertThrowsError(try comparisonEngine.compare(productA, productB)) { error in
            if case .incompatibleUnits(let unitA, let unitB) = error as? ComparisonError {
                XCTAssertEqual(unitA, .gram, "単位Aはgramであるべき")
                XCTAssertEqual(unitB, .milliliter, "単位Bはmilliliterであるべき")
            } else {
                XCTFail("incompatibleUnitsエラーが投げられるべき")
            }
        }
    }
    
    func testZeroQuantity() {
        // ゼロ数量エラーテスト
        let invalidProduct = ComparisonProduct.sample(quantity: 0)
        let validProduct = ComparisonProduct.sample(quantity: 1)
        
        XCTAssertThrowsError(try comparisonEngine.compare(invalidProduct, validProduct)) { error in
            XCTAssertTrue(error is ComparisonError, "ComparisonErrorが投げられるべき")
        }
    }
    
    // MARK: - 境界値テスト
    
    func testMinimumValues() throws {
        // 最小値テスト
        let productA = ComparisonProduct.sample(
            name: "最小商品A",
            price: 0.01,
            quantity: 0.01,
            unit: .gram
        )
        let productB = ComparisonProduct.sample(
            name: "最小商品B",
            price: 0.02,
            quantity: 0.01,
            unit: .gram
        )
        
        let result = try comparisonEngine.compare(productA, productB)
        
        XCTAssertEqual(result.winner, .productA, "商品Aがお得であるべき")
        XCTAssertEqual(result.comparisonDetails.unitPriceA, 1, "単価A=0.01/0.01=1円/g")
        XCTAssertEqual(result.comparisonDetails.unitPriceB, 2, "単価B=0.02/0.01=2円/g")
    }
    
    func testMaximumValues() throws {
        // 最大値テスト
        let productA = ComparisonProduct.sample(
            name: "最大商品A",
            price: 999999.99,
            quantity: 99999.99,
            unit: .gram
        )
        let productB = ComparisonProduct.sample(
            name: "最大商品B",
            price: 999999.98,
            quantity: 99999.99,
            unit: .gram
        )
        
        let result = try comparisonEngine.compare(productA, productB)
        
        XCTAssertEqual(result.winner, .productB, "商品Bがお得であるべき")
    }
    
    func testThresholdBoundary() throws {
        // 閾値境界テスト（1円未満の差）
        let productA = ComparisonProduct.sample(price: 100.00, quantity: 1)
        let productB = ComparisonProduct.sample(price: 100.005, quantity: 1) // 0.5円差
        
        let result = try comparisonEngine.compare(productA, productB)
        
        XCTAssertEqual(result.winner, .tie, "1円未満の差は同価格判定されるべき")
    }
    
    // MARK: - パフォーマンステスト
    
    func testPerformance() throws {
        // パフォーマンステスト
        let productA = ComparisonProduct.sample(price: 100, quantity: 1)
        let productB = ComparisonProduct.sample(price: 150, quantity: 1)
        
        measure {
            for _ in 0..<1000 {
                _ = try? comparisonEngine.compare(productA, productB)
            }
        }
    }
    
    // MARK: - 精度テスト
    
    func testCalculationPrecision() throws {
        // 計算精度テスト
        let productA = ComparisonProduct.sample(
            name: "精度テストA",
            price: 100.00,
            quantity: 3,
            unit: .gram
        )
        let productB = ComparisonProduct.sample(
            name: "精度テストB",
            price: 150.00,
            quantity: 4.5,
            unit: .gram
        )
        
        let result = try comparisonEngine.compare(productA, productB)
        
        // 33.33... vs 33.33... の精度確認
        XCTAssertEqual(result.comparisonDetails.unitPriceA, 33.33, accuracy: 0.01, "商品Aの単価精度")
        XCTAssertEqual(result.comparisonDetails.unitPriceB, 33.33, accuracy: 0.01, "商品Bの単価精度")
        XCTAssertEqual(result.winner, .tie, "精度を考慮した同価格判定")
    }
    
    // MARK: - 追加単位テスト
    
    func testJapaneseVolumeUnits() throws {
        // 日本の容量単位テスト（合）
        let productA = ComparisonProduct.sample(
            name: "米（合）",
            price: 180,
            quantity: 1,
            unit: .gou
        )
        let productB = ComparisonProduct.sample(
            name: "米（カップ）",
            price: 180,
            quantity: 1,
            unit: .cup
        )
        
        let result = try comparisonEngine.compare(productA, productB)
        
        // 1合=180ml, 1カップ=180ml, 単価: A=180/180=1円/ml, B=180/180=1円/ml
        XCTAssertEqual(result.winner, .tie, "合・カップ変換後は同価格")
        XCTAssertEqual(result.comparisonDetails.unitPriceA, 1, accuracy: 0.01, "商品Aの単価")
        XCTAssertEqual(result.comparisonDetails.unitPriceB, 1, accuracy: 0.01, "商品Bの単価")
    }
    
    func testVolumeUnits() throws {
        // 容量単位テスト
        let productA = ComparisonProduct.sample(
            name: "カップ商品",
            price: 180,
            quantity: 1,
            unit: .cup
        )
        let productB = ComparisonProduct.sample(
            name: "ミリリットル商品",
            price: 360,
            quantity: 180,
            unit: .milliliter
        )
        
        let result = try comparisonEngine.compare(productA, productB)
        
        // 1カップ=180ml, 単価: A=180/180=1円/ml, B=360/180=2円/ml
        XCTAssertEqual(result.winner, .productA, "商品Aがお得")
        XCTAssertEqual(result.comparisonDetails.unitPriceA, 1, accuracy: 0.01, "商品Aの単価")
        XCTAssertEqual(result.comparisonDetails.unitPriceB, 2, accuracy: 0.01, "商品Bの単価")
    }
    
    func testCountUnits() throws {
        // 個数系単位テスト（新規単位）
        let productA = ComparisonProduct.sample(
            name: "食パン（枚）",
            price: 100,
            quantity: 5,
            unit: .sheet
        )
        let productB = ComparisonProduct.sample(
            name: "食パン（個）",
            price: 100,
            quantity: 5,
            unit: .piece
        )
        
        let result = try comparisonEngine.compare(productA, productB)
        
        // 枚も個も基本単位は同じ: A=100/5=20円/個, B=100/5=20円/個
        XCTAssertEqual(result.winner, .tie, "枚・個変換後は同価格")
        XCTAssertEqual(result.comparisonDetails.unitPriceA, 20, accuracy: 0.01, "商品Aの単価")
        XCTAssertEqual(result.comparisonDetails.unitPriceB, 20, accuracy: 0.01, "商品Bの単価")
    }
    
    func testSliceUnits() throws {
        // 切れ単位テスト
        let productA = ComparisonProduct.sample(
            name: "お刺身（切れ）",
            price: 500,
            quantity: 10,
            unit: .slice
        )
        let productB = ComparisonProduct.sample(
            name: "お刺身（個）",
            price: 250,
            quantity: 5,
            unit: .piece
        )
        
        let result = try comparisonEngine.compare(productA, productB)
        
        // 単価: A=500/10=50円/個, B=250/5=50円/個
        XCTAssertEqual(result.winner, .tie, "切れ・個変換後は同価格")
        XCTAssertEqual(result.comparisonDetails.unitPriceA, 50, accuracy: 0.01, "商品Aの単価")
        XCTAssertEqual(result.comparisonDetails.unitPriceB, 50, accuracy: 0.01, "商品Bの単価")
    }
}

// MARK: - モックとテストヘルパー

extension ComparisonProduct {
    /// テスト用のビルダーメソッド
    static func testBuilder() -> ComparisonProductBuilder {
        return ComparisonProductBuilder()
    }
}

/// ComparisonProductのテスト用ビルダー
class ComparisonProductBuilder {
    private var name: String = "テスト商品"
    private var price: Decimal = 100
    private var quantity: Decimal = 1
    private var unit: Unit = .gram
    private var taxIncluded: Bool = true
    private var taxRate: Decimal = 0.1
    
    func name(_ value: String) -> ComparisonProductBuilder {
        name = value
        return self
    }
    
    func price(_ value: Decimal) -> ComparisonProductBuilder {
        price = value
        return self
    }
    
    func quantity(_ value: Decimal) -> ComparisonProductBuilder {
        quantity = value
        return self
    }
    
    func unit(_ value: Unit) -> ComparisonProductBuilder {
        unit = value
        return self
    }
    
    func taxIncluded(_ value: Bool) -> ComparisonProductBuilder {
        taxIncluded = value
        return self
    }
    
    func taxRate(_ value: Decimal) -> ComparisonProductBuilder {
        taxRate = value
        return self
    }
    
    func build() -> ComparisonProduct {
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