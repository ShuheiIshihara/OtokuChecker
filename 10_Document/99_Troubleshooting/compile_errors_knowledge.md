# Swiftコンパイルエラー解決ナレッジ

## 概要

OtokuCheckerプロジェクトの開発中に発生したコンパイルエラーとその解決方法をまとめた技術ナレッジドキュメントです。

## エラーカテゴリ別解決方法

### 1. MainActor関連エラー

#### エラー内容
```
Call to main actor-isolated initializer 'init(comparisonUseCase:productManagementUseCase:)' in a synchronous nonisolated context
```

#### 解決方法
ViewModelファクトリーメソッドに`@MainActor`アノテーションを追加：

```swift
// 修正前
func makeMainComparisonViewModel() -> MainComparisonViewModel {
    return MainComparisonViewModel(...)
}

// 修正後
@MainActor
func makeMainComparisonViewModel() -> MainComparisonViewModel {
    return MainComparisonViewModel(...)
}
```

#### 適用箇所
- `BaseViewModel.swift`: 全ViewModelファクトリーメソッド
  - `makeMainComparisonViewModel()`
  - `makeDataEntryViewModel()`
  - `makeHistoryViewModel()`
  - `makeSettingsViewModel()`

---

### 2. 依存性注入（DI）エラー

#### エラー内容
```
Cannot convert value of type 'KeyPath<any DIContainerProtocol, () -> any ComparisonUseCaseProtocol>' to expected argument type 'KeyPath<any DIContainerProtocol, any ComparisonUseCaseProtocol>'
```

#### 解決方法
`@Injected`プロパティラッパーをクロージャベースに変更：

```swift
// 修正前
@propertyWrapper
struct Injected<T> {
    private let keyPath: KeyPath<DIContainerProtocol, T>
    
    init(_ keyPath: KeyPath<DIContainerProtocol, T>) {
        self.keyPath = keyPath
    }
}

// 修正後
@propertyWrapper
struct Injected<T> {
    private let getter: (DIContainerProtocol) -> T
    
    init(_ getter: @escaping (DIContainerProtocol) -> T) {
        self.getter = getter
    }
}
```

#### 使用例
```swift
@Injected({ $0.getComparisonUseCase() })
private var comparisonUseCase: any ComparisonUseCaseProtocol
```

---

### 3. 戻り値型変換エラー

#### エラー内容
```
Cannot convert return expression of type '[ComparisonValidationError]' to return type '[String]'
```

#### 解決方法
LocalizedErrorの`errorDescription`を使用して文字列に変換：

```swift
// 修正前
func validateProductForComparison(_ product: ComparisonProduct) -> [String] {
    return product.validateInput()  // [ComparisonValidationError]を返す
}

// 修正後
func validateProductForComparison(_ product: ComparisonProduct) -> [String] {
    return product.validateInput().compactMap { $0.errorDescription }
}
```

---

### 4. enum ケース不一致エラー

#### エラー内容
```
Type 'ExtendedComparisonResult.Winner' has no member 'incomparable'
```

#### 解決方法
存在しないenumケースを削除し、適切な例外処理を使用：

```swift
// 修正前
switch extendedResult.winner {
case .productA: winner = .productA
case .productB: winner = .productB
case .tie: winner = .tie
case .incomparable: return nil  // 存在しないケース
}

// 修正後
switch extendedResult.winner {
case .productA: winner = .productA
case .productB: winner = .productB
case .tie: winner = .tie
// incomparableケースは削除、例外処理でハンドリング
}
```

---

### 5. Core Data型変換エラー

#### エラー内容
```
Cannot convert value of type 'ObjectIdentifier' to expected argument type 'UUID'
```

#### 解決方法
Core DataエンティティのUUIDプロパティを使用：

```swift
// 修正前
input = ComparisonInput(
    productA: productA, 
    productB: nil, 
    historicalProductId: selectedProduct.id  // ObjectIdentifier
)

// 修正後
input = ComparisonInput(
    productA: productA, 
    productB: nil, 
    historicalProductId: selectedProduct.entityID  // UUID
)
```

---

### 6. NSDecimalNumber演算エラー

#### エラー内容
```
Binary operator '/' cannot be applied to two 'NSDecimalNumber' operands
```

#### 解決方法
NSDecimalNumberの適切なメソッドを使用：

```swift
// 修正前
let unitPriceA = productAPrice / productAQuantity
let savings = abs(unitPriceA - unitPriceB)

// 修正後
let unitPriceA = productAPrice.dividing(by: productAQuantity)
let priceDifference = unitPriceA.subtracting(unitPriceB)
let savings = priceDifference.compare(NSDecimalNumber.zero) == .orderedAscending ? 
    priceDifference.multiplying(by: NSDecimalNumber(value: -1)) : priceDifference
```

