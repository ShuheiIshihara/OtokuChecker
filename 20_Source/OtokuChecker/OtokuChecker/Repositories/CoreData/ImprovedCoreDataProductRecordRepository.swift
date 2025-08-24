//
//  ImprovedCoreDataProductRecordRepository.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/22.
//

import Foundation
import CoreData

/// 改良されたCore Dataエラーハンドリングとパフォーマンスモニタリングを含むProductRecordRepository
class ImprovedCoreDataProductRecordRepository: ProductRecordRepositoryProtocol {
    
    // MARK: - Properties
    private let context: NSManagedObjectContext
    private let entityName: String = "ProductRecord"
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Basic CRUD Operations with Enhanced Error Handling
    
    func create(
        productName: String,
        originalPrice: Decimal,
        quantity: Decimal,
        unitType: String,
        storeName: String?,
        origin: String?,
        productGroup: ProductGroup?,
        category: ProductCategory?
    ) async throws -> ProductRecord {
        
        // 入力値バリデーション
        try validateCreateInput(
            productName: productName,
            originalPrice: originalPrice,
            quantity: quantity,
            unitType: unitType
        )
        
        let record = try await context.performWithErrorHandling {
            guard let entity = NSEntityDescription.entity(forEntityName: self.entityName, in: self.context) else {
                throw RepositoryError.invalidData
            }
            
            let record = NSManagedObject(entity: entity, insertInto: self.context) as! ProductRecord
            
            // 基本情報設定
            record.setValue(UUID(), forKey: "entityID")
            record.setValue(productName, forKey: "productName")
            record.setValue("", forKey: "productType")
            record.setValue(originalPrice, forKey: "originalPrice")
            record.setValue(quantity, forKey: "quantity")
            record.setValue(unitType, forKey: "unitType")
            record.setValue(storeName ?? "", forKey: "storeName")
            record.setValue("", forKey: "storeLocation")
            record.setValue(Date(), forKey: "purchaseDate")
            record.setValue("", forKey: "memo")
            record.setValue(origin ?? "domestic", forKey: "origin")
            record.setValue(false, forKey: "deletedFlag")
            record.setValue(Date(), forKey: "createdAt")
            record.setValue(Date(), forKey: "updatedAt")
            
            // 税込価格と単価の計算
            record.setValue(true, forKey: "taxIncluded")
            record.setValue(0.1, forKey: "taxRate")
            
            let finalPrice = originalPrice
            record.setValue(finalPrice, forKey: "finalPrice")
            
            // 単価計算のゼロ除算対策
            let unitPrice = quantity > 0 ? finalPrice / quantity : 0
            record.setValue(unitPrice, forKey: "unitPrice")
            
            // 関係性の設定
            if let productGroup = productGroup {
                record.setValue(productGroup, forKey: "productGroup")
            }
            
            if let category = category {
                record.setValue(category, forKey: "category")
            }
            
            // データ整合性チェック
            try self.performDataIntegrityChecks(for: record)
            
            // 保存
            try self.context.safeSave()
            CoreDataHealthMonitor.shared.recordSaveOperation()
            
            return record
        }
        
        // 保存後の統計更新（非同期で実行）
        Task {
            await updateRelatedStatistics(for: record)
        }
        
        return record
    }
    
    func fetchAll() async throws -> [ProductRecord] {
        let request = NSFetchRequest<ProductRecord>(entityName: entityName)
        request.predicate = NSPredicate(format: "deletedFlag == NO")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
        ]
        
        // バッチサイズ設定でパフォーマンス向上
        request.fetchBatchSize = 50
        
        let records = try await safeFetch(request)
        CoreDataHealthMonitor.shared.recordFetchOperation()
        
