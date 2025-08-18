# Repository実装詳細設計

## 1. Repository パターンの設計思想

### 1.1 設計原則
- **関心の分離**: ビジネスロジックとデータアクセスを分離
- **テスタビリティ**: モックを使った単体テストが容易
- **拡張性**: 将来のCloudKit対応を見据えた設計
- **型安全性**: Swiftの型システムを最大限活用

### 1.2 アーキテクチャ概要
```
ViewModel
    ↓
Repository (Protocol)
    ↓
DataSource (Core Data / CloudKit)
    ↓
Persistent Store (SQLite / CloudKit)
```

## 2. Protocol定義

### 2.1 メインRepository Protocol
```swift
protocol ProductRepository {
    // MARK: - ProductGroup Operations
    func fetchProductGroups(
        category: Category?,
        sortBy: ProductGroupSortOption,
        limit: Int?,
        offset: Int?
    ) async throws -> [ProductGroup]
    
    func searchProductGroups(
        query: String,
        category: Category?,
        limit: Int?
    ) async throws -> [ProductGroup]
    
    func saveProductGroup(_ group: ProductGroup) async throws
    func deleteProductGroup(_ group: ProductGroup) async throws
    func getProductGroup(by id: UUID) async throws -> ProductGroup?
    
    // MARK: - ProductRecord Operations
    func fetchProductRecords(
        for group: ProductGroup,
        sortBy: ProductRecordSortOption,
        limit: Int?
    ) async throws -> [ProductRecord]
    
    func saveProductRecord(_ record: ProductRecord) async throws
    func deleteProductRecord(_ record: ProductRecord) async throws
    func getProductRecord(by id: UUID) async throws -> ProductRecord?
    func updateProductRecord(_ record: ProductRecord) async throws
    
    // MARK: - ComparisonHistory Operations
    func fetchComparisonHistory(
        limit: Int?,
        offset: Int?
    ) async throws -> [ComparisonHistory]
    
    func saveComparisonHistory(_ history: ComparisonHistory) async throws
    func deleteComparisonHistory(_ history: ComparisonHistory) async throws
    func cleanupOldComparisonHistory(keepCount: Int) async throws
    
    // MARK: - Category Operations
    func fetchCategories(includeSystem: Bool) async throws -> [Category]
    func saveCategory(_ category: Category) async throws
    func deleteCategory(_ category: Category) async throws
    func updateCategory(_ category: Category) async throws
    
    // MARK: - Statistics & Analytics
    func getProductStatistics() async throws -> ProductStatistics
    func getCategoryStatistics() async throws -> [CategoryStatistics]
    func getRecentProductsForComparison(limit: Int) async throws -> [ProductRecord]
    
    // MARK: - Data Management
    func exportAllData() async throws -> Data
    func importData(_ data: Data) async throws
    func deleteAllData() async throws
}
```

### 2.2 ソート・フィルター定義
```swift
enum ProductGroupSortOption {
    case nameAscending
    case nameDescending
    case lastRecordDateDescending
    case lowestPriceAscending
    case recordCountDescending
}

enum ProductRecordSortOption {
    case dateDescending
    case dateAscending
    case unitPriceAscending
    case unitPriceDescending
    case storeNameAscending
}

struct ProductStatistics {
    let totalProducts: Int
    let totalRecords: Int
    let averageUnitPrice: Decimal
    let mostFrequentCategory: Category?
    let recentlyAddedCount: Int
}

struct CategoryStatistics {
    let category: Category
    let productCount: Int
    let averageUnitPrice: Decimal
    let lowestUnitPrice: Decimal
    let lastUpdated: Date
}
```

## 3. Core Data Repository実装

