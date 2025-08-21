# 比較エンジン仕様書

## 1. 概要

### 1.1 目的
お買い物比較アプリにおいて、2つの商品の価格を正確かつ高速に比較し、ユーザーに最適な購入判断を提供する。

### 1.2 設計原則
- **精度保証**: Decimal型による高精度計算
- **単位統一**: 異なる単位での商品を適切に比較
- **エラー耐性**: 不正な入力に対する堅牢な処理
- **拡張性**: 将来の機能追加に対応できる設計
- **パフォーマンス**: 1秒以内での比較結果提供

## 2. 機能仕様

### 2.1 基本比較機能

#### 入力仕様
```swift
struct ComparisonProduct {
    let name: String              // 商品名（1-100文字）
    let price: Decimal           // 価格（0.01-999,999.99）
    let quantity: Decimal        // 数量（0.01-99,999.99）
    let unit: Unit               // 単位（enum）
    let taxIncluded: Bool        // 税込/税別フラグ
    let taxRate: Decimal         // 税率（0.00-1.00）
}
```

#### 出力仕様
```swift
struct ComparisonResult {
    let productA: ComparisonProduct       // 商品A情報
    let productB: ComparisonProduct       // 商品B情報
    let winner: Winner                    // 勝者判定
    let comparisonDetails: ComparisonDetails  // 詳細比較情報
    let recommendations: [String]         // 推奨事項
}
```

### 2.2 比較アルゴリズム

#### 2.2.1 基本計算フロー
```
1. 入力値検証
   ├── 商品名の妥当性確認
   ├── 価格の範囲確認
   ├── 数量の妥当性確認
   └── 単位の互換性確認

2. 価格正規化
   ├── 税込価格計算
   ├── 単位統一処理
   └── 基本単位への変換

3. 単価計算
   ├── 高精度除算実行
   ├── 四捨五入処理
   └── 精度保証確認

4. 比較判定
   ├── 価格差計算
   ├── パーセンテージ計算
   ├── 勝者決定
   └── 同価格判定

5. 結果生成
   ├── 比較詳細情報作成
   ├── 推奨事項生成
   ├── 計算過程記録
   └── 結果構造体作成
```

#### 2.2.2 税込価格計算
```swift
// 税込価格の計算式
finalPrice = taxIncluded ? price : price * (1 + taxRate)

// 計算例
税別価格: ¥1,000, 税率: 10% → 税込価格: ¥1,100
税込価格: ¥1,100, 税率: 10% → 税込価格: ¥1,100
```

#### 2.2.3 単価計算
```swift
// 単価計算の基本式
unitPrice = finalPrice / baseQuantity

// baseQuantityは基本単位での数量
例：2kg → 2000g (基本単位: g)
例：500ml → 500ml (基本単位: ml)
```

#### 2.2.4 勝者判定アルゴリズム
```swift
let threshold: Decimal = 0.01  // 1円未満は同価格とみなす
let difference = abs(unitPriceA - unitPriceB)

if difference < threshold {
    winner = .tie
} else if unitPriceA < unitPriceB {
    winner = .productA
} else {
    winner = .productB
}
```

## 3. 単位変換システム

### 3.1 サポート単位

#### 重量系
```swift
enum WeightUnit: String, CaseIterable {
    case gram = "g"           // 基本単位
    case kilogram = "kg"      // 1kg = 1,000g
    case pound = "lb"         // 1lb ≈ 453.592g
    case ounce = "oz"         // 1oz ≈ 28.3495g
}
```

#### 容量系
```swift
enum VolumeUnit: String, CaseIterable {
    case milliliter = "ml"    // 基本単位
    case liter = "L"          // 1L = 1,000ml
    case cup = "cup"          // 1cup = 200ml (日本標準)
    case tablespoon = "tbsp"  // 1tbsp = 15ml
    case teaspoon = "tsp"     // 1tsp = 5ml
}
```

#### 個数系
```swift
enum CountUnit: String, CaseIterable {
    case piece = "個"         // 基本単位
    case pack = "パック"      // 1パック = 1個
    case bottle = "本"        // 1本 = 1個
    case bag = "袋"           // 1袋 = 1個
    case dozen = "ダース"     // 1ダース = 12個
}
```

