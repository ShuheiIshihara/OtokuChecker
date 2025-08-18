import Foundation

// MARK: - 比較エンジンのプロトコル定義

protocol ComparisonEngine {
    func compare(_ productA: ComparisonProduct, _ productB: ComparisonProduct) throws -> ComparisonResult
    func validateProducts(_ productA: ComparisonProduct, _ productB: ComparisonProduct) throws
}

// MARK: - 比較対象商品の構造体

struct ComparisonProduct {
    let name: String
    let price: Decimal
    let quantity: Decimal
    let unit: Unit
    let taxIncluded: Bool
    let taxRate: Decimal
    
    init(name: String, price: Decimal, quantity: Decimal, unit: Unit, taxIncluded: Bool = true, taxRate: Decimal = 0.1) {
        self.name = name
        self.price = price
        self.quantity = quantity
        self.unit = unit
        self.taxIncluded = taxIncluded
        self.taxRate = taxRate
    }
    
    // 税込み価格を計算
    var finalPrice: Decimal {
        return taxIncluded ? price : price * (1 + taxRate)
    }
    
    // 基本単位での数量（g, ml等）
    var baseQuantity: Decimal {
        return unit.convertToBaseUnit(quantity)
    }
    
    // 単価（円/基本単位）
    var unitPrice: Decimal {
        guard baseQuantity > 0 else { return 0 }
        return finalPrice / baseQuantity
    }
}

// MARK: - 比較結果の構造体

struct ComparisonResult {
    let productA: ComparisonProduct
    let productB: ComparisonProduct
    let winner: Winner
    let comparisonDetails: ComparisonDetails
    let recommendations: [String]
    
    enum Winner {
        case productA
        case productB
        case tie
        
        var description: String {
            switch self {
            case .productA: return "商品A"
            case .productB: return "商品B"
            case .tie: return "同じ"
            }
        }
    }
}

struct ComparisonDetails {
    let unitPriceA: Decimal           // 商品Aの単価
    let unitPriceB: Decimal           // 商品Bの単価
    let priceDifference: Decimal      // 価格差（絶対値）
    let percentageDifference: Decimal // パーセンテージ差
    let commonUnit: String            // 比較に使用した単位
    let calculationNotes: [String]    // 計算過程の注記
}

// MARK: - 比較エンジンの実装

class DefaultComparisonEngine: ComparisonEngine {
    
    private let decimalHandler = NSDecimalNumberHandler(
        roundingMode: .bankers,
        scale: 2,
        raiseOnExactness: false,
        raiseOnOverflow: false,
        raiseOnUnderflow: false,
        raiseOnDivideByZero: true
    )
    
    func compare(_ productA: ComparisonProduct, _ productB: ComparisonProduct) throws -> ComparisonResult {
        // 入力値検証
        try validateProducts(productA, productB)
        
        // 単位の互換性チェック
        guard productA.unit.isConvertibleTo(productB.unit) else {
            throw ComparisonError.incompatibleUnits(productA.unit, productB.unit)
        }
        
        // 単価計算
        let unitPriceA = calculateUnitPrice(for: productA)
        let unitPriceB = calculateUnitPrice(for: productB)
        
        // 比較実行
        let winner = determineWinner(unitPriceA: unitPriceA, unitPriceB: unitPriceB)
        
        // 価格差計算
        let priceDifference = abs(unitPriceA - unitPriceB)
        let percentageDifference = calculatePercentageDifference(
            unitPriceA: unitPriceA,
            unitPriceB: unitPriceB
        )
        
        // 計算過程の記録
        let calculationNotes = generateCalculationNotes(
            productA: productA,
            productB: productB,
            unitPriceA: unitPriceA,
            unitPriceB: unitPriceB
        )
        
        // 比較詳細情報の生成
        let details = ComparisonDetails(
            unitPriceA: unitPriceA,
            unitPriceB: unitPriceB,
            priceDifference: priceDifference,
            percentageDifference: percentageDifference,
            commonUnit: getCommonUnit(productA.unit, productB.unit),
            calculationNotes: calculationNotes
        )
        
        // 推奨事項の生成
        let recommendations = generateRecommendations(
            productA: productA,
            productB: productB,
            winner: winner,
            details: details
        )
        
        return ComparisonResult(
            productA: productA,
            productB: productB,
            winner: winner,
            comparisonDetails: details,
            recommendations: recommendations
        )
    }
    
