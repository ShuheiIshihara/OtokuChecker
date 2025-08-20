//
//  CoreDataComparisonHistoryRepository.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/20.
//

import Foundation
import CoreData

class CoreDataComparisonHistoryRepository: ComparisonHistoryRepositoryProtocol {
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Basic CRUD Operations
    
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
    ) async throws -> ComparisonHistory {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let historyEntity = NSEntityDescription.entity(forEntityName: "ComparisonHistory", in: self.context)!
                    let history = NSManagedObject(entity: historyEntity, insertInto: self.context) as! ComparisonHistory
                    
                    // 基本情報設定
                    history.setValue(UUID(), forKey: "entityID")
                    history.setValue(comparisonType, forKey: "comparisonType")
                    history.setValue("", forKey: "comparisonContext")
                    
                    // 商品A情報
                    history.setValue(productAName, forKey: "productAName")
                    history.setValue(productAPrice, forKey: "productAPrice")
                    history.setValue(productAQuantity, forKey: "productAQuantity")
                    history.setValue(productAUnitType, forKey: "productAUnitType")
                    let productAUnitPrice = productAQuantity > 0 ? productAPrice / productAQuantity : 0
                    history.setValue(productAUnitPrice, forKey: "productAUnitPrice")
                    
                    // 商品B情報
                    history.setValue(productBName, forKey: "productBName")
                    history.setValue(productBPrice, forKey: "productBPrice")
                    history.setValue(productBQuantity, forKey: "productBQuantity")
                    history.setValue(productBUnitType, forKey: "productBUnitType")
                    let productBUnitPrice = productBQuantity > 0 ? productBPrice / productBQuantity : 0
                    history.setValue(productBUnitPrice, forKey: "productBUnitPrice")
                    
                    // 比較結果計算
                    let priceDifference = abs(productAUnitPrice - productBUnitPrice)
                    let percentageDifference = productAUnitPrice > 0 ? 
                        (priceDifference / min(productAUnitPrice, productBUnitPrice)) * 100 : 0
                    
                    history.setValue(winnerProduct, forKey: "winnerProduct")
                    history.setValue(priceDifference, forKey: "priceDifference")
                    history.setValue(percentageDifference, forKey: "percentageDifference")
                    history.setValue(nil, forKey: "userChoice")
                    history.setValue(false, forKey: "wasDataSaved")
                    
                    // システム情報
                    history.setValue(false, forKey: "isDeleted")
                    history.setValue(Date(), forKey: "createdAt")
                    
                    try self.context.save()
                    continuation.resume(returning: history)
                } catch {
                    continuation.resume(throwing: RepositoryError.saveFailed)
                }
            }
        }
    }
    
    func fetchAll() async throws -> [ComparisonHistory] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ComparisonHistory>(entityName: "ComparisonHistory")
                    request.predicate = NSPredicate(format: "isDeleted == NO")
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ComparisonHistory.createdAt, ascending: false)
                    ]
                    
                    let histories = try self.context.fetch(request)
                    continuation.resume(returning: histories)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchById(_ id: UUID) async throws -> ComparisonHistory? {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ComparisonHistory>(entityName: "ComparisonHistory")
                    request.predicate = NSPredicate(format: "entityID == %@ AND isDeleted == NO", id as CVarArg)
                    request.fetchLimit = 1
                    
                    let histories = try self.context.fetch(request)
                    continuation.resume(returning: histories.first)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func delete(_ history: ComparisonHistory) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // ソフトデリート
                    history.setValue(true, forKey: "isDeleted")
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
    
    func fetch() async throws -> [ComparisonHistory] {
        return try await fetchAll()
    }
    
    // MARK: - Query Operations
    
    func fetchByType(_ type: String) async throws -> [ComparisonHistory] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ComparisonHistory>(entityName: "ComparisonHistory")
                    request.predicate = NSPredicate(format: "comparisonType == %@ AND isDeleted == NO", type)
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ComparisonHistory.createdAt, ascending: false)
                    ]
                    
                    let histories = try self.context.fetch(request)
                    continuation.resume(returning: histories)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchRecent(limit: Int) async throws -> [ComparisonHistory] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ComparisonHistory>(entityName: "ComparisonHistory")
                    request.predicate = NSPredicate(format: "isDeleted == NO")
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ComparisonHistory.createdAt, ascending: false)
                    ]
                    request.fetchLimit = limit
                    
                    let histories = try self.context.fetch(request)
                    continuation.resume(returning: histories)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchByDateRange(startDate: Date, endDate: Date) async throws -> [ComparisonHistory] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ComparisonHistory>(entityName: "ComparisonHistory")
                    request.predicate = NSPredicate(
                        format: "createdAt >= %@ AND createdAt <= %@ AND isDeleted == NO",
                        startDate as NSDate, endDate as NSDate
                    )
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ComparisonHistory.createdAt, ascending: false)
                    ]
                    
                    let histories = try self.context.fetch(request)
                    continuation.resume(returning: histories)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func search(productName: String) async throws -> [ComparisonHistory] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<ComparisonHistory>(entityName: "ComparisonHistory")
                    request.predicate = NSPredicate(
                        format: "(productAName CONTAINS[cd] %@ OR productBName CONTAINS[cd] %@) AND isDeleted == NO",
                        productName, productName
                    )
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \ComparisonHistory.createdAt, ascending: false)
                    ]
                    
                    let histories = try self.context.fetch(request)
                    continuation.resume(returning: histories)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    // MARK: - Statistics Operations
    
    func fetchMostComparedProducts(limit: Int) async throws -> [(productName: String, count: Int)] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    // 商品Aと商品Bの名前を集計するための複雑なクエリ
                    let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ComparisonHistory")
                    request.predicate = NSPredicate(format: "isDeleted == NO")
                    request.resultType = .dictionaryResultType
                    
                    // 商品A名での集計
                    let productANameExpression = NSExpression(forKeyPath: "productAName")
                    let countAExpression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "entityID")])
                    
                    let productANameDescription = NSExpressionDescription()
                    productANameDescription.name = "productName"
                    productANameDescription.expression = productANameExpression
                    productANameDescription.expressionResultType = .stringAttributeType
                    
                    let countADescription = NSExpressionDescription()
                    countADescription.name = "count"
                    countADescription.expression = countAExpression
                    countADescription.expressionResultType = .integer32AttributeType
                    
                    request.propertiesToFetch = [productANameDescription, countADescription]
                    request.propertiesToGroupBy = [productANameDescription]
                    request.sortDescriptors = [
                        NSSortDescriptor(key: "count", ascending: false)
                    ]
                    request.fetchLimit = limit
                    
                    let results = try self.context.fetch(request) as! [[String: Any]]
                    
                    let statistics = results.compactMap { result -> (String, Int)? in
                        guard let productName = result["productName"] as? String,
                              let count = result["count"] as? Int,
                              !productName.isEmpty else {
                            return nil
                        }
                        return (productName, count)
                    }
                    
                    continuation.resume(returning: statistics)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
    
    func fetchComparisonStats() async throws -> (totalComparisons: Int, averageSavings: Decimal) {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ComparisonHistory")
                    request.predicate = NSPredicate(format: "isDeleted == NO")
                    request.resultType = .dictionaryResultType
                    
                    let countExpression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "entityID")])
                    let avgSavingsExpression = NSExpression(forFunction: "average:", arguments: [NSExpression(forKeyPath: "priceDifference")])
                    
                    let countDescription = NSExpressionDescription()
                    countDescription.name = "totalCount"
                    countDescription.expression = countExpression
                    countDescription.expressionResultType = .integer32AttributeType
                    
                    let avgSavingsDescription = NSExpressionDescription()
                    avgSavingsDescription.name = "averageSavings"
                    avgSavingsDescription.expression = avgSavingsExpression
                    avgSavingsDescription.expressionResultType = .decimalAttributeType
                    
                    request.propertiesToFetch = [countDescription, avgSavingsDescription]
                    
                    let results = try self.context.fetch(request) as! [[String: Any]]
                    
                    if let result = results.first {
                        let totalCount = result["totalCount"] as? Int ?? 0
                        let averageSavings = result["averageSavings"] as? Decimal ?? 0
                        continuation.resume(returning: (totalCount, averageSavings))
                    } else {
                        continuation.resume(returning: (0, 0))
                    }
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
}

