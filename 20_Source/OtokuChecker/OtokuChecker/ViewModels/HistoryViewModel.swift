//
//  HistoryViewModel.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class HistoryViewModel: BaseListViewModel<ProductRecord> {
    
    // MARK: - Dependencies
    
    private let historyManagementUseCase: any HistoryManagementUseCaseProtocol
    private let productManagementUseCase: any ProductManagementUseCaseProtocol
    
    // MARK: - Published Properties - View Mode
    
    @Published var viewMode: HistoryViewMode = .products
    @Published var sortMode: HistorySortMode = .dateDescending
    @Published var filterMode: HistoryFilterMode = .all
    
    // MARK: - Published Properties - Data
    
    @Published var comparisonHistory: [ComparisonHistory] = []
    @Published var productGroups: [ProductGroup] = []
    @Published var selectedProductGroup: ProductGroup?
    @Published var statistics: ComparisonStatistics?
    
    // MARK: - Published Properties - UI State
    
    @Published var showingDeleteConfirmation: Bool = false
    @Published var itemToDelete: (any Identifiable)?
    @Published var showingFilterSheet: Bool = false
    @Published var showingSortSheet: Bool = false
    @Published var showingStatsSheet: Bool = false
    
    // MARK: - Published Properties - Filter & Sort
    
    @Published var selectedDateRange: DateRange = .all
    @Published var selectedCategory: ProductCategory?
    @Published var selectedStore: String?
    @Published var priceRange: PriceRange = PriceRange()
    
    // MARK: - Computed Properties
    
    var displayData: [any Identifiable] {
        switch viewMode {
        case .products:
            return applySortAndFilter(items: items)
        case .comparisons:
            return applySortAndFilter(history: comparisonHistory)
        case .groups:
            return applySortAndFilter(groups: productGroups)
        }
    }
    
    override var isEmpty: Bool {
        switch viewMode {
        case .products:
            return items.isEmpty
        case .comparisons:
            return comparisonHistory.isEmpty
        case .groups:
            return productGroups.isEmpty
        }
    }
    
    var hasAnyData: Bool {
        !items.isEmpty || !comparisonHistory.isEmpty || !productGroups.isEmpty
    }
    
    // MARK: - Initialization
    
    init(
        historyManagementUseCase: any HistoryManagementUseCaseProtocol,
        productManagementUseCase: any ProductManagementUseCaseProtocol
    ) {
        self.historyManagementUseCase = historyManagementUseCase
        self.productManagementUseCase = productManagementUseCase
        
        super.init()
        
        setupBindings()
        loadInitialData()
    }
    
    // MARK: - Public Methods - Data Loading
    
    override func refreshData() async {
        await loadAllData()
    }
    
    func loadAllData() async {
        await withLoadingVoid {
            async let products = self.productManagementUseCase.fetchRecentProducts(limit: 100)
            async let history = self.historyManagementUseCase.fetchComparisonHistory(limit: 100)
            async let groups = self.productManagementUseCase.fetchProductGroups()
            async let stats = self.historyManagementUseCase.getComparisonStatistics()
            
            self.items = try await products
            self.comparisonHistory = try await history
            self.productGroups = try await groups
            
            let statsResult = try await stats
            self.statistics = ComparisonStatistics(
                totalComparisons: statsResult.totalComparisons,
                averageSavings: statsResult.averageSavings,
                totalProducts: self.items.count,
                totalGroups: self.productGroups.count
            )
        }
    }
    
    func loadProductsForGroup(_ group: ProductGroup) async {
        selectedProductGroup = group
        
        await withLoadingVoid {
            self.items = try await self.productManagementUseCase.execute(
                ProductManagementInput(
                    operation: .search,
                    product: nil,
                    productGroup: group,
                    searchKeyword: group.productName,
                    limit: nil
                )
            ).products ?? []
        }
    }
    
    // MARK: - Public Methods - View Mode
    
    func switchViewMode(_ mode: HistoryViewMode) {
        viewMode = mode
        searchText = ""
        isSearching = false
    }
    
    func switchSortMode(_ mode: HistorySortMode) {
        sortMode = mode
        showingSortSheet = false
    }
    
    func switchFilterMode(_ mode: HistoryFilterMode) {
        filterMode = mode
        showingFilterSheet = false
    }
    
    // MARK: - Public Methods - Actions
    
    func deleteItem(_ item: any Identifiable) {
        itemToDelete = item
        showingDeleteConfirmation = true
    }
    
    func confirmDelete() {
        guard let item = itemToDelete else { return }
        
        executeVoidTask {
            if let product = item as? ProductRecord {
                try await self.productManagementUseCase.deleteProduct(product)
                self.items.removeAll { $0.id == product.id }
            } else if let history = item as? ComparisonHistory {
                try await self.historyManagementUseCase.deleteHistoryItem(history)
                self.comparisonHistory.removeAll { $0.id == history.id }
            }
            
            self.itemToDelete = nil
            self.showingDeleteConfirmation = false
        }
    }
    
    func cancelDelete() {
        itemToDelete = nil
        showingDeleteConfirmation = false
    }
    
    // MARK: - Public Methods - Search & Filter
    
    override func filterItems(_ items: [ProductRecord], with searchText: String) -> [ProductRecord] {
        return items.filter { product in
            let name = product.productName?.localizedCaseInsensitiveContains(searchText) ?? false
            let store = product.storeName?.localizedCaseInsensitiveContains(searchText) ?? false
            return name || store
        }
    }
    
    private func filterHistory(_ history: [ComparisonHistory], with searchText: String) -> [ComparisonHistory] {
        return history.filter { item in
            let productA = item.productAName?.localizedCaseInsensitiveContains(searchText) ?? false
            let productB = item.productBName?.localizedCaseInsensitiveContains(searchText) ?? false
            return productA || productB
        }
    }
    
    private func filterGroups(_ groups: [ProductGroup], with searchText: String) -> [ProductGroup] {
        return groups.filter { group in
            group.productName?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }
    
    func applyDateFilter(_ range: DateRange) {
        selectedDateRange = range
        showingFilterSheet = false
    }
    
    func clearFilters() {
        selectedDateRange = .all
        selectedCategory = nil
        selectedStore = nil
        priceRange = PriceRange()
        filterMode = .all
        showingFilterSheet = false
    }
    
    // MARK: - Public Methods - Statistics
    
    func loadDetailedStatistics() {
        executeVoidTask {
            let stats = try await self.historyManagementUseCase.getComparisonStatistics()
            let mostCompared = try await self.historyManagementUseCase.getMostComparedProducts(limit: 10)
            
            self.statistics = ComparisonStatistics(
                totalComparisons: stats.totalComparisons,
                averageSavings: stats.averageSavings,
                totalProducts: self.items.count,
                totalGroups: self.productGroups.count,
                mostComparedProducts: mostCompared
            )
        }
        
        showingStatsSheet = true
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // View mode changes trigger data refresh
        $viewMode
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.refreshData()
                }
            }
            .store(in: &cancellables)
        
        // Sort mode changes trigger re-sorting
        $sortMode
            .dropFirst()
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        Task { @MainActor in
            await refreshData()
        }
    }
    
    private func applySortAndFilter<T: Identifiable>(items: [T]) -> [T] {
        var result = items
        
        // Apply search filter if searching
        if isSearching && !searchText.isEmpty {
            if let products = items as? [ProductRecord] {
                result = filterItems(products, with: searchText) as? [T] ?? result
            }
        }
        
        // Apply additional filters based on filter mode
        result = applyFilters(result)
        
        // Apply sorting
        return applySorting(result)
    }
    
    private func applySortAndFilter(history: [ComparisonHistory]) -> [ComparisonHistory] {
        var result = history
        
        if isSearching && !searchText.isEmpty {
            result = filterHistory(result, with: searchText)
        }
        
        return applySorting(result)
    }
    
    private func applySortAndFilter(groups: [ProductGroup]) -> [ProductGroup] {
        var result = groups
        
        if isSearching && !searchText.isEmpty {
            result = filterGroups(result, with: searchText)
        }
        
        return applySorting(result)
    }
    
    private func applyFilters<T: Identifiable>(_ items: [T]) -> [T] {
        switch filterMode {
        case .all:
            return items
        case .recent:
            // 最近のアイテムのみ (過去7日間)
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            if let products = items as? [ProductRecord] {
                return products.filter { ($0.createdAt ?? Date.distantPast) >= cutoffDate } as? [T] ?? items
            }
            return items
        case .favorites:
            // お気に入り (よく使われる商品グループ)
            if let products = items as? [ProductRecord] {
                return products.filter { ($0.productGroup?.recordCount ?? 0) > 3 } as? [T] ?? items
            }
            return items
        }
    }
    
    private func applySorting<T: Identifiable>(_ items: [T]) -> [T] {
        switch sortMode {
        case .dateAscending:
            if let products = items as? [ProductRecord] {
                return products.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) } as? [T] ?? items
            }
        case .dateDescending:
            if let products = items as? [ProductRecord] {
                return products.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) } as? [T] ?? items
            }
        case .nameAscending:
            if let products = items as? [ProductRecord] {
                return products.sorted { ($0.productName ?? "") < ($1.productName ?? "") } as? [T] ?? items
            }
        case .nameDescending:
            if let products = items as? [ProductRecord] {
                return products.sorted { ($0.productName ?? "") > ($1.productName ?? "") } as? [T] ?? items
            }
        case .priceAscending:
            if let products = items as? [ProductRecord] {
                return products.sorted { 
                    guard let price0 = $0.originalPrice, let price1 = $1.originalPrice else { return false }
                    return price0.compare(price1) == .orderedAscending 
                } as? [T] ?? items
            }
        case .priceDescending:
            if let products = items as? [ProductRecord] {
                return products.sorted { 
                    guard let price0 = $0.originalPrice, let price1 = $1.originalPrice else { return false }
                    return price0.compare(price1) == .orderedDescending 
                } as? [T] ?? items
            }
        }
        
        return items
    }
    
    private func applySorting(_ history: [ComparisonHistory]) -> [ComparisonHistory] {
        switch sortMode {
        case .dateAscending:
            return history.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        case .dateDescending:
            return history.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
        case .nameAscending:
            return history.sorted { ($0.productAName ?? "") < ($1.productAName ?? "") }
        case .nameDescending:
            return history.sorted { ($0.productAName ?? "") > ($1.productAName ?? "") }
        default:
            return history
        }
    }
    
    private func applySorting(_ groups: [ProductGroup]) -> [ProductGroup] {
        switch sortMode {
        case .dateAscending:
            return groups.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        case .dateDescending:
            return groups.sorted { ($0.createdAt ?? Date.distantPast) > ($1.createdAt ?? Date.distantPast) }
        case .nameAscending:
            return groups.sorted { ($0.productName ?? "") < ($1.productName ?? "") }
        case .nameDescending:
            return groups.sorted { ($0.productName ?? "") > ($1.productName ?? "") }
        default:
            return groups
        }
    }
}

// MARK: - Supporting Types

enum HistoryViewMode: String, CaseIterable {
    case products = "products"
    case comparisons = "comparisons"
    case groups = "groups"
    
    var title: String {
        switch self {
        case .products:
            return "商品"
        case .comparisons:
            return "比較履歴"
        case .groups:
            return "商品グループ"
        }
    }
    
    var systemImage: String {
        switch self {
        case .products:
            return "list.bullet"
        case .comparisons:
            return "clock"
        case .groups:
            return "folder"
        }
    }
}

enum HistorySortMode: String, CaseIterable {
    case dateDescending = "date_desc"
    case dateAscending = "date_asc"
    case nameAscending = "name_asc"
    case nameDescending = "name_desc"
    case priceAscending = "price_asc"
    case priceDescending = "price_desc"
    
    var title: String {
        switch self {
        case .dateDescending:
            return "日付 (新しい順)"
        case .dateAscending:
            return "日付 (古い順)"
        case .nameAscending:
            return "名前 (A-Z)"
        case .nameDescending:
            return "名前 (Z-A)"
        case .priceAscending:
            return "価格 (安い順)"
        case .priceDescending:
            return "価格 (高い順)"
        }
    }
}

enum HistoryFilterMode: String, CaseIterable {
    case all = "all"
    case recent = "recent"
    case favorites = "favorites"
    
    var title: String {
        switch self {
        case .all:
            return "すべて"
        case .recent:
            return "最近の項目"
        case .favorites:
            return "よく使用"
        }
    }
}

enum DateRange: String, CaseIterable {
    case all = "all"
    case today = "today"
    case week = "week"
    case month = "month"
    case threeMonths = "three_months"
    case year = "year"
    
    var title: String {
        switch self {
        case .all:
            return "すべての期間"
        case .today:
            return "今日"
        case .week:
            return "過去1週間"
        case .month:
            return "過去1ヶ月"
        case .threeMonths:
            return "過去3ヶ月"
        case .year:
            return "過去1年"
        }
    }
}

struct PriceRange {
    var min: Decimal = 0
    var max: Decimal = 10000
    
    var isDefault: Bool {
        min == 0 && max == 10000
    }
}

struct ComparisonStatistics {
    let totalComparisons: Int
    let averageSavings: Decimal
    let totalProducts: Int
    let totalGroups: Int
    var mostComparedProducts: [(productName: String, count: Int)] = []
}