    func validateProducts(_ productA: ComparisonProduct, _ productB: ComparisonProduct) throws {
        // 商品名チェック
        guard !productA.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ComparisonError.emptyProductName("商品A")
        }
        
        guard !productB.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ComparisonError.emptyProductName("商品B")
        }
        
        // 価格チェック
        guard productA.price > 0 else {
            throw ComparisonError.invalidPrice("商品A", productA.price)
        }
        
        guard productB.price > 0 else {
            throw ComparisonError.invalidPrice("商品B", productB.price)
        }
        
        // 数量チェック
        guard productA.quantity > 0 else {
            throw ComparisonError.invalidQuantity("商品A", productA.quantity)
        }
        
        guard productB.quantity > 0 else {
            throw ComparisonError.invalidQuantity("商品B", productB.quantity)
        }
        
        // 税率チェック
        guard productA.taxRate >= 0 && productA.taxRate <= 1 else {
            throw ComparisonError.invalidTaxRate("商品A", productA.taxRate)
        }
        
        guard productB.taxRate >= 0 && productB.taxRate <= 1 else {
            throw ComparisonError.invalidTaxRate("商品B", productB.taxRate)
        }
    }
    
    // MARK: - Private Methods
    
    private func calculateUnitPrice(for product: ComparisonProduct) -> Decimal {
        guard product.baseQuantity > 0 else { return 0 }
        
        let finalPrice = product.finalPrice
        let baseQuantity = product.baseQuantity
        
        // 高精度計算を実行
        let priceNumber = NSDecimalNumber(decimal: finalPrice)
        let quantityNumber = NSDecimalNumber(decimal: baseQuantity)
        
        let unitPriceNumber = priceNumber.dividing(by: quantityNumber, withBehavior: decimalHandler)
        
        return unitPriceNumber.decimalValue
    }
    
    private func determineWinner(unitPriceA: Decimal, unitPriceB: Decimal) -> ComparisonResult.Winner {
        let threshold: Decimal = 0.01 // 1円未満の差は同等とみなす
        
        let difference = abs(unitPriceA - unitPriceB)
        
        if difference < threshold {
            return .tie
        } else if unitPriceA < unitPriceB {
            return .productA
        } else {
            return .productB
        }
    }
    
    private func calculatePercentageDifference(unitPriceA: Decimal, unitPriceB: Decimal) -> Decimal {
        let higherPrice = max(unitPriceA, unitPriceB)
        let lowerPrice = min(unitPriceA, unitPriceB)
        
        guard higherPrice > 0 else { return 0 }
        
        let difference = higherPrice - lowerPrice
        let percentage = (difference / higherPrice) * 100
        
        let percentageNumber = NSDecimalNumber(decimal: percentage)
        return percentageNumber.rounding(accordingToBehavior: decimalHandler).decimalValue
    }
    
    private func generateCalculationNotes(
        productA: ComparisonProduct,
        productB: ComparisonProduct,
        unitPriceA: Decimal,
        unitPriceB: Decimal
    ) -> [String] {
        var notes: [String] = []
        
        // 税込み処理の説明
        if !productA.taxIncluded {
            notes.append("商品A: 税別価格 ¥\(productA.price) → 税込 ¥\(productA.finalPrice)")
        }
        
        if !productB.taxIncluded {
            notes.append("商品B: 税別価格 ¥\(productB.price) → 税込 ¥\(productB.finalPrice)")
        }
        
        // 単位変換の説明
        let commonUnit = getCommonUnit(productA.unit, productB.unit)
        
        if productA.unit != productB.unit {
            notes.append("単位を\(commonUnit)に統一して比較")
        }
        
        // 単価計算の説明
        notes.append("商品A: ¥\(productA.finalPrice) ÷ \(productA.baseQuantity)\(commonUnit) = ¥\(unitPriceA)/\(commonUnit)")
        notes.append("商品B: ¥\(productB.finalPrice) ÷ \(productB.baseQuantity)\(commonUnit) = ¥\(unitPriceB)/\(commonUnit)")
        
        return notes
    }
    
    private func generateRecommendations(
        productA: ComparisonProduct,
        productB: ComparisonProduct,
        winner: ComparisonResult.Winner,
        details: ComparisonDetails
    ) -> [String] {
        var recommendations: [String] = []
        
        switch winner {
        case .productA:
            recommendations.append("商品Aがお得です！")
            
            if details.percentageDifference > 20 {
                recommendations.append("20%以上お得な大変良い買い物です")
            } else if details.percentageDifference > 10 {
                recommendations.append("10%以上お得な良い買い物です")
            }
            
        case .productB:
            recommendations.append("商品Bがお得です！")
            
            if details.percentageDifference > 20 {
                recommendations.append("20%以上お得な大変良い買い物です")
            } else if details.percentageDifference > 10 {
                recommendations.append("10%以上お得な良い買い物です")
            }
            
        case .tie:
            recommendations.append("価格はほぼ同等です")
            recommendations.append("お好みや品質で選択してください")
        }
        
        // 容量による推奨
        let quantityDifference = abs(productA.quantity - productB.quantity) / max(productA.quantity, productB.quantity)
        if quantityDifference > 0.5 {
            recommendations.append("容量が大きく異なります。使用頻度を考慮してください")
        }
        
        // 価格帯による推奨
        let averageUnitPrice = (details.unitPriceA + details.unitPriceB) / 2
        if averageUnitPrice > 1000 {
            recommendations.append("高価格帯商品です。品質重視で選択することをお勧めします")
        }
        
        return recommendations
    }
    
    private func getCommonUnit(_ unitA: Unit, _ unitB: Unit) -> String {
        // 同じカテゴリの基本単位を返す
        switch unitA.category {
        case .weight:
            return "g"
        case .volume:
            return "ml"
        case .count:
            return "個"
        }
    }
}

