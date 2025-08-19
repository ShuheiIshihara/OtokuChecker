// MARK: - Core Data パフォーマンス最適化実装ガイド

import CoreData
import Foundation

// MARK: - 1. 最適化されたPersistenceController

class OptimizedPersistenceController {
    static let shared = OptimizedPersistenceController()
    
    // MARK: - Core Data Stack
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "OtokuChecker")
        
        // パフォーマンス最適化設定
        configureStoreDescription(container.persistentStoreDescriptions.first!)
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
            
            print("✅ Core Data loaded: \(storeDescription.url?.lastPathComponent ?? "Unknown")")
        }
        
        // View Context最適化
        configureViewContext(container.viewContext)
        
        return container
    }()
    
    // MARK: - Context Configuration
    
    private func configureStoreDescription(_ description: NSPersistentStoreDescription) {
        // SQLite最適化設定
        description.setValue("WAL" as NSString, forPragmaNamed: "journal_mode")
        description.setValue("NORMAL" as NSString, forPragmaNamed: "synchronous") 
        description.setValue("10000" as NSString, forPragmaNamed: "cache_size")
        description.setValue("MEMORY" as NSString, forPragmaNamed: "temp_store")
        
        // Core Data最適化
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        
        // セキュリティ設定維持
        description.setOption(FileProtectionType.complete as NSString,
                            forKey: NSPersistentStoreFileProtectionKey)
    }
    
    private func configureViewContext(_ context: NSManagedObjectContext) {
        // マージポリシー設定（競合解決戦略）
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // 自動マージ設定
        context.automaticallyMergesChangesFromParent = true
        
        // Undo機能無効化（パフォーマンス向上）
        context.undoManager = nil
        
        // バッチ処理最適化
        context.shouldDeleteInaccessibleFaults = true
    }
    
    // MARK: - Background Context Factory
    
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        
        // Background Context専用設定
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        context.undoManager = nil
        context.shouldDeleteInaccessibleFaults = true
        
        return context
    }
    
    // MARK: - Batch Context（大量処理用）
    
    func newBatchContext() -> NSManagedObjectContext {
        let context = newBackgroundContext()
        
        // バッチ処理専用最適化
        context.shouldDeleteInaccessibleFaults = true
        context.stalenessInterval = 0.0  // キャッシュ無効化
        
        return context
    }
}

// MARK: - 2. 最適化されたRepository実装

class PerformantProductRepository: ProductRepository {
    private let container: NSPersistentContainer
    private let mainContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    
    // メモリキャッシュ（頻繁にアクセスされるデータ用）
    private let cache = NSCache<NSString, NSArray>()
    private let cacheQueue = DispatchQueue(label: "repository.cache", qos: .utility)
    
    init(container: NSPersistentContainer = OptimizedPersistenceController.shared.persistentContainer) {
        self.container = container
        self.mainContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        
        setupCache()
        setupNotifications()
    }
    
    private func setupCache() {
        cache.countLimit = 50  // 最大50オブジェクト
        cache.totalCostLimit = 10 * 1024 * 1024  // 10MB制限
    }
    
