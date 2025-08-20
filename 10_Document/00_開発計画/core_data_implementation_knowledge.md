# Core Data実装エラー解決ナレッジ

## 概要

OtokuCheckerプロジェクトでCore Data実装時に発生した一連のエラーとその解決方法をまとめたナレッジドキュメント。
Repositoryパターンとプロトコル準拠の実装で遭遇した問題から学んだベストプラクティス。

## 発生したエラーと解決経緯

### 1. BaseRepositoryプロトコル準拠エラー

**エラー**: `Type 'CoreDataProductCategoryRepository' does not conform to protocol 'BaseRepository'`

**原因**: 
- Core Dataエンティティクラス（ProductCategory、ProductGroup等）が自動生成されていない
- プロトコルで要求されるメソッドシグネチャと実装が一致しない

**解決方法**:
```swift
// 手動でCore Dataエンティティクラスを作成
@objc(ProductCategory)
public class ProductCategory: NSManagedObject {
    // NSManagedObjectサブクラスとして実装
}
```

### 2. オーバーライドキーワード必要エラー

**エラー**: `Overriding declaration requires an 'override' keyword`

**原因**: 
- `isDeleted`プロパティがNSManagedObjectの既存プロパティと重複

**初期対応**: `override`キーワード追加
```swift
@NSManaged public override var isDeleted: Bool // 問題のあるアプローチ
```

**最終解決**: プロパティ名変更
```swift
@NSManaged public var deletedFlag: Bool // 重複回避
```

### 3. Mock継承問題

**エラー**: `MockProductCategory: ProductCategory` の継承が型推論エラーを引き起こす

**原因**:
- Core DataのNSManagedObjectサブクラスを継承したMockクラスは、Core Dataコンテキストなしでは正常動作しない
- プロパティの重複や型推論の曖昧性が発生

**解決方法**:
```swift
// 継承を止めて独立したクラスに変更
class MockProductCategory {  // Core Data非依存
    var entityID: UUID
    var name: String
    // 必要なプロパティのみ実装
}
```

### 4. 型変換エラー

**エラー**: `Cannot convert return expression of type 'MockProductCategory' to return type 'ProductCategory'`

**解決方法**: 変換ヘルパー関数の実装
```swift
private func convertToProductCategory(_ mockCategory: MockProductCategory) -> ProductCategory {
    let category = ProductCategory(context: PersistenceController.shared.container.viewContext)
    // プロパティをコピー
    category.entityID = mockCategory.entityID
    category.name = mockCategory.name
    // ...
    return category
}
```

### 5. Swift新構文対応

**エラー**: `Use of protocol 'ProductCategoryRepositoryProtocol' as a type must be written 'any ProductCategoryRepositoryProtocol'`

**解決方法**: Swift 5.6以降の新しいプロトコル型構文に対応
```swift
// 修正前
let repository: ProductCategoryRepositoryProtocol

// 修正後  
let repository: any ProductCategoryRepositoryProtocol
```

## 学習したベストプラクティス

### Core Data設計

1. **エンティティクラスの管理**
   - 自動生成に依存せず、手動作成を検討
   - NSManagedObjectの既存プロパティとの名前衝突を避ける
   - プロパティ名は具体的に（`isDeleted` → `deletedFlag`）

2. **プロパティ命名規則**
   - Bool型フラグは `xxxFlag` 形式で重複回避
   - Core Dataの予約語を確認する

### Repositoryパターン実装

1. **プロトコル設計**
   - BaseRepositoryで共通操作を定義
   - 具体的なRepositoryプロトコルで拡張
   - 型安全性を重視したジェネリクス活用

2. **エラーハンドリング**
   ```swift
   enum RepositoryError: LocalizedError {
       case entityNotFound
       case saveFailed
       case coreDataError(Error)
   }
   ```

### Mock実装設計

1. **継承関係の設計**
   - Core DataクラスのMockは継承を避ける
   - 独立したクラスとして実装
   - 変換ヘルパー関数で型安全な変換

2. **変換パターン**
   ```swift
   // フィルタリング + 変換の統一パターン
   func fetchAll() async throws -> [Entity] {
       let filteredMocks = mocks.filter { !$0.deletedFlag }
       return filteredMocks.map { convertToEntity($0) }
   }
   ```

### コード品質

1. **型安全性**
   - 明示的な型変換関数使用
   - プロトコル型での`any`キーワード活用
   - 曖昧な型推論を避ける

2. **保守性**
   - 変換ロジックの一元化
   - エラーメッセージの日本語対応
   - 統一されたコーディングパターン

## 今後の注意点

### 開発時
- Core Dataモデル変更時はエンティティクラスも同期更新
- 新しいエンティティ追加時は名前衝突を事前チェック
- Mock実装は変換ヘルパー関数パターンを踏襲

### 技術的負債回避
- プロトコル準拠の検証を自動化
- 型安全性チェックの強化
- 継続的なSwift言語仕様更新への対応

## 参考リソース

- [Core Data Programming Guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreData/)
- [Swift Evolution - SE-0335 Existential any](https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md)
- Repository Pattern in iOS Development

---

**作成日**: 2025年8月20日  
**対象プロジェクト**: OtokuChecker iOS App  
**Swift Version**: 5.x  
**Xcode Version**: 15.x