// MARK: - Convenience Extensions

extension CoreDataComparisonHistoryRepository {
    
    /// 詳細情報付きで比較履歴作成
    func createDetailedHistory(
        comparisonType: String,
        productAName: String,
        productAPrice: Decimal,
        productAQuantity: Decimal,
        productAUnitType: String,
        productBName: String,
        productBPrice: Decimal,
        productBQuantity: Decimal,
        productBUnitType: String,
        winnerProduct: String,
        comparisonContext: String? = nil,
        userChoice: String? = nil,
        wasDataSaved: Bool = false
    ) async throws -> ComparisonHistory {
        let history = try await create(
            comparisonType: comparisonType,
            productAName: productAName,
            productAPrice: productAPrice,
            productAQuantity: productAQuantity,
            productAUnitType: productAUnitType,
            productBName: productBName,
            productBPrice: productBPrice,
            productBQuantity: productBQuantity,
            productBUnitType: productBUnitType,
            winnerProduct: winnerProduct
        )
        
        // 追加情報設定
        if let context = comparisonContext {
            history.setValue(context, forKey: "comparisonContext")
        }
        
        if let choice = userChoice {
            history.setValue(choice, forKey: "userChoice")
        }
        
        history.setValue(wasDataSaved, forKey: "wasDataSaved")
        
        try await save()
        return history
    }
    
