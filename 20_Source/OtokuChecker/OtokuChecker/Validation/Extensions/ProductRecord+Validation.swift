//
//  ProductRecord+Validation.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/23.
//

import Foundation
import CoreData

/// ProductRecordのバリデーション拡張
extension ProductRecord {
    
    // MARK: - Core Data Validation Override
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateBasics()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateBasics()
    }
    
    // MARK: - Basic Validation
    
    /// 基本的なバリデーションを実行
    private func validateBasics() throws {
        // 商品名のバリデーション
        try validateProductName()
        
        // 価格のバリデーション
        try validatePrice()
        
        // 数量のバリデーション
        try validateQuantity()
        
        // 単価の整合性チェック
        try validateUnitPrice()
        
        // 日付のバリデーション
        try validateDates()
    }
    
    /// 商品名のバリデーション
    private func validateProductName() throws {
        guard let name = productName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            throw ValidationInputError.productName(.empty)
        }
        
        if name.count > ProductNameValidator.maxLength {
            throw ValidationInputError.productName(.tooLong)
        }
    }
    
    /// 価格のバリデーション
    private func validatePrice() throws {
        if originalPrice == nil || originalPrice!.decimalValue <= Decimal.zero {
            throw ValidationInputError.price(.negativeOrZero)
        }
        
        if originalPrice!.decimalValue > PriceValidator.maxValue {
            throw ValidationInputError.price(.tooLarge)
        }
    }
    
    /// 数量のバリデーション
    private func validateQuantity() throws {
        if quantity == nil || quantity!.decimalValue <= Decimal.zero {
            throw ValidationInputError.quantity(.negativeOrZero)
        }
        
        if quantity!.decimalValue > QuantityValidator.maxValue {
            throw ValidationInputError.quantity(.tooLarge)
        }
        
        // 単位がある場合は単位別チェック
        if let unitString = unitType,
           let unit = Unit(rawValue: unitString),
           unit.category == .count {
            // 個数系単位の場合は整数チェック
            if quantity!.floatValue.truncatingRemainder(dividingBy: 1) != 0 {
                throw ValidationInputError.quantity(.mustBeInteger)
            }
        }
    }
    
    /// 単価の整合性チェック
    private func validateUnitPrice() throws {
        guard quantity!.decimalValue > Decimal.zero else { return }
        
        // 単価を再計算して整合性を確認
        let calculatedUnitPrice = originalPrice!.multiplying(by: quantity ?? NSDecimalNumber.zero)
        let tolerance: Decimal = 0.01
        
        if abs(calculatedUnitPrice.decimalValue - unitPrice!.decimalValue) > tolerance {
            // 単価が一致しない場合は自動で修正
            unitPrice = calculatedUnitPrice
        }
    }
    
    /// 日付のバリデーション
    private func validateDates() throws {
        // 購入日が未来の場合はエラー
        if let purchaseDate = purchaseDate, purchaseDate > Date() {
            throw ValidationInputError.comparison(.invalidProducts) // 適切なエラー型がないため代用
        }
        
        // 作成日と更新日の整合性
        if let createdAt = createdAt, let updatedAt = updatedAt, createdAt > updatedAt {
            self.updatedAt = Date()
        }
    }
    
    // MARK: - Validation Helpers
    
    /// レコードが有効かどうかをチェック（保存前確認用）
    func isValid() -> Bool {
        do {
            try validateBasics()
            return true
        } catch {
            return false
        }
    }
    
    /// バリデーションエラーの詳細を取得（デバッグ用）
    func getValidationInputErrors() -> [ValidationInputError] {
        var errors: [ValidationInputError] = []
        
        // 各項目を個別にチェック
        do {
            try validateProductName()
        } catch let error as ValidationInputError {
            errors.append(error)
        } catch {}
        
        do {
            try validatePrice()
        } catch let error as ValidationInputError {
            errors.append(error)
        } catch {}
        
        do {
            try validateQuantity()
        } catch let error as ValidationInputError {
            errors.append(error)
        } catch {}
        
        do {
            try validateUnitPrice()
        } catch let error as ValidationInputError {
            errors.append(error)
        } catch {}
        
        do {
            try validateDates()
        } catch let error as ValidationInputError {
            errors.append(error)
        } catch {}
        
        return errors
    }
    
    /// 保存前の自動修正を実行
    func autoCorrect() {
        // 商品名の正規化
        if let name = productName {
            productName = ProductNameValidator.normalize(name)
        }
        
        // 単価の再計算
        if quantity != nil && quantity!.intValue > 0 {
            unitPrice = originalPrice!.multiplying(by: quantity ?? NSDecimalNumber.zero)
        }
        
        // 更新日時の設定
        updatedAt = Date()
        
        // 作成日時が未設定の場合は現在時刻を設定
        if createdAt == nil {
            createdAt = Date()
        }
    }
    
    /// レコードの整合性を修復する
    func repairData() {
        // 自動修正を実行
        autoCorrect()
        
        // 無効な値のデフォルト値設定
        if productName?.isEmpty ?? true {
            productName = "未設定"
        }
        
        if originalPrice!.compare(NSDecimalNumber.zero) == .orderedAscending {
            originalPrice = 0.01 // 最小値を設定
        }
        
        if quantity!.compare(NSDecimalNumber.zero) == .orderedAscending {
            quantity = 1 // デフォルト数量
        }
        
        // 購入日が未来の場合は今日に設定
        if let purchaseDate = purchaseDate, purchaseDate > Date() {
            self.purchaseDate = Date()
        }
    }
}

// MARK: - Validation Convenience Methods

extension ProductRecord {
    
    /// 文字列から安全にレコードを作成する
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        price: String,
        quantity: String,
        unit: Unit,
        store: String? = nil,
        purchaseDate: Date? = nil
    ) throws -> ProductRecord {
        
        // バリデーション実行
        let nameResult = ProductNameValidator.validate(name)
        let priceResult = PriceValidator.validate(price)
        let quantityResult = QuantityValidator.validate(quantity, unit: unit)
        
        // エラーチェック
        switch nameResult {
        case .failure(let error): throw error
        case .success: break
        }
        
        switch priceResult {
        case .failure(let error): throw error
        case .success: break
        }
        
        switch quantityResult {
        case .failure(let error): throw error
        case .success: break
        }
        
        // レコード作成
        let record = ProductRecord(context: context)
        record.productName = nameResult.value!
        record.originalPrice = NSDecimalNumber(decimal: priceResult.value!)
        record.quantity = NSDecimalNumber(decimal: quantityResult.value!)
        record.unitType = record.unitType
        record.unitPrice = record.originalPrice?.multiplying(by: record.quantity!)
        record.storeName = store
        record.purchaseDate = purchaseDate ?? Date()
        record.createdAt = Date()
        record.updatedAt = Date()
        
        return record
    }
    
    /// 安全にレコードを更新する
    func updateSafely(
        name: String? = nil,
        price: String? = nil,
        quantity: String? = nil,
        unit: Unit? = nil,
        store: String? = nil,
        purchaseDate: Date? = nil
    ) throws {
        
        // 商品名の更新
        if let name = name {
            let result = ProductNameValidator.validate(name)
            switch result {
            case .failure(let error): throw error
            case .success(let validName): self.productName = validName
            }
        }
        
        // 価格の更新
        if let price = price {
            let result = PriceValidator.validate(price)
            switch result {
            case .failure(let error): throw error
            case .success(let validPrice): self.originalPrice = NSDecimalNumber(decimal: validPrice)
            }
        }
        
        // 数量の更新
        if let quantity = quantity, let unit = unit {
            let result = QuantityValidator.validate(quantity, unit: unit)
            switch result {
            case .failure(let error): throw error
            case .success(let validQuantity):
                self.quantity = NSDecimalNumber(decimal: validQuantity)
                self.unitType = unit.rawValue
            }
        }
        
        // 単価の再計算
        if ((self.quantity?.compare(NSDecimalNumber.zero)) != nil) {
            self.unitPrice = self.originalPrice?.multiplying(by: self.quantity!)
        }
        
        // その他の更新
        if let store = store {
            self.storeName = store
        }
        
        if let purchaseDate = purchaseDate {
            self.purchaseDate = purchaseDate
        }
        
        // 更新日時の設定
        self.updatedAt = Date()
    }
}
