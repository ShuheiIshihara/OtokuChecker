//
//  BaseViewModel.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Base View Model Protocol

@MainActor
protocol BaseViewModelProtocol: ObservableObject {
    var isLoading: Bool { get set }
    var errorMessage: String? { get set }
    var hasError: Bool { get }
    
    func clearError()
    func handleError(_ error: Error)
}

// MARK: - Loading State

enum LoadingState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
    
    var isLoading: Bool {
        switch self {
        case .loading:
            return true
        default:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .error(let message):
            return message
        default:
            return nil
        }
    }
}

// MARK: - Base View Model

@MainActor
class BaseViewModel: BaseViewModelProtocol {
    
    // MARK: - Published Properties
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var currentError: AppError? = nil
    @Published var loadingState: LoadingState = .idle
    
    // MARK: - Computed Properties
    
    var hasError: Bool {
        currentError != nil || errorMessage != nil
    }
    
    // MARK: - Internal Properties (accessible by subclasses)
    
    internal var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupBindings()
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        errorMessage = nil
        currentError = nil
        if case .error = loadingState {
            loadingState = .idle
        }
    }
    
    func handleError(_ error: Error) {
        let appError = error.asAppError()
        
        // エラー状態の更新
        errorMessage = appError.userMessage
        currentError = appError
        loadingState = .error(appError.userMessage)
        isLoading = false
        
        // エラーハンドラーに委譲（ログ・表示・リカバリーを含む）
        ErrorHandler.shared.handle(
            appError,
            strategy: .queued,
            context: String(describing: type(of: self))
        )
    }
    
    /// ViewModel固有のエラーハンドリング（カスタム戦略付き）
    func handleError(_ error: Error, strategy: ErrorHandler.ErrorHandlingStrategy) {
        let appError = error.asAppError()
        
        // エラー状態の更新
        errorMessage = appError.userMessage
        currentError = appError
        loadingState = .error(appError.userMessage)
        isLoading = false
        
        // エラーハンドラーに委譲（ログ・表示・リカバリーを含む）
        ErrorHandler.shared.handle(
            appError,
            strategy: strategy,
            context: String(describing: type(of: self))
        )
    }
    
    /// ViewModel固有のエラーハンドリング（便利メソッド）
    func handleError(_ error: Error, showToast: Bool = false, allowRetry: Bool = false) {
        let strategy: ErrorHandler.ErrorHandlingStrategy = showToast ? .immediate : .queued
        handleError(error, strategy: strategy)
    }
    
    /// バリデーションエラーのハンドリング
    func handleValidationErrors(_ errors: [ComparisonValidationError]) {
        let formError = ErrorHandler.shared.handleValidationErrors(errors)
        handleError(formError, strategy: .immediate)
    }
    
    /// 買い物中のエラーハンドリング（特別な考慮事項あり）
    func handleShoppingError(_ error: ShoppingContextError) {
        let appError = AppError.shoppingContextError(error)
        
        // 買い物中は邪魔にならないよう配慮
        let strategy: ErrorHandler.ErrorHandlingStrategy
        switch error {
        case .batteryLowWarning, .timeConstraintViolation:
            strategy = .immediate // 重要なエラーは即座に表示
        default:
            strategy = .silent // その他は静かに処理
        }
        
        handleError(appError, strategy: strategy)
    }
    
    // MARK: - Loading State Management
    
    func setLoadingState(_ state: LoadingState) {
        loadingState = state
        isLoading = state.isLoading
        
        if let error = state.errorMessage {
            errorMessage = error
        } else if case .loaded = state, case .error = loadingState {
            // 成功時にエラーをクリア
            errorMessage = nil
        }
    }
    
    func withLoading<T>(_ operation: @escaping () async throws -> T) async -> T? {
        setLoadingState(.loading)
        
        do {
            let result = try await operation()
            setLoadingState(.loaded)
            return result
        } catch {
            handleError(error)
            return nil
        }
    }
    
    func withLoadingVoid(_ operation: @escaping () async throws -> Void) async {
        setLoadingState(.loading)
        
        do {
            try await operation()
            setLoadingState(.loaded)
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // LoadingStateの変更をisLoadingとerrorMessageに反映
        $loadingState
            .map { $0.isLoading }
            .removeDuplicates()
            .assign(to: &$isLoading)
        
        $loadingState
            .map { $0.errorMessage }
            .removeDuplicates()
            .assign(to: &$errorMessage)
    }
}

// MARK: - View State Protocol

protocol ViewStateProtocol {
    var isEmpty: Bool { get }
    var hasData: Bool { get }
}

// MARK: - List View Model Base

@MainActor
class BaseListViewModel<T: Identifiable>: BaseViewModel {
    
    // MARK: - Published Properties
    
    @Published var items: [T] = []
    @Published var filteredItems: [T] = []
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    
    // MARK: - Computed Properties
    
    var isEmpty: Bool {
        items.isEmpty
    }
    
