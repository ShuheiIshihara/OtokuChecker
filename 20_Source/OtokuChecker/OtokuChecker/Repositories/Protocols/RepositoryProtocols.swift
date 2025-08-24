//
//  RepositoryProtocols.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/20.
//

import Foundation
import CoreData

// MARK: - Base Repository Protocol

protocol BaseRepository {
    associatedtype Entity
    
    func save() async throws
    func fetch() async throws -> [Entity]
    func delete(_ entity: Entity) async throws
}

// MARK: - Product Category Repository Protocol

protocol ProductCategoryRepositoryProtocol: BaseRepository where Entity == ProductCategory {
    
    // MARK: - Basic CRUD
    func create(name: String, icon: String, colorHex: String?, sortOrder: Int?) async throws -> ProductCategory
    func fetchAll() async throws -> [ProductCategory]
    func fetchById(_ id: UUID) async throws -> ProductCategory?
    func update(_ category: ProductCategory) async throws
    func delete(_ category: ProductCategory) async throws
    
    // MARK: - Query Operations
    func fetchSystemCategories() async throws -> [ProductCategory]
    func fetchCustomCategories() async throws -> [ProductCategory]
    func fetchByName(_ name: String) async throws -> ProductCategory?
    func search(keyword: String) async throws -> [ProductCategory]
    
    // MARK: - Business Logic
    func createDefaultSystemCategories() async throws
    func updateStatistics(_ category: ProductCategory) async throws
}

// MARK: - Product Group Repository Protocol

protocol ProductGroupRepositoryProtocol: BaseRepository where Entity == ProductGroup {
    
    // MARK: - Basic CRUD
    func create(productName: String, productType: String?, category: ProductCategory?) async throws -> ProductGroup
    func fetchAll() async throws -> [ProductGroup]
    func fetchById(_ id: UUID) async throws -> ProductGroup?
    func update(_ group: ProductGroup) async throws
    func delete(_ group: ProductGroup) async throws
    
    // MARK: - Query Operations
    func fetchByCategory(_ category: ProductCategory) async throws -> [ProductGroup]
    func fetchByProductName(_ name: String) async throws -> ProductGroup?
    func search(keyword: String) async throws -> [ProductGroup]
    func searchByNormalizedName(_ normalizedName: String) async throws -> [ProductGroup]
    
    // MARK: - Statistics Operations
    func fetchTopGroups(limit: Int) async throws -> [ProductGroup]
    func fetchRecentGroups(limit: Int) async throws -> [ProductGroup]
    func updateStatistics(_ group: ProductGroup) async throws
}

// MARK: - Product Record Repository Protocol

protocol ProductRecordRepositoryProtocol: BaseRepository where Entity == ProductRecord {
    
    // MARK: - Basic CRUD
    func create(
        productName: String,
        originalPrice: Decimal,
        quantity: Decimal,
        unitType: String,
        storeName: String?,
        origin: String?,
        productGroup: ProductGroup?,
        category: ProductCategory?
    ) async throws -> ProductRecord
    func fetchAll() async throws -> [ProductRecord]
    func fetchById(_ id: UUID) async throws -> ProductRecord?
    func update(_ record: ProductRecord) async throws
    func delete(_ record: ProductRecord) async throws
    
    // MARK: - Query Operations
    func fetchByProductGroup(_ group: ProductGroup) async throws -> [ProductRecord]
    func fetchByCategory(_ category: ProductCategory) async throws -> [ProductRecord]
    func fetchByStoreName(_ storeName: String) async throws -> [ProductRecord]
    func fetchByPriceRange(min: Decimal, max: Decimal) async throws -> [ProductRecord]
    func fetchByDateRange(startDate: Date, endDate: Date) async throws -> [ProductRecord]
    
    // MARK: - Search Operations
    func search(keyword: String) async throws -> [ProductRecord]
    func fetchRecent(limit: Int) async throws -> [ProductRecord]
    func fetchCheapest(limit: Int) async throws -> [ProductRecord]
}

// MARK: - Comparison History Repository Protocol

protocol ComparisonHistoryRepositoryProtocol: BaseRepository where Entity == ComparisonHistory {
    
    // MARK: - Basic CRUD
    func create(
        comparisonType: String,
        productAName: String,
        productAPrice: Decimal,
        productAQuantity: Decimal,
        productAUnitType: String,
        productBName: String,
        productBPrice: Decimal,
        productBQuantity: Decimal,
        productBUnitType: String,
        winnerProduct: String
    ) async throws -> ComparisonHistory
    func fetchAll() async throws -> [ComparisonHistory]
    func fetchById(_ id: UUID) async throws -> ComparisonHistory?
    func delete(_ history: ComparisonHistory) async throws
    
    // MARK: - Query Operations
    func fetchByType(_ type: String) async throws -> [ComparisonHistory]
    func fetchRecent(limit: Int) async throws -> [ComparisonHistory]
    func fetchByDateRange(startDate: Date, endDate: Date) async throws -> [ComparisonHistory]
    func search(productName: String) async throws -> [ComparisonHistory]
    
    // MARK: - Statistics Operations
    func fetchMostComparedProducts(limit: Int) async throws -> [(productName: String, count: Int)]
    func fetchComparisonStats() async throws -> (totalComparisons: Int, averageSavings: Decimal)
}

// MARK: - Repository Error Types

enum RepositoryError: LocalizedError {
    case entityNotFound
    case invalidData
    case saveFailed
    case deleteFailed
    case coreDataError(Error)
    
    var errorDescription: String? {
        switch self {
        case .entityNotFound:
            return "エンティティが見つかりません"
        case .invalidData:
            return "無効なデータです"
        case .saveFailed:
            return "保存に失敗しました"
        case .deleteFailed:
            return "削除に失敗しました"
        case .coreDataError(let error):
            return "Core Dataエラー: \(error.localizedDescription)"
        }
    }
}