#### NSDecimalNumber演算子対応表
| 演算子 | NSDecimalNumberメソッド |
|--------|------------------------|
| `+` | `.adding()` |
| `-` | `.subtracting()` |
| `*` | `.multiplying(by:)` |
| `/` | `.dividing(by:)` |
| `>`, `<` | `.compare()` |

---

### 7. NSDecimalNumber ↔ Decimal変換エラー

#### エラー内容
```
'NSDecimalNumber' is not implicitly convertible to 'Decimal'
```

#### 解決方法
`.decimalValue`プロパティを使用：

```swift
// 修正前
return ComparisonSavings(
    absoluteSavings: savings,  // NSDecimalNumber
    percentageSavings: savingsPercentage  // NSDecimalNumber
)

// 修正後
return ComparisonSavings(
    absoluteSavings: savings.decimalValue,  // Decimal
    percentageSavings: savingsPercentage.decimalValue  // Decimal
)
```

逆変換の場合：
```swift
// Decimal → NSDecimalNumber
existingProduct.originalPrice = NSDecimalNumber(decimal: product.price)
```

---

### 8. オプショナル値アンラップエラー

#### エラー内容
```
Value of optional type 'NSDecimalNumber?' must be unwrapped to refer to member 'description'
```

#### 解決方法
オプショナルチェーニングとnil-coalescing演算子を使用：

```swift
// 修正前
price = product.originalPrice.description

// 修正後
price = product.originalPrice?.description ?? ""
```

---

### 9. プロパティ名不一致エラー

#### エラー内容
```
Value of type 'ProductRecord' has no member 'notes'
Value of type 'ProductGroup' has no member 'usageCount'
```

#### 解決方法
Core Dataエンティティの正しいプロパティ名を使用：

```swift
// 修正前
notes = product.notes ?? ""
($0.productGroup?.usageCount ?? 0) > 3

// 修正後
notes = product.memo ?? ""  // Core Dataでは'memo'
($0.productGroup?.recordCount ?? 0) > 3  // Core Dataでは'recordCount'
```

---

### 10. エラーハンドリング不備

#### エラー内容
```
Errors thrown from here are not handled
```

#### 解決方法
try文をdo-catchブロックで囲む：

```swift
// 修正前
private func createNewProduct(_ product: ComparisonProduct) async {
    _ = try await productManagementUseCase.saveProduct(product, category: selectedCategory)
}

// 修正後
private func createNewProduct(_ product: ComparisonProduct) async {
    do {
        _ = try await productManagementUseCase.saveProduct(product, category: selectedCategory)
    } catch {
        // Handle error - could set an error state here
    }
}
```

---

### 11. プロトコル準拠不備

#### エラー内容
```
Value of type 'any CategoryManagementUseCaseProtocol' has no member 'suggestCategoriesFor'
```

#### 解決方法
プロトコルに不足しているメソッドを追加：

```swift
// UseCaseProtocols.swiftに追加
protocol CategoryManagementUseCaseProtocol: BaseUseCase {
    // 既存のメソッド...
    func suggestCategoriesFor(productName: String) async throws -> [ProductCategory]
}
```

---

### 12. クロージャパラメータエラー

#### エラー内容
```
Contextual type for closure argument list expects 1 argument, which cannot be implicitly ignored
```

#### 解決方法
タプルの分解を適切に行う：

```swift
// 修正前
.map { (validation, mode), historicalProduct in
    let (productAValid, productBValid, currentMode) = validation
}

// 修正後
.map { validationAndMode, historicalProduct in
    let (productAValid, productBValid, currentMode) = validationAndMode
}
```

---

## 予防策とベストプラクティス

### 1. 型安全性の確保
- Core Dataプロパティの型を事前に確認
- NSDecimalNumberとDecimalの変換を明示的に行う
- オプショナル値は常にアンラップしてから使用

### 2. エラーハンドリング
- 非同期処理では必ずdo-catchブロックを使用
- エラー状態を適切にViewModelに反映

### 3. プロトコル設計
- 実装前にプロトコルの完全性を確認
- 新機能追加時は対応するプロトコルメソッドも追加

### 4. MainActor使用
- UI関連のViewModelは`@MainActor`でマーク
- ファクトリーメソッドも適切にMainActorで分離

### 5. 依存性注入
- KeyPathではなくクロージャベースのDIを使用
- 型安全性を保ちながら柔軟性を確保

## 参考資料

- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Core Data Programming Guide](https://developer.apple.com/documentation/coredata)
- [NSDecimalNumber Documentation](https://developer.apple.com/documentation/foundation/nsdecimalnumber)