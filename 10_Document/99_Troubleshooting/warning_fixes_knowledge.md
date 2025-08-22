# Swiftワーニング修正ナレッジ

## 概要

OtokuCheckerプロジェクトの開発中に発生したSwiftワーニングとその解決方法をまとめた技術ナレッジドキュメントです。

## ワーニングカテゴリ別解決方法

### 1. Existential Type ワーニング

#### ワーニング内容
```
Existential type warning: protocol 'SomeProtocol' can only be used as a generic constraint because it has Self or associated type requirements
```

#### 原因
Swift 5.6以降で、プロトコル型を使用する箇所で`any`キーワードが必要になった。

#### 解決方法
プロトコル型の前に`any`キーワードを追加：

```swift
// 修正前
private let useCase: UseCaseProtocol
func getRepository() -> RepositoryProtocol

// 修正後  
private let useCase: any UseCaseProtocol
func getRepository() -> any RepositoryProtocol
```

#### 適用箇所
- `ProductManagementUseCase.swift` - プロパティとイニシャライザー引数
- `HistoryManagementUseCase.swift` - プロパティとイニシャライザー引数
- `MainComparisonViewModel.swift` - プロパティとイニシャライザー引数
- `DataEntryViewModel.swift` - プロパティとイニシャライザー引数
- `HistoryViewModel.swift` - プロパティとイニシャライザー引数
- `SettingsViewModel.swift` - プロパティとイニシャライザー引数
- `DIContainer.swift` - 戻り値型とプロパティ宣言

---

### 2. MainActor分離ワーニング (Swift 6)

#### ワーニング内容
```
Main actor-isolated property cannot be used to satisfy nonisolated requirement from protocol; this is an error in the Swift 6 language mode
```

#### 原因
Swift 6では、`@MainActor`でマークされたクラスのプロパティ・メソッドは、同様に`@MainActor`でマークされたプロトコルでのみ使用可能。

#### 解決方法
プロトコルに`@MainActor`アノテーションを追加：

```swift
// 修正前
protocol BaseViewModelProtocol: ObservableObject {
    var isLoading: Bool { get set }
    // ...
}

protocol ViewModelFactory {
    func makeMainComparisonViewModel() -> MainComparisonViewModel
    // ...
}

// 修正後
@MainActor
protocol BaseViewModelProtocol: ObservableObject {
    var isLoading: Bool { get set }
    // ...
}

@MainActor
protocol ViewModelFactory {
    func makeMainComparisonViewModel() -> MainComparisonViewModel
    // ...
}
```

#### 適用箇所
- `BaseViewModelProtocol` - UI関連プロトコルの並行性安全性確保
- `ViewModelFactory` - ViewModelファクトリーメソッドの並行性統一

---

### 3. 未使用戻り値ワーニング

#### ワーニング内容
```
Result of call to 'executeVoidTask' is unused
```

#### 原因
`executeVoidTask`がTaskを返すが、呼び出し側で戻り値を使用していない。

#### 解決方法
メソッド定義に`@discardableResult`アノテーションを追加：

```swift
// 修正前
func executeVoidTask(_ task: @escaping () async throws -> Void) -> Task<Void, Never> {
    // ...
}

// 修正後
@discardableResult
func executeVoidTask(_ task: @escaping () async throws -> Void) -> Task<Void, Never> {
    // ...
}
```

#### 適用箇所
- `BaseViewModel.swift` - `executeTask`と`executeVoidTask`メソッド

---

### 4. 非同期操作なしワーニング

#### ワーニング内容
```
No 'async' operations occur within 'await' expression
```

#### 原因
同期メソッドに`await`キーワードを使用している。

#### 解決方法
同期メソッドから`await`キーワードを削除：

```swift
// 修正前
executeVoidTask {
    try await self.someAsyncMethod()
    await self.loadData()  // loadData()は同期メソッド
}

// 修正後
executeVoidTask {
    try await self.someAsyncMethod()
    self.loadData()  // awaitを削除
}
```