### 3.2 変換係数テーブル
```swift
private static let conversionFactors: [Unit: Decimal] = [
    // 重量系（グラム基準）
    .gram: 1,
    .kilogram: 1000,
    .pound: 453.592,
    .ounce: 28.3495,
    
    // 容量系（ミリリットル基準）
    .milliliter: 1,
    .liter: 1000,
    .cup: 200,
    .tablespoon: 15,
    .teaspoon: 5,
    
    // 個数系（個基準）
    .piece: 1,
    .pack: 1,
    .bottle: 1,
    .bag: 1,
    .dozen: 12
]
```

### 3.3 単位互換性チェック
```swift
func isConvertibleTo(_ other: Unit) -> Bool {
    return self.category == other.category
}

// 使用例
Unit.gram.isConvertibleTo(.kilogram)     // true
Unit.gram.isConvertibleTo(.milliliter)   // false
```

## 4. エラーハンドリング仕様

### 4.1 入力検証エラー

#### 4.1.1 商品名エラー
```swift
enum ValidationError: LocalizedError {
    case emptyProductName(String)
    case productNameTooLong(String, Int)  // 最大100文字
}

// 検証ロジック
guard !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
    throw ValidationError.emptyProductName("商品A")
}

guard productName.count <= 100 else {
    throw ValidationError.productNameTooLong("商品A", productName.count)
}
```

#### 4.1.2 価格エラー
```swift
enum ValidationError: LocalizedError {
    case invalidPrice(String, Decimal)
    case priceOutOfRange(String, Decimal)
}

// 検証ロジック
guard price > 0 else {
    throw ValidationError.invalidPrice("商品A", price)
}

guard price <= 999_999.99 else {
    throw ValidationError.priceOutOfRange("商品A", price)
}
```

#### 4.1.3 数量エラー
```swift
enum ValidationError: LocalizedError {
    case invalidQuantity(String, Decimal)
    case quantityOutOfRange(String, Decimal)
}

// 検証ロジック
guard quantity > 0 else {
    throw ValidationError.invalidQuantity("商品A", quantity)
}

guard quantity <= 99_999.99 else {
    throw ValidationError.quantityOutOfRange("商品A", quantity)
}
```

#### 4.1.4 単位互換性エラー
```swift
enum ComparisonError: LocalizedError {
    case incompatibleUnits(Unit, Unit)
}

// 検証ロジック
guard productA.unit.isConvertibleTo(productB.unit) else {
    throw ComparisonError.incompatibleUnits(productA.unit, productB.unit)
}
```

### 4.2 計算エラー

#### 4.2.1 オーバーフローエラー
```swift
enum CalculationError: LocalizedError {
    case calculationOverflow(String)
    case divisionByZero(String)
    case precisionLoss(String)
}
```

#### 4.2.2 エラー回復戦略
```swift
// 計算エラー時の安全な処理
func safeCalculateUnitPrice(price: Decimal, quantity: Decimal) -> Decimal? {
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
```

## 5. パフォーマンス仕様

### 5.1 性能要件
```
レスポンス時間:
├── 基本比較: 10ms以内
├── 複雑な単位変換: 50ms以内
├── 大量データ処理: 1秒以内
└── エラー処理: 5ms以内

メモリ使用量:
├── 単発比較: 1MB以内
├── 連続比較: 5MB以内
└── キャッシュ含む: 10MB以内
```

### 5.2 最適化手法

#### 5.2.1 計算最適化
```swift
// 事前計算による最適化
private static let precomputedConversions: [String: Decimal] = [
    "kg_to_g": 1000,
    "L_to_ml": 1000,
    "dozen_to_piece": 12
]

// キャッシュによる最適化
private var calculationCache: [String: Decimal] = [:]
```

#### 5.2.2 メモリ最適化
```swift
// 軽量な比較専用構造体
struct LightweightComparisonProduct {
    let finalPrice: Decimal
    let baseQuantity: Decimal
    let unitType: UnitCategory
}
```

## 6. 拡張仕様

### 6.1 将来対応予定機能

#### 6.1.1 割引計算対応
```swift
struct DiscountInfo {
    let discountType: DiscountType  // 定額/定率
    let discountValue: Decimal      // 割引額/割引率
    let conditions: [DiscountCondition]  // 適用条件
}

enum DiscountType {
    case fixed(Decimal)        // 定額割引
    case percentage(Decimal)   // 定率割引
    case buyXGetY(Int, Int)    // X個買ってY個無料
}
```

