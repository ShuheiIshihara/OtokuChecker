# Core Data データベース設計詳細

## 1. エンティティ設計

### 1.1 ProductGroup エンティティ
**概要**: 同一商品の複数記録をグループ化するエンティティ

```swift
@Model
class ProductGroup {
    // MARK: - 基本情報
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute var productName: String = ""           // 表示用商品名
    @Attribute var normalizedName: String = ""        // 検索用正規化名
    @Attribute var productType: String = ""           // 品目（例：米、パン等）
    
    // MARK: - カテゴリ関連
    @Relationship(deleteRule: .nullify, inverse: \Category.productGroups) 
    var category: Category?
    
    // MARK: - 統計情報（非正規化データ）
    @Attribute var recordCount: Int = 0               // 記録数
    @Attribute var lowestUnitPrice: Decimal = 0       // 最安単価
    @Attribute var lowestPriceStoreName: String = ""  // 最安店舗名
    @Attribute var lastRecordDate: Date?              // 最終記録日
    @Attribute var averageUnitPrice: Decimal = 0      // 平均単価
    
    // MARK: - システム情報
    @Attribute var isDeleted: Bool = false            // 論理削除フラグ
    @Attribute var createdAt: Date = Date()
    @Attribute var updatedAt: Date = Date()
    
    // MARK: - リレーションシップ
    @Relationship(deleteRule: .cascade, inverse: \ProductRecord.productGroup) 
    var records: [ProductRecord] = []
    
    // MARK: - Computed Properties
    var displayName: String {
        return productName.isEmpty ? "未設定" : productName
    }
    
    var formattedLowestPrice: String {
        return lowestUnitPrice > 0 ? "¥\(lowestUnitPrice)/\(commonUnit)" : "未設定"
    }
    
    // MARK: - ビジネスロジック
    func updateStatistics() {
        let activeRecords = records.filter { !$0.isDeleted }
        
        recordCount = activeRecords.count
        lastRecordDate = activeRecords.map(\.createdAt).max()
        
        if !activeRecords.isEmpty {
            let unitPrices = activeRecords.map(\.unitPrice)
            lowestUnitPrice = unitPrices.min() ?? 0
            averageUnitPrice = unitPrices.reduce(0, +) / Decimal(unitPrices.count)
            
            // 最安値の店舗名を取得
            if let lowestRecord = activeRecords.min(by: { $0.unitPrice < $1.unitPrice }) {
                lowestPriceStoreName = lowestRecord.storeName
            }
        }
        
        updatedAt = Date()
    }
    
    static func normalizeProductName(_ name: String) -> String {
        return name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "・", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "　", with: "")
            .replacingOccurrences(of: "-", with: "")
            .applyingTransform(.hiraganaToKatakana, reverse: false) ?? name
            .applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? name
            .lowercased()
    }
}
```

### 1.2 ProductRecord エンティティ
**概要**: 個別の商品購入記録

```swift
@Model
class ProductRecord {
    // MARK: - 基本情報
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute var productName: String = ""
    @Attribute var productType: String = ""           // 品目
    
    // MARK: - 価格情報
    @Attribute var originalPrice: Decimal = 0         // 表示価格
    @Attribute var finalPrice: Decimal = 0            // 税込最終価格
    @Attribute var taxIncluded: Bool = true           // 税込表示フラグ
    @Attribute var taxRate: Decimal = 0.1             // 税率（10%）
    @Attribute var unitPrice: Decimal = 0             // 単価（円/kg等）
    
    // MARK: - 容量・重量情報
    @Attribute var quantity: Decimal = 0              // 数量
    @Attribute var unit: Unit = .gram                 // 単位
    
    // MARK: - 店舗・購入情報
    @Attribute var storeName: String = ""             // 店舗名
    @Attribute var storeLocation: String = ""         // 店舗所在地
    @Attribute var purchaseDate: Date?                // 購入日
    @Attribute var memo: String = ""                  // メモ
    
    // MARK: - システム情報
    @Attribute var isDeleted: Bool = false
    @Attribute var createdAt: Date = Date()
    @Attribute var updatedAt: Date = Date()
    
    // MARK: - リレーションシップ
    @Relationship(deleteRule: .nullify, inverse: \ProductGroup.records) 
    var productGroup: ProductGroup?
    
    @Relationship(deleteRule: .nullify, inverse: \Category.productRecords) 
    var category: Category?
    
    // MARK: - ビジネスロジック
    func calculateFinalPrice() {
        if taxIncluded {
            finalPrice = originalPrice
        } else {
            finalPrice = originalPrice * (1 + taxRate)
        }
    }
    
    func calculateUnitPrice() {
        guard quantity > 0 else { return }
        
        let baseQuantity = unit.convertToBaseUnit(quantity)
        unitPrice = finalPrice / baseQuantity
    }
    
    // 保存前の自動計算
    func prepareForSave() {
        calculateFinalPrice()
        calculateUnitPrice()
        updatedAt = Date()
    }
}
```