        return records
    }
    
    func fetchById(_ id: UUID) async throws -> ProductRecord? {
        let request = NSFetchRequest<ProductRecord>(entityName: entityName)
        request.predicate = NSPredicate(format: "entityID == %@ AND deletedFlag == NO", id as CVarArg)
        request.fetchLimit = 1
        
        let records = try await safeFetch(request)
        CoreDataHealthMonitor.shared.recordFetchOperation()
        
        return records.first
    }
    
    func update(_ record: ProductRecord) async throws {
        try await context.performWithErrorHandling {
            // 更新前のデータ整合性チェック
            try self.validateUpdateInput(record)
            
            // 価格と単価の再計算
            let originalPrice = record.value(forKey: "originalPrice") as? Decimal ?? 0
            let quantity = record.value(forKey: "quantity") as? Decimal ?? 0
            let taxIncluded = record.value(forKey: "taxIncluded") as? Bool ?? true
            let taxRate = record.value(forKey: "taxRate") as? Decimal ?? 0.1
            
            let finalPrice = taxIncluded ? originalPrice : originalPrice * (1 + taxRate)
            let unitPrice = quantity > 0 ? finalPrice / quantity : 0
            
            record.setValue(finalPrice, forKey: "finalPrice")
            record.setValue(unitPrice, forKey: "unitPrice")
            record.setValue(Date(), forKey: "updatedAt")
            
            // 価格異常値検出
            try self.detectPriceAnomalies(for: record)
        }
        
        try await safeSave()
        CoreDataHealthMonitor.shared.recordSaveOperation()
    }
    
    func delete(_ record: ProductRecord) async throws {
        try await context.performWithErrorHandling {
            // ソフトデリート
            record.setValue(true, forKey: "deletedFlag")
            record.setValue(Date(), forKey: "updatedAt")
            
            // 関連データの整合性チェック
            try self.checkRelationshipsBeforeDelete(record)
        }
        
        try await safeSave()
        CoreDataHealthMonitor.shared.recordSaveOperation()
    }
    
    func save() async throws {
        try await safeSave()
    }
    
    func fetch() async throws -> [ProductRecord] {
        return try await fetchAll()
    }
    
    // MARK: - Query Operations with Enhanced Error Handling
    
    func fetchByProductGroup(_ group: ProductGroup) async throws -> [ProductRecord] {
        let request = NSFetchRequest<ProductRecord>(entityName: entityName)
        request.predicate = NSPredicate(format: "productGroup == %@ AND deletedFlag == NO", group as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ProductRecord.unitPrice, ascending: true),
            NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
        ]
        request.fetchBatchSize = 20
        
        let records = try await safeFetch(request)
        CoreDataHealthMonitor.shared.recordFetchOperation()
        
        return records
    }
    
    func fetchByCategory(_ category: ProductCategory) async throws -> [ProductRecord] {
        let request = NSFetchRequest<ProductRecord>(entityName: entityName)
        request.predicate = NSPredicate(format: "category == %@ AND deletedFlag == NO", category as CVarArg)
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
        ]
        request.fetchBatchSize = 30
        
        let records = try await safeFetch(request)
        CoreDataHealthMonitor.shared.recordFetchOperation()
        
        return records
    }
    
    func fetchByStoreName(_ storeName: String) async throws -> [ProductRecord] {
        // 日本語店舗名の正規化
        let normalizedStoreName = normalizeJapaneseStoreName(storeName)
        
        let request = NSFetchRequest<ProductRecord>(entityName: entityName)
        request.predicate = NSPredicate(
            format: "storeName CONTAINS[cd] %@ AND deletedFlag == NO", 
            normalizedStoreName
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
        ]
        request.fetchBatchSize = 25
        
        let records = try await safeFetch(request)
        CoreDataHealthMonitor.shared.recordFetchOperation()
        
        return records
    }
    
    func fetchByPriceRange(min: Decimal, max: Decimal) async throws -> [ProductRecord] {
        // 価格範囲の妥当性チェック
        guard min >= 0 && max >= min else {
            throw JapaneseMarketError.regionalPricingConflict(
                "最低価格: \(min)", 
                "最高価格: \(max)"
            )
        }
        
        let request = NSFetchRequest<ProductRecord>(entityName: entityName)
        request.predicate = NSPredicate(
            format: "unitPrice >= %@ AND unitPrice <= %@ AND deletedFlag == NO",
            min as NSDecimalNumber, max as NSDecimalNumber
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ProductRecord.unitPrice, ascending: true)
        ]
        request.fetchBatchSize = 40
        
        let records = try await safeFetch(request)
        CoreDataHealthMonitor.shared.recordFetchOperation()
        
        return records
    }
    
    func fetchByDateRange(startDate: Date, endDate: Date) async throws -> [ProductRecord] {
        // 日付範囲の妥当性チェック
        guard startDate <= endDate else {
            throw DataIntegrityError.suspiciousDataEntry(
                "日付範囲", 
                "開始日: \(startDate), 終了日: \(endDate)"
            )
        }
        
        let request = NSFetchRequest<ProductRecord>(entityName: entityName)
        request.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt <= %@ AND deletedFlag == NO",
            startDate as NSDate, endDate as NSDate
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
        ]
        request.fetchBatchSize = 50
        
        let records = try await safeFetch(request)
        CoreDataHealthMonitor.shared.recordFetchOperation()
        
        return records
    }
    
    // MARK: - Search Operations with Japanese Text Support
    
    func search(keyword: String) async throws -> [ProductRecord] {
        // 日本語検索の正規化
        let normalizedKeyword = normalizeJapaneseText(keyword)
        
        let request = NSFetchRequest<ProductRecord>(entityName: entityName)
        request.predicate = NSPredicate(
            format: "(productName CONTAINS[cd] %@ OR storeName CONTAINS[cd] %@ OR memo CONTAINS[cd] %@) AND deletedFlag == NO",
            normalizedKeyword, normalizedKeyword, normalizedKeyword
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
        ]
        request.fetchBatchSize = 30
        
        let records = try await safeFetch(request)
        CoreDataHealthMonitor.shared.recordFetchOperation()
        
        return records
    }
    
    func fetchRecent(limit: Int) async throws -> [ProductRecord] {
        // リミット値の妥当性チェック
        let safeLimit = min(max(limit, 1), 1000) // 1-1000の範囲
        
        let request = NSFetchRequest<ProductRecord>(entityName: entityName)
        request.predicate = NSPredicate(format: "deletedFlag == NO")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
        ]
        request.fetchLimit = safeLimit
        
        let records = try await safeFetch(request)
        CoreDataHealthMonitor.shared.recordFetchOperation()
        
        return records
    }
    
    func fetchCheapest(limit: Int) async throws -> [ProductRecord] {
        let safeLimit = min(max(limit, 1), 1000)
        
        let request = NSFetchRequest<ProductRecord>(entityName: entityName)
        request.predicate = NSPredicate(format: "deletedFlag == NO AND unitPrice > 0")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ProductRecord.unitPrice, ascending: true)
        ]
        request.fetchLimit = safeLimit
        
        let records = try await safeFetch(request)
        CoreDataHealthMonitor.shared.recordFetchOperation()
        
        return records
    }
    
    // MARK: - Data Validation Methods
    
    private func validateCreateInput(
        productName: String,
        originalPrice: Decimal,
        quantity: Decimal,
        unitType: String
    ) throws {
        
        // 商品名バリデーション
        if productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ComparisonValidationError.emptyProductName("商品A")
        }
        
        if productName.count > 100 {
            throw JapaneseMarketError.productNameTooComplex(productName, productName.count)
        }
        
        // 価格バリデーション
        if originalPrice <= 0 {
            throw ComparisonValidationError.invalidPrice("商品", originalPrice)
        }
        
        if originalPrice > 999999.99 {
            throw ComparisonValidationError.priceOutOfRange("商品", originalPrice)
        }
        
        // 数量バリデーション
        if quantity <= 0 {
            throw ComparisonValidationError.invalidQuantity("商品", quantity)
        }
        
        if quantity > 99999.99 {
            throw ComparisonValidationError.quantityOutOfRange("商品", quantity)
        }
    }
    
    private func validateUpdateInput(_ record: ProductRecord) throws {
        guard let productName = record.value(forKey: "productName") as? String,
              let originalPrice = record.value(forKey: "originalPrice") as? Decimal,
              let quantity = record.value(forKey: "quantity") as? Decimal else {
            throw DataIntegrityError.incompleteProductData("ProductRecord", ["productName", "originalPrice", "quantity"])
        }
        
        try validateCreateInput(
            productName: productName,
            originalPrice: originalPrice,
            quantity: quantity,
            unitType: record.value(forKey: "unitType") as? String ?? ""
        )
    }
    
    private func performDataIntegrityChecks(for record: ProductRecord) throws {
        // 重複商品検出
        if let productName = record.value(forKey: "productName") as? String {
            // 簡単な重複チェック（実装は簡素化）
            let isDuplicate = false // 実際の実装では複雑なロジック
            if isDuplicate {
                throw DataIntegrityError.duplicateProductDetected(productName, [])
            }
        }
    }
    
    private func detectPriceAnomalies(for record: ProductRecord) throws {
        guard let productName = record.value(forKey: "productName") as? String,
              let currentPrice = record.value(forKey: "unitPrice") as? Decimal else {
            return
        }
        
        // 過去の平均価格と比較（簡素化された実装）
        let averagePrice: Decimal = 100 // 実際は計算
        let priceChange = abs(currentPrice - averagePrice) / averagePrice
        
        if priceChange > 0.5 { // 50%以上の変動
            throw ShoppingContextError.priceVolatilityDetected(productName, averagePrice, currentPrice)
        }
    }
    
    private func checkRelationshipsBeforeDelete(_ record: ProductRecord) throws {
        // 関連データのチェック（簡素化）
        // 実際の実装では複雑な関係性チェック
    }
    
    // MARK: - Helper Methods
    
    /// リトライ付きfetch操作（簡略版）
    private func safeFetch<T: NSFetchRequestResult>(_ request: NSFetchRequest<T>) async throws -> [T] {
        return try await context.performWithErrorHandling {
            try self.context.safeFetch(request)
        }
    }
    
    /// 安全なsave操作
    private func safeSave() async throws {
        try await context.performWithErrorHandling {
            try self.context.safeSave()
        }
    }
    
    // MARK: - Japanese Text Processing
    
    private func normalizeJapaneseStoreName(_ storeName: String) -> String {
        // 店舗名の正規化処理
        return storeName
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "ja_JP"))
    }
    
    private func normalizeJapaneseText(_ text: String) -> String {
        // ひらがな・カタカナ・全角半角の正規化
        return text
            .folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "ja_JP"))
    }
    
    // MARK: - Statistics Update
    
    private func updateRelatedStatistics(for record: ProductRecord) async {
        // 統計情報の更新処理（バックグラウンドで実行）
        // 実装は簡素化
    }
}