### 3.1 メインRepository実装
```swift
class CoreDataProductRepository: ProductRepository {
    private let container: NSPersistentContainer
    private let backgroundContext: NSManagedObjectContext
    private let mainContext: NSManagedObjectContext
    
    init(container: NSPersistentContainer) {
        self.container = container
        self.mainContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        
        // コンテキスト設定
        backgroundContext.automaticallyMergesChangesFromParent = true
        mainContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - ProductGroup Operations
    
    func fetchProductGroups(
        category: Category? = nil,
        sortBy: ProductGroupSortOption = .lastRecordDateDescending,
        limit: Int? = nil,
        offset: Int? = nil
    ) async throws -> [ProductGroup] {
        return try await backgroundContext.perform {
            let request: NSFetchRequest<ProductGroup> = ProductGroup.fetchRequest()
            
            // フィルター設定
            var predicates: [NSPredicate] = []
            predicates.append(NSPredicate(format: "isDeleted == NO"))
            
            if let category = category {
                predicates.append(NSPredicate(format: "category == %@", category))
            }
            
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            
            // ソート設定
            request.sortDescriptors = self.getSortDescriptors(for: sortBy)
            
            // ページネーション
            if let limit = limit {
                request.fetchLimit = limit
                if let offset = offset {
                    request.fetchOffset = offset
                }
            }
            
            // パフォーマンス最適化
            request.fetchBatchSize = 20
            request.relationshipKeyPathsForPrefetching = ["category", "records"]
            
            return try self.backgroundContext.fetch(request)
        }
    }
    
    func searchProductGroups(
        query: String,
        category: Category? = nil,
        limit: Int? = 50
    ) async throws -> [ProductGroup] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        return try await backgroundContext.perform {
            let normalizedQuery = ProductGroup.normalizeProductName(query)
            let request: NSFetchRequest<ProductGroup> = ProductGroup.fetchRequest()
            
            var predicates: [NSPredicate] = []
            predicates.append(NSPredicate(format: "isDeleted == NO"))
            
            // 正規化名での検索（優先）
            let normalizedSearchPredicate = NSPredicate(
                format: "normalizedName CONTAINS %@",
                normalizedQuery
            )
            
            // 元の商品名での検索（フォールバック）
            let originalSearchPredicate = NSPredicate(
                format: "productName CONTAINS[cd] %@",
                query
            )
            
            predicates.append(NSCompoundPredicate(
                orPredicateWithSubpredicates: [normalizedSearchPredicate, originalSearchPredicate]
            ))
            
            if let category = category {
                predicates.append(NSPredicate(format: "category == %@", category))
            }
            
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \ProductGroup.lastRecordDate, ascending: false),
                NSSortDescriptor(keyPath: \ProductGroup.productName, ascending: true)
            ]
            
            if let limit = limit {
                request.fetchLimit = limit
            }
            
            return try self.backgroundContext.fetch(request)
        }
    }
    
    func saveProductGroup(_ group: ProductGroup) async throws {
        try await backgroundContext.perform {
            // 既存チェック
            if let existingGroup = try self.findExistingProductGroup(name: group.productName) {
                throw RepositoryError.duplicateProductGroup(group.productName)
            }
            
            self.backgroundContext.insert(group)
            group.updatedAt = Date()
            
            try self.backgroundContext.save()
        }
        
        // メインコンテキストに反映
        await MainActor.run {
            self.mainContext.refreshAllObjects()
        }
    }
    
    // MARK: - ProductRecord Operations
    
    func saveProductRecord(_ record: ProductRecord) async throws {
        try await backgroundContext.perform {
            self.backgroundContext.insert(record)
            record.updatedAt = Date()
            
            // 関連ProductGroupの統計情報更新
            if let productGroup = record.productGroup {
                productGroup.updateStatistics()
            }
            
            try self.backgroundContext.save()
        }
        
        await MainActor.run {
            self.mainContext.refreshAllObjects()
        }
    }
    
    func fetchProductRecords(
        for group: ProductGroup,
        sortBy: ProductRecordSortOption = .dateDescending,
        limit: Int? = nil
    ) async throws -> [ProductRecord] {
        return try await backgroundContext.perform {
            let request: NSFetchRequest<ProductRecord> = ProductRecord.fetchRequest()
            request.predicate = NSPredicate(
                format: "productGroup == %@ AND isDeleted == NO",
                group
            )
            request.sortDescriptors = self.getSortDescriptors(for: sortBy)
            
            if let limit = limit {
                request.fetchLimit = limit
            }
            
            return try self.backgroundContext.fetch(request)
        }
    }
    
    // MARK: - ComparisonHistory Operations
    
    func saveComparisonHistory(_ history: ComparisonHistory) async throws {
        try await backgroundContext.perform {
            self.backgroundContext.insert(history)
            try self.backgroundContext.save()
        }
    }
    
    func fetchComparisonHistory(
        limit: Int? = 30,
        offset: Int? = nil
    ) async throws -> [ComparisonHistory] {
        return try await backgroundContext.perform {
            let request: NSFetchRequest<ComparisonHistory> = ComparisonHistory.fetchRequest()
            request.predicate = NSPredicate(format: "isDeleted == NO")
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \ComparisonHistory.createdAt, ascending: false)
            ]
            
            if let limit = limit {
                request.fetchLimit = limit
                if let offset = offset {
                    request.fetchOffset = offset
                }
            }
            
            return try self.backgroundContext.fetch(request)
        }
    }
    
    func cleanupOldComparisonHistory(keepCount: Int = 100) async throws {
        try await backgroundContext.perform {
            let request: NSFetchRequest<ComparisonHistory> = ComparisonHistory.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \ComparisonHistory.createdAt, ascending: false)
            ]
            
            let allHistories = try self.backgroundContext.fetch(request)
            
            // 古い履歴を論理削除
            if allHistories.count > keepCount {
                let historiesToDelete = Array(allHistories.dropFirst(keepCount))
                for history in historiesToDelete {
                    history.isDeleted = true
                }
                
                try self.backgroundContext.save()
            }
        }
    }
    
    // MARK: - Statistics Operations
    
    func getProductStatistics() async throws -> ProductStatistics {
        return try await backgroundContext.perform {
            // 商品グループ数
            let groupRequest: NSFetchRequest<ProductGroup> = ProductGroup.fetchRequest()
            groupRequest.predicate = NSPredicate(format: "isDeleted == NO")
            let totalProducts = try self.backgroundContext.count(for: groupRequest)
            
            // 商品記録数
            let recordRequest: NSFetchRequest<ProductRecord> = ProductRecord.fetchRequest()
            recordRequest.predicate = NSPredicate(format: "isDeleted == NO")
            let totalRecords = try self.backgroundContext.count(for: recordRequest)
            
            // 平均単価計算
            let avgRequest: NSFetchRequest<NSFetchRequestResult> = ProductRecord.fetchRequest()
            avgRequest.predicate = NSPredicate(format: "isDeleted == NO")
            
            let avgExpression = NSExpression(forFunction: "average:", arguments: [
                NSExpression(forKeyPath: "unitPrice")
            ])
            let avgExpressionDescription = NSExpressionDescription()
            avgExpressionDescription.name = "averagePrice"
            avgExpressionDescription.expression = avgExpression
            avgExpressionDescription.expressionResultType = .decimalAttributeType
            
            avgRequest.propertiesToFetch = [avgExpressionDescription]
            avgRequest.resultType = .dictionaryResultType
            
            let avgResults = try self.backgroundContext.fetch(avgRequest)
            let averagePrice = (avgResults.first as? [String: Any])?["averagePrice"] as? Decimal ?? 0
            
            // 最頻出カテゴリ
            let categoryRequest: NSFetchRequest<NSFetchRequestResult> = ProductGroup.fetchRequest()
            categoryRequest.predicate = NSPredicate(format: "isDeleted == NO AND category != nil")
            categoryRequest.propertiesToFetch = ["category"]
            categoryRequest.resultType = .dictionaryResultType
            
            let categoryResults = try self.backgroundContext.fetch(categoryRequest)
            // カテゴリ集計ロジック...
            
            return ProductStatistics(
                totalProducts: totalProducts,
                totalRecords: totalRecords,
                averageUnitPrice: averagePrice,
                mostFrequentCategory: nil, // TODO: 実装
                recentlyAddedCount: 0 // TODO: 実装
            )
        }
    }
    
    func getRecentProductsForComparison(limit: Int = 10) async throws -> [ProductRecord] {
        return try await backgroundContext.perform {
            let request: NSFetchRequest<ProductRecord> = ProductRecord.fetchRequest()
            request.predicate = NSPredicate(format: "isDeleted == NO")
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
            ]
            request.fetchLimit = limit
            
            // 最低限の情報のみ取得（パフォーマンス最適化）
            request.propertiesToFetch = [
                "id", "productName", "finalPrice", "quantity", "unit",
                "storeName", "purchaseDate", "unitPrice"
            ]
            request.relationshipKeyPathsForPrefetching = ["productGroup"]
            
            return try self.backgroundContext.fetch(request)
        }
    }
}
```

