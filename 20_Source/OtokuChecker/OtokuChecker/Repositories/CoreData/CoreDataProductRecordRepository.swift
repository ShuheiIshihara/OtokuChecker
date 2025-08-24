//
//  CoreDataProductRecordRepository.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/20.
//

import Foundation
import CoreData

class CoreDataProductRecordRepository: ProductRecordRepositoryProtocol {
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Basic CRUD Operations
    
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
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let recordEntity = NSEntityDescription.entity(forEntityName: "ProductRecord", in: self.context)!
                    let record = NSManagedObject(entity: recordEntity, insertInto: self.context) as! ProductRecord
                    
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
                    
                    // 税込価格とか単価の計算
                    record.setValue(true, forKey: "taxIncluded")
                    record.setValue(0.1, forKey: "taxRate")
                    
                    let finalPrice = originalPrice // 税込の場合
                    record.setValue(finalPrice, forKey: "finalPrice")
                    
                    // 単価計算 (価格/数量)
                    let unitPrice = quantity > 0 ? finalPrice / quantity : 0
                    record.setValue(unitPrice, forKey: "unitPrice")
                    
                    // 関係性の設定
                    if let productGroup = productGroup {
                        record.setValue(productGroup, forKey: "productGroup")
                    }
                    
                    if let category = category {
                        record.setValue(category, forKey: "category")
                    }
                    
                    try self.context.save()
                    continuation.resume(returning: record)
                } catch {
                    continuation.resume(throwing: RepositoryError.saveFailed)
                }
            }
        }
    }
    
    func fetchAll() async throws -> [ProductRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductRecord>(entityName: "ProductRecord")
                    request.predicate = NSPredicate(format: "deletedFlag == NO")
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
                    ]
                    
                    let records = try self.context.fetch(request)
                    continuation.resume(returning: records)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchById(_ id: UUID) async throws -> ProductRecord? {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductRecord>(entityName: "ProductRecord")
                    request.predicate = NSPredicate(format: "entityID == %@ AND deletedFlag == NO", id as CVarArg)
                    request.fetchLimit = 1
                    
                    let records = try self.context.fetch(request)
                    continuation.resume(returning: records.first)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func update(_ record: ProductRecord) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
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
                    
                    try self.context.save()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: RepositoryError.saveFailed)
                }
            }
        }
    }
    
    func delete(_ record: ProductRecord) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // ソフトデリート
                    record.setValue(true, forKey: "deletedFlag")
                    record.setValue(Date(), forKey: "updatedAt")
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
    
    func fetch() async throws -> [ProductRecord] {
        return try await fetchAll()
    }
    
    // MARK: - Query Operations
    
    func fetchByProductGroup(_ group: ProductGroup) async throws -> [ProductRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductRecord>(entityName: "ProductRecord")
                    request.predicate = NSPredicate(format: "productGroup == %@ AND deletedFlag == NO", group)
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductRecord.unitPrice, ascending: true),
                        NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
                    ]
                    
                    let records = try self.context.fetch(request)
                    continuation.resume(returning: records)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchByCategory(_ category: ProductCategory) async throws -> [ProductRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductRecord>(entityName: "ProductRecord")
                    request.predicate = NSPredicate(format: "category == %@ AND deletedFlag == NO", category)
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
                    ]
                    
                    let records = try self.context.fetch(request)
                    continuation.resume(returning: records)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchByStoreName(_ storeName: String) async throws -> [ProductRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductRecord>(entityName: "ProductRecord")
                    request.predicate = NSPredicate(format: "storeName CONTAINS[cd] %@ AND deletedFlag == NO", storeName)
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
                    ]
                    
                    let records = try self.context.fetch(request)
                    continuation.resume(returning: records)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchByPriceRange(min: Decimal, max: Decimal) async throws -> [ProductRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductRecord>(entityName: "ProductRecord")
                    request.predicate = NSPredicate(
                        format: "unitPrice >= %@ AND unitPrice <= %@ AND deletedFlag == NO",
                        min as NSDecimalNumber, max as NSDecimalNumber
                    )
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductRecord.unitPrice, ascending: true)
                    ]
                    
                    let records = try self.context.fetch(request)
                    continuation.resume(returning: records)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchByDateRange(startDate: Date, endDate: Date) async throws -> [ProductRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductRecord>(entityName: "ProductRecord")
                    request.predicate = NSPredicate(
                        format: "createdAt >= %@ AND createdAt <= %@ AND deletedFlag == NO",
                        startDate as NSDate, endDate as NSDate
                    )
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
                    ]
                    
                    let records = try self.context.fetch(request)
                    continuation.resume(returning: records)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    // MARK: - Search Operations
    
    func search(keyword: String) async throws -> [ProductRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductRecord>(entityName: "ProductRecord")
                    request.predicate = NSPredicate(
                        format: "(productName CONTAINS[cd] %@ OR storeName CONTAINS[cd] %@ OR memo CONTAINS[cd] %@) AND deletedFlag == NO",
                        keyword, keyword, keyword
                    )
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
                    ]
                    
                    let records = try self.context.fetch(request)
                    continuation.resume(returning: records)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchRecent(limit: Int) async throws -> [ProductRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductRecord>(entityName: "ProductRecord")
                    request.predicate = NSPredicate(format: "deletedFlag == NO")
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductRecord.createdAt, ascending: false)
                    ]
                    request.fetchLimit = limit
                    
                    let records = try self.context.fetch(request)
                    continuation.resume(returning: records)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchCheapest(limit: Int) async throws -> [ProductRecord] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductRecord>(entityName: "ProductRecord")
                    request.predicate = NSPredicate(format: "deletedFlag == NO AND unitPrice > 0")
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductRecord.unitPrice, ascending: true)
                    ]
                    request.fetchLimit = limit
                    
                    let records = try self.context.fetch(request)
                    continuation.resume(returning: records)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
}

