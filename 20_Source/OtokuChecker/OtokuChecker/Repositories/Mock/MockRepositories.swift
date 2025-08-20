//
//  MockRepositories.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/20.
//

import Foundation

// MARK: - Mock Product Category Repository

class MockProductCategoryRepository: ProductCategoryRepositoryProtocol {
    
    private var categories: [MockProductCategory] = []
    private var nextId = 1
    
    init() {
        setupDefaultCategories()
    }
    
    func create(name: String, icon: String, colorHex: String?, sortOrder: Int?) async throws -> ProductCategory {
        let category = MockProductCategory(
            id: nextId,
            name: name,
            icon: icon,
            colorHex: colorHex ?? "#007AFF",
            sortOrder: sortOrder ?? 0
        )
        nextId += 1
        categories.append(category)
        
        // MockをCore Dataオブジェクトに変換
        let coreDataCategory = ProductCategory(context: PersistenceController.shared.container.viewContext)
        coreDataCategory.entityID = category.entityID
        coreDataCategory.name = category.name
        coreDataCategory.icon = category.icon
        coreDataCategory.colorHex = category.colorHex
        coreDataCategory.sortOrder = category.sortOrder
        coreDataCategory.averageUnitPrice = NSDecimalNumber(decimal: category.averageUnitPrice)
        coreDataCategory.productCount = category.productCount
        coreDataCategory.deletedFlag = category.deletedFlag
        coreDataCategory.isSystemCategory = category.isSystemCategory
        coreDataCategory.createdAt = category.createdAt
        coreDataCategory.updatedAt = category.updatedAt
        coreDataCategory.lastUpdated = category.lastUpdated
        
        return coreDataCategory
    }
    
    func fetchAll() async throws -> [ProductCategory] {
        let filteredCategories = categories.filter { category in 
            return category.deletedFlag == false 
        }
        return filteredCategories.map { mockCategory in
            let category = ProductCategory(context: PersistenceController.shared.container.viewContext)
            category.entityID = mockCategory.entityID
            category.name = mockCategory.name
            category.icon = mockCategory.icon
            category.colorHex = mockCategory.colorHex
            category.sortOrder = mockCategory.sortOrder
            category.averageUnitPrice = NSDecimalNumber(decimal: mockCategory.averageUnitPrice)
            category.productCount = mockCategory.productCount
            category.deletedFlag = mockCategory.deletedFlag
            category.isSystemCategory = mockCategory.isSystemCategory
            category.createdAt = mockCategory.createdAt
            category.updatedAt = mockCategory.updatedAt
            category.lastUpdated = mockCategory.lastUpdated
            return category
        }
    }
    
    func fetchById(_ id: UUID) async throws -> ProductCategory? {
        guard let mockCategory = categories.first(where: { $0.entityID == id && !$0.deletedFlag }) else {
            return nil
        }
        
        // MockをCore Dataオブジェクトに変換
        let coreDataCategory = ProductCategory(context: PersistenceController.shared.container.viewContext)
        coreDataCategory.entityID = mockCategory.entityID
        coreDataCategory.name = mockCategory.name
        coreDataCategory.icon = mockCategory.icon
        coreDataCategory.colorHex = mockCategory.colorHex
        coreDataCategory.sortOrder = mockCategory.sortOrder
        coreDataCategory.averageUnitPrice = NSDecimalNumber(decimal: mockCategory.averageUnitPrice)
        coreDataCategory.productCount = mockCategory.productCount
        coreDataCategory.deletedFlag = mockCategory.deletedFlag
        coreDataCategory.isSystemCategory = mockCategory.isSystemCategory
        coreDataCategory.createdAt = mockCategory.createdAt
        coreDataCategory.updatedAt = mockCategory.updatedAt
        coreDataCategory.lastUpdated = mockCategory.lastUpdated
        
        return coreDataCategory
    }
    
    func update(_ category: ProductCategory) async throws {
        if let index = categories.firstIndex(where: { $0.entityID == category.entityID }) {
            categories[index].updatedAt = Date()
        }
    }
    
    func delete(_ category: ProductCategory) async throws {
        if let index = categories.firstIndex(where: { $0.entityID == category.entityID }) {
            categories[index].deletedFlag = true
        }
    }
    
    func save() async throws {
        // Mock implementation - no actual persistence needed
    }
    
    func fetch() async throws -> [ProductCategory] {
        return try await fetchAll()
    }
    
