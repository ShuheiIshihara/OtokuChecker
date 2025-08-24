//
//  DataEntryViewModel.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class DataEntryViewModel: BaseFormViewModel {
    
    // MARK: - Supporting Types
    enum TaxType {
        case inclusive, exclusive
    }
    
    enum OriginType {
        case domestic, imported
    }
    
    // MARK: - Dependencies
    
    private let productManagementUseCase: any ProductManagementUseCaseProtocol
    private let categoryManagementUseCase: any CategoryManagementUseCaseProtocol
    
    // MARK: - Published Properties - Product Data
    
    @Published var productName: String = ""
    @Published var productType: String = ""
    @Published var selectedCategory: String = ""
    @Published var price: String = ""
    @Published var taxType: TaxType = .exclusive
    @Published var taxRate: String = "10"
    @Published var quantity: String = ""
    @Published var selectedUnit: String = ""
    @Published var origin: OriginType = .domestic
    @Published var storeName: String = ""
    @Published var registrationDate: Date = Date()
    @Published var memo: String = ""
    @Published var unit: Unit = .gram
    @Published var notes: String = ""
    
    // MARK: - Published Properties - Category
    
    @Published var selectedCategoryObject: ProductCategory?
    @Published var availableCategories: [ProductCategory] = []
    @Published var showingCategoryPicker: Bool = false
    @Published var suggestedCategories: [ProductCategory] = []
    
    // MARK: - Published Properties - UI State
    
    @Published var isEditing: Bool = false
    @Published var editingProduct: ProductRecord?
    @Published var showingSaveConfirmation: Bool = false
    @Published var showingDiscardAlert: Bool = false
    
    // MARK: - Published Properties - Auto-complete
    
    @Published var showingProductSuggestions: Bool = false
    @Published var productSuggestions: [ProductRecord] = []
    @Published var showingStoreSuggestions: Bool = false
    @Published var storeSuggestions: [String] = []
    
    // MARK: - Computed Properties
    
    var canSave: Bool {
        isValid && !isLoading
    }
    
    var isFormValid: Bool {
        !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !price.isEmpty &&
        !quantity.isEmpty &&
        !selectedUnit.isEmpty &&
        Decimal(string: price) != nil &&
        Decimal(string: quantity) != nil &&
        memo.count <= 500
    }
    
    var unitPrice: String {
        guard let priceValue = Decimal(string: price),
              let quantityValue = Decimal(string: quantity),
              quantityValue > 0 else {
            return "- 円 /単位"
        }
        
        let finalPrice: Decimal
        if taxType == .exclusive {
            let taxRateValue = Decimal(string: taxRate) ?? 10
            finalPrice = priceValue * (1 + taxRateValue / 100)
        } else {
            finalPrice = priceValue
        }
        
        let unitPriceValue = finalPrice / quantityValue
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        
        let formattedPrice = formatter.string(from: NSDecimalNumber(decimal: unitPriceValue)) ?? "0"
        return "\(formattedPrice) 円 /\(selectedUnit)"
    }
    
    var productPreview: ComparisonProduct? {
        guard let priceValue = Decimal(string: price),
              let quantityValue = Decimal(string: quantity),
              !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        return ComparisonProduct(
            name: productName,
            price: priceValue,
            quantity: quantityValue,
            unit: unit,
            taxIncluded: true, // デフォルトで税込
            taxRate: 0.10, // 10%税率
            origin: origin == .domestic ? "domestic" : "imported"
        )
    }
    
    var hasUnsavedChanges: Bool {
        isDirty && !isEditing
    }
    
    // MARK: - Initialization
    
    convenience override init() {
        let container = DIContainer.shared
        let productUseCase = container.getProductManagementUseCase()
        let categoryUseCase = container.getCategoryManagementUseCase()
        
        self.init(
            productManagementUseCase: productUseCase,
            categoryManagementUseCase: categoryUseCase
        )
    }
    
    init(
        productManagementUseCase: any ProductManagementUseCaseProtocol,
        categoryManagementUseCase: any CategoryManagementUseCaseProtocol
    ) {
        self.productManagementUseCase = productManagementUseCase
        self.categoryManagementUseCase = categoryManagementUseCase
        
        super.init()
        
        setupValidation()
        setupAutoComplete()
        loadCategories()
    }
    
    // MARK: - Public Methods - Form Management
    
    func saveProduct() {
        guard let product = productPreview else { return }
        
        executeVoidTask {
            if self.isEditing {
                await self.updateExistingProduct(product)
            } else {
                await self.createNewProduct(product)
            }
            
            self.showingSaveConfirmation = true
            self.resetForm()
        }
    }
    
    func startEditing(_ product: ProductRecord) {
        editingProduct = product
        isEditing = true
        
        productName = product.productName ?? ""
        price = product.originalPrice?.description ?? ""
        quantity = product.quantity?.description ?? ""
        selectedUnit = product.unitType ?? ""
        unit = Unit(rawValue: product.unitType ?? "gram") ?? .gram
        storeName = product.storeName ?? ""
        memo = product.memo ?? ""
        notes = product.memo ?? ""
        origin = (product.origin ?? "domestic") == "domestic" ? .domestic : .imported
        selectedCategoryObject = product.category
        
        markAsClean()
        validateForm()
    }
    
    func cancelEditing() {
        if hasUnsavedChanges {
            showingDiscardAlert = true
        } else {
            discardChanges()
        }
    }
    
    func discardChanges() {
        resetForm()
        editingProduct = nil
        isEditing = false
        showingDiscardAlert = false
    }
    
    func registerProduct() {
        guard isFormValid else { return }
        
        executeVoidTask {
            do {
                let product = ComparisonProduct(
                    name: self.productName,
                    price: Decimal(string: self.price) ?? 0,
                    quantity: Decimal(string: self.quantity) ?? 0,
                    unit: Unit(rawValue: self.selectedUnit) ?? .gram,
                    taxIncluded: self.taxType == .inclusive,
                    taxRate: (Decimal(string: self.taxRate) ?? 10) / 100,
                    origin: self.origin == .domestic ? "domestic" : "imported"
                )
                
                _ = try await self.productManagementUseCase.saveProduct(product, category: self.selectedCategoryObject)
                
                self.showingSaveConfirmation = true
                self.resetForm()
            } catch {
                // エラーハンドリング
            }
        }
    }
    
    override func resetForm() {
        productName = ""
        productType = ""
        selectedCategory = ""
        price = ""
        taxType = .exclusive
        taxRate = "10"
        quantity = ""
        selectedUnit = ""
        origin = .domestic
        storeName = ""
        registrationDate = Date()
        memo = ""
        unit = .gram
        notes = ""
        selectedCategoryObject = nil
        
        hideAllSuggestions()
        clearValidationErrors()
        markAsClean()
    }
    
    // MARK: - Public Methods - Category Management
    
    func selectCategory(_ category: ProductCategory) {
        selectedCategoryObject = category
        showingCategoryPicker = false
        markAsDirty()
    }
    
    func clearCategory() {
        selectedCategoryObject = nil
        markAsDirty()
    }
    
    func suggestCategoriesForCurrentProduct() {
        guard !productName.isEmpty else {
            suggestedCategories = []
            return
        }
        
        executeVoidTask {
            self.suggestedCategories = try await self.categoryManagementUseCase.suggestCategoriesFor(productName: self.productName)
        }
    }
    
    // MARK: - Public Methods - Auto-complete
    
    func searchProducts(_ query: String) {
        guard query.count > 1 else {
            productSuggestions = []
            showingProductSuggestions = false
            return
        }
        
        executeVoidTask {
            self.productSuggestions = try await self.productManagementUseCase.searchProducts(keyword: query)
            self.showingProductSuggestions = !self.productSuggestions.isEmpty
        }
    }
    
    func selectProductSuggestion(_ product: ProductRecord) {
        productName = product.productName ?? ""
        price = product.originalPrice?.description ?? ""
        quantity = product.quantity?.description ?? ""
        selectedUnit = product.unitType ?? ""
        unit = Unit(rawValue: product.unitType ?? "gram") ?? .gram
        storeName = product.storeName ?? ""
        memo = product.memo ?? ""
        origin = (product.origin ?? "domestic") == "domestic" ? .domestic : .imported
        selectedCategoryObject = product.category
        
        hideAllSuggestions()
        markAsDirty()
        validateForm()
    }
    
    func hideAllSuggestions() {
        showingProductSuggestions = false
        showingStoreSuggestions = false
        productSuggestions = []
        storeSuggestions = []
    }
    
    // MARK: - Public Methods - Quick Actions
    
    func duplicateProduct() {
        guard let product = editingProduct else { return }
        
        isEditing = false
        editingProduct = nil
        
        productName = "\(product.productName ?? "") のコピー"
        markAsDirty()
        validateForm()
    }
    
    func clearPrice() {
        price = ""
        markAsDirty()
    }
    
    func clearQuantity() {
        quantity = ""
        markAsDirty()
    }
    
    // MARK: - Private Methods
    
    private func setupValidation() {
        Publishers.CombineLatest3($productName, $price, $quantity)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] name, price, quantity in
                self?.validateForm()
                self?.markAsDirty()
                
                // カテゴリの自動提案
                if !name.isEmpty {
                    self?.suggestCategoriesForCurrentProduct()
                }
            }
            .store(in: &cancellables)
        
        $unit
            .dropFirst()
            .sink { [weak self] _ in
                self?.markAsDirty()
            }
            .store(in: &cancellables)
        
        $storeName
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] storeName in
                self?.markAsDirty()
                self?.searchStores(storeName)
            }
            .store(in: &cancellables)
    }
    
    private func setupAutoComplete() {
        $productName
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                if !query.isEmpty && query.count > 1 {
                    self?.searchProducts(query)
                } else {
                    self?.hideAllSuggestions()
                }
            }
            .store(in: &cancellables)
    }
    
    override func performValidation() -> [String: String] {
        var errors: [String: String] = [:]
        
        if productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors["productName"] = "商品名を入力してください"
        }
        
        if price.isEmpty {
            errors["price"] = "価格を入力してください"
        } else if let priceValue = Decimal(string: price), priceValue <= 0 {
            errors["price"] = "有効な価格を入力してください"
        } else if Decimal(string: price) == nil {
            errors["price"] = "数字で入力してください"
        }
        
        if quantity.isEmpty {
            errors["quantity"] = "数量を入力してください"
        } else if let quantityValue = Decimal(string: quantity), quantityValue <= 0 {
            errors["quantity"] = "有効な数量を入力してください"
        } else if Decimal(string: quantity) == nil {
            errors["quantity"] = "数字で入力してください"
        }
        
        return errors
    }
    
    private func loadCategories() {
        executeVoidTask {
            self.availableCategories = try await self.categoryManagementUseCase.fetchAllCategories()
        }
    }
    
    private func createNewProduct(_ product: ComparisonProduct) async {
        do {
            _ = try await productManagementUseCase.saveProduct(product, category: selectedCategoryObject)
        } catch {
            // Handle error - could set an error state here
        }
    }
    
    private func updateExistingProduct(_ product: ComparisonProduct) async {
        guard let existingProduct = editingProduct else { return }
        
        existingProduct.productName = product.name
        existingProduct.originalPrice = NSDecimalNumber(decimal: product.price)
        existingProduct.quantity = NSDecimalNumber(decimal: product.quantity)
        existingProduct.unitType = product.unit.rawValue
        existingProduct.storeName = storeName.isEmpty ? nil : storeName
        existingProduct.memo = memo.isEmpty ? nil : memo
        existingProduct.origin = origin == .domestic ? "domestic" : "imported"
        existingProduct.category = selectedCategoryObject
        
        do {
            _ = try await productManagementUseCase.updateProductGroup(existingProduct.productGroup!)
        } catch {
            // Handle error - could set an error state here
        }
    }
    
    private func searchStores(_ query: String) {
        guard query.count > 1 else {
            storeSuggestions = []
            showingStoreSuggestions = false
            return
        }
        
        // 実際の実装では、過去のストア名から検索する
        executeVoidTask {
            let recentProducts = try await self.productManagementUseCase.fetchRecentProducts(limit: 100)
            let storeNames = Set(recentProducts.compactMap { $0.storeName })
            
            self.storeSuggestions = storeNames
                .filter { $0.localizedCaseInsensitiveContains(query) }
                .sorted()
                .prefix(5)
                .map { $0 }
            
            self.showingStoreSuggestions = !self.storeSuggestions.isEmpty
        }
    }
}