#### 適用箇所
- `SettingsViewModel.swift:69` - `loadCategories()`呼び出し
- `MainComparisonViewModel.swift:187,196` - `loadRecentProducts()`呼び出し

---

### 5. 非推奨API使用ワーニング

#### ワーニング内容
```
'canCompareProducts' is deprecated: Use canCompareProducts(_ productA: ComparisonProduct, _ productB: ComparisonProduct) instead
'compareProducts' is deprecated: Use compare(productA:productB:) instead
```

#### 原因
レガシーAPIから新しい高精度比較APIに移行。

#### 解決方法
新しいAPIを使用し、適切な型変換を実装：

```swift
// 修正前
let validation = comparisonService.canCompareProducts(productA, productB)
comparisonResult = comparisonService.compareProducts(productA, productB)

// 修正後
let comparisonProductA = ComparisonProduct(
    name: productA.name,
    price: Decimal(string: productA.price) ?? 0,
    quantity: Decimal(string: productA.quantity) ?? 0,
    unit: productA.unit,
    taxIncluded: true,
    taxRate: Decimal(0.10)
)
// ComparisonProductBも同様

let validation = comparisonService.canCompareProducts(comparisonProductA, comparisonProductB)
let result = try comparisonService.compare(productA: comparisonProductA, productB: comparisonProductB)
```

#### 適用箇所
- `ContentView.swift` - 比較機能の新API移行

---

### 6. 型変換ワーニング

#### ワーニング内容
```
No exact matches in call to initializer
Cannot convert value of type 'ExtendedComparisonResult.Winner' to expected argument type 'ComparisonResult.Winner'
```

#### 原因
1. String → Decimal変換の方法が不適切
2. 異なるenum型間の変換が必要

#### 解決方法

**String → Decimal変換**:
```swift
// 修正前
price: Decimal(productA.price) ?? 0

// 修正後
price: Decimal(string: productA.price) ?? 0
```

**Enum型変換**:
```swift
// 修正前
winner: result.winner  // 型不一致

// 修正後
let winner: ComparisonResult.Winner = {
    switch result.winner {
    case .productA: return .productA
    case .productB: return .productB
    case .tie: return .tie
    }
}()
```

#### 適用箇所
- `ContentView.swift` - ComparisonProduct初期化とComparisonResult変換

---

## 予防策とベストプラクティス

### 1. Swift言語バージョン対応
- **Existential Type**: Swift 5.6以降では`any`キーワードを積極使用
- **MainActor**: Swift 6ではUI関連プロトコルに`@MainActor`を付与
- **並行性**: 非同期・同期メソッドの区別を明確にする

### 2. API設計
- **戻り値破棄**: 必要に応じて`@discardableResult`を使用
- **非推奨対応**: 新APIへの移行時は適切な型変換を実装
- **エラーハンドリング**: try-catch文による適切な例外処理

### 3. 型安全性
- **文字列変換**: `Decimal(string:)`など適切な変換メソッドを使用
- **Enum変換**: 型安全なswitch文による変換処理
- **プロトコル準拠**: 実装クラスとの並行性レベル統一

### 4. コードメンテナンス
- **定期的な確認**: 新しいSwiftバージョンでのワーニング確認
- **段階的移行**: レガシーAPIから新APIへの計画的移行
- **ドキュメント化**: 変更理由と対応方法の記録

## 参考資料

- [Swift Evolution SE-0335: Introduce existential any](https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md)
- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [MainActor Documentation](https://developer.apple.com/documentation/swift/mainactor)

## 修正履歴

| 日付 | 修正内容 | 対象ファイル |
|------|----------|--------------|
| 2025-08-22 | Existential type修正 | 全ViewModelファイル |
| 2025-08-22 | MainActor分離修正 | BaseViewModel.swift |
| 2025-08-22 | 未使用戻り値修正 | BaseViewModel.swift |
| 2025-08-22 | 非同期操作修正 | Settings/MainComparisonViewModel |
| 2025-08-22 | 非推奨API修正 | ContentView.swift |
| 2025-08-22 | 型変換修正 | ContentView.swift |