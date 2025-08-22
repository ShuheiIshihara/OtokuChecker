//
//  CustomErrorTypes.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/22.
//

import Foundation

// MARK: - 買い物中特有のエラー

/// 買い物中の使用コンテキストで発生する特有のエラー
enum ShoppingContextError: LocalizedError, Equatable {
    
    // 通信・環境エラー
    case weakSignalInStore(String?)  // 店舗名
    case backgroundAppInterruption
    case batteryLowWarning(Int)      // 残量パーセンテージ
    
    // 操作エラー
    case oneHandedInputMistake(String)  // 誤入力フィールド
    case timeConstraintViolation(TimeInterval, TimeInterval)  // 実測時間、制限時間
    case cartCollisionInput  // カート操作中の誤入力
    
    // データ同期エラー
    case storeDataConflict(String, String)  // 店舗A、店舗B
    case priceVolatilityDetected(String, Decimal, Decimal)  // 商品名、前回価格、現在価格
    
    var errorDescription: String? {
        switch self {
        case .weakSignalInStore(let storeName):
            let store = storeName ?? "店舗内"
            return "\(store)で通信状況が不安定です"
            
        case .backgroundAppInterruption:
            return "他のアプリ使用により処理が中断されました"
            
        case .batteryLowWarning(let percentage):
            return "バッテリー残量が\(percentage)%です"
            
        case .oneHandedInputMistake(let field):
            return "\(field)で入力エラーが発生しました"
            
        case .timeConstraintViolation(let actual, let limit):
            return "処理時間が制限(\(String(format: "%.1f", limit))秒)を\(String(format: "%.1f", actual - limit))秒超過しました"
            
        case .cartCollisionInput:
            return "カート操作中の入力エラーが検出されました"
            
        case .storeDataConflict(let storeA, let storeB):
            return "\(storeA)と\(storeB)のデータで矛盾が検出されました"
            
        case .priceVolatilityDetected(let productName, let oldPrice, let newPrice):
            let changePercent = abs((newPrice - oldPrice) / oldPrice * 100)
            return "\(productName)の価格が\(String(format: "%.1f", changePercent as CVarArg))%変動しています（\(oldPrice)円→\(newPrice)円）"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .weakSignalInStore:
            return "オフラインモードで比較を続行できます。データは後で同期されます"
            
        case .backgroundAppInterruption:
            return "アプリを再起動して最新の状態で比較してください"
            
        case .batteryLowWarning:
            return "電源に接続するか、必要最小限の操作で比較してください"
            
        case .oneHandedInputMistake:
            return "両手での操作、または音声入力機能をご利用ください"
            
        case .timeConstraintViolation:
            return "データ量を減らすか、アプリを再起動してください"
            
        case .cartCollisionInput:
            return "カートを安全な場所に停めてから操作してください"
            
        case .storeDataConflict:
            return "最新の価格情報を確認して更新してください"
            
        case .priceVolatilityDetected:
            return "価格変動が大きいため、再度確認することをお勧めします"
        }
    }
}

// MARK: - 日本市場特有のエラー

/// 日本の商品・市場に特化したエラー
enum JapaneseMarketError: LocalizedError, Equatable {
    
    // 税制・価格エラー
    case taxRateAmbiguity(Decimal, Decimal)  // 標準税率、軽減税率
    case includedTaxMismatch(String)  // 商品名
    case regionalPricingConflict(String, String)  // 地域A、地域B
    
    // 単位・表記エラー
    case traditionalUnitConversion(String, String)  // 従来単位、現代単位
    case kanjiNumeralConversion(String)  // 漢数字表記
    case fullWidthHalfWidthMixing(String)  // 混在フィールド
    
    // 商品名・表記エラー
    case hiraganaKatakanaMismatch(String, String)  // ひらがな版、カタカナ版
    case brandNameVariation(String, String)  // バリエーション1、バリエーション2
    case productNameTooComplex(String, Int)  // 商品名、文字数
    
    // 店舗・地域エラー
    case storeChainDetection([String])  // 可能性のある店舗チェーン名
    case regionalDialectInStoreName(String)  // 方言を含む店舗名
    
