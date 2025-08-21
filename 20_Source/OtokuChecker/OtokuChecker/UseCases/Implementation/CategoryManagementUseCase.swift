//
//  CategoryManagementUseCase.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation

class CategoryManagementUseCase: CategoryManagementUseCaseProtocol {
    
    private let categoryRepository: any ProductCategoryRepositoryProtocol
    
    init(categoryRepository: any ProductCategoryRepositoryProtocol) {
        self.categoryRepository = categoryRepository
    }
    
    // MARK: - BaseUseCase Implementation
    
    func execute(_ input: CategoryManagementInput) async throws -> CategoryManagementOutput {
        switch input.operation {
        case .fetchAll:
            let categories = try await fetchAllCategories()
            return CategoryManagementOutput(categories: categories, createdCategory: nil)
            
        case .fetchSystem:
            let categories = try await fetchSystemCategories()
            return CategoryManagementOutput(categories: categories, createdCategory: nil)
            
        case .fetchCustom:
            let categories = try await fetchCustomCategories()
            return CategoryManagementOutput(categories: categories, createdCategory: nil)
            
        case .create:
            guard let name = input.name,
                  let icon = input.icon else {
                throw UseCaseError.invalidInput
            }
            let createdCategory = try await createCustomCategory(
                name: name,
                icon: icon,
                colorHex: input.colorHex
            )
            return CategoryManagementOutput(categories: nil, createdCategory: createdCategory)
            
        case .update:
            guard let category = input.category else {
                throw UseCaseError.invalidInput
            }
            try await updateCategory(category)
            return CategoryManagementOutput(categories: nil, createdCategory: nil)
            
        case .delete:
            guard let category = input.category else {
                throw UseCaseError.invalidInput
            }
            try await deleteCategory(category)
            return CategoryManagementOutput(categories: nil, createdCategory: nil)
            
        case .initialize:
            try await initializeSystemCategories()
            return CategoryManagementOutput(categories: nil, createdCategory: nil)
        }
    }
    
    // MARK: - CategoryManagementUseCaseProtocol Implementation
    
    func fetchAllCategories() async throws -> [ProductCategory] {
        do {
            return try await categoryRepository.fetchAll()
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func fetchSystemCategories() async throws -> [ProductCategory] {
        do {
            return try await categoryRepository.fetchSystemCategories()
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func fetchCustomCategories() async throws -> [ProductCategory] {
        do {
            return try await categoryRepository.fetchCustomCategories()
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func createCustomCategory(name: String, icon: String, colorHex: String?) async throws -> ProductCategory {
        // 重複チェック
        do {
            if let existingCategory = try await categoryRepository.fetchByName(name) {
                throw UseCaseError.invalidInput
            }
        } catch {
            // 既存カテゴリが見つからない場合は正常
        }
        
        do {
            // ソート順序を決定（既存のカスタムカテゴリの最大値 + 1）
            let customCategories = try await fetchCustomCategories()
            let maxSortOrder = customCategories.map { $0.sortOrder }.max() ?? 999
            
            return try await categoryRepository.create(
                name: name,
                icon: icon,
                colorHex: colorHex,
                sortOrder: Int(maxSortOrder) + 1
            )
        } catch {
            throw UseCaseError.saveFailed
        }
    }
    
    func updateCategory(_ category: ProductCategory) async throws {
        do {
            try await categoryRepository.update(category)
            try await categoryRepository.updateStatistics(category)
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func deleteCategory(_ category: ProductCategory) async throws {
        // システムカテゴリは削除不可
        if category.isSystemCategory {
            throw UseCaseError.invalidInput
        }
        
        // 使用されているカテゴリかチェック
        if category.productCount > 0 {
            throw UseCaseError.invalidInput
        }
        
        do {
            try await categoryRepository.delete(category)
        } catch {
            throw UseCaseError.deleteFailed
        }
    }
    
    func initializeSystemCategories() async throws {
        do {
            try await categoryRepository.createDefaultSystemCategories()
        } catch {
            throw UseCaseError.saveFailed
        }
    }
    
    // MARK: - Additional Business Logic Methods
    
    func searchCategories(keyword: String) async throws -> [ProductCategory] {
        do {
            return try await categoryRepository.search(keyword: keyword)
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func getMostUsedCategories(limit: Int = 5) async throws -> [ProductCategory] {
        do {
            let allCategories = try await fetchAllCategories()
            return Array(allCategories
                .sorted { $0.productCount > $1.productCount }
                .prefix(limit))
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func reorderCategories(_ categories: [ProductCategory]) async throws {
        do {
            for (index, category) in categories.enumerated() {
                category.sortOrder = Int32(index)
                try await categoryRepository.update(category)
            }
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func getCategoryWithProducts(_ category: ProductCategory) async throws -> CategoryWithProducts {
        // カテゴリに紐づく商品情報も含めて返す
        do {
            try await categoryRepository.updateStatistics(category)
            
            return CategoryWithProducts(
                category: category,
                productCount: Int(category.productCount),
                lastUsed: category.lastUpdated ?? Date.distantPast
            )
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func suggestCategoriesFor(productName: String) async throws -> [ProductCategory] {
        // 商品名から適切なカテゴリを推測
        let productNameLower = productName.lowercased()
        let allCategories = try await fetchAllCategories()
        
        var suggestions: [ProductCategory] = []
        
        // キーワードベースの推測
        for category in allCategories {
            let categoryKeywords = getCategoryKeywords(for: category)
            
            for keyword in categoryKeywords {
                if productNameLower.contains(keyword.lowercased()) {
                    suggestions.append(category)
                    break
                }
            }
        }
        
        // 使用頻度順にソート
        return suggestions.sorted { $0.productCount > $1.productCount }
    }
    
    // MARK: - Private Helper Methods
    
    private func getCategoryKeywords(for category: ProductCategory) -> [String] {
        // カテゴリ名から関連キーワードを生成
        guard let categoryName = category.name else { return [] }
        
        switch categoryName {
        case "食品":
            return ["食品", "食べ物", "フード", "米", "パン", "肉", "魚", "野菜", "果物"]
        case "飲料":
            return ["飲み物", "ドリンク", "お茶", "コーヒー", "ジュース", "水", "ビール", "酒"]
        case "日用品":
            return ["洗剤", "シャンプー", "石鹸", "歯磨き", "ティッシュ", "トイレットペーパー"]
        case "冷凍食品":
            return ["冷凍", "フローズン", "アイス", "冷食"]
        case "お菓子":
            return ["菓子", "スナック", "チョコ", "クッキー", "飴", "ガム"]
        case "調味料":
            return ["醤油", "味噌", "塩", "砂糖", "油", "酢", "だし", "スパイス"]
        default:
            return [categoryName]
        }
    }
}

// MARK: - Supporting Data Types

struct CategoryWithProducts {
    let category: ProductCategory
    let productCount: Int
    let lastUsed: Date
}
