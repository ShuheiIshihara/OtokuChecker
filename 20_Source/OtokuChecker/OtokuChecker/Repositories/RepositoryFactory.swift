//
//  RepositoryFactory.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/20.
//

import Foundation
import CoreData

/// Repository層のファクトリクラス
/// 本番とテスト環境でのRepository実装を切り替える
class RepositoryFactory {
    
    // MARK: - Properties
    
    private let context: NSManagedObjectContext?
    private let useMockData: Bool
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext?, useMockData: Bool = false) {
        self.context = context
        self.useMockData = useMockData
    }
    
    // MARK: - Repository Creation
    
    func createProductCategoryRepository() -> any ProductCategoryRepositoryProtocol {
        if useMockData {
            return MockProductCategoryRepository()
        } else {
            guard let context = context else {
                fatalError("Core Data context is required for production repositories")
            }
            return CoreDataProductCategoryRepository(context: context)
        }
    }
    
    func createProductGroupRepository() -> any ProductGroupRepositoryProtocol {
        if useMockData {
            return MockProductGroupRepository()
        } else {
            guard let context = context else {
                fatalError("Core Data context is required for production repositories")
            }
            return CoreDataProductGroupRepository(context: context)
        }
    }
    
    func createProductRecordRepository() -> any ProductRecordRepositoryProtocol {
        if useMockData {
            // MockProductRecordRepository is not implemented yet
            // Return a simple mock or implement it as needed
            fatalError("MockProductRecordRepository not implemented yet")
        } else {
            guard let context = context else {
                fatalError("Core Data context is required for production repositories")
            }
            return CoreDataProductRecordRepository(context: context)
        }
    }
    
    func createComparisonHistoryRepository() -> any ComparisonHistoryRepositoryProtocol {
        if useMockData {
            // MockComparisonHistoryRepository is not implemented yet
            // Return a simple mock or implement it as needed
            fatalError("MockComparisonHistoryRepository not implemented yet")
        } else {
            guard let context = context else {
                fatalError("Core Data context is required for production repositories")
            }
            return CoreDataComparisonHistoryRepository(context: context)
        }
    }
}

// MARK: - Repository Container

/// 全てのRepositoryを統合管理するコンテナ
class RepositoryContainer {
    
    // MARK: - Properties
    
    let productCategoryRepository: any ProductCategoryRepositoryProtocol
    let productGroupRepository: any ProductGroupRepositoryProtocol
    let productRecordRepository: any ProductRecordRepositoryProtocol
    let comparisonHistoryRepository: any ComparisonHistoryRepositoryProtocol
    
    // MARK: - Initialization
    
    init(factory: RepositoryFactory) {
        self.productCategoryRepository = factory.createProductCategoryRepository()
        self.productGroupRepository = factory.createProductGroupRepository()
        self.productRecordRepository = factory.createProductRecordRepository()
        self.comparisonHistoryRepository = factory.createComparisonHistoryRepository()
    }
    
    convenience init(context: NSManagedObjectContext) {
        let factory = RepositoryFactory(context: context, useMockData: false)
        self.init(factory: factory)
    }
    
    convenience init(useMockData: Bool = true) {
        let factory = RepositoryFactory(context: nil, useMockData: useMockData)
        self.init(factory: factory)
    }
    
    // MARK: - Initialization Helper
    
    /// システムカテゴリとサンプルデータの初期化
    func initializeData() async throws {
        try await productCategoryRepository.createDefaultSystemCategories()
    }
}

// MARK: - SwiftUI Preview Extension

extension RepositoryContainer {
    
    /// SwiftUI Preview用のサンプルデータ付きコンテナ
    static func preview() -> RepositoryContainer {
        let container = RepositoryContainer(useMockData: true)
        
        // サンプルデータの非同期初期化は個別に行う
        Task {
            try await container.initializeData()
        }
        
        return container
    }
}
