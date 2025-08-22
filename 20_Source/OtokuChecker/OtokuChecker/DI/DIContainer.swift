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
    
    private lazy var _productCategoryRepository: any ProductCategoryRepositoryProtocol = {
        return CoreDataProductCategoryRepository(context: getManagedObjectContext())
    }()
    
    private lazy var _productGroupRepository: any ProductGroupRepositoryProtocol = {
        return CoreDataProductGroupRepository(context: getManagedObjectContext())
    }()
    
    private lazy var _productRecordRepository: any ProductRecordRepositoryProtocol = {
        return CoreDataProductRecordRepository(context: getManagedObjectContext())
    }()
    
    private lazy var _comparisonHistoryRepository: any ComparisonHistoryRepositoryProtocol = {
        return CoreDataComparisonHistoryRepository(context: getManagedObjectContext())
    }()
    
    // MARK: - Service Instances (Lazy Loading)
    
    private lazy var _comparisonService: ComparisonService = {
        return ComparisonService()
    }()
    
    // MARK: - UseCase Instances (Lazy Loading)
    
    private lazy var _comparisonUseCase: any ComparisonUseCaseProtocol = {
        return ComparisonUseCase(
            comparisonService: getComparisonService(),
            comparisonHistoryRepository: getComparisonHistoryRepository(),
            productRecordRepository: getProductRecordRepository()
        )
    }()
    
    private lazy var _productManagementUseCase: any ProductManagementUseCaseProtocol = {
        return ProductManagementUseCase(
            productRecordRepository: getProductRecordRepository(),
            productGroupRepository: getProductGroupRepository(),
            categoryRepository: getProductCategoryRepository()
        )
    }()
    
    private lazy var _historyManagementUseCase: any HistoryManagementUseCaseProtocol = {
        return HistoryManagementUseCase(
            comparisonHistoryRepository: getComparisonHistoryRepository()
        )
    }()
    
    private lazy var _categoryManagementUseCase: any CategoryManagementUseCaseProtocol = {
        return CategoryManagementUseCase(
            categoryRepository: getProductCategoryRepository()
        )
    }()
    
    // MARK: - DIContainerProtocol Implementation
    
    func getProductCategoryRepository() -> any ProductCategoryRepositoryProtocol {
        return _productCategoryRepository
    }
    
    func getProductGroupRepository() -> any ProductGroupRepositoryProtocol {
        return _productGroupRepository
    }
    
    func getProductRecordRepository() -> any ProductRecordRepositoryProtocol {
        return _productRecordRepository
    }
    
    func getComparisonHistoryRepository() -> any ComparisonHistoryRepositoryProtocol {
        return _comparisonHistoryRepository
    }
    
    func getComparisonService() -> ComparisonService {
        return _comparisonService
    }
    
    func getComparisonUseCase() -> any ComparisonUseCaseProtocol {
        return _comparisonUseCase
    }
    
    func getProductManagementUseCase() -> any ProductManagementUseCaseProtocol {
        return _productManagementUseCase
    }
    
    func getHistoryManagementUseCase() -> any HistoryManagementUseCaseProtocol {
        return _historyManagementUseCase
    }
    
    func getCategoryManagementUseCase() -> any CategoryManagementUseCaseProtocol {
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
    
    func getProductCategoryRepository() -> any ProductCategoryRepositoryProtocol {
        return MockProductCategoryRepository()
    }
    
    func getProductGroupRepository() -> any ProductGroupRepositoryProtocol {
        return MockProductGroupRepository()
    }
    
    func getProductRecordRepository() -> any ProductRecordRepositoryProtocol {
        return MockProductRecordRepository()
    }
    
    func getComparisonHistoryRepository() -> any ComparisonHistoryRepositoryProtocol {
        return MockComparisonHistoryRepository()
    }
    
    // MARK: - Real Services
    
    func getComparisonService() -> ComparisonService {
        return ComparisonService()
    }
    
    // MARK: - UseCases with Mock Dependencies
    
    func getComparisonUseCase() -> any ComparisonUseCaseProtocol {
        return ComparisonUseCase(
            comparisonService: getComparisonService(),
            comparisonHistoryRepository: getComparisonHistoryRepository(),
            productRecordRepository: getProductRecordRepository()
        )
    }
    
    func getProductManagementUseCase() -> any ProductManagementUseCaseProtocol {
        return ProductManagementUseCase(
            productRecordRepository: getProductRecordRepository(),
            productGroupRepository: getProductGroupRepository(),
            categoryRepository: getProductCategoryRepository()
        )
    }
    
    func getHistoryManagementUseCase() -> any HistoryManagementUseCaseProtocol {
        return HistoryManagementUseCase(
            comparisonHistoryRepository: getComparisonHistoryRepository()
        )
    }
    
    func getCategoryManagementUseCase() -> any CategoryManagementUseCaseProtocol {
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
