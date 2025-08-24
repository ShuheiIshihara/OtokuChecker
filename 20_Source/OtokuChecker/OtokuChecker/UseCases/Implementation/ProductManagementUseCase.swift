//
//  ProductManagementUseCase.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation

class ProductManagementUseCase: ProductManagementUseCaseProtocol {
    
    private let productRecordRepository: any ProductRecordRepositoryProtocol
    private let productGroupRepository: any ProductGroupRepositoryProtocol
    private let categoryRepository: any ProductCategoryRepositoryProtocol
    
    init(
        productRecordRepository: any ProductRecordRepositoryProtocol,
        productGroupRepository: any ProductGroupRepositoryProtocol,
        categoryRepository: any ProductCategoryRepositoryProtocol
    ) {
        self.productRecordRepository = productRecordRepository
        self.productGroupRepository = productGroupRepository
        self.categoryRepository = categoryRepository
    }
    
    // MARK: - BaseUseCase Implementation
    
    func execute(_ input: ProductManagementInput) async throws -> ProductManagementOutput {
        switch input.operation {
        case .save:
            guard let product = input.product else {
                throw UseCaseError.invalidInput
            }
            let savedProduct = try await saveProduct(product, category: nil)
            return ProductManagementOutput(products: nil, productGroups: nil, savedProduct: savedProduct)
            
        case .fetchRecent:
            let limit = input.limit ?? 10
            let products = try await fetchRecentProducts(limit: limit)
            return ProductManagementOutput(products: products, productGroups: nil, savedProduct: nil)
            
        case .fetchGroups:
            let groups = try await fetchProductGroups()
            return ProductManagementOutput(products: nil, productGroups: groups, savedProduct: nil)
            
        case .search:
            guard let keyword = input.searchKeyword else {
                throw UseCaseError.invalidInput
            }
            let products = try await searchProducts(keyword: keyword)
            return ProductManagementOutput(products: products, productGroups: nil, savedProduct: nil)
            
        case .update:
            guard let group = input.productGroup else {
                throw UseCaseError.invalidInput
            }
            try await updateProductGroup(group)
            return ProductManagementOutput(products: nil, productGroups: nil, savedProduct: nil)
            
        case .delete:
            throw UseCaseError.invalidInput // この操作にはProductRecordが必要
        }
    }
    
    // MARK: - ProductManagementUseCaseProtocol Implementation
    
    func saveProduct(_ product: ComparisonProduct, category: ProductCategory?) async throws -> ProductRecord {
        do {
            // 既存の商品グループを検索または作成
            let productGroup = try await findOrCreateProductGroup(for: product, category: category)
            
            // 商品レコードを作成
            let savedProduct = try await productRecordRepository.create(
                productName: product.name,
                originalPrice: product.price,
                quantity: product.quantity,
                unitType: product.unit.rawValue,
                storeName: nil, // UIで設定される場合は引数で受け取る
                origin: product.origin,
                productGroup: productGroup,
                category: category
            )
            
            // 商品グループの統計を更新
            try await productGroupRepository.updateStatistics(productGroup)
            
            return savedProduct
        } catch {
            throw UseCaseError.saveFailed
        }
    }
    
    func fetchRecentProducts(limit: Int) async throws -> [ProductRecord] {
        do {
            return try await productRecordRepository.fetchRecent(limit: limit)
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func fetchProductGroups() async throws -> [ProductGroup] {
        do {
            return try await productGroupRepository.fetchAll()
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func fetchProductGroup(by name: String) async throws -> ProductGroup? {
        do {
            return try await productGroupRepository.fetchByProductName(name)
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func updateProductGroup(_ group: ProductGroup) async throws {
        do {
            try await productGroupRepository.update(group)
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    func deleteProduct(_ product: ProductRecord) async throws {
        do {
            try await productRecordRepository.delete(product)
            
            // 商品グループの統計を更新
            if let productGroup = product.productGroup {
                try await productGroupRepository.updateStatistics(productGroup)
            }
        } catch {
            throw UseCaseError.deleteFailed
        }
    }
    
    func searchProducts(keyword: String) async throws -> [ProductRecord] {
        do {
            return try await productRecordRepository.search(keyword: keyword)
        } catch {
            throw UseCaseError.repositoryError(error)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func findOrCreateProductGroup(for product: ComparisonProduct, category: ProductCategory?) async throws -> ProductGroup {
        // 商品名の正規化
        let normalizedName = normalizeProductName(product.name)
        
        // 既存の商品グループを正規化された名前で検索
        let existingGroups = try await productGroupRepository.searchByNormalizedName(normalizedName)
        
        if let existingGroup = existingGroups.first {
            return existingGroup
        } else {
            // 新しい商品グループを作成
            return try await productGroupRepository.create(
                productName: product.name,
                productType: determineProductType(from: product),
                category: category
            )
        }
    }
    
    private func normalizeProductName(_ name: String) -> String {
        // 商品名の正規化処理
        // ひらがな→カタカナ、全角→半角など
        return name
            .applyingTransform(.fullwidthToHalfwidth, reverse: false)?
            .applyingTransform(.hiraganaToKatakana, reverse: false)?
            .uppercased() ?? name
    }
    
    private func determineProductType(from product: ComparisonProduct) -> String {
        // 単位から商品タイプを推定
        switch product.unit {
        case .gram, .kilogram:
            return "重量商品"
        case .milliliter, .liter, .cup, .gou:
            return "液体商品"
        case .piece, .pack, .bottle, .bag, .sheet, .slice:
            return "個数商品"
        }
    }
}