#### 6.1.2 複数商品比較
```swift
func compareMultipleProducts(_ products: [ComparisonProduct]) -> MultipleComparisonResult {
    // 3個以上の商品の一括比較
}
```

#### 6.1.3 履歴統合比較
```swift
func compareWithHistory(
    currentProduct: ComparisonProduct,
    historicalData: [ProductRecord]
) -> HistoricalComparisonResult {
    // 過去の価格データとの比較
}
```

### 6.2 国際化対応

#### 6.2.1 通貨対応
```swift
struct CurrencyInfo {
    let code: String      // "JPY", "USD", etc.
    let symbol: String    // "¥", "$", etc.
    let rate: Decimal     // 為替レート
}
```

#### 6.2.2 地域別単位対応
```swift
enum LocaleUnits {
    case japan    // ml, g, 個
    case us       // fl oz, oz, piece
    case europe   // ml, g, piece
}
```

## 7. テスト仕様

### 7.1 単体テストケース

#### 7.1.1 正常系テスト
```swift
func testBasicComparison() {
    // 基本的な比較機能テスト
    let productA = ComparisonProduct(name: "商品A", price: 100, quantity: 1, unit: .gram)
    let productB = ComparisonProduct(name: "商品B", price: 150, quantity: 1, unit: .gram)
    
    let result = try comparisonEngine.compare(productA, productB)
    
    XCTAssertEqual(result.winner, .productA)
    XCTAssertEqual(result.comparisonDetails.unitPriceA, 100)
    XCTAssertEqual(result.comparisonDetails.unitPriceB, 150)
}
```

#### 7.1.2 異常系テスト
```swift
func testInvalidInputs() {
    let invalidProduct = ComparisonProduct(name: "", price: -100, quantity: 0, unit: .gram)
    
    XCTAssertThrowsError(try comparisonEngine.compare(invalidProduct, validProduct)) { error in
        XCTAssertTrue(error is ValidationError)
    }
}
```

#### 7.1.3 境界値テスト
```swift
func testBoundaryValues() {
    // 最小値テスト
    let minProduct = ComparisonProduct(name: "最小", price: 0.01, quantity: 0.01, unit: .gram)
    
    // 最大値テスト  
    let maxProduct = ComparisonProduct(name: "最大", price: 999999.99, quantity: 99999.99, unit: .gram)
    
    // 同価格テスト
    let samePrice1 = ComparisonProduct(name: "同価格1", price: 100, quantity: 1, unit: .gram)
    let samePrice2 = ComparisonProduct(name: "同価格2", price: 100, quantity: 1, unit: .gram)
}
```

### 7.2 パフォーマンステスト
```swift
func testPerformance() {
    measure {
        for _ in 0..<1000 {
            _ = try? comparisonEngine.compare(productA, productB)
        }
    }
    // 期待値: 10ms以内
}
```

### 7.3 精度テスト
```swift
func testCalculationPrecision() {
    let product1 = ComparisonProduct(name: "精度テスト1", price: 100.00, quantity: 3, unit: .gram)
    let product2 = ComparisonProduct(name: "精度テスト2", price: 150.00, quantity: 4.5, unit: .gram)
    
    let result = try comparisonEngine.compare(product1, product2)
    
    // 33.33... vs 33.33... の精度確認
    XCTAssertEqual(result.comparisonDetails.unitPriceA, 33.33, accuracy: 0.01)
    XCTAssertEqual(result.comparisonDetails.unitPriceB, 33.33, accuracy: 0.01)
}
```

## 8. 実装優先度

### 8.1 Phase 1（必須機能）
- ✅ 基本比較機能
- ✅ 単位変換システム（基本単位のみ）
- ✅ エラーハンドリング
- ✅ 入力検証
- ✅ 精度保証

### 8.2 Phase 2（拡張機能）
- ⭕ 追加単位対応
- ⭕ パフォーマンス最適化
- ⭕ 詳細なエラーメッセージ
- ⭕ 計算履歴機能

### 8.3 Phase 3（高度機能）
- 🔲 割引計算対応
- 🔲 複数商品比較
- 🔲 国際化対応
- 🔲 AI推奨機能

この仕様に基づいて、確実で高精度な比較エンジンを実装できます。