//
//  DIContainer.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation
import CoreData

// MARK: - Dependency Injection Container Protocol

protocol DIContainerProtocol {
    // MARK: - Repositories
    func getProductCategoryRepository() -> any ProductCategoryRepositoryProtocol
    func getProductGroupRepository() -> any ProductGroupRepositoryProtocol
    func getProductRecordRepository() -> any ProductRecordRepositoryProtocol
    func getComparisonHistoryRepository() -> any ComparisonHistoryRepositoryProtocol
    
    // MARK: - Services
    func getComparisonService() -> ComparisonService
    
    // MARK: - UseCases
    func getComparisonUseCase() -> any ComparisonUseCaseProtocol
    func getProductManagementUseCase() -> any ProductManagementUseCaseProtocol
    func getHistoryManagementUseCase() -> any HistoryManagementUseCaseProtocol
    func getCategoryManagementUseCase() -> any CategoryManagementUseCaseProtocol
    
    // MARK: - Core Data
    func getManagedObjectContext() -> NSManagedObjectContext
}

// MARK: - Production DI Container

class DIContainer: DIContainerProtocol {
    
    // MARK: - Singleton
    
    static let shared = DIContainer()
    
    private init() {}
    
    // MARK: - Core Data Context
    
    private lazy var persistenceController = PersistenceController.shared
    
    func getManagedObjectContext() -> NSManagedObjectContext {
        return persistenceController.container.viewContext
    }
    
    // MARK: - Repository Instances (Lazy Loading)
    
    private lazy var _productCategoryRepository: ProductCategoryRepositoryProtocol = {
        return CoreDataProductCategoryRepository(context: getManagedObjectContext())
    }()
    
    private lazy var _productGroupRepository: ProductGroupRepositoryProtocol = {
        return CoreDataProductGroupRepository(context: getManagedObjectContext())
    }()
    
    private lazy var _productRecordRepository: ProductRecordRepositoryProtocol = {
        return CoreDataProductRecordRepository(context: getManagedObjectContext())
    }()
    
    private lazy var _comparisonHistoryRepository: ComparisonHistoryRepositoryProtocol = {
        return CoreDataComparisonHistoryRepository(context: getManagedObjectContext())
    }()
    
    // MARK: - Service Instances (Lazy Loading)
    
    private lazy var _comparisonService: ComparisonService = {
        return ComparisonService()
    }()
    
    // MARK: - UseCase Instances (Lazy Loading)
    
    private lazy var _comparisonUseCase: ComparisonUseCaseProtocol = {
        return ComparisonUseCase(
            comparisonService: getComparisonService(),
            comparisonHistoryRepository: getComparisonHistoryRepository(),
            productRecordRepository: getProductRecordRepository()
        )
    }()
    
    private lazy var _productManagementUseCase: ProductManagementUseCaseProtocol = {
        return ProductManagementUseCase(
            productRecordRepository: getProductRecordRepository(),
            productGroupRepository: getProductGroupRepository(),
            categoryRepository: getProductCategoryRepository()
        )
    }()
    
    private lazy var _historyManagementUseCase: HistoryManagementUseCaseProtocol = {
        return HistoryManagementUseCase(
            comparisonHistoryRepository: getComparisonHistoryRepository()
        )
    }()
    
    private lazy var _categoryManagementUseCase: CategoryManagementUseCaseProtocol = {
        return CategoryManagementUseCase(
            categoryRepository: getProductCategoryRepository()
        )
    }()
    
    // MARK: - DIContainerProtocol Implementation
    
    func getProductCategoryRepository() -> ProductCategoryRepositoryProtocol {
        return _productCategoryRepository
    }
    
    func getProductGroupRepository() -> ProductGroupRepositoryProtocol {
        return _productGroupRepository
    }
    
    func getProductRecordRepository() -> ProductRecordRepositoryProtocol {
        return _productRecordRepository
    }
    
    func getComparisonHistoryRepository() -> ComparisonHistoryRepositoryProtocol {
        return _comparisonHistoryRepository
    }
    
    func getComparisonService() -> ComparisonService {
        return _comparisonService
    }
    
    func getComparisonUseCase() -> ComparisonUseCaseProtocol {
        return _comparisonUseCase
    }
    
    func getProductManagementUseCase() -> ProductManagementUseCaseProtocol {
        return _productManagementUseCase
    }
    
    func getHistoryManagementUseCase() -> HistoryManagementUseCaseProtocol {
        return _historyManagementUseCase
    }
    
    func getCategoryManagementUseCase() -> CategoryManagementUseCaseProtocol {
        return _categoryManagementUseCase
    }
}

// MARK: - Test DI Container

class TestDIContainer: DIContainerProtocol {
    
    // MARK: - Test Context
    
    private lazy var testContext: NSManagedObjectContext = {
        let container = NSPersistentContainer(name: "OtokuChecker")
        container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        container.loadPersistentStores { _, _ in }
        return container.viewContext
    }()
    
    func getManagedObjectContext() -> NSManagedObjectContext {
        return testContext
    }
    
    // MARK: - Mock Repositories
    
    func getProductCategoryRepository() -> ProductCategoryRepositoryProtocol {
        return MockProductCategoryRepository()
    }
    
    func getProductGroupRepository() -> ProductGroupRepositoryProtocol {
        return MockProductGroupRepository()
    }
    
    func getProductRecordRepository() -> ProductRecordRepositoryProtocol {
        return MockProductRecordRepository()
    }
    
    func getComparisonHistoryRepository() -> ComparisonHistoryRepositoryProtocol {
        return MockComparisonHistoryRepository()
    }
    
    // MARK: - Real Services
    
    func getComparisonService() -> ComparisonService {
        return ComparisonService()
    }
    
    // MARK: - UseCases with Mock Dependencies
    
    func getComparisonUseCase() -> ComparisonUseCaseProtocol {
        return ComparisonUseCase(
            comparisonService: getComparisonService(),
            comparisonHistoryRepository: getComparisonHistoryRepository(),
            productRecordRepository: getProductRecordRepository()
        )
    }
    
    func getProductManagementUseCase() -> ProductManagementUseCaseProtocol {
        return ProductManagementUseCase(
            productRecordRepository: getProductRecordRepository(),
            productGroupRepository: getProductGroupRepository(),
            categoryRepository: getProductCategoryRepository()
        )
    }
    
    func getHistoryManagementUseCase() -> HistoryManagementUseCaseProtocol {
        return HistoryManagementUseCase(
            comparisonHistoryRepository: getComparisonHistoryRepository()
        )
    }
    
    func getCategoryManagementUseCase() -> CategoryManagementUseCaseProtocol {
        return CategoryManagementUseCase(
            categoryRepository: getProductCategoryRepository()
        )
    }
}

// MARK: - DI Container Environment Key

private struct DIContainerKey: EnvironmentKey {
    static let defaultValue: DIContainerProtocol = DIContainer.shared
}

// MARK: - SwiftUI Environment Extension

import SwiftUI

extension EnvironmentValues {
    var diContainer: DIContainerProtocol {
        get { self[DIContainerKey.self] }
        set { self[DIContainerKey.self] = newValue }
    }
}

// MARK: - View Modifier for DI Container

struct DIContainerModifier: ViewModifier {
    let container: DIContainerProtocol
    
    func body(content: Content) -> some View {
        content
            .environment(\.diContainer, container)
    }
}

extension View {
    func diContainer(_ container: DIContainerProtocol) -> some View {
        modifier(DIContainerModifier(container: container))
    }
    
    func testDIContainer() -> some View {
        diContainer(TestDIContainer())
    }
}

// MARK: - Property Wrapper for Dependency Injection

@propertyWrapper
struct Injected<T> {
    private let getter: (DIContainerProtocol) -> T
    private var container: DIContainerProtocol?
    
    init(_ getter: @escaping (DIContainerProtocol) -> T) {
        self.getter = getter
    }
    
    var wrappedValue: T {
        get {
            let container = self.container ?? DIContainer.shared
            return getter(container)
        }
    }
    
    mutating func setContainer(_ container: DIContainerProtocol) {
        self.container = container
    }
}

// MARK: - Example Usage
//
// struct SomeViewModel {
//     @Injected({ $0.getComparisonUseCase() })
//     private var comparisonUseCase: any ComparisonUseCaseProtocol
// }
