//
//  CoreDataProductCategoryRepository.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/20.
//

import Foundation
import CoreData

class CoreDataProductCategoryRepository: ProductCategoryRepositoryProtocol {
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Basic CRUD Operations
    
    func create(name: String, icon: String, colorHex: String?, sortOrder: Int?) async throws -> ProductCategory {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let category = ProductCategory(context: self.context)
                    
                    category.entityID = UUID()
                    category.name = name
                    category.icon = icon
                    category.colorHex = colorHex ?? "#007AFF"
                    category.sortOrder = Int32(sortOrder ?? 0)
                    category.productCount = 0
                    category.averageUnitPrice = NSDecimalNumber(value: 0)
                    category.deletedFlag = false
                    category.isSystemCategory = false
                    category.createdAt = Date()
                    category.updatedAt = Date()
                    
                    try self.context.save()
                    continuation.resume(returning: category)
                } catch {
                    continuation.resume(throwing: RepositoryError.saveFailed)
                }
            }
        }
    }
    
    func fetchAll() async throws -> [ProductCategory] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductCategory>(entityName: "ProductCategory")
                    request.predicate = NSPredicate(format: "deletedFlag == NO")
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductCategory.sortOrder, ascending: true),
                        NSSortDescriptor(keyPath: \ProductCategory.name, ascending: true)
                    ]
                    
                    let categories = try self.context.fetch(request)
                    continuation.resume(returning: categories)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchById(_ id: UUID) async throws -> ProductCategory? {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductCategory>(entityName: "ProductCategory")
                    request.predicate = NSPredicate(format: "entityID == %@ AND deletedFlag == NO", id as CVarArg)
                    request.fetchLimit = 1
                    
                    let categories = try self.context.fetch(request)
                    continuation.resume(returning: categories.first)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func update(_ category: ProductCategory) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    category.updatedAt = Date()
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: RepositoryError.saveFailed)
                }
            }
        }
    }
    
    func delete(_ entity: ProductCategory) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // ソフトデリート
                    entity.deletedFlag = true
                    entity.updatedAt = Date()
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: RepositoryError.deleteFailed)
                }
            }
        }
    }
    
    func save() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: RepositoryError.saveFailed)
                }
            }
        }
    }
    
    func fetch() async throws -> [ProductCategory] {
        return try await fetchAll()
    }
    
    // MARK: - Query Operations
    
    func fetchSystemCategories() async throws -> [ProductCategory] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductCategory>(entityName: "ProductCategory")
                    request.predicate = NSPredicate(format: "isSystemCategory == YES AND deletedFlag == NO")
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductCategory.sortOrder, ascending: true)
                    ]
                    
                    let categories = try self.context.fetch(request)
                    continuation.resume(returning: categories)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchCustomCategories() async throws -> [ProductCategory] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductCategory>(entityName: "ProductCategory")
                    request.predicate = NSPredicate(format: "isSystemCategory == NO AND deletedFlag == NO")
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductCategory.name, ascending: true)
                    ]
                    
                    let categories = try self.context.fetch(request)
                    continuation.resume(returning: categories)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchByName(_ name: String) async throws -> ProductCategory? {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductCategory>(entityName: "ProductCategory")
                    request.predicate = NSPredicate(format: "name == %@ AND deletedFlag == NO", name)
                    request.fetchLimit = 1
                    
                    let categories = try self.context.fetch(request)
                    continuation.resume(returning: categories.first)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func search(keyword: String) async throws -> [ProductCategory] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductCategory>(entityName: "ProductCategory")
                    request.predicate = NSPredicate(format: "name CONTAINS[cd] %@ AND deletedFlag == NO", keyword)
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductCategory.productCount, ascending: false),
                        NSSortDescriptor(keyPath: \ProductCategory.name, ascending: true)
                    ]
                    
                    let categories = try self.context.fetch(request)
                    continuation.resume(returning: categories)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    // MARK: - Business Logic Operations
    
    func createDefaultSystemCategories() async throws {
        let defaultCategories = [
            ("全て", "📁", "#007AFF", 0),
            ("食料品", "🍎", "#FF9500", 1),
            ("日用品", "🧴", "#34C759", 2),
            ("その他", "📦", "#8E8E93", 99)
        ]
        
        for (name, icon, color, sortOrder) in defaultCategories {
            // 既存チェック
            if let _ = try await fetchByName(name) {
                continue // 既に存在する場合はスキップ
            }
            
            let category = try await create(name: name, icon: icon, colorHex: color, sortOrder: sortOrder)
            category.isSystemCategory = true
            try await save()
        }
    }
    
    func updateStatistics(_ category: ProductCategory) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // 関連するProductGroupsを取得
                    let request = NSFetchRequest<ProductGroup>(entityName: "ProductGroup")
                    request.predicate = NSPredicate(format: "category == %@ AND deletedFlag == NO", category)
                    
                    let productGroups = try self.context.fetch(request)
                    
                    // 統計情報を計算
                    let productCount = productGroups.count
                    let averagePrice = productGroups.isEmpty ? 0 : 
                        productGroups.compactMap { $0.averageUnitPrice?.decimalValue }
                            .reduce(0, +) / Decimal(productGroups.count)
                    
                    // 統計情報を更新
                    category.productCount = Int32(productCount)
                    category.averageUnitPrice = NSDecimalNumber(decimal: averagePrice)
                    category.lastUpdated = Date()
                    category.updatedAt = Date()
                    
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: RepositoryError.saveFailed)
                }
            }
        }
    }
}

// MARK: - Convenience Extensions

extension CoreDataProductCategoryRepository {
    
    /// デフォルトのシステムカテゴリを取得（なければ作成）
    func getOrCreateDefaultCategory() async throws -> ProductCategory {
        if let defaultCategory = try await fetchByName("その他") {
            return defaultCategory
        } else {
            return try await create(name: "その他", icon: "📦", colorHex: "#8E8E93", sortOrder: 99)
        }
    }
    
    /// カテゴリの商品数を更新
    func incrementProductCount(_ category: ProductCategory) async throws {
        let currentCount = category.productCount
        category.productCount = currentCount + 1
        try await update(category)
    }
    
    /// カテゴリの商品数を減算
    func decrementProductCount(_ category: ProductCategory) async throws {
        let currentCount = category.productCount
        let newCount = max(0, currentCount - 1)
        category.productCount = newCount
        try await update(category)
    }
}