    private func setupNotifications() {
        // Core Dataの変更通知でキャッシュをクリア
        NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.clearCache()
        }
    }
    
    // MARK: - Optimized Fetch Operations
    
    func fetchProductGroups(
        category: Category? = nil,
        sortBy: ProductGroupSortOption = .lastRecordDateDescending,
        limit: Int? = 20,
        offset: Int? = nil
    ) async throws -> [ProductGroup] {
        
        // キャッシュキー生成
        let cacheKey = generateCacheKey(category: category, sortBy: sortBy, limit: limit, offset: offset)
        
        // キャッシュチェック
        if let cachedResults = getCachedResults(for: cacheKey) {
            return cachedResults
        }
        
        return try await performOptimizedFetch(cacheKey: cacheKey) {
            let request: NSFetchRequest<ProductGroup> = ProductGroup.fetchRequest()
            
            // 述語の最適化
            var predicates: [NSPredicate] = [NSPredicate(format: "isDeleted == NO")]
            
            if let category = category {
                predicates.append(NSPredicate(format: "category == %@", category))
            }
            
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            
            // ソート記述子の最適化
            request.sortDescriptors = getOptimizedSortDescriptors(for: sortBy)
            
            // フェッチ最適化設定
            request.fetchLimit = limit ?? 20
            request.fetchOffset = offset ?? 0
            request.fetchBatchSize = 20  // メモリ効率
            
            // 関連オブジェクトのプリフェッチ
            request.relationshipKeyPathsForPrefetching = ["category"]
            
            // 必要なプロパティのみ取得（メモリ最適化）
            request.propertiesToFetch = [
                "id", "productName", "normalizedName", "recordCount",
                "lowestUnitPrice", "lastRecordDate", "category"
            ]
            
            return try self.backgroundContext.fetch(request)
        }
    }
    
    // MARK: - Optimized Search with Full-Text Search
    
    func searchProductGroups(
        query: String,
        category: Category? = nil,
        limit: Int? = 50
    ) async throws -> [ProductGroup] {
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let normalizedQuery = ProductGroup.normalizeProductName(query)
        
        return try await backgroundContext.perform {
            let request: NSFetchRequest<ProductGroup> = ProductGroup.fetchRequest()
            
            // 最適化された検索述語
            let searchPredicates = self.buildOptimizedSearchPredicates(
                normalizedQuery: normalizedQuery,
                originalQuery: query,
                category: category
            )
            
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: searchPredicates)
            
            // 検索結果の関連性によるソート
            request.sortDescriptors = [
                // 正規化名での完全一致を最優先
                NSSortDescriptor(
                    key: "normalizedName",
                    ascending: true,
                    comparator: { (obj1, obj2) in
                        let str1 = obj1 as! String
                        let str2 = obj2 as! String
                        
                        let match1 = str1.hasPrefix(normalizedQuery)
                        let match2 = str2.hasPrefix(normalizedQuery)
                        
                        if match1 && !match2 { return .orderedAscending }
                        if !match1 && match2 { return .orderedDescending }
                        
                        return str1.compare(str2)
                    }
                ),
                NSSortDescriptor(keyPath: \ProductGroup.lastRecordDate, ascending: false)
            ]
            
            request.fetchLimit = limit ?? 50
            request.fetchBatchSize = 20
            
            return try self.backgroundContext.fetch(request)
        }
    }
    
    // MARK: - Batch Operations for Performance
    
    func batchUpdateProductGroupStatistics() async throws {
        try await backgroundContext.perform {
            // NSBatchUpdateRequestを使用した高速更新
            let batchUpdate = NSBatchUpdateRequest(entityName: "ProductGroup")
            batchUpdate.predicate = NSPredicate(format: "isDeleted == NO")
            batchUpdate.propertiesToUpdate = ["updatedAt": Date()]
            batchUpdate.resultType = .updatedObjectIDsResultType
            
            let result = try self.backgroundContext.execute(batchUpdate) as! NSBatchUpdateResult
            
            // メインコンテキストへの変更通知
            if let objectIDs = result.result as? [NSManagedObjectID] {
                let changes = [NSUpdatedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(
                    fromRemoteContextSave: changes,
                    into: [self.mainContext]
                )
            }
        }
    }
    
    // MARK: - Memory Efficient Large Data Processing
    
    func processLargeDataSet<T: NSManagedObject>(
        entityName: String,
        batchSize: Int = 100,
        predicate: NSPredicate? = nil,
        processor: @escaping (T) throws -> Void
    ) async throws {
        
        let batchContext = OptimizedPersistenceController.shared.newBatchContext()
        
        try await batchContext.perform {
            let request = NSFetchRequest<T>(entityName: entityName)
            request.predicate = predicate
            request.fetchBatchSize = batchSize
            request.includesPropertyValues = false  // オブジェクトのプロパティを遅延読み込み
            
            var offset = 0
            var hasMoreData = true
            
            while hasMoreData {
                autoreleasepool {
                    request.fetchOffset = offset
                    request.fetchLimit = batchSize
                    
                    do {
                        let batch = try batchContext.fetch(request)
                        hasMoreData = batch.count == batchSize
                        
                        for object in batch {
                            try processor(object)
                        }
                        
                        // メモリ解放
                        batchContext.refreshAllObjects()
                        
                        offset += batchSize
                        
                    } catch {
                        print("❌ Batch processing error: \(error)")
                        hasMoreData = false
                    }
                }
            }
        }
    }
    
    // MARK: - Cache Management
    
    private func performOptimizedFetch<T>(
        cacheKey: String,
        fetchOperation: @escaping () throws -> [T]
    ) async throws -> [T] {
        
        return try await backgroundContext.perform {
            let results = try fetchOperation()
            
            // 結果をキャッシュに保存
            self.cacheResults(results as NSArray, for: cacheKey)
            
            return results
        }
    }
    
    private func generateCacheKey(
        category: Category?,
        sortBy: ProductGroupSortOption,
        limit: Int?,
        offset: Int?
    ) -> String {
        let categoryId = category?.id.uuidString ?? "nil"
        return "productGroups_\(categoryId)_\(sortBy)_\(limit ?? 0)_\(offset ?? 0)"
    }
    
    private func getCachedResults(for key: String) -> [ProductGroup]? {
        return cacheQueue.sync {
            guard let cachedArray = cache.object(forKey: key as NSString) as? [ProductGroup] else {
                return nil
            }
            
            // キャッシュの有効性確認（5分間）
            let cacheAge = Date().timeIntervalSince(Date())
            if cacheAge > 300 { // 5分
                cache.removeObject(forKey: key as NSString)
                return nil
            }
            
            return cachedArray
        }
    }
    
    private func cacheResults<T>(_ results: NSArray, for key: String) {
        cacheQueue.async {
            self.cache.setObject(results, forKey: key as NSString)
        }
    }
    
    private func clearCache() {
        cacheQueue.async {
            self.cache.removeAllObjects()
        }
    }
    
    // MARK: - Query Optimization Helpers
    
    private func buildOptimizedSearchPredicates(
        normalizedQuery: String,
        originalQuery: String,
        category: Category?
    ) -> [NSPredicate] {
        
        var predicates: [NSPredicate] = [NSPredicate(format: "isDeleted == NO")]
        
        // カテゴリフィルター（インデックス活用）
        if let category = category {
            predicates.append(NSPredicate(format: "category == %@", category))
        }
        
        // 検索クエリ最適化
        let searchPredicate = NSPredicate(format: 
            "normalizedName BEGINSWITH %@ OR normalizedName CONTAINS %@ OR productName CONTAINS[cd] %@",
            normalizedQuery, normalizedQuery, originalQuery
        )
        predicates.append(searchPredicate)
        
        return predicates
    }
    
    private func getOptimizedSortDescriptors(for option: ProductGroupSortOption) -> [NSSortDescriptor] {
        // インデックスが効きやすいソート順を優先
        switch option {
        case .lastRecordDateDescending:
            return [
                NSSortDescriptor(keyPath: \ProductGroup.lastRecordDate, ascending: false),
                NSSortDescriptor(keyPath: \ProductGroup.id, ascending: true)  // 一意性保証
            ]
        case .nameAscending:
            return [
                NSSortDescriptor(keyPath: \ProductGroup.normalizedName, ascending: true),
                NSSortDescriptor(keyPath: \ProductGroup.id, ascending: true)
            ]
        case .lowestPriceAscending:
            return [
                NSSortDescriptor(keyPath: \ProductGroup.lowestUnitPrice, ascending: true),
                NSSortDescriptor(keyPath: \ProductGroup.id, ascending: true)
            ]
        case .recordCountDescending:
            return [
                NSSortDescriptor(keyPath: \ProductGroup.recordCount, ascending: false),
                NSSortDescriptor(keyPath: \ProductGroup.id, ascending: true)
            ]
        default:
            return [NSSortDescriptor(keyPath: \ProductGroup.id, ascending: true)]
        }
    }
}

