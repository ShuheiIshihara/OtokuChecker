# Core Data実装ナレッジ

## 概要

OtokuCheckerアプリのCore Data実装において発生した問題と解決策をまとめたナレッジドキュメントです。今後の開発や類似プロジェクトで同じ問題を回避するための参考資料として活用してください。

## 実装完了状況

### ✅ 実装済みエンティティ

| エンティティ名 | 用途 | 主要プロパティ |
|-------------|------|-------------|
| ProductCategory | 商品カテゴリ管理 | name, icon, colorHex, sortOrder |
| ProductGroup | 商品グループと統計 | productName, recordCount, lowestUnitPrice |
| ProductRecord | 個別商品購入記録 | productName, originalPrice, quantity, unitType |
| ComparisonHistory | 比較履歴記録 | comparisonType, productA/B情報, 比較結果 |

### エンティティ設計の標準化

全エンティティで以下の構造を採用：

1. **主キー**: `entityID` (UUID型)
2. **コアプロパティ**: 基本情報（名前、タイプなど）
3. **ビジネスロジック**: 価格、数量、計算結果など
4. **統計情報**: 非正規化データ、集計値
5. **システムフラグ**: `isDeleted`, `isSystemCategory`など
6. **タイムスタンプ**: `createdAt`, `updatedAt` (最下位)

## 発生した問題と解決策

### 1. 「Override keyword」エラー

#### 問題
```
Overriding declaration requires an 'override' keyword
```

#### 原因
Core Dataの自動生成プロパティがNSManagedObjectの基底クラスプロパティと重複

#### 根本原因となったプロパティ名
- `id` → NSManagedObjectの`objectID`と概念的に重複
- `description` → NSObject.descriptionと重複  
- `hash` → NSObject.hashと重複

#### 解決策
1. **プロパティ名変更**: `id` → `entityID`
2. **Code Generation設定変更**: `codeGenerationType="class"` を削除（Manual/None設定）

```xml
<!-- 修正前 -->
<entity name="ProductCategory" codeGenerationType="class">
    <attribute name="id" optional="NO" attributeType="UUID"/>
</entity>

<!-- 修正後 -->
<entity name="ProductCategory">
    <attribute name="entityID" optional="NO" attributeType="UUID"/>
</entity>
```

### 2. 「Cannot find Entity in scope」エラー

#### 問題
```
Cannot find 'Item' in scope
```

#### 原因
古いエンティティ（Item）への参照がPersistence.swiftに残存

#### 解決策
Persistence.swiftのpreviewデータ作成コードを新エンティティに対応：

```swift
// 修正前
let newItem = Item(context: viewContext)
newItem.timestamp = Date()

// 修正後  
let sampleCategory = NSEntityDescription.entity(forEntityName: "ProductCategory", in: viewContext)!
let category = NSManagedObject(entity: sampleCategory, insertInto: viewContext)
category.setValue(UUID(), forKey: "entityID")
category.setValue("食料品", forKey: "name")
```

### 3. Swift標準ライブラリとの命名衝突

#### 問題のある命名パターン
| 使用した名前 | 衝突するSwift要素 | 採用した安全な名前 |
|-------------|------------------|------------------|
| `Category` | Objective-C Category概念 | `ProductCategory` |
| `id` | Identifiableプロトコル | `entityID` |
| `unit` | Foundation.Unit | `unitType` |

#### 安全な命名ルール
1. **ドメイン固有の接頭辞を追加**: `Category` → `ProductCategory`
2. **より具体的な名前を使用**: `id` → `entityID`, `unit` → `unitType`
3. **NSObjectの既存プロパティを避ける**: `description`, `hash`など

## Code Generation戦略の比較

### Manual/None設定（採用）
```xml
<entity name="ProductCategory" syncable="YES">
```

**メリット**:
- Override衝突を完全回避
- 生成コードの完全制御
- より安全な開発環境

**デメリット**:
- 手動でのクラス生成が必要
- モデル変更時の手動対応

**使用方法**:
Xcode → Editor → Create NSManagedObject Subclass

### Category/Extension設定（代替案）
```xml
<entity name="ProductCategory" codeGenerationType="category">
```

**メリット**:
- 自動生成を維持
- Classより衝突が少ない

**デメリット**:
- 一部の衝突リスクは残存
- 生成コードの制御が限定的

### Class設定（問題あり）
```xml
<entity name="ProductCategory" codeGenerationType="class">
```

**問題**:
- NSManagedObjectとの衝突が頻発
- Override keywordエラーの原因

## 今後の開発指針

### モデル設計時の注意点

1. **主キー命名**: 常に`entityID`を使用
2. **プロパティ順序**: ID → コア → ビジネス → システム → タイムスタンプ
3. **Soft Delete**: 全エンティティに`isDeleted`フラグを追加
4. **監査証跡**: `createdAt`, `updatedAt`を必須に
5. **リレーション削除ルール**: 適切なCascade/Nullify設定

### 避けるべき命名パターン

```swift
// ❌ 避けるべき
id, description, hash, unit, Category

// ✅ 推奨
entityID, itemDescription, hashValue, unitType, ProductCategory
```

### エラー発生時のチェックリスト

1. **Build Error発生時**:
   - [ ] プロパティ名がNSObjectと重複していないか
   - [ ] Code Generation設定は適切か
   - [ ] 古いエンティティ参照が残っていないか

2. **新エンティティ追加時**:
   - [ ] `entityID` (UUID)を主キーに設定
   - [ ] `isDeleted` フラグを追加
   - [ ] `createdAt`, `updatedAt` タイムスタンプを追加
   - [ ] Swift予約語との衝突をチェック

3. **モデル変更時**:
   - [ ] 既存コードの参照を全て更新
   - [ ] Persistence.swiftのpreviewデータを更新
   - [ ] 関連するビジネスロジックを更新

## 参考情報

### 有用なXcodeコマンド
- **NSManagedObjectサブクラス生成**: Editor → Create NSManagedObject Subclass
- **Derived Data削除**: Xcode → Window → Organizer → Projects → Delete Derived Data
- **Clean Build**: Product → Clean Build Folder (Cmd+Shift+K)

### Core Data実装の品質チェック
1. エンティティ名がSwift標準と衝突しない
2. プロパティ名がNSObjectプロパティと重複しない  
3. リレーションシップの削除ルールが適切
4. 一意性制約が正しく設定されている
5. インデックスが適切に配置されている

---

**作成日**: 2025年8月20日  
**最終更新**: 2025年8月20日  
**作成者**: Claude Code + 石原脩平  
**プロジェクト**: OtokuChecker iOS App