    /// 最近の比較から重複商品を取得
    func getRecentlyComparedProducts(limit: Int = 20) async throws -> [String] {
        let recentHistories = try await fetchRecent(limit: limit * 2) // 多めに取得
        
        var uniqueProducts = Set<String>()
        for history in recentHistories {
            if let productAName = history.value(forKey: "productAName") as? String, !productAName.isEmpty {
                uniqueProducts.insert(productAName)
            }
            if let productBName = history.value(forKey: "productBName") as? String, !productBName.isEmpty {
                uniqueProducts.insert(productBName)
            }
            
            if uniqueProducts.count >= limit {
                break
            }
        }
        
        return Array(uniqueProducts.prefix(limit))
    }
    
    /// 特定期間の節約額合計を取得
    func getTotalSavingsForPeriod(startDate: Date, endDate: Date) async throws -> Decimal {
        let histories = try await fetchByDateRange(startDate: startDate, endDate: endDate)
        
        return histories.reduce(0) { total, history in
            if let priceDifference = history.value(forKey: "priceDifference") as? Decimal {
                return total + priceDifference
            }
            return total
        }
    }
    
    /// 比較タイプ別の統計取得
    func getStatsByComparisonType() async throws -> [(type: String, count: Int, averageSavings: Decimal)] {
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ComparisonHistory")
                    request.predicate = NSPredicate(format: "isDeleted == NO")
                    request.resultType = .dictionaryResultType
                    
                    let typeExpression = NSExpression(forKeyPath: "comparisonType")
                    let countExpression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "entityID")])
                    let avgSavingsExpression = NSExpression(forFunction: "average:", arguments: [NSExpression(forKeyPath: "priceDifference")])
                    
                    let typeDescription = NSExpressionDescription()
                    typeDescription.name = "type"
                    typeDescription.expression = typeExpression
                    typeDescription.expressionResultType = .stringAttributeType
                    
                    let countDescription = NSExpressionDescription()
                    countDescription.name = "count"
                    countDescription.expression = countExpression
                    countDescription.expressionResultType = .integer32AttributeType
                    
                    let avgSavingsDescription = NSExpressionDescription()
                    avgSavingsDescription.name = "averageSavings"
                    avgSavingsDescription.expression = avgSavingsExpression
                    avgSavingsDescription.expressionResultType = .decimalAttributeType
                    
                    request.propertiesToFetch = [typeDescription, countDescription, avgSavingsDescription]
                    request.propertiesToGroupBy = [typeDescription]
                    request.sortDescriptors = [
                        NSSortDescriptor(key: "count", ascending: false)
                    ]
                    
                    let results = try self.context.fetch(request) as! [[String: Any]]
                    
                    let statistics = results.compactMap { result -> (String, Int, Decimal)? in
                        guard let type = result["type"] as? String,
                              let count = result["count"] as? Int,
                              let averageSavings = result["averageSavings"] as? Decimal else {
                            return nil
                        }
                        return (type, count, averageSavings)
                    }
                    
                    continuation.resume(returning: statistics)
                } catch {
                    continuation.resume(throwing: RepositoryError.coreDataError(error))
                }
            }
        }
    }
}