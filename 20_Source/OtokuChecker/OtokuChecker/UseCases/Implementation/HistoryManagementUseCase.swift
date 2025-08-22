//
//  HistoryManagementUseCase.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation

class HistoryManagementUseCase: HistoryManagementUseCaseProtocol {
    
    private let comparisonHistoryRepository: any ComparisonHistoryRepositoryProtocol
    
    init(comparisonHistoryRepository: any ComparisonHistoryRepositoryProtocol) {
        self.comparisonHistoryRepository = comparisonHistoryRepository
    }
    
    // MARK: - BaseUseCase Implementation
    
    func execute(_ input: HistoryManagementInput) async throws -> HistoryManagementOutput {
        switch input.operation {
        case .fetchRecent:
            let limit = input.limit ?? 20
            let historyItems = try await fetchComparisonHistory(limit: limit)
            return HistoryManagementOutput(historyItems: historyItems, statistics: nil, topProducts: nil)
            
        case .fetchByProduct:
            guard let productName = input.productName else {
                throw UseCaseError.invalidInput
            }
            let historyItems = try await fetchHistoryByProduct(productName: productName)
            return HistoryManagementOutput(historyItems: historyItems, statistics: nil, topProducts: nil)
            
        case .fetchByDateRange:
            guard let startDate = input.startDate,
                  let endDate = input.endDate else {
                throw UseCaseError.invalidInput
            }
            let historyItems = try await fetchHistoryByDateRange(startDate: startDate, endDate: endDate)
            return HistoryManagementOutput(historyItems: historyItems, statistics: nil, topProducts: nil)
            
        case .delete:
            guard let historyItem = input.historyItem else {
                throw UseCaseError.invalidInput
            }
            try await deleteHistoryItem(historyItem)
            return HistoryManagementOutput(historyItems: nil, statistics: nil, topProducts: nil)
            
        case .getMostCompared:
            let limit = input.limit ?? 10
            let topProducts = try await getMostComparedProducts(limit: limit)
            return HistoryManagementOutput(historyItems: nil, statistics: nil, topProducts: topProducts)
            
        case .getStatistics:
            let statistics = try await getComparisonStatistics()
            return HistoryManagementOutput(historyItems: nil, statistics: statistics, topProducts: nil)
        }
    }
    
    // MARK: - HistoryManagementUseCaseProtocol Implementation
    
    func fetchComparisonHistory(limit: Int) async throws -> [ComparisonHistory] {
        do {
            return try await comparisonHistoryRepository.fetchRecent(limit: limit)
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func fetchHistoryByProduct(productName: String) async throws -> [ComparisonHistory] {
        do {
            return try await comparisonHistoryRepository.search(productName: productName)
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func fetchHistoryByDateRange(startDate: Date, endDate: Date) async throws -> [ComparisonHistory] {
        guard startDate <= endDate else {
            throw UseCaseError.invalidInput
        }
        
        do {
            return try await comparisonHistoryRepository.fetchByDateRange(startDate: startDate, endDate: endDate)
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func deleteHistoryItem(_ history: ComparisonHistory) async throws {
        do {
            try await comparisonHistoryRepository.delete(history)
        } catch {
            throw UseCaseError.deleteFailed
        }
    }
    
    func getMostComparedProducts(limit: Int) async throws -> [(productName: String, count: Int)] {
        do {
            return try await comparisonHistoryRepository.fetchMostComparedProducts(limit: limit)
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func getComparisonStatistics() async throws -> (totalComparisons: Int, averageSavings: Decimal) {
        do {
            return try await comparisonHistoryRepository.fetchComparisonStats()
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    // MARK: - Additional Business Logic Methods
    
    func fetchHistoryGroupedByProduct() async throws -> [String: [ComparisonHistory]] {
        do {
            let allHistory = try await comparisonHistoryRepository.fetchAll()
            return Dictionary(grouping: allHistory) { history in
                // ProductAとProductBのうち、より頻繁に登場する商品名でグループ化
                return determinePrimaryProduct(history)
            }
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func fetchSavingsHistory(for productName: String) async throws -> [ComparisonSavings] {
        do {
            let productHistory = try await fetchHistoryByProduct(productName: productName)
            return productHistory.compactMap { history in
                calculateSavings(from: history)
            }
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func getRecentTrends(days: Int = 30) async throws -> ComparisonTrends {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        
        do {
            let recentHistory = try await fetchHistoryByDateRange(startDate: startDate, endDate: endDate)
            return analyzeTrends(from: recentHistory)
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func determinePrimaryProduct(_ history: ComparisonHistory) -> String {
        // より短い商品名、または勝者の商品名を主要商品とする
        let productAName = history.productAName ?? ""
        let productBName = history.productBName ?? ""
        
        if productAName.count <= productBName.count {
            return productAName
        } else {
            return productBName
        }
    }
    
    private func calculateSavings(from history: ComparisonHistory) -> ComparisonSavings? {
        guard let productAPrice = history.productAPrice,
              let productAQuantity = history.productAQuantity,
              let productBPrice = history.productBPrice,
              let productBQuantity = history.productBQuantity else {
            return nil
        }
        
        let unitPriceA = productAPrice.dividing(by: productAQuantity)
        let unitPriceB = productBPrice.dividing(by: productBQuantity)
        
        let priceDifference = unitPriceA.subtracting(unitPriceB)
        let savings = priceDifference.compare(NSDecimalNumber.zero) == .orderedAscending ? 
            priceDifference.multiplying(by: NSDecimalNumber(value: -1)) : priceDifference
        let maxPrice = unitPriceA.compare(unitPriceB) == .orderedDescending ? unitPriceA : unitPriceB
        let savingsPercentage = savings.dividing(by: maxPrice).multiplying(by: NSDecimalNumber(value: 100))
        
        return ComparisonSavings(
            date: history.createdAt ?? Date(),
            absoluteSavings: savings.decimalValue,
            percentageSavings: savingsPercentage.decimalValue,
            cheaperProduct: unitPriceA.compare(unitPriceB) == .orderedAscending ? history.productAName ?? "" : history.productBName ?? ""
        )
    }
    
    private func analyzeTrends(from history: [ComparisonHistory]) -> ComparisonTrends {
        let totalComparisons = history.count
        let averageComparisonsPerDay = Double(totalComparisons) / 30.0
        
        // 勝者の分布を計算
        let winners = history.compactMap { $0.winnerProduct }
        let winnerDistribution = Dictionary(winners.map { ($0, 1) }, uniquingKeysWith: +)
        
        // 最も節約できた商品を特定
        let savings = history.compactMap { calculateSavings(from: $0) }
        let topSavingProduct = savings.max { $0.absoluteSavings < $1.absoluteSavings }?.cheaperProduct ?? ""
        
        return ComparisonTrends(
            totalComparisons: totalComparisons,
            averageComparisonsPerDay: averageComparisonsPerDay,
            mostPopularProduct: winnerDistribution.max { $0.value < $1.value }?.key ?? "",
            topSavingProduct: topSavingProduct
        )
    }
}

// MARK: - Supporting Data Types

struct ComparisonSavings {
    let date: Date
    let absoluteSavings: Decimal
    let percentageSavings: Decimal
    let cheaperProduct: String
}

struct ComparisonTrends {
    let totalComparisons: Int
    let averageComparisonsPerDay: Double
    let mostPopularProduct: String
    let topSavingProduct: String
}