    var errorDescription: String? {
        switch self {
        case .taxRateAmbiguity(let standard, let reduced):
            return "税率が曖昧です（標準\(standard)%、軽減\(reduced)%）"
            
        case .includedTaxMismatch(let productName):
            return "\(productName)の税込・税別表示が不明確です"
            
        case .regionalPricingConflict(let regionA, let regionB):
            return "\(regionA)と\(regionB)で地域価格差が検出されました"
            
        case .traditionalUnitConversion(let traditional, let modern):
            return "従来単位「\(traditional)」の「\(modern)」への変換に失敗しました"
            
        case .kanjiNumeralConversion(let kanjiNumber):
            return "漢数字「\(kanjiNumber)」の変換に失敗しました"
            
        case .fullWidthHalfWidthMixing(let field):
            return "\(field)で全角・半角文字が混在しています"
            
        case .hiraganaKatakanaMismatch(let hiragana, let katakana):
            return "ひらがな「\(hiragana)」とカタカナ「\(katakana)」の商品名が一致しません"
            
        case .brandNameVariation(let variation1, let variation2):
            return "ブランド名「\(variation1)」と「\(variation2)」の表記ゆれを検出しました"
            
        case .productNameTooComplex(let name, let length):
            return "商品名「\(name.prefix(20))...」が複雑すぎます（\(length)文字）"
            
        case .storeChainDetection(let chains):
            return "店舗チェーンの判定が困難です: \(chains.joined(separator: "、"))"
            
        case .regionalDialectInStoreName(let storeName):
            return "店舗名「\(storeName)」に方言が含まれている可能性があります"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .taxRateAmbiguity:
            return "設定で適用する税率を明確に指定してください"
            
        case .includedTaxMismatch:
            return "価格入力時に税込・税別を明示してください"
            
        case .regionalPricingConflict:
            return "比較時は同一地域の価格を使用してください"
            
        case .traditionalUnitConversion:
            return "現代的な単位（g、ml等）での入力をお試しください"
            
        case .kanjiNumeralConversion:
            return "数字は算用数字（1、2、3）で入力してください"
            
        case .fullWidthHalfWidthMixing:
            return "統一した文字種で入力し直してください"
            
        case .hiraganaKatakanaMismatch:
            return "商品名の表記を統一してください"
            
        case .brandNameVariation:
            return "正式なブランド名で入力してください"
            
        case .productNameTooComplex:
            return "商品名を簡潔にまとめてください（100文字以内推奨）"
            
        case .storeChainDetection:
            return "店舗の正式名称を入力してください"
            
        case .regionalDialectInStoreName:
            return "店舗の正式名称を確認してください"
        }
    }
}

// MARK: - パフォーマンス関連エラー

/// アプリのパフォーマンスに関するエラー
enum PerformanceError: LocalizedError, Equatable {
    
    // レスポンス時間エラー
    case comparisonTimeout(TimeInterval)  // 実際の処理時間
    case searchTimeout(String, TimeInterval)  // 検索キーワード、処理時間
    case dataLoadTimeout(String, TimeInterval)  // データタイプ、処理時間
    
    // メモリ・リソースエラー
    case memoryPressureHigh(Int64, Int64)  // 使用メモリ、利用可能メモリ
    case tooManyRecordsLoaded(Int, Int)  // 実際の件数、推奨上限
    case cacheOverflow(String, Int)  // キャッシュタイプ、サイズ
    
    // CPU・処理エラー
    case calculationComplexity(String)  // 複雑な計算タイプ
    case backgroundProcessingDelay(String)  // 遅延処理タイプ
    
    var errorDescription: String? {
        switch self {
        case .comparisonTimeout(let duration):
            return "比較処理がタイムアウトしました（\(String(format: "%.2f", duration))秒）"
            
        case .searchTimeout(let keyword, let duration):
            return "「\(keyword)」の検索がタイムアウトしました（\(String(format: "%.2f", duration))秒）"
            
        case .dataLoadTimeout(let dataType, let duration):
            return "\(dataType)の読み込みがタイムアウトしました（\(String(format: "%.2f", duration))秒）"
            
        case .memoryPressureHigh(let used, let available):
            let usagePercent = Double(used) / Double(available) * 100
            return "メモリ使用量が高くなっています（\(String(format: "%.1f", usagePercent))%）"
            
        case .tooManyRecordsLoaded(let count, let limit):
            return "データ読み込み件数が上限を超えています（\(count)件、上限\(limit)件）"
            
        case .cacheOverflow(let cacheType, let size):
            return "\(cacheType)キャッシュがオーバーフローしています（\(size)KB）"
            
        case .calculationComplexity(let calculationType):
            return "\(calculationType)の計算が複雑すぎます"
            
        case .backgroundProcessingDelay(let processType):
            return "\(processType)のバックグラウンド処理が遅延しています"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .comparisonTimeout:
            return "商品データを簡素化するか、アプリを再起動してください"
            
        case .searchTimeout:
            return "検索条件を絞り込んでください"
            
        case .dataLoadTimeout:
            return "データ件数を制限するか、アプリを再起動してください"
            
        case .memoryPressureHigh:
            return "他のアプリを終了するか、デバイスを再起動してください"
            
        case .tooManyRecordsLoaded:
            return "表示件数を制限してください"
            
        case .cacheOverflow:
            return "キャッシュをクリアしてください"
            
        case .calculationComplexity:
            return "より簡単な単位や価格で計算してください"
            
        case .backgroundProcessingDelay:
            return "しばらくお待ちいただくか、アプリを再起動してください"
        }
    }
}