    func fetchSystemCategories() async throws -> [ProductCategory] {
        let filteredCategories = categories.filter { $0.isSystemCategory && !$0.deletedFlag }
        return filteredCategories.map { convertToProductCategory($0) }
    }
    
    func fetchCustomCategories() async throws -> [ProductCategory] {
        let filteredCategories = categories.filter { !$0.isSystemCategory && !$0.deletedFlag }
        return filteredCategories.map { convertToProductCategory($0) }
    }
    
    func fetchByName(_ name: String) async throws -> ProductCategory? {
        guard let mockCategory = categories.first(where: { $0.name == name && !$0.deletedFlag }) else {
            return nil
        }
        return convertToProductCategory(mockCategory)
    }
    
    func search(keyword: String) async throws -> [ProductCategory] {
        let filteredCategories = categories.filter { 
            $0.name.localizedCaseInsensitiveContains(keyword) && !$0.deletedFlag
        }
        return filteredCategories.map { convertToProductCategory($0) }
    }
    
    func createDefaultSystemCategories() async throws {
        // Already created in init
    }
    
    func updateStatistics(_ category: ProductCategory) async throws {
        // Mock implementation
    }
    
    private func convertToProductCategory(_ mockCategory: MockProductCategory) -> ProductCategory {
        let category = ProductCategory(context: PersistenceController.shared.container.viewContext)
        category.entityID = mockCategory.entityID
        category.name = mockCategory.name
        category.icon = mockCategory.icon
        category.colorHex = mockCategory.colorHex
        category.sortOrder = mockCategory.sortOrder
        category.averageUnitPrice = NSDecimalNumber(decimal: mockCategory.averageUnitPrice)
        category.productCount = mockCategory.productCount
        category.deletedFlag = mockCategory.deletedFlag
        category.isSystemCategory = mockCategory.isSystemCategory
        category.createdAt = mockCategory.createdAt
        category.updatedAt = mockCategory.updatedAt
        category.lastUpdated = mockCategory.lastUpdated
        return category
    }
    
    private func setupDefaultCategories() {
        let defaultCategories = [
            ("全て", "📁", "#007AFF", 0),
            ("食料品", "🍎", "#FF9500", 1),
            ("日用品", "🧴", "#34C759", 2),
            ("その他", "📦", "#8E8E93", 99)
        ]
        
        for (name, icon, color, sortOrder) in defaultCategories {
            let category = MockProductCategory(
                id: nextId,
                name: name,
                icon: icon,
                colorHex: color,
                sortOrder: sortOrder
            )
            category.isSystemCategory = true
            categories.append(category)
            nextId += 1
        }
    }
}

// MARK: - Mock Product Group Repository

class MockProductGroupRepository: ProductGroupRepositoryProtocol {
    
    private var groups: [MockProductGroup] = []
    private var nextId = 1
    
    func create(productName: String, productType: String?, category: ProductCategory?) async throws -> ProductGroup {
        let group = MockProductGroup(
            id: nextId,
            productName: productName,
            productType: productType
        )
        nextId += 1
        groups.append(group)
        return convertToProductGroup(group)
    }
    
    func fetchAll() async throws -> [ProductGroup] {
        let filteredGroups = groups.filter { !$0.deletedFlag }
        return filteredGroups.map { convertToProductGroup($0) }
    }
    
    func fetchById(_ id: UUID) async throws -> ProductGroup? {
        guard let mockGroup = groups.first(where: { $0.entityID == id && !$0.deletedFlag }) else {
            return nil
        }
        return convertToProductGroup(mockGroup)
    }
    
    func update(_ group: ProductGroup) async throws {
        if let index = groups.firstIndex(where: { $0.entityID == group.entityID }) {
            groups[index].updatedAt = Date()
        }
    }
    
    func delete(_ group: ProductGroup) async throws {
        if let index = groups.firstIndex(where: { $0.entityID == group.entityID }) {
            groups[index].deletedFlag = true
        }
    }
    
    func save() async throws {}
    
    func fetch() async throws -> [ProductGroup] {
        return try await fetchAll()
    }
    
    func fetchByCategory(_ category: ProductCategory) async throws -> [ProductGroup] {
        let filteredGroups = groups.filter { !$0.deletedFlag }
        return filteredGroups.map { convertToProductGroup($0) }
    }
    
    func fetchByProductName(_ name: String) async throws -> ProductGroup? {
        guard let mockGroup = groups.first(where: { $0.productName == name && !$0.deletedFlag }) else {
            return nil
        }
        return convertToProductGroup(mockGroup)
    }
    
    func search(keyword: String) async throws -> [ProductGroup] {
        let filteredGroups = groups.filter { 
            $0.productName.localizedCaseInsensitiveContains(keyword) && !$0.deletedFlag
        }
        return filteredGroups.map { convertToProductGroup($0) }
    }
    
    func searchByNormalizedName(_ normalizedName: String) async throws -> [ProductGroup] {
        let filteredGroups = groups.filter { 
            $0.normalizedName.localizedCaseInsensitiveContains(normalizedName) && !$0.deletedFlag
        }
        return filteredGroups.map { convertToProductGroup($0) }
    }
    
    func fetchTopGroups(limit: Int) async throws -> [ProductGroup] {
        let filteredGroups = Array(groups.filter { !$0.deletedFlag }.prefix(limit))
        return filteredGroups.map { convertToProductGroup($0) }
    }
    
    func fetchRecentGroups(limit: Int) async throws -> [ProductGroup] {
        let filteredGroups = Array(groups.filter { !$0.deletedFlag }.prefix(limit))
        return filteredGroups.map { convertToProductGroup($0) }
    }
    
    func updateStatistics(_ group: ProductGroup) async throws {}
    
    private func convertToProductGroup(_ mockGroup: MockProductGroup) -> ProductGroup {
        let group = ProductGroup(context: PersistenceController.shared.container.viewContext)
        group.entityID = mockGroup.entityID
        group.productName = mockGroup.productName
        group.normalizedName = mockGroup.normalizedName
        group.productType = mockGroup.productType
        group.recordCount = mockGroup.recordCount
        group.averageUnitPrice = NSDecimalNumber(decimal: mockGroup.averageUnitPrice)
        group.lowestUnitPrice = NSDecimalNumber(decimal: mockGroup.lowestUnitPrice)
        group.lowestPriceStoreName = mockGroup.lowestPriceStoreName
        group.lastRecordDate = mockGroup.lastRecordDate
        group.deletedFlag = mockGroup.deletedFlag
        group.createdAt = mockGroup.createdAt
        group.updatedAt = mockGroup.updatedAt
        return group
    }
}

// MARK: - Mock Models

class MockProductCategory {
    var entityID: UUID
    var name: String
    var icon: String
    var colorHex: String
    var sortOrder: Int32
    var averageUnitPrice: Decimal = 0
    var productCount: Int32 = 0
    var deletedFlag: Bool = false
    var isSystemCategory: Bool = false
    var createdAt: Date
    var updatedAt: Date
    var lastUpdated: Date?
    
    init(id: Int, name: String, icon: String, colorHex: String, sortOrder: Int) {
        self.entityID = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = Int32(sortOrder)
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

class MockProductGroup {
    var entityID: UUID
    var productName: String
    var normalizedName: String
    var productType: String?
    var recordCount: Int32 = 0
    var averageUnitPrice: Decimal = 0
    var lowestUnitPrice: Decimal = 0
    var lowestPriceStoreName: String = ""
    var lastRecordDate: Date?
    var deletedFlag: Bool = false
    var createdAt: Date
    var updatedAt: Date
    
    init(id: Int, productName: String, productType: String?) {
        self.entityID = UUID()
        self.productName = productName
        self.normalizedName = productName.lowercased()
        self.productType = productType
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Repository Container

class MockRepositoryContainer {
    let productCategoryRepository: any ProductCategoryRepositoryProtocol
    let productGroupRepository: any ProductGroupRepositoryProtocol
    
    init() {
        self.productCategoryRepository = MockProductCategoryRepository()
        self.productGroupRepository = MockProductGroupRepository()
    }
}

// MARK: - Sample Data Provider

extension MockRepositoryContainer {
    
    func setupSampleData() async throws {
        // サンプルカテゴリは既に初期化で作成済み
        
        // サンプル商品グループを作成
        let foodCategory = try await productCategoryRepository.fetchByName("食料品")
        let dailyCategory = try await productCategoryRepository.fetchByName("日用品")
        
        let sampleProducts = [
            ("お米（5kg）", "米・雑穀", foodCategory),
            ("牛乳（1L）", "乳製品", foodCategory),
            ("食パン", "パン", foodCategory),
            ("卵（10個入り）", "卵", foodCategory),
            ("シャンプー", "ヘアケア", dailyCategory),
            ("洗剤", "洗剤・柔軟剤", dailyCategory)
        ]
        
        for (productName, productType, category) in sampleProducts {
            _ = try await productGroupRepository.create(
                productName: productName,
                productType: productType,
                category: category
            )
        }
    }
}
