//
//  CoreDataProductGroupRepository.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/20.
//

import Foundation
import CoreData

class CoreDataProductGroupRepository: ProductGroupRepositoryProtocol {
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Basic CRUD Operations
    
    func create(productName: String, productType: String?, category: ProductCategory?) async throws -> ProductGroup {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let groupEntity = NSEntityDescription.entity(forEntityName: "ProductGroup", in: self.context)!
                    let group = NSManagedObject(entity: groupEntity, insertInto: self.context) as! ProductGroup
                    
                    let normalizedName = self.normalizeProductName(productName)
                    
                    group.setValue(UUID(), forKey: "entityID")
                    group.setValue(productName, forKey: "productName")
                    group.setValue(normalizedName, forKey: "normalizedName")
                    group.setValue(productType, forKey: "productType")
                    group.setValue(0, forKey: "recordCount")
                    group.setValue(0, forKey: "averageUnitPrice")
                    group.setValue(0, forKey: "lowestUnitPrice")
                    group.setValue("", forKey: "lowestPriceStoreName")
                    group.setValue(nil, forKey: "lastRecordDate")
                    group.setValue(false, forKey: "deletedFlag")
                    group.setValue(Date(), forKey: "createdAt")
                    group.setValue(Date(), forKey: "updatedAt")
                    
                    // カテゴリ関連付け
                    if let category = category {
                        group.setValue(category, forKey: "category")
                    }
                    
                    try self.context.save()
                    continuation.resume(returning: group)
                } catch {
                    continuation.resume(throwing: RepositoryError.saveFailed)
                }
            }
        }
    }
    
    func fetchAll() async throws -> [ProductGroup] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductGroup>(entityName: "ProductGroup")
                    request.predicate = NSPredicate(format: "deletedFlag == NO")
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductGroup.lastRecordDate, ascending: false),
                        NSSortDescriptor(keyPath: \ProductGroup.productName, ascending: true)
                    ]
                    
                    let groups = try self.context.fetch(request)
                    continuation.resume(returning: groups)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchById(_ id: UUID) async throws -> ProductGroup? {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductGroup>(entityName: "ProductGroup")
                    request.predicate = NSPredicate(format: "entityID == %@ AND deletedFlag == NO", id as CVarArg)
                    request.fetchLimit = 1
                    
                    let groups = try self.context.fetch(request)
                    continuation.resume(returning: groups.first)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func update(_ group: ProductGroup) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    group.setValue(Date(), forKey: "updatedAt")
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: RepositoryError.saveFailed)
                }
            }
        }
    }
    
    func delete(_ group: ProductGroup) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // ソフトデリート
                    group.setValue(true, forKey: "deletedFlag")
                    group.setValue(Date(), forKey: "updatedAt")
                    
                    // 関連するProductRecordもソフトデリート
                    if let records = group.value(forKey: "records") as? Set<ProductRecord> {
                        for record in records {
                            record.setValue(true, forKey: "deletedFlag")
                            record.setValue(Date(), forKey: "updatedAt")
                        }
                    }
                    
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
    
    func fetch() async throws -> [ProductGroup] {
        return try await fetchAll()
    }
    
    // MARK: - Query Operations
    
    func fetchByCategory(_ category: ProductCategory) async throws -> [ProductGroup] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductGroup>(entityName: "ProductGroup")
                    request.predicate = NSPredicate(format: "category == %@ AND deletedFlag == NO", category)
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductGroup.recordCount, ascending: false),
                        NSSortDescriptor(keyPath: \ProductGroup.productName, ascending: true)
                    ]
                    
                    let groups = try self.context.fetch(request)
                    continuation.resume(returning: groups)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchByProductName(_ name: String) async throws -> ProductGroup? {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductGroup>(entityName: "ProductGroup")
                    request.predicate = NSPredicate(format: "productName == %@ AND deletedFlag == NO", name)
                    request.fetchLimit = 1
                    
                    let groups = try self.context.fetch(request)
                    continuation.resume(returning: groups.first)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func search(keyword: String) async throws -> [ProductGroup] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductGroup>(entityName: "ProductGroup")
                    request.predicate = NSPredicate(
                        format: "(productName CONTAINS[cd] %@ OR normalizedName CONTAINS[cd] %@) AND deletedFlag == NO",
                        keyword, keyword
                    )
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductGroup.recordCount, ascending: false),
                        NSSortDescriptor(keyPath: \ProductGroup.lastRecordDate, ascending: false)
                    ]
                    
                    let groups = try self.context.fetch(request)
                    continuation.resume(returning: groups)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func searchByNormalizedName(_ normalizedName: String) async throws -> [ProductGroup] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductGroup>(entityName: "ProductGroup")
                    request.predicate = NSPredicate(format: "normalizedName BEGINSWITH[cd] %@ AND deletedFlag == NO", normalizedName)
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductGroup.recordCount, ascending: false)
                    ]
                    request.fetchLimit = 10
                    
                    let groups = try self.context.fetch(request)
                    continuation.resume(returning: groups)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    // MARK: - Statistics Operations
    
    func fetchTopGroups(limit: Int) async throws -> [ProductGroup] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductGroup>(entityName: "ProductGroup")
                    request.predicate = NSPredicate(format: "deletedFlag == NO AND recordCount > 0")
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductGroup.recordCount, ascending: false),
                        NSSortDescriptor(keyPath: \ProductGroup.lastRecordDate, ascending: false)
                    ]
                    request.fetchLimit = limit
                    
                    let groups = try self.context.fetch(request)
                    continuation.resume(returning: groups)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchRecentGroups(limit: Int) async throws -> [ProductGroup] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductGroup>(entityName: "ProductGroup")
                    request.predicate = NSPredicate(format: "deletedFlag == NO AND lastRecordDate != nil")
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductGroup.lastRecordDate, ascending: false)
                    ]
                    request.fetchLimit = limit
                    
                    let groups = try self.context.fetch(request)
                    continuation.resume(returning: groups)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func updateStatistics(_ group: ProductGroup) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // 関連するProductRecordsを取得
                    let request = NSFetchRequest<ProductRecord>(entityName: "ProductRecord")
                    request.predicate = NSPredicate(format: "productGroup == %@ AND deletedFlag == NO", group)
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductRecord.unitPrice, ascending: true)
                    ]
                    
                    let records = try self.context.fetch(request)
                    
                    // 統計情報を計算
                    let recordCount = records.count
                    let averagePrice = records.isEmpty ? 0 : 
                        records.compactMap { $0.value(forKey: "unitPrice") as? Decimal }
                            .reduce(0, +) / Decimal(records.count)
                    
                    let lowestPrice = records.first?.value(forKey: "unitPrice") as? Decimal ?? 0
                    let lowestPriceStore = records.first?.value(forKey: "storeName") as? String ?? ""
                    let lastRecordDate = records.compactMap { $0.value(forKey: "createdAt") as? Date }.max()
                    
                    // 統計情報を更新
                    group.setValue(recordCount, forKey: "recordCount")
                    group.setValue(averagePrice, forKey: "averageUnitPrice")
                    group.setValue(lowestPrice, forKey: "lowestUnitPrice")
                    group.setValue(lowestPriceStore, forKey: "lowestPriceStoreName")
                    group.setValue(lastRecordDate, forKey: "lastRecordDate")
                    group.setValue(Date(), forKey: "updatedAt")
                    
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: RepositoryError.saveFailed)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func normalizeProductName(_ name: String) -> String {
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

// MARK: - Convenience Extensions

extension CoreDataProductGroupRepository {
    
    /// 商品名で検索、なければ作成
    func findOrCreateProductGroup(
        productName: String,
        productType: String? = nil,
        category: ProductCategory? = nil
    ) async throws -> ProductGroup {
        if let existingGroup = try await fetchByProductName(productName) {
            return existingGroup
        } else {
            return try await create(productName: productName, productType: productType, category: category)
        }
    }
    
    /// 正規化名での重複チェック
    func checkDuplicateByNormalizedName(_ productName: String) async throws -> ProductGroup? {
        let normalizedName = normalizeProductName(productName)
        let results = try await searchByNormalizedName(normalizedName)
        return results.first
    }
    
    /// 統計情報の一括更新
    func updateAllStatistics() async throws {
        let allGroups = try await fetchAll()
        for group in allGroups {
            try await updateStatistics(group)
        }
    }
}