// MARK: - Convenience Extensions

extension CoreDataProductRecordRepository {
    
    /// 詳細情報付きでレコード作成
    func createDetailedRecord(
        productName: String,
        originalPrice: Decimal,
        quantity: Decimal,
        unitType: String,
        storeName: String?,
        origin: String? = nil,
        storeLocation: String? = nil,
        purchaseDate: Date? = nil,
        memo: String? = nil,
        taxIncluded: Bool = true,
        taxRate: Decimal = 0.1,
        productGroup: ProductGroup? = nil,
        category: ProductCategory? = nil
    ) async throws -> ProductRecord {
        let record = try await create(
            productName: productName,
            originalPrice: originalPrice,
            quantity: quantity,
            unitType: unitType,
            storeName: storeName,
            origin: origin ?? "domestic",
            productGroup: productGroup,
            category: category
        )
        
        // 追加情報設定
        record.setValue(storeLocation ?? "", forKey: "storeLocation")
        record.setValue(purchaseDate ?? Date(), forKey: "purchaseDate")
        record.setValue(memo ?? "", forKey: "memo")
        record.setValue(taxIncluded, forKey: "taxIncluded")
        record.setValue(taxRate, forKey: "taxRate")
        
        try await update(record)
        return record
    }
    
    /// 価格による最安値検索
    func findCheapestByProduct(_ productName: String) async throws -> ProductRecord? {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ProductRecord>(entityName: "ProductRecord")
                    request.predicate = NSPredicate(
                        format: "productName CONTAINS[cd] %@ AND deletedFlag == NO AND unitPrice > 0",
                        productName
                    )
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ProductRecord.unitPrice, ascending: true)
                    ]
                    request.fetchLimit = 1
                    
                    let records = try self.context.fetch(request)
                    continuation.resume(returning: records.first)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    /// 店舗別統計取得
    func getStoreStatistics() async throws -> [(storeName: String, count: Int, averagePrice: Decimal)] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ProductRecord")
                    request.predicate = NSPredicate(format: "deletedFlag == NO AND storeName != ''")
                    request.resultType = .dictionaryResultType
                    
                    let storeNameExpression = NSExpression(forKeyPath: "storeName")
                    let countExpression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "entityID")])
                    let avgPriceExpression = NSExpression(forFunction: "average:", arguments: [NSExpression(forKeyPath: "unitPrice")])
                    
                    let storeNameDescription = NSExpressionDescription()
                    storeNameDescription.name = "storeName"
                    storeNameDescription.expression = storeNameExpression
                    storeNameDescription.expressionResultType = .stringAttributeType
                    
                    let countDescription = NSExpressionDescription()
                    countDescription.name = "count"
                    countDescription.expression = countExpression
                    countDescription.expressionResultType = .integer32AttributeType
                    
                    let avgPriceDescription = NSExpressionDescription()
                    avgPriceDescription.name = "averagePrice"
                    avgPriceDescription.expression = avgPriceExpression
                    avgPriceDescription.expressionResultType = .decimalAttributeType
                    
                    request.propertiesToFetch = [storeNameDescription, countDescription, avgPriceDescription]
                    request.propertiesToGroupBy = [storeNameDescription]
                    
                    let results = try self.context.fetch(request) as! [[String: Any]]
                    
                    let statistics = results.compactMap { result -> (String, Int, Decimal)? in
                        guard let storeName = result["storeName"] as? String,
                              let count = result["count"] as? Int,
                              let averagePrice = result["averagePrice"] as? Decimal else {
                            return nil
                        }
                        return (storeName, count, averagePrice)
                    }
                    
                    continuation.resume(returning: statistics)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
}