    var hasData: Bool {
        !items.isEmpty
    }
    
    var displayItems: [T] {
        isSearching ? filteredItems : items
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupSearchBindings()
    }
    
    // MARK: - Search Methods
    
    func startSearch() {
        isSearching = true
        performSearch()
    }
    
    func endSearch() {
        isSearching = false
        searchText = ""
        filteredItems = []
    }
    
    func performSearch() {
        guard isSearching, !searchText.isEmpty else {
            filteredItems = []
            return
        }
        
        filteredItems = filterItems(items, with: searchText)
    }
    
    // MARK: - Abstract Methods (Override in subclasses)
    
    func filterItems(_ items: [T], with searchText: String) -> [T] {
        // サブクラスでオーバーライドする
        return items
    }
    
    func refreshData() async {
        // サブクラスでオーバーライドする
    }
    
    // MARK: - Private Methods
    
    private func setupSearchBindings() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.performSearch()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Form View Model Base

@MainActor
class BaseFormViewModel: BaseViewModel {
    
    // MARK: - Published Properties
    
    @Published var isValid: Bool = false
    @Published var validationErrors: [String: String] = [:]
    @Published var comparisonValidationErrors: [ComparisonValidationError] = []
    @Published var isDirty: Bool = false
    
    // MARK: - Computed Properties
    
    var hasValidationErrors: Bool {
        !validationErrors.isEmpty || !comparisonValidationErrors.isEmpty
    }
    
    // MARK: - Form Methods
    
    func validateForm() {
        let errors = performValidation()
        let comparisonErrors = performComparisonValidation()
        
        validationErrors = errors
        comparisonValidationErrors = comparisonErrors
        isValid = errors.isEmpty && comparisonErrors.isEmpty
        
        // バリデーションエラーがある場合はエラーハンドラーに通知
        if !comparisonErrors.isEmpty {
            handleValidationErrors(comparisonErrors)
        }
    }
    
    func clearValidationErrors() {
        validationErrors = [:]
        comparisonValidationErrors = []
    }
    
    func clearValidationError(for field: String) {
        validationErrors.removeValue(forKey: field)
        isValid = validationErrors.isEmpty
    }
    
    func addValidationError(for field: String, message: String) {
        validationErrors[field] = message
        isValid = false
    }
    
    func markAsDirty() {
        isDirty = true
    }
    
    func markAsClean() {
        isDirty = false
    }
    
    // MARK: - Abstract Methods (Override in subclasses)
    
    func performValidation() -> [String: String] {
        // サブクラスでオーバーライドする
        return [:]
    }
    
    func performComparisonValidation() -> [ComparisonValidationError] {
        // サブクラスでオーバーライドする
        return []
    }
    
    func resetForm() {
        // サブクラスでオーバーライドする
        clearValidationErrors()
        markAsClean()
    }
}

// MARK: - View Model State Management Extension

extension BaseViewModel {
    
    @discardableResult
    func executeTask<T>(_ task: @escaping () async throws -> T) -> Task<T?, Never> {
        return Task { @MainActor in
            return await withLoading {
                try await task()
            }
        }
    }
    
    @discardableResult
    func executeVoidTask(_ task: @escaping () async throws -> Void) -> Task<Void, Never> {
        return Task { @MainActor in
            await withLoadingVoid {
                try await task()
            }
        }
    }
}

// MARK: - View Model Factory Protocol

@MainActor
protocol ViewModelFactory {
    func makeMainComparisonViewModel() -> MainComparisonViewModel
    func makeDataEntryViewModel() -> DataEntryViewModel
    func makeHistoryViewModel() -> HistoryViewModel
    func makeSettingsViewModel() -> SettingsViewModel
}

// MARK: - Default View Model Factory

class DefaultViewModelFactory: ViewModelFactory {
    private let diContainer: DIContainerProtocol
    
    init(diContainer: DIContainerProtocol = DIContainer.shared) {
        self.diContainer = diContainer
    }
    
    @MainActor
    func makeMainComparisonViewModel() -> MainComparisonViewModel {
        return MainComparisonViewModel(
            comparisonUseCase: diContainer.getComparisonUseCase(),
            productManagementUseCase: diContainer.getProductManagementUseCase()
        )
    }
    
    @MainActor
    func makeDataEntryViewModel() -> DataEntryViewModel {
        return DataEntryViewModel(
            productManagementUseCase: diContainer.getProductManagementUseCase(),
            categoryManagementUseCase: diContainer.getCategoryManagementUseCase()
        )
    }
    
    @MainActor
    func makeHistoryViewModel() -> HistoryViewModel {
        return HistoryViewModel(
            historyManagementUseCase: diContainer.getHistoryManagementUseCase(),
            productManagementUseCase: diContainer.getProductManagementUseCase()
        )
    }
    
    @MainActor
    func makeSettingsViewModel() -> SettingsViewModel {
        return SettingsViewModel(
            categoryManagementUseCase: diContainer.getCategoryManagementUseCase()
        )
    }
}