### 3.2 ヘルパーメソッド
```swift
extension CoreDataProductRepository {
    private func getSortDescriptors(for option: ProductGroupSortOption) -> [NSSortDescriptor] {
        switch option {
        case .nameAscending:
            return [NSSortDescriptor(keyPath: \ProductGroup.productName, ascending: true)]
        case .nameDescending:
            return [NSSortDescriptor(keyPath: \ProductGroup.productName, ascending: false)]
        case .lastRecordDateDescending:
            return [
                NSSortDescriptor(keyPath: \ProductGroup.lastRecordDate, ascending: false),
                NSSortDescriptor(keyPath: \ProductGroup.productName, ascending: true)
            ]
        case .lowestPriceAscending:
            return [
                NSSortDescriptor(keyPath: \ProductGroup.lowestUnitPrice, ascending: true),
                NSSortDescriptor(keyPath: \ProductGroup.productName, ascending: true)
            ]
        case .recordCountDescending:
            return [
                NSSortDescriptor(keyPath: \ProductGroup.recordCount, ascending: false),
                NSSortDescriptor(keyPath: \ProductGroup.productName, ascending: true)
            ]
        }
    }
    
    private func getSortDescriptors(for option: ProductRecordSortOption) -> [NSSortDescriptor] {
        switch option {
        case .dateDescending:
            return [NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)]
        case .dateAscending:
            return [NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: true)]
        case .unitPriceAscending:
            return [
                NSSortDescriptor(keyPath: \ProductRecord.unitPrice, ascending: true),
                NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
            ]
        case .unitPriceDescending:
            return [
                NSSortDescriptor(keyPath: \ProductRecord.unitPrice, ascending: false),
                NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
            ]
        case .storeNameAscending:
            return [
                NSSortDescriptor(keyPath: \ProductRecord.storeName, ascending: true),
                NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
            ]
        }
    }
    
    private func findExistingProductGroup(name: String) throws -> ProductGroup? {
        let normalizedName = ProductGroup.normalizeProductName(name)
        let request: NSFetchRequest<ProductGroup> = ProductGroup.fetchRequest()
        request.predicate = NSPredicate(
            format: "normalizedName == %@ AND isDeleted == NO",
            normalizedName
        )
        request.fetchLimit = 1
        
        return try backgroundContext.fetch(request).first
    }
}
```

## 4. エラーハンドリング

### 4.1 Repository専用エラー
```swift
enum RepositoryError: LocalizedError {
    case entityNotFound(String)
    case duplicateProductGroup(String)
    case invalidData(String)
    case persistentStoreError(Error)
    case migrationRequired
    case quotaExceeded(String)
    
    var errorDescription: String? {
        switch self {
        case .entityNotFound(let entity):
            return "\(entity)が見つかりません"
        case .duplicateProductGroup(let name):
            return "商品「\(name)」は既に存在します"
        case .invalidData(let reason):
            return "データが無効です: \(reason)"
        case .persistentStoreError(let error):
            return "データベースエラー: \(error.localizedDescription)"
        case .migrationRequired:
            return "データベースの更新が必要です"
        case .quotaExceeded(let resource):
            return "容量制限を超えています: \(resource)"
        }
    }
}
```

### 4.2 エラー処理の実装
```swift
extension CoreDataProductRepository {
    private func handleCoreDataError(_ error: Error) throws {
        if let nsError = error as NSError? {
            switch nsError.code {
            case NSValidationErrorKey:
                throw RepositoryError.invalidData(nsError.localizedDescription)
            case NSMigrationMissingSourceModelError:
                throw RepositoryError.migrationRequired
            default:
                throw RepositoryError.persistentStoreError(error)
            }
        }
        throw error
    }
    
    private func validateProductRecord(_ record: ProductRecord) throws {
        guard !record.productName.isEmpty else {
            throw RepositoryError.invalidData("商品名が空です")
        }
        
        guard record.originalPrice > 0 else {
            throw RepositoryError.invalidData("価格は0より大きい値である必要があります")
        }
        
        guard record.quantity > 0 else {
            throw RepositoryError.invalidData("容量は0より大きい値である必要があります")
        }
    }
}
```

## 5. パフォーマンス最適化

### 5.1 クエリ最適化
```swift
extension CoreDataProductRepository {
    // バッチ処理での効率的な更新
    func batchUpdateProductGroupStatistics() async throws {
        try await backgroundContext.perform {
            let batchUpdateRequest = NSBatchUpdateRequest(entityName: "ProductGroup")
            batchUpdateRequest.predicate = NSPredicate(format: "isDeleted == NO")
            batchUpdateRequest.propertiesToUpdate = ["updatedAt": Date()]
            batchUpdateRequest.resultType = .updatedObjectIDsResultType
            
            let result = try self.backgroundContext.execute(batchUpdateRequest)
            
            // 更新されたオブジェクトをコンテキストにマージ
            if let updateResult = result as? NSBatchUpdateResult,
               let objectIDs = updateResult.result as? [NSManagedObjectID] {
                let changes = [NSUpdatedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: changes,
                    into: [self.mainContext]
                )
            }
        }
    }
    
    // メモリ効率的な大量データ処理
    func processLargeDataSet<T>(
        fetchRequest: NSFetchRequest<T>,
        batchSize: Int = 100,
        processor: (T) throws -> Void
    ) async throws {
        try await backgroundContext.perform {
            fetchRequest.fetchBatchSize = batchSize
            
            var offset = 0
            var hasMoreData = true
            
            while hasMoreData {
                fetchRequest.fetchOffset = offset
                fetchRequest.fetchLimit = batchSize
                
                let batch = try self.backgroundContext.fetch(fetchRequest)
                hasMoreData = batch.count == batchSize
                
                for item in batch {
                    try processor(item)
                }
                
                // メモリ解放
                self.backgroundContext.refreshAllObjects()
                offset += batchSize
            }
        }
    }
}
```

### 5.2 キャッシュ戦略
```swift
class CachedProductRepository: ProductRepository {
    private let coreDataRepository: CoreDataProductRepository
    private let cache = NSCache<NSString, AnyObject>()
    private let cacheQueue = DispatchQueue(label: "repository.cache", attributes: .concurrent)
    
    init(coreDataRepository: CoreDataProductRepository) {
        self.coreDataRepository = coreDataRepository
        setupCache()
    }
    
    private func setupCache() {
        cache.countLimit = 100 // 最大100オブジェクトをキャッシュ
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB制限
    }
    
    func fetchProductGroups(
        category: Category?,
        sortBy: ProductGroupSortOption,
        limit: Int?,
        offset: Int?
    ) async throws -> [ProductGroup] {
        let cacheKey = generateCacheKey(category: category, sortBy: sortBy, limit: limit, offset: offset)
        
        // キャッシュチェック
        if let cachedResult = getCachedResult(for: cacheKey) as? [ProductGroup] {
            return cachedResult
        }
        
        // データベースから取得
        let result = try await coreDataRepository.fetchProductGroups(
            category: category,
            sortBy: sortBy,
            limit: limit,
            offset: offset
        )
        
        // キャッシュに保存
        setCachedResult(result, for: cacheKey)
        
        return result
    }
    
    private func generateCacheKey(
        category: Category?,
        sortBy: ProductGroupSortOption,
        limit: Int?,
        offset: Int?
    ) -> String {
        return "productGroups_\(category?.id.uuidString ?? "nil")_\(sortBy)_\(limit ?? 0)_\(offset ?? 0)"
    }
    
    private func getCachedResult(for key: String) -> AnyObject? {
        return cacheQueue.sync {
            return cache.object(forKey: key as NSString)
        }
    }
    
    private func setCachedResult(_ result: AnyObject, for key: String) {
        cacheQueue.async(flags: .barrier) {
            self.cache.setObject(result, forKey: key as NSString)
        }
    }
    
    private func invalidateCache() {
        cacheQueue.async(flags: .barrier) {
            self.cache.removeAllObjects()
        }
    }
}
```

## 6. テスト対応

### 6.1 Mock Repository実装
```swift
class MockProductRepository: ProductRepository {
    private var productGroups: [ProductGroup] = []
    private var productRecords: [ProductRecord] = []
    private var comparisonHistories: [ComparisonHistory] = []
    private var categories: [Category] = []
    
    // テスト用の制御フラグ
    var shouldThrowError = false
    var delayDuration: TimeInterval = 0
    
    func fetchProductGroups(
        category: Category?,
        sortBy: ProductGroupSortOption,
        limit: Int?,
        offset: Int?
    ) async throws -> [ProductGroup] {
        if shouldThrowError {
            throw RepositoryError.entityNotFound("ProductGroup")
        }
        
        if delayDuration > 0 {
            try await Task.sleep(nanoseconds: UInt64(delayDuration * 1_000_000_000))
        }
        
        var filtered = productGroups
        
        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }
        
        // ソート適用
        filtered = applySorting(filtered, sortBy: sortBy)
        
        // ページネーション適用
        if let offset = offset {
            filtered = Array(filtered.dropFirst(offset))
        }
        if let limit = limit {
            filtered = Array(filtered.prefix(limit))
        }
        
        return filtered
    }
    
    func saveProductGroup(_ group: ProductGroup) async throws {
        if shouldThrowError {
            throw RepositoryError.duplicateProductGroup(group.productName)
        }
        
        productGroups.append(group)
    }
    
    // テスト用ヘルパーメソッド
    func addTestData() {
        let category = Category(name: "テストカテゴリ", icon: "🧪")
        categories.append(category)
        
        let group = ProductGroup(productName: "テスト商品", category: category)
        productGroups.append(group)
        
        let record = ProductRecord(
            productName: "テスト商品",
            originalPrice: 100,
            quantity: 1,
            unit: .kilogram
        )
        record.productGroup = group
        productRecords.append(record)
    }
    
    func clearTestData() {
        productGroups.removeAll()
        productRecords.removeAll()
        comparisonHistories.removeAll()
        categories.removeAll()
    }
    
    private func applySorting(_ groups: [ProductGroup], sortBy: ProductGroupSortOption) -> [ProductGroup] {
        switch sortBy {
        case .nameAscending:
            return groups.sorted { $0.productName < $1.productName }
        case .nameDescending:
            return groups.sorted { $0.productName > $1.productName }
        case .lastRecordDateDescending:
            return groups.sorted { ($0.lastRecordDate ?? Date.distantPast) > ($1.lastRecordDate ?? Date.distantPast) }
        case .lowestPriceAscending:
            return groups.sorted { $0.lowestUnitPrice < $1.lowestUnitPrice }
        case .recordCountDescending:
            return groups.sorted { $0.recordCount > $1.recordCount }
        }
    }
}
```

### 6.2 Repository テスト
```swift
class CoreDataProductRepositoryTests: XCTestCase {
    private var repository: CoreDataProductRepository!
    private var testContainer: NSPersistentContainer!
    
    override func setUp() {
        super.setUp()
        setupInMemoryDatabase()
    }
    
    override func tearDown() {
        repository = nil
        testContainer = nil
        super.tearDown()
    }
    
    private func setupInMemoryDatabase() {
        testContainer = NSPersistentContainer(name: "DataModel")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        testContainer.persistentStoreDescriptions = [description]
        
        testContainer.loadPersistentStores { _, error in
            XCTAssertNil(error)
        }
        
        repository = CoreDataProductRepository(container: testContainer)
    }
    
    func testFetchProductGroupsEmpty() async throws {
        let groups = try await repository.fetchProductGroups()
        XCTAssertEqual(groups.count, 0)
    }
    
    func testSaveAndFetchProductGroup() async throws {
        let category = Category(name: "テストカテゴリ", icon: "🧪")
        let group = ProductGroup(productName: "テスト商品", category: category)
        
        try await repository.saveProductGroup(group)
        
        let fetchedGroups = try await repository.fetchProductGroups()
        XCTAssertEqual(fetchedGroups.count, 1)
        XCTAssertEqual(fetchedGroups.first?.productName, "テスト商品")
    }
    
    func testSearchProductGroups() async throws {
        // テストデータ準備
        let groups = [
            ProductGroup(productName: "コカ・コーラ"),
            ProductGroup(productName: "ペプシコーラ"),
            ProductGroup(productName: "お茶")
        ]
        
        for group in groups {
            try await repository.saveProductGroup(group)
        }
        
        // 検索テスト
        let results = try await repository.searchProductGroups(query: "コーラ")
        XCTAssertEqual(results.count, 2)
        
        let names = results.map { $0.productName }
        XCTAssertTrue(names.contains("コカ・コーラ"))
        XCTAssertTrue(names.contains("ペプシコーラ"))
    }
    
    func testPerformance() {
        measure {
            Task {
                // 大量データでのパフォーマンステスト
                for i in 0..<1000 {
                    let group = ProductGroup(productName: "商品\(i)")
                    try await repository.saveProductGroup(group)
                }
                
                let groups = try await repository.fetchProductGroups(limit: 100)
                XCTAss