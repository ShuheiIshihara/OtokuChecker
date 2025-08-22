//
//  LoggingService.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/22.
//

import Foundation
import OSLog

// MARK: - ログサービス

/// OSLogを活用した構造化ログシステム
final class LoggingService {
    
    // MARK: - Singleton
    static let shared = LoggingService()
    private init() {}
    
    // MARK: - Logger Categories
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.otokuchecker"
    
    private let errorLogger = Logger(subsystem: subsystem, category: "error")
    private let comparisonLogger = Logger(subsystem: subsystem, category: "comparison")
    private let dataLogger = Logger(subsystem: subsystem, category: "data")
    private let uiLogger = Logger(subsystem: subsystem, category: "ui")
    private let performanceLogger = Logger(subsystem: subsystem, category: "performance")
    
    // MARK: - Error Logging
    func logError(_ error: AppErrorProtocol, context: String? = nil) {
        let contextInfo = context.map { " context=\($0)" } ?? ""
        let technicalDetails = error.technicalDetails.map { " technical=\($0)" } ?? ""
        
        errorLogger.error("code=\(error.errorCode) title=\(error.errorTitle) message=\(error.userMessage)\(contextInfo)\(technicalDetails)")
        
        // 重要度に応じた追加ログ
        if isCriticalError(error) {
            errorLogger.fault("CRITICAL_ERROR code=\(error.errorCode) recovery=\(error.recoveryAction?.suggestion ?? "none")")
        }
    }
    
    func logError(_ error: Error, context: String? = nil) {
        logError(error.asAppError(), context: context)
    }
    
    // MARK: - Comparison Logging
    func logComparison(productA: String, productB: String, result: String, duration: TimeInterval) {
        comparisonLogger.info("comparison productA=\(productA) productB=\(productB) result=\(result) duration=\(duration)ms")
    }
    
    func logComparisonError(productA: String, productB: String, error: ComparisonError) {
        comparisonLogger.error("comparison_error productA=\(productA) productB=\(productB) error=\(error.localizedDescription)")
    }
    
    // MARK: - Data Operation Logging
    func logDataOperation(_ operation: String, entityType: String, success: Bool, duration: TimeInterval? = nil) {
        let durationInfo = duration.map { " duration=\($0)ms" } ?? ""
        
        if success {
            dataLogger.info("data_operation operation=\(operation) entity=\(entityType) success=true\(durationInfo)")
        } else {
            dataLogger.error("data_operation operation=\(operation) entity=\(entityType) success=false\(durationInfo)")
        }
    }
    
    func logCoreDataError(_ error: NSError, operation: String) {
        let userInfo = error.userInfo.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        dataLogger.error("core_data_error operation=\(operation) code=\(error.code) domain=\(error.domain) userInfo=\(userInfo)")
    }
    
    // MARK: - UI Event Logging
    func logUserAction(_ action: String, screen: String, additionalInfo: [String: String] = [:]) {
        let infoString = additionalInfo.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        let additionalInfoString = infoString.isEmpty ? "" : " \(infoString)"
        
        uiLogger.info("user_action action=\(action) screen=\(screen)\(additionalInfoString)")
    }
    
    func logUIError(_ error: String, screen: String, context: String? = nil) {
        let contextInfo = context.map { " context=\($0)" } ?? ""
        uiLogger.error("ui_error error=\(error) screen=\(screen)\(contextInfo)")
    }
    
    // MARK: - Performance Logging
    func logPerformance(_ metric: String, value: Double, threshold: Double? = nil) {
        let thresholdInfo = threshold.map { " threshold=\($0)" } ?? ""
        let status = threshold.map { value > $0 ? "exceeded" : "normal" } ?? "measured"
        
        performanceLogger.info("performance metric=\(metric) value=\(value) status=\(status)\(thresholdInfo)")
        
        if let threshold = threshold, value > threshold {
            performanceLogger.warning("performance_threshold_exceeded metric=\(metric) value=\(value) threshold=\(threshold)")
        }
    }
    
    func logMemoryUsage(_ usage: Int64, available: Int64) {
        let usagePercent = Double(usage) / Double(available) * 100
        performanceLogger.info("memory_usage used=\(usage) available=\(available) percent=\(String(format: "%.1f", usagePercent))%")
        
        if usagePercent > 80 {
            performanceLogger.warning("high_memory_usage percent=\(String(format: "%.1f", usagePercent))%")
        }
    }
    
    // MARK: - General Purpose Logging
    func logInfo(_ message: String, context: String? = nil) {
        let contextInfo = context.map { " context=\($0)" } ?? ""
        Logger(subsystem: Self.subsystem, category: "general").info("\(message)\(contextInfo)")
    }
    
    func logWarning(_ message: String, context: String? = nil) {
        let contextInfo = context.map { " context=\($0)" } ?? ""
        Logger(subsystem: Self.subsystem, category: "general").warning("\(message)\(contextInfo)")
    }
    
    func logDebug(_ message: String, context: String? = nil) {
        let contextInfo = context.map { " context=\($0)" } ?? ""
        Logger(subsystem: Self.subsystem, category: "debug").debug("\(message)\(contextInfo)")
    }
    
    // MARK: - Critical Error Detection
    private func isCriticalError(_ error: AppErrorProtocol) -> Bool {
        switch error.errorCode {
        case "DATA_CORRUPTION", "MEMORY_LIMIT_EXCEEDED", "STORAGE_UNAVAILABLE":
            return true
        default:
            return false
        }
    }
}

// MARK: - Performance Measurement Helper

/// パフォーマンス計測ヘルパー
struct PerformanceMeasurement {
    private let startTime: CFAbsoluteTime
    private let operation: String
    private let logger: LoggingService
    
    init(operation: String, logger: LoggingService = .shared) {
        self.startTime = CFAbsoluteTimeGetCurrent()
        self.operation = operation
        self.logger = logger
    }
    
    func finish(threshold: TimeInterval? = nil) {
        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // ms
        logger.logPerformance(operation, value: duration, threshold: threshold.map { $0 * 1000 })
    }
}

// MARK: - Structured Logging Protocols

/// 構造化ログ対応のプロトコル
protocol StructuredLoggable {
    var logIdentifier: String { get }
    var logProperties: [String: String] { get }
}

extension ComparisonProduct: StructuredLoggable {
    var logIdentifier: String {
        return "product"
    }
    
    var logProperties: [String: String] {
        return [
            "name": name.prefix(20).description, // プライバシー配慮で商品名は短縮
            "price": price.description,
            "quantity": quantity.description,
            "unit": unit.rawValue
        ]
    }
}

// MARK: - Privacy-Safe Logging Extensions

extension LoggingService {
    
    /// プライバシーを考慮したユーザーデータログ
    func logUserDataOperation(_ operation: String, dataType: String, recordCount: Int) {
        // 個人を特定できる情報は記録しない
        dataLogger.info("user_data_operation operation=\(operation) dataType=\(dataType) recordCount=\(recordCount)")
    }
    
    /// 匿名化された商品情報ログ
    func logAnonymizedProduct(category: String, priceRange: String, unitType: String) {
        comparisonLogger.info("product_usage category=\(category) priceRange=\(priceRange) unitType=\(unitType)")
    }
}