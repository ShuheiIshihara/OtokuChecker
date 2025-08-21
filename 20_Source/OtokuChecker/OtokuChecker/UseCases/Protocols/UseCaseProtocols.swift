//
//  UseCaseProtocols.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation

// MARK: - Base UseCase Protocol

protocol BaseUseCase {
    associatedtype Input
    associatedtype Output
    
    func execute(_ input: Input) async throws -> Output
}

// MARK: - Comparison UseCase Protocol

protocol ComparisonUseCaseProtocol: BaseUseCase where Input == ComparisonInput, Output == ComparisonOutput {
    
    func compareProducts(productA: ComparisonProduct, productB: ComparisonProduct) async throws -> ExtendedComparisonResult
    func compareWithHistory(currentProduct: ComparisonProduct, historicalProductId: UUID) async throws -> ExtendedComparisonResult
    func saveComparisonResult(_ result: ExtendedComparisonResult) async throws
}

struct ComparisonInput {
    let productA: ComparisonProduct
    let productB: ComparisonProduct?
    let historicalProductId: UUID?
}

struct ComparisonOutput {
    let result: ExtendedComparisonResult
    let savedToHistory: Bool
}

// MARK: - Product Management UseCase Protocol

protocol ProductManagementUseCaseProtocol: BaseUseCase where Input == ProductManagementInput, Output == ProductManagementOutput {
    
    func saveProduct(_ product: ComparisonProduct, category: ProductCategory?) async throws -> ProductRecord
    func fetchRecentProducts(limit: Int) async throws -> [ProductRecord]
    func fetchProductGroups() async throws -> [ProductGroup]
    func fetchProductGroup(by name: String) async throws -> ProductGroup?
    func updateProductGroup(_ group: ProductGroup) async throws
    func deleteProduct(_ product: ProductRecord) async throws
    func searchProducts(keyword: String) async throws -> [ProductRecord]
}

struct ProductManagementInput {
    let operation: ProductOperation
    let product: ComparisonProduct?
    let productGroup: ProductGroup?
    let searchKeyword: String?
    let limit: Int?
}

struct ProductManagementOutput {
    let products: [ProductRecord]?
    let productGroups: [ProductGroup]?
    let savedProduct: ProductRecord?
}

enum ProductOperation {
    case save
    case fetchRecent
    case fetchGroups
    case search
    case update
    case delete
}

// MARK: - History Management UseCase Protocol

protocol HistoryManagementUseCaseProtocol: BaseUseCase where Input == HistoryManagementInput, Output == HistoryManagementOutput {
    
    func fetchComparisonHistory(limit: Int) async throws -> [ComparisonHistory]
    func fetchHistoryByProduct(productName: String) async throws -> [ComparisonHistory]
    func fetchHistoryByDateRange(startDate: Date, endDate: Date) async throws -> [ComparisonHistory]
    func deleteHistoryItem(_ history: ComparisonHistory) async throws
    func getMostComparedProducts(limit: Int) async throws -> [(productName: String, count: Int)]
    func getComparisonStatistics() async throws -> (totalComparisons: Int, averageSavings: Decimal)
}

struct HistoryManagementInput {
    let operation: HistoryOperation
    let limit: Int?
    let productName: String?
    let startDate: Date?
    let endDate: Date?
    let historyItem: ComparisonHistory?
}

struct HistoryManagementOutput {
    let historyItems: [ComparisonHistory]?
    let statistics: (totalComparisons: Int, averageSavings: Decimal)?
    let topProducts: [(productName: String, count: Int)]?
}

enum HistoryOperation {
    case fetchRecent
    case fetchByProduct
    case fetchByDateRange
    case delete
    case getMostCompared
    case getStatistics
}

// MARK: - Category Management UseCase Protocol

protocol CategoryManagementUseCaseProtocol: BaseUseCase where Input == CategoryManagementInput, Output == CategoryManagementOutput {
    
    func fetchAllCategories() async throws -> [ProductCategory]
    func fetchSystemCategories() async throws -> [ProductCategory]
    func fetchCustomCategories() async throws -> [ProductCategory]
    func createCustomCategory(name: String, icon: String, colorHex: String?) async throws -> ProductCategory
    func updateCategory(_ category: ProductCategory) async throws
    func deleteCategory(_ category: ProductCategory) async throws
    func initializeSystemCategories() async throws
    func suggestCategoriesFor(productName: String) async throws -> [ProductCategory]
}

struct CategoryManagementInput {
    let operation: CategoryOperation
    let category: ProductCategory?
    let name: String?
    let icon: String?
    let colorHex: String?
}

struct CategoryManagementOutput {
    let categories: [ProductCategory]?
    let createdCategory: ProductCategory?
}

enum CategoryOperation {
    case fetchAll
    case fetchSystem
    case fetchCustom
    case create
    case update
    case delete
    case initialize
}

// MARK: - UseCase Error Types

enum UseCaseError: LocalizedError {
    case invalidInput
    case productNotFound
    case categoryNotFound
    case historyNotFound
    case comparisonFailed
    case saveFailed
    case deleteFailed
    case repositoryError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "入力データが無効です"
        case .productNotFound:
            return "商品が見つかりません"
        case .categoryNotFound:
            return "カテゴリが見つかりません"
        case .historyNotFound:
            return "履歴が見つかりません"
        case .comparisonFailed:
            return "比較処理に失敗しました"
        case .saveFailed:
            return "データの保存に失敗しました"
        case .deleteFailed:
            return "データの削除に失敗しました"
        case .repositoryError(let error):
            return "データアクセスエラー: \(error.localizedDescription)"
        }
    }
}