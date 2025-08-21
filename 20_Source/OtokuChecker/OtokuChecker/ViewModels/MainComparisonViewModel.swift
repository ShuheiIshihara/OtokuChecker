//
//  MainComparisonViewModel.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class MainComparisonViewModel: BaseFormViewModel {
    
    // MARK: - Dependencies
    
    private let comparisonUseCase: ComparisonUseCaseProtocol
    private let productManagementUseCase: ProductManagementUseCaseProtocol
    
    // MARK: - Published Properties - Product A
    
    @Published var productAName: String = ""
    @Published var productAPrice: String = ""
    @Published var productAQuantity: String = ""
    @Published var productAUnit: Unit = .gram
    
    // MARK: - Published Properties - Product B
    
    @Published var productBName: String = ""
    @Published var productBPrice: String = ""
    @Published var productBQuantity: String = ""
    @Published var productBUnit: Unit = .gram
    
    // MARK: - Published Properties - UI State
    
    @Published var comparisonResult: ExtendedComparisonResult?
    @Published var showingResult: Bool = false
    @Published var comparisonMode: ComparisonMode = .directComparison
    @Published var selectedHistoricalProduct: ProductRecord?
    @Published var recentProducts: [ProductRecord] = []
    @Published var showingHistoryPicker: Bool = false
    
    // MARK: - Published Properties - Form State
    
    @Published var productAValid: Bool = false
    @Published var productBValid: Bool = false
    @Published var canCompare: Bool = false
    
    // MARK: - Computed Properties
    
    var productA: ComparisonProduct? {
        guard productAValid,
              let price = Decimal(string: productAPrice),
              let quantity = Decimal(string: productAQuantity) else {
            return nil
        }
        
        return ComparisonProduct(
            name: productAName,
            price: price,
            quantity: quantity,
            unit: productAUnit,
            taxIncluded: true, // デフォルトで税込
            taxRate: 0.10 // 10%税率
        )
    }
    
    var productB: ComparisonProduct? {
        guard comparisonMode == .directComparison,
              productBValid,
              let price = Decimal(string: productBPrice),
              let quantity = Decimal(string: productBQuantity) else {
            return nil
        }
        
        return ComparisonProduct(
            name: productBName,
            price: price,
            quantity: quantity,
            unit: productBUnit,
            taxIncluded: true, // デフォルトで税込
            taxRate: 0.10 // 10%税率
        )
    }
    
    // MARK: - Initialization
    
    init(
        comparisonUseCase: ComparisonUseCaseProtocol,
        productManagementUseCase: ProductManagementUseCaseProtocol
    ) {
        self.comparisonUseCase = comparisonUseCase
        self.productManagementUseCase = productManagementUseCase
        
        super.init()
        
        setupValidation()
        loadRecentProducts()
    }
    
    // MARK: - Public Methods
    
    func compareProducts() {
        guard let productA = productA else { return }
        
        executeVoidTask {
            let input: ComparisonInput
            
            switch self.comparisonMode {
            case .directComparison:
                guard let productB = self.productB else { return }
                input = ComparisonInput(productA: productA, productB: productB, historicalProductId: nil)
                
            case .historicalComparison:
                guard let selectedProduct = self.selectedHistoricalProduct else { return }
                input = ComparisonInput(productA: productA, productB: nil, historicalProductId: selectedProduct.entityID)
            }
            
            let output = try await self.comparisonUseCase.execute(input)
            self.comparisonResult = output.result
            self.showingResult = true
        }
    }
    
    func switchComparisonMode(_ mode: ComparisonMode) {
        comparisonMode = mode
        clearComparisonResult()
        validateForm()
        
        if mode == .historicalComparison && recentProducts.isEmpty {
            loadRecentProducts()
        }
    }
    
    func selectHistoricalProduct(_ product: ProductRecord) {
        selectedHistoricalProduct = product
        showingHistoryPicker = false
        validateForm()
    }
    
    func swapProducts() {
        guard comparisonMode == .directComparison else { return }
        
        let tempName = productAName
        let tempPrice = productAPrice
        let tempQuantity = productAQuantity
        let tempUnit = productAUnit
        
        productAName = productBName
        productAPrice = productBPrice
        productAQuantity = productBQuantity
        productAUnit = productBUnit
        
        productBName = tempName
        productBPrice = tempPrice
        productBQuantity = tempQuantity
        productBUnit = tempUnit
    }
    
    func clearForm() {
        productAName = ""
        productAPrice = ""
        productAQuantity = ""
        productAUnit = .gram
        
        productBName = ""
        productBPrice = ""
        productBQuantity = ""
        productBUnit = .gram
        
        selectedHistoricalProduct = nil
        clearComparisonResult()
        clearValidationErrors()
        markAsClean()
    }
    
    func clearComparisonResult() {
        comparisonResult = nil
        showingResult = false
    }
    
    func saveProductA() {
        guard let product = productA else { return }
        
        executeVoidTask {
            _ = try await self.productManagementUseCase.saveProduct(product, category: nil)
            await self.loadRecentProducts()
        }
    }
    
    func saveProductB() {
        guard let product = productB else { return }
        
        executeVoidTask {
            _ = try await self.productManagementUseCase.saveProduct(product, category: nil)
            await self.loadRecentProducts()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupValidation() {
        // Product A validation
        Publishers.CombineLatest4($productAName, $productAPrice, $productAQuantity, $productAUnit)
            .map { name, price, quantity, _ in
                self.validateProduct(name: name, price: price, quantity: quantity)
            }
            .assign(to: &$productAValid)
        
        // Product B validation (only for direct comparison)
        Publishers.CombineLatest4($productBName, $productBPrice, $productBQuantity, $productBUnit)
            .map { name, price, quantity, _ in
                self.validateProduct(name: name, price: price, quantity: quantity)
            }
            .assign(to: &$productBValid)
        
        // Overall comparison validation
        Publishers.CombineLatest3($productAValid, $productBValid, $comparisonMode)
            .combineLatest($selectedHistoricalProduct)
            .map { validationAndMode, historicalProduct in
                let (productAValid, productBValid, currentMode) = validationAndMode
                
                switch currentMode {
                case .directComparison:
                    return productAValid && productBValid
                case .historicalComparison:
                    return productAValid && historicalProduct != nil
                }
            }
            .assign(to: &$canCompare)
        
        // Mark as dirty when any field changes
        Publishers.CombineLatest4($productAName, $productAPrice, $productAQuantity, $productAUnit)
            .combineLatest(Publishers.CombineLatest4($productBName, $productBPrice, $productBQuantity, $productBUnit))
            .sink { [weak self] _, _ in
                self?.markAsDirty()
            }
            .store(in: &cancellables)
    }
    
    private func validateProduct(name: String, price: String, quantity: String) -> Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard let priceValue = Decimal(string: price), priceValue > 0 else { return false }
        guard let quantityValue = Decimal(string: quantity), quantityValue > 0 else { return false }
        return true
    }
    
    override func performValidation() -> [String: String] {
        var errors: [String: String] = [:]
        
        // Product A validation
        if productAName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors["productAName"] = "商品名を入力してください"
        }
        
        if productAPrice.isEmpty {
            errors["productAPrice"] = "価格を入力してください"
        } else if Decimal(string: productAPrice) == nil || Decimal(string: productAPrice)! <= 0 {
            errors["productAPrice"] = "有効な価格を入力してください"
        }
        
        if productAQuantity.isEmpty {
            errors["productAQuantity"] = "数量を入力してください"
        } else if Decimal(string: productAQuantity) == nil || Decimal(string: productAQuantity)! <= 0 {
            errors["productAQuantity"] = "有効な数量を入力してください"
        }
        
        // Product B validation (only for direct comparison)
        if comparisonMode == .directComparison {
            if productBName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors["productBName"] = "商品名を入力してください"
            }
            
            if productBPrice.isEmpty {
                errors["productBPrice"] = "価格を入力してください"
            } else if Decimal(string: productBPrice) == nil || Decimal(string: productBPrice)! <= 0 {
                errors["productBPrice"] = "有効な価格を入力してください"
            }
            
            if productBQuantity.isEmpty {
                errors["productBQuantity"] = "数量を入力してください"
            } else if Decimal(string: productBQuantity) == nil || Decimal(string: productBQuantity)! <= 0 {
                errors["productBQuantity"] = "有効な数量を入力してください"
            }
        }
        
        // Historical comparison validation
        if comparisonMode == .historicalComparison && selectedHistoricalProduct == nil {
            errors["historicalProduct"] = "比較する商品を選択してください"
        }
        
        return errors
    }
    
    private func loadRecentProducts() {
        executeVoidTask {
            self.recentProducts = try await self.productManagementUseCase.fetchRecentProducts(limit: 20)
        }
    }
}

// MARK: - Supporting Types

enum ComparisonMode: CaseIterable {
    case directComparison
    case historicalComparison
    
    var title: String {
        switch self {
        case .directComparison:
            return "商品同士を比較"
        case .historicalComparison:
            return "過去の商品と比較"
        }
    }
    
    var description: String {
        switch self {
        case .directComparison:
            return "2つの商品を直接比較します"
        case .historicalComparison:
            return "現在の商品と過去に保存した商品を比較します"
        }
    }
}