// MARK: - データ整合性エラー

/// データの整合性・品質に関するエラー
enum DataIntegrityError: LocalizedError, Equatable {
    
    // 重複・矛盾エラー
    case duplicateProductDetected(String, [String])  // 商品名、類似商品名リスト
    case priceOutlierDetected(String, Decimal, Decimal)  // 商品名、通常価格、異常価格
    case categoryMismatch(String, String, String)  // 商品名、現在カテゴリ、推定カテゴリ
    
    // データ品質エラー
    case incompleteProductData(String, [String])  // 商品名、不足項目リスト
    case suspiciousDataEntry(String, String)  // フィールド名、怪しいデータ
    case dataVersionMismatch(String, String)  // 期待バージョン、実際バージョン
    
    // 関連性エラー
    case orphanedRecord(String, String)  // レコードタイプ、レコードID
    case brokenRelationship(String, String, String)  // 親エンティティ、子エンティティ、関係名
    
    var errorDescription: String? {
        switch self {
        case .duplicateProductDetected(let productName, let similars):
            return "「\(productName)」と類似商品が検出されました: \(similars.joined(separator: "、"))"
            
        case .priceOutlierDetected(let productName, let normalPrice, let outlierPrice):
            let difference = abs(outlierPrice - normalPrice) / normalPrice * 100
            return "「\(productName)」の価格が通常価格から大幅に乖離しています（\(String(format: "%.1f", difference as CVarArg))%差、\(normalPrice)円→\(outlierPrice)円）"
            
        case .categoryMismatch(let productName, let currentCategory, let suggestedCategory):
            return "「\(productName)」のカテゴリが不適切です（現在:\(currentCategory)、推奨:\(suggestedCategory)）"
            
        case .incompleteProductData(let productName, let missingFields):
            return "「\(productName)」の必須データが不足しています: \(missingFields.joined(separator: "、"))"
            
        case .suspiciousDataEntry(let fieldName, let data):
            return "\(fieldName)のデータ「\(data)」が不審です"
            
        case .dataVersionMismatch(let expected, let actual):
            return "データバージョンが一致しません（期待:\(expected)、実際:\(actual)）"
            
        case .orphanedRecord(let recordType, let recordId):
            return "\(recordType)レコード（ID:\(recordId)）の親データが見つかりません"
            
        case .brokenRelationship(let parent, let child, let relationName):
            return "\(parent)と\(child)の\(relationName)関係が破損しています"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .duplicateProductDetected:
            return "重複商品を統合するか、削除してください"
            
        case .priceOutlierDetected:
            return "価格を再確認し、必要に応じて修正してください"
            
        case .categoryMismatch:
            return "商品を適切なカテゴリに移動してください"
            
        case .incompleteProductData:
            return "不足している項目を入力してください"
            
        case .suspiciousDataEntry:
            return "データの正確性を確認し、修正してください"
            
        case .dataVersionMismatch:
            return "アプリを更新するか、データを再同期してください"
            
        case .orphanedRecord:
            return "孤立したレコードを削除するか、親データを復元してください"
            
        case .brokenRelationship:
            return "データの整合性チェックを実行してください"
        }
    }
}

// MARK: - エラー重要度分類の拡張

extension ErrorSeverity {
    
    /// カスタムエラータイプの重要度を判定
    static func severity(for error: Error) -> ErrorSeverity {
        switch error {
        // 買い物中特有エラー
        case is ShoppingContextError:
            let shoppingError = error as! ShoppingContextError
            switch shoppingError {
            case .batteryLowWarning, .timeConstraintViolation:
                return .high
            case .backgroundAppInterruption, .priceVolatilityDetected:
                return .medium
            default:
                return .low
            }
            
        // 日本市場特有エラー
        case is JapaneseMarketError:
            let marketError = error as! JapaneseMarketError
            switch marketError {
            case .taxRateAmbiguity, .includedTaxMismatch:
                return .high
            case .traditionalUnitConversion, .productNameTooComplex:
                return .medium
            default:
                return .low
            }
            
        // パフォーマンスエラー
        case is PerformanceError:
            let perfError = error as! PerformanceError
            switch perfError {
            case .memoryPressureHigh, .comparisonTimeout:
                return .critical
            case .tooManyRecordsLoaded, .calculationComplexity:
                return .high
            default:
                return .medium
            }
            
        // データ整合性エラー
        case is DataIntegrityError:
            let dataError = error as! DataIntegrityError
            switch dataError {
            case .brokenRelationship, .dataVersionMismatch:
                return .critical
            case .priceOutlierDetected, .categoryMismatch:
                return .high
            default:
                return .medium
            }
            
        default:
            return .low
        }
    }
}
