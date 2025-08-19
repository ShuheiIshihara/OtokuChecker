//
//  Unit.swift
//  OtokuChecker
//
//  Created by Claude on 2025/08/19.
//

import Foundation

enum Unit: String, CaseIterable {
    // 重量
    case gram = "g"
    case kilogram = "kg"
    
    // 容量
    case milliliter = "ml"
    case liter = "L"
    
    // 個数
    case piece = "個"
    case pack = "パック"
    case bottle = "本"
    case bag = "袋"
    
    var displayName: String {
        switch self {
        case .gram: return "グラム"
        case .kilogram: return "キログラム"
        case .milliliter: return "ミリリットル"
        case .liter: return "リットル"
        case .piece: return "個"
        case .pack: return "パック"
        case .bottle: return "本"
        case .bag: return "袋"
        }
    }
    
    var category: UnitCategory {
        switch self {
        case .gram, .kilogram:
            return .weight
        case .milliliter, .liter:
            return .volume
        case .piece, .pack, .bottle, .bag:
            return .count
        }
    }
    
    // 基本単位への変換係数
    var baseUnitConversionFactor: Decimal {
        switch self {
        case .gram: return 1
        case .kilogram: return 1000
        case .milliliter: return 1
        case .liter: return 1000
        case .piece, .pack, .bottle, .bag: return 1
        }
    }
    
    func convertToBaseUnit(_ value: Decimal) -> Decimal {
        return value * baseUnitConversionFactor
    }
    
    // 単位間変換の可否チェック
    func isConvertibleTo(_ other: Unit) -> Bool {
        return self.category == other.category
    }
    
    // 表示用の基本単位を取得
    var baseUnitForDisplay: String {
        switch category {
        case .weight: return "g"
        case .volume: return "ml"
        case .count: return "個"
        }
    }
}

enum UnitCategory: String, CaseIterable {
    case weight = "weight"
    case volume = "volume"
    case count = "count"
    
    var displayName: String {
        switch self {
        case .weight: return "重量"
        case .volume: return "容量"
        case .count: return "個数"
        }
    }
}