// MARK: - 高度な比較エンジン（将来拡張用）

class AdvancedComparisonEngine: DefaultComparisonEngine {
    
    private let priceHistoryService: PriceHistoryService
    private let recommendationEngine: RecommendationEngine
    
    init(priceHistoryService: PriceHistoryService, recommendationEngine: RecommendationEngine) {
        self.priceHistoryService = priceHistoryService
        self.recommendationEngine = recommendationEngine
        super.init()
    }
    
    override func compare(_ productA: ComparisonProduct, _ productB: ComparisonProduct) throws -> ComparisonResult {
        // 基本比較を実行
        var result = try super.compare(productA, productB)
        
        // 過去価格データとの比較
        let historicalInsights = try generateHistoricalInsights(productA: productA, productB: productB)
        
        // 高度な推奨事項の追加
        let advancedRecommendations = try recommendationEngine.generateAdvancedRecommendations(
            comparisonResult: result,
            historicalInsights: historicalInsights
        )
        
        // 結果を更新
        let updatedRecommendations = result.recommendations + advancedRecommendations
        
        return ComparisonResult(
            productA: result.productA,
            productB: result.productB,
            winner: result.winner,
            comparisonDetails: result.comparisonDetails,
            recommendations: updatedRecommendations
        )
    }
    
    private func generateHistoricalInsights(productA: ComparisonProduct, productB: ComparisonProduct) throws -> HistoricalInsights {
        let historyA = try priceHistoryService.getPriceHistory(for: productA.name)
        let historyB = try priceHistoryService.getPriceHistory(for: productB.name)
        
        return HistoricalInsights(
            productAHistory: historyA,
            productBHistory: historyB,
            analysisDate: Date()
        )
    }
}

// MARK: - エラー定義

enum ComparisonError: LocalizedError {
    case emptyProductName(String)
    case invalidPrice(String, Decimal)
    case invalidQuantity(String, Decimal)
    case invalidTaxRate(String, Decimal)
    case incompatibleUnits(Unit, Unit)
    case calculationOverflow
    case divisionByZero
    
    var errorDescription: String? {
        switch self {
        case .emptyProductName(let product):
            return "\(product)の商品名を入力してください"
            
        case .invalidPrice(let product, let price):
            return "\(product)の価格が無効です: ¥\(price)"
            
        case .invalidQuantity(let product, let quantity):
            return "\(product)の数量が無効です: \(quantity)"
            
        case .invalidTaxRate(let product, let rate):
            return "\(product)の税率が無効です: \(rate * 100)%"
            
        case .incompatibleUnits(let unitA, let unitB):
            return "異なる種類の単位は比較できません: \(unitA.rawValue) と \(unitB.rawValue)"
            
        case .calculationOverflow:
            return "計算結果が大きすぎます"
            
        case .divisionByZero:
            return "0で割ろうとしました"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptyProductName:
            return "商品名を入力してください"
            
        case .invalidPrice:
            return "0より大きい価格を入力してください"
            
        case .invalidQuantity:
            return "0より大きい数量を入力してください"
            
        case .invalidTaxRate:
            return "0%から100%の間の税率を入力してください"
            
        case .incompatibleUnits:
            return "同じ種類の単位（重量同士、容量同士など）で比較してください"
            
        case .calculationOverflow, .divisionByZero:
            return "より小さな値で再試行してください"
        }
    }
}

// MARK: - サポート用構造体

struct HistoricalInsights {
    let productAHistory: PriceHistory?
    let productBHistory: PriceHistory?
    let analysisDate: Date
}

struct PriceHistory {
    let productName: String
    let averageUnitPrice: Decimal
    let lowestUnitPrice: Decimal
    let highestUnitPrice: Decimal
    let priceEntries: [PriceEntry]
    
    struct PriceEntry {
        let unitPrice: Decimal
        let storeName: String
        let recordDate: Date
    }
    
    var isCurrentPriceCompetitive: Bool {
        guard let latestPrice = priceEntries.last?.unitPrice else { return false }
        return latestPrice <= averageUnitPrice
    }
}

// MARK: - サービス層のプロトコル

protocol PriceHistoryService {
    func getPriceHistory(for productName: String) throws -> PriceHistory?
}

protocol RecommendationEngine {
    func generateAdvancedRecommendations(
        comparisonResult: ComparisonResult,
        historicalInsights: HistoricalInsights
    ) throws -> [String]
}

// MARK: - 比較エンジンのファクトリー

class ComparisonEngineFactory {
    static func createEngine(type: EngineType) -> ComparisonEngine {
        switch type {
        case .basic:
            return DefaultComparisonEngine()
            
        case .advanced(let priceHistoryService, let recommendationEngine):
            return AdvancedComparisonEngine(
                priceHistoryService: priceHistoryService,
                recommendationEngine: recommendationEngine
            )
        }
    }
    
    enum EngineType {
        case basic
        case advanced(PriceHistoryService, RecommendationEngine)
    }
}

// MARK: - 使用例

/*
// 基本的な使用例
let productA = ComparisonProduct(
    name: "コシヒカリ 5kg",
    price: 1400,
    quantity: 5,
    unit: .kilogram
)

let productB = ComparisonProduct(
    name: "コシヒカリ 2kg",
    price: 650,
    quantity: 2,
    unit: .kilogram
)

let engine = ComparisonEngineFactory.createEngine(type: .basic)

do {
    let result = try engine.compare(productA, productB)
    
    print("勝者: \(result.winner.description)")
    print("商品A単価: ¥\(result.comparisonDetails.unitPriceA)/kg")
    print("商品B単価: ¥\(result.comparisonDetails.unitPriceB)/kg")
    print("価格差: \(result.comparisonDetails.percentageDifference)%")
    
    for recommendation in result.recommendations {
        print("💡 \(recommendation)")
    }
    
} catch let error as ComparisonError {
    print("エラー: \(error.localizedDescription)")
    if let suggestion = error.recoverySuggestion {
        print("対処法: \(suggestion)")
    }
}
*/