### 1.3 Category エンティティ
**概要**: 商品カテゴリ管理

```swift
@Model
class Category {
    // MARK: - 基本情報
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute var name: String = ""                  // カテゴリ名
    @Attribute var icon: String = "📦"                // アイコン（絵文字）
    @Attribute var colorHex: String = "#007AFF"       // テーマカラー
    @Attribute var sortOrder: Int = 0                 // 表示順序
    
    // MARK: - システム情報
    @Attribute var isSystemCategory: Bool = false     // システム提供カテゴリ
    @Attribute var isDeleted: Bool = false
    @Attribute var createdAt: Date = Date()
    @Attribute var updatedAt: Date = Date()
    
    // MARK: - 統計情報
    @Attribute var productCount: Int = 0              // 所属商品数
    @Attribute var averageUnitPrice: Decimal = 0      // 平均単価
    @Attribute var lastUpdated: Date?                 // 最終更新日
    
    // MARK: - リレーションシップ
    @Relationship(deleteRule: .nullify, inverse: \ProductGroup.category) 
    var productGroups: [ProductGroup] = []
    
    @Relationship(deleteRule: .nullify, inverse: \ProductRecord.category) 
    var productRecords: [ProductRecord] = []
    
    // MARK: - システムカテゴリ生成
    static func createSystemCategories() -> [Category] {
        return [
            Category(name: "全て", icon: "📁", isSystem: true, sortOrder: 0),
            Category(name: "食料品", icon: "🍎", isSystem: true, sortOrder: 1),
            Category(name: "日用品", icon: "🧴", isSystem: true, sortOrder: 2),
            Category(name: "その他", icon: "📦", isSystem: true, sortOrder: 99)
        ]
    }
    
    init(name: String, icon: String, isSystem: Bool = false, sortOrder: Int = 0) {
        self.name = name
        self.icon = icon
        self.isSystemCategory = isSystem
        self.sortOrder = sortOrder
    }
}
```

### 1.4 ComparisonHistory エンティティ
**概要**: 比較履歴の記録

```swift
@Model
class ComparisonHistory {
    // MARK: - 基本情報
    @Attribute(.unique) var id: UUID = UUID()
    @Attribute var comparisonType: ComparisonType = .simple
    
    // MARK: - 商品A情報
    @Attribute var productAName: String = ""
    @Attribute var productAPrice: Decimal = 0
    @Attribute var productAQuantity: Decimal = 0
    @Attribute var productAUnit: Unit = .gram
    @Attribute var productAUnitPrice: Decimal = 0
    
    // MARK: - 商品B情報
    @Attribute var productBName: String = ""
    @Attribute var productBPrice: Decimal = 0
    @Attribute var productBQuantity: Decimal = 0
    @Attribute var productBUnit: Unit = .gram
    @Attribute var productBUnitPrice: Decimal = 0
    
    // MARK: - 比較結果
    @Attribute var winnerProduct: Winner = .productA  // どちらがお得か
    @Attribute var priceDifference: Decimal = 0       // 価格差（円/単位）
    @Attribute var percentageDifference: Decimal = 0  // パーセンテージ差
    @Attribute var userChoice: Winner?                // ユーザーの選択
    
    // MARK: - メタデータ
    @Attribute var comparisonContext: String = ""     // 比較時の状況
    @Attribute var wasDataSaved: Bool = false         // データ保存されたか
    
    // MARK: - システム情報
    @Attribute var isDeleted: Bool = false
    @Attribute var createdAt: Date = Date()
    
    enum ComparisonType: String, CaseIterable, Codable {
        case simple = "simple"           // 単純比較
        case withHistory = "withHistory" // 過去記録との比較
        case crossCategory = "crossCategory" // 異カテゴリ比較
    }
    
    enum Winner: String, CaseIterable, Codable {
        case productA = "productA"
        case productB = "productB"
        case tie = "tie"
    }
}
```

## 2. Enumeration 設計

### 2.1 Unit enum（単位）
```swift
enum Unit: String, CaseIterable, Codable {
    // 重量
    case gram = "g"
    case kilogram = "kg"
    case pound = "lb"
    case ounce = "oz"
    
    // 容量
    case milliliter = "ml"
    case liter = "L"
    case cup = "cup"
    case tablespoon = "tbsp"
    case teaspoon = "tsp"
    
    // 個数
    case piece = "個"
    case pack = "パック"
    case bottle = "本"
    case bag = "袋"
    
    var displayName: String {
        switch self {
        case .gram: return "グラム"
        case .kilogram: return "キログラム"
        case .milliliter: return "ミリリットル"
        case .liter: return "リットル"
        case .piece: return "個"
        case .pack: return "パック"
        case .bottle: return "本"
        case .bag: return "袋"
        default: return rawValue
        }
    }
    
    var category: UnitCategory {
        switch self {
        case .gram, .kilogram, .pound, .ounce:
            return .weight
        case .milliliter, .liter, .cup, .tablespoon, .teaspoon:
            return .volume
        case .piece, .pack, .bottle, .bag:
            return .count
        }
    }
    
    // 基本単位への変換係数
    var baseUnitConversionFactor: Decimal {
        switch self {
        case .gram: return 1
        case .kilogram: return 1000
        case .milliliter: return 1
        case .liter: return 1000
        case .piece, .pack, .bottle, .bag: return 1
        default: return 1
        }
    }
    
    func convertToBaseUnit(_ value: Decimal) -> Decimal {
        return value * baseUnitConversionFactor
    }
    
    // 単位間変換の可否チェック
    func isConvertibleTo(_ other: Unit) -> Bool {
        return self.category == other.category
    }
}

enum UnitCategory: String, CaseIterable {
    case weight = "weight"
    case volume = "volume"
    case count = "count"
}
```

## 3. インデックス設計

### 3.1 パフォーマンス重視のインデックス
```swift
// Core Data Model Editor でのインデックス設定

ProductGroup:
  - normalizedName: Hash Index (検索最適化)
  - category + lastRecordDate: Compound Index (カテゴリ別ソート)
  - isDeleted + updatedAt: Compound Index (論理削除対応)

ProductRecord:
  - productGroup + createdAt: Compound Index (グループ内ソート)
  - unitPrice: B-Tree Index (価格ソート)
  - storeName: Hash Index (店舗別検索)
  - isDeleted + purchaseDate: Compound Index (期間検索)

Category:
  - isSystemCategory + sortOrder: Compound Index (カテゴリ一覧)
  - isDeleted: Hash Index (論理削除フィルタ)

ComparisonHistory:
  - createdAt: B-Tree Index (時系列ソート)
  - comparisonType: Hash Index (種別フィルタ)
```

### 3.2 クエリパフォーマンス最適化
```swift
// 頻繁に実行されるクエリの最適化例

// 1. カテゴリ別商品グループ検索
NSFetchRequest<ProductGroup> = ProductGroup.fetchRequest()
request.predicate = NSPredicate(format: "category == %@ AND isDeleted == NO", category)
request.sortDescriptors = [NSSortDescriptor(keyPath: \ProductGroup.lastRecordDate, ascending: false)]
request.fetchLimit = 20
request.fetchBatchSize = 20

// 2. 商品名検索（正規化名使用）
request.predicate = NSPredicate(format: "normalizedName BEGINSWITH %@ AND isDeleted == NO", normalizedQuery)
request.relationshipKeyPathsForPrefetching = ["category"]

// 3. 価格帯検索
request.predicate = NSPredicate(format: "unitPrice BETWEEN {%@, %@} AND isDeleted == NO", [minPrice, maxPrice])
```

## 4. データマイグレーション戦略

### 4.1 バージョニング戦略
```swift
// Core Data Migration Version Strategy

Version 1.0: 初期リリース
- ProductGroup, ProductRecord, Category, ComparisonHistory

Version 1.1: 機能拡張
- ProductRecord に storeLocation 追加
- Category に colorHex 追加

Version 1.2: パフォーマンス改善
- ProductGroup に統計情報フィールド追加
- インデックス追加・変更

Version 2.0: 大幅機能追加
- 新エンティティ追加（Store, Promotion等）
- リレーションシップ変更
```

### 4.2 軽量マイグレーション設定
```swift
lazy var persistentContainer: NSPersistentContainer = {
    let container = NSPersistentContainer(name: "DataModel")
    
    let storeDescription = container.persistentStoreDescriptions.first
    storeDescription?.shouldMigrateStoreAutomatically = true
    storeDescription?.shouldInferMappingModelAutomatically = true
    
    // 大きなデータセットでのマイグレーション最適化
    storeDescription?.setValue("DELETE", forPragmaNamed: "journal_mode")
    storeDescription?.setValue("MEMORY", forPragmaNamed: "temp_store")
    
    container.loadPersistentStores { _, error in
        if let error = error as NSError? {
            // マイグレーションエラーハンドリング
            fatalError("Core Data Migration failed: \(error)")
        }
    }
    
    return container
}()
```

## 5. データ整合性制約

### 5.1 必須フィールド検証
```swift
extension ProductRecord {
    func validate() throws {
        // 商品名必須
        guard !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyProductName
        }
        
        // 価格は正の値
        guard originalPrice > 0 else {
            throw ValidationError.invalidPrice
        }
        
        // 数量は正の値
        guard quantity > 0 else {
            throw ValidationError.invalidQuantity
        }
        
        // ProductGroup との整合性
        if let group = productGroup {
            guard group.productName == productName else {
                throw ValidationError.productGroupMismatch
            }
        }
    }
}

enum ValidationError: LocalizedError {
    case emptyProductName
    case invalidPrice
    case invalidQuantity
    case productGroupMismatch
    
    var errorDescription: String? {
        switch self {
        case .emptyProductName: return "商品名を入力してください"
        case .invalidPrice: return "価格は0より大きい値を入力してください"
        case .invalidQuantity: return "数量は0より大きい値を入力してください"
        case .productGroupMismatch: return "商品グループとの整合性エラー"
        }
    }
}
```

### 5.2 カスケード削除の制御
```swift
// ProductGroup 削除時の動作
extension ProductGroup {
    func safeDelete() {
        // 関連レコードを論理削除
        for record in records {
            record.isDeleted = true
        }
        
        // 自身も論理削除
        isDeleted = true
        updatedAt = Date()
        
        // 統計情報更新
        if let category = category {
            category.updateStatistics()
        }
    }
}
```

## 6. バックアップ・復元機能

### 6.1 データエクスポート
```swift
struct DataExportService {
    func exportAllData() async throws -> Data {
        let exportData = ExportData(
            productGroups: try await fetchAllProductGroups(),
            productRecords: try await fetchAllProductRecords(),
            categories: try await fetchAllCategories(),
            comparisonHistories: try await fetchRecentComparisonHistories(),
            exportDate: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        )
        
        return try JSONEncoder().encode(exportData)
    }
}

struct ExportData: Codable {
    let productGroups: [ProductGroupDTO]
    let productRecords: [ProductRecordDTO]
    let categories: [CategoryDTO]
    let comparisonHistories: [ComparisonHistoryDTO]
    let exportDate: Date
    let appVersion: String
}
```

## 7. パフォーマンス監視

### 7.1 クエリパフォーマンス計測
```swift
extension NSManagedObjectContext {
    func performWithTiming<T>(_ block: () throws -> T) rethrows -> (result: T, duration: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        #if DEBUG
        if duration > 0.1 { // 100ms以上の場合は警告
            print("⚠️ Slow Core Data query detected: \(duration)s")
        }
        #endif
        
        return (result, duration)
    }
}
```

この設計により、アプリの要件を満たす効率的で拡張性の高いデータベース構造が実現できます。