//
//  ComparisonUseCase.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation

class ComparisonUseCase: ComparisonUseCaseProtocol {
    
    private let comparisonService: ComparisonService
    private let comparisonHistoryRepository: any ComparisonHistoryRepositoryProtocol
    private let productRecordRepository: any ProductRecordRepositoryProtocol
    
    init(
        comparisonService: ComparisonService,
        comparisonHistoryRepository: any ComparisonHistoryRepositoryProtocol,
        productRecordRepository: any ProductRecordRepositoryProtocol
    ) {
        self.comparisonService = comparisonService
        self.comparisonHistoryRepository = comparisonHistoryRepository
        self.productRecordRepository = productRecordRepository
    }
    
    // MARK: - BaseUseCase Implementation
    
    func execute(_ input: ComparisonInput) async throws -> ComparisonOutput {
        let result: ExtendedComparisonResult
        
        if let productB = input.productB {
            // 2つの商品を比較
            result = try await compareProducts(productA: input.productA, productB: productB)
        } else if let historicalProductId = input.historicalProductId {
            // 現在の商品と過去の商品を比較
            result = try await compareWithHistory(currentProduct: input.productA, historicalProductId: historicalProductId)
        } else {
            throw UseCaseError.invalidInput
        }
        
        // 比較結果を履歴に保存
        do {
            try await saveComparisonResult(result)
            return ComparisonOutput(result: result, savedToHistory: true)
        } catch {
            // 履歴保存に失敗しても比較結果は返す
            return ComparisonOutput(result: result, savedToHistory: false)
        }
    }
    
    // MARK: - ComparisonUseCaseProtocol Implementation
    
    func compareProducts(productA: ComparisonProduct, productB: ComparisonProduct) async throws -> ExtendedComparisonResult {
        do {
            return try comparisonService.compare(productA: productA, productB: productB)
        } catch {
            throw UseCaseError.comparisonFailed
        }
    }
    
    func compareWithHistory(currentProduct: ComparisonProduct, historicalProductId: UUID) async throws -> ExtendedComparisonResult {
        // 履歴から商品レコードを取得
        guard let historicalRecord = try await productRecordRepository.fetchById(historicalProductId) else {
            throw UseCaseError.productNotFound
        }
        
        // ProductRecordをComparisonProductに変換
        let historicalProduct = ComparisonProduct(
            name: historicalRecord.productName ?? "不明な商品",
            price: historicalRecord.originalPrice?.decimalValue ?? 0,
            quantity: historicalRecord.quantity?.decimalValue ?? 0,
            unit: Unit(rawValue: historicalRecord.unitType ?? "個") ?? .piece,
            taxIncluded: true, // デフォルトで税込として扱う
            taxRate: 0.10, // デフォルトで10%税率
            origin: historicalRecord.origin
        )
        
        do {
            return try comparisonService.compare(productA: currentProduct, productB: historicalProduct)
        } catch {
            throw UseCaseError.comparisonFailed
        }
    }
    
    func saveComparisonResult(_ result: ExtendedComparisonResult) async throws {
        do {
            let comparisonType = determineComparisonType(result)
            let winnerProduct = determineWinnerProduct(result)
            
            _ = try await comparisonHistoryRepository.create(
                comparisonType: comparisonType,
                productAName: result.productA.name,
                productAPrice: result.productA.price,
                productAQuantity: result.productA.quantity,
                productAUnitType: result.productA.unit.rawValue,
                productBName: result.productB.name,
                productBPrice: result.productB.price,
                productBQuantity: result.productB.quantity,
                productBUnitType: result.productB.unit.rawValue,
                winnerProduct: winnerProduct
            )
        } catch {
            throw UseCaseError.saveFailed
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func determineComparisonType(_ result: ExtendedComparisonResult) -> String {
        switch result.winner {
        case .productA:
            return "商品A勝利"
        case .productB:
            return "商品B勝利"
        case .tie:
            return "同等"
        }
    }
    
    private func determineWinnerProduct(_ result: ExtendedComparisonResult) -> String {
        switch result.winner {
        case .productA:
            return result.productA.name
        case .productB:
            return result.productB.name
        case .tie:
            return "引き分け"
        }
    }
}