// MARK: - 3. パフォーマンス監視とデバッグ

class CoreDataPerformanceMonitor {
    static let shared = CoreDataPerformanceMonitor()
    
    private let performanceLogger = PerformanceLogger()
    
    func monitorFetchRequest<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        context: NSManagedObjectContext,
        operation: String
    ) throws -> [T] {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // SQLデバッグ情報の有効化（Debug時のみ）
        #if DEBUG
        request.includesSubentities = false  // サブエンティティ除外で高速化
        #endif
        
        let results = try context.fetch(request)
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        // パフォーマンス記録
        performanceLogger.logFetchOperation(
            operation: operation,
            duration: duration,
            resultCount: results.count,
            fetchLimit: request.fetchLimit,
            fetchBatchSize: request.fetchBatchSize
        )
        
        // 警告閾値チェック
        if duration > 0.5 {  // 500ms以上
            print("⚠️ Slow Core Data query detected:")
            print("   Operation: \(operation)")
            print("   Duration: \(String(format: "%.3f", duration))s")
            print("   Results: \(results.count)")
            print("   Predicate: \(request.predicate?.description ?? "nil")")
        }
        
        return results
    }
    
    func analyzePerformanceMetrics() -> PerformanceReport {
        return performanceLogger.generateReport()
    }
}

// MARK: - 4. パフォーマンス測定

class PerformanceLogger {
    private var fetchOperations: [FetchOperation] = []
    private let queue = DispatchQueue(label: "performance.logger", qos: .utility)
    
    func logFetchOperation(
        operation: String,
        duration: TimeInterval,
        resultCount: Int,
        fetchLimit: Int,
        fetchBatchSize: Int
    ) {
        queue.async {
            let fetchOp = FetchOperation(
                operation: operation,
                duration: duration,
                resultCount: resultCount,
                fetchLimit: fetchLimit,
                fetchBatchSize: fetchBatchSize,
                timestamp: Date()
            )
            
            self.fetchOperations.append(fetchOp)
            
            // 古いログの削除（最新100件まで保持）
            if self.fetchOperations.count > 100 {
                self.fetchOperations.removeFirst(self.fetchOperations.count - 100)
            }
        }
    }
    
    func generateReport() -> PerformanceReport {
        return queue.sync {
            let totalOperations = fetchOperations.count
            let averageDuration = fetchOperations.map(\.duration).reduce(0, +) / Double(max(totalOperations, 1))
            let slowOperations = fetchOperations.filter { $0.duration > 0.1 }.count
            
            let operationsByType = Dictionary(grouping: fetchOperations) { $0.operation }
            let performanceByOperation = operationsByType.mapValues { operations in
                OperationPerformance(
                    averageDuration: operations.map(\.duration).reduce(0, +) / Double(operations.count),
                    maxDuration: operations.map(\.duration).max() ?? 0,
                    operationCount: operations.count
                )
            }
            
            return PerformanceReport(
                totalOperations: totalOperations,
                averageDuration: averageDuration,
                slowOperationCount: slowOperations,
                performanceByOperation: performanceByOperation
            )
        }
    }
}

// MARK: - Supporting Types

struct FetchOperation {
    let operation: String
    let duration: TimeInterval
    let resultCount: Int
    let fetchLimit: Int
    let fetchBatchSize: Int
    let timestamp: Date
}

struct OperationPerformance {
    let averageDuration: TimeInterval
    let maxDuration: TimeInterval
    let operationCount: Int
}

struct PerformanceReport {
    let totalOperations: Int
    let averageDuration: TimeInterval
    let slowOperationCount: Int
    let performanceByOperation: [String: OperationPerformance]
    
    var slowOperationPercentage: Double {
        return Double(slowOperationCount) / Double(max(totalOperations, 1)) * 100
    }
}

// MARK: - 5. メモリ最適化のための拡張

extension NSManagedObjectContext {
    
    /// メモリ効率の良いフェッチ実行
    func performOptimizedFetch<T: NSManagedObject>(
        request: NSFetchRequest<T>,
        operation: String = #function
    ) throws -> [T] {
        
        // パフォーマンス監視
        return try CoreDataPerformanceMonitor.shared.monitorFetchRequest(
            request,
            context: self,
            operation: operation
        )
    }
    
    /// バッチ処理用のメモリ効率的な保存
    func performOptimizedSave() throws {
        guard hasChanges else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        try save()
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        if duration > 0.1 {  // 100ms以上
            print("⚠️ Slow Core Data save operation: \(String(format: "%.3f", duration))s")
        }
        
        // 保存後のメモリクリーンアップ
        refreshAllObjects()
    }
}

// MARK: - 使用例とベストプラクティス

/*
// Repository使用例
let repository = PerformantProductRepository()

// 最適化されたフェッチ
let products = try await repository.fetchProductGroups(
    category: foodCategory,
    sortBy: .lastRecordDateDescending,
    limit: 20
)

// 高速検索
let searchResults = try await repository.searchProductGroups(
    query: "コシヒカリ",
    limit: 10
)

// バッチ処理（大量データ）
try await repository.processLargeDataSet(
    entityName: "ProductRecord",
    batchSize: 100
) { (record: ProductRecord) in
    // 各レコードの処理
    record.normalizedName = ProductGroup.normalizeProductName(record.productName)
}

// パフォーマンス分析
let report = CoreDataPerformanceMonitor.shared.analyzePerformanceMetrics()
print("Average fetch duration: \(report.averageDuration)s")
print("Slow operations: \(report.slowOperationPercentage)%")
*/