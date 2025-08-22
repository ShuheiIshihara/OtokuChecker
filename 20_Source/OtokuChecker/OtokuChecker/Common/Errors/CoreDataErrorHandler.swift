//
//  CoreDataErrorHandler.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/22.
//

import Foundation
import CoreData
import OSLog

// MARK: - Core Data専用エラーハンドラー

/// Core Data操作のエラーハンドリングを専門に扱うクラス
final class CoreDataErrorHandler {
    
    // MARK: - Singleton
    static let shared = CoreDataErrorHandler()
    private init() {}
    
    // MARK: - Error Analysis & Conversion
    
    /// NSErrorをアプリ固有のエラーに変換
    func convertCoreDataError(_ error: NSError, operation: String, entityName: String) -> RepositoryError {
        LoggingService.shared.logCoreDataError(error, operation: operation)
        
        // Core Dataエラーコード別の詳細処理
        switch error.code {
        case NSValidationMissingMandatoryPropertyError,
             NSValidationRelationshipLacksMinimumCountError,
             NSValidationRelationshipExceedsMaximumCountError,
             NSValidationRelationshipDeniedDeleteError,
             NSValidationNumberTooLargeError,
             NSValidationNumberTooSmallError,
             NSValidationDateTooLateError,
             NSValidationDateTooSoonError,
             NSValidationInvalidDateError,
             NSValidationStringTooLongError,
             NSValidationStringTooShortError,
             NSValidationStringPatternMatchingError:
            return .invalidData
            
        case NSManagedObjectValidationError:
            return handleValidationError(error, entityName: entityName)
            
        case NSValidationMultipleErrorsError:
            return handleConstraintViolationError(error, entityName: entityName)
            
        case NSManagedObjectContextLockingError,
             NSPersistentStoreCoordinatorLockingError:
            return handleConcurrencyError(error, operation: operation)
            
        case NSCoreDataError:
            return handleGeneralCoreDataError(error, operation: operation)
            
        case NSPersistentStoreTimeoutError,
             NSPersistentStoreUnsupportedRequestTypeError,
             NSPersistentStoreOpenError:
            return handlePersistentStoreError(error)
            
        case NSMigrationError,
             NSMigrationConstraintViolationError,
             NSMigrationCancelledError,
             NSMigrationMissingSourceModelError,
             NSMigrationMissingMappingModelError:
            return handleMigrationError(error)
            
        case NSInferredMappingModelError,
             NSExternalRecordImportError:
            return handleDataImportError(error)
            
        default:
            return .coreDataError(error)
        }
    }
    
    // MARK: - Specific Error Handlers
    
    private func handleValidationError(_ error: NSError, entityName: String) -> RepositoryError {
        guard let validationErrors = error.userInfo[NSDetailedErrorsKey] as? [NSError] else {
            return .invalidData
        }
        
        let errorMessages = validationErrors.compactMap { validationError in
            return validationError.localizedDescription
        }
        
        LoggingService.shared.logError(
            DataIntegrityError.incompleteProductData(entityName, errorMessages),
            context: "Core Data Validation"
        )
        
        return .invalidData
    }
    
    private func handleConstraintViolationError(_ error: NSError, entityName: String) -> RepositoryError {
        if let conflictList = error.userInfo["conflictList"] as? [Any] {
            LoggingService.shared.logError(
                DataIntegrityError.duplicateProductDetected(
                    entityName,
                    conflictList.map { "\($0)" }
                ),
                context: "Core Data Constraint Violation"
            )
        }
        
        return .saveFailed
    }
    
    private func handleConcurrencyError(_ error: NSError, operation: String) -> RepositoryError {
        LoggingService.shared.logError(
            PerformanceError.backgroundProcessingDelay("Core Data \(operation)"),
            context: "Core Data Concurrency"
        )
        
        return .coreDataError(error)
    }
    
    private func handleGeneralCoreDataError(_ error: NSError, operation: String) -> RepositoryError {
        // ストレージ容量チェック
        if error.localizedDescription.contains("disk") || error.localizedDescription.contains("space") {
            return .coreDataError(error) // AppErrorでstorageUnavailableに変換される
        }
        
        return .coreDataError(error)
    }
    
    private func handlePersistentStoreError(_ error: NSError) -> RepositoryError {
        LoggingService.shared.logError(
            AppError.dataCorruption.asAppError(),
            context: "Persistent Store Error"
        )
        
        return .coreDataError(error)
    }
    
    private func handleMigrationError(_ error: NSError) -> RepositoryError {
        LoggingService.shared.logError(
            AppError.migrationFailed.asAppError(),
            context: "Core Data Migration"
        )
        
        return .coreDataError(error)
    }
    
    private func handleDataImportError(_ error: NSError) -> RepositoryError {
        let underlyingErrorDescription = (error.userInfo["NSUnderlyingError"] as? NSError)?.localizedDescription ?? "unknown"
        
        LoggingService.shared.logError(
            DataIntegrityError.dataVersionMismatch(
                "unknown",
                underlyingErrorDescription
            ),
            context: "Data Import Error"
        )
        
        return .coreDataError(error)
    }
}

// MARK: - Core Data操作拡張

extension NSManagedObjectContext {
    
    /// 安全なsave操作（エラーハンドリング付き）
    func safeSave() throws {
        guard hasChanges else { return }
        
        let measurement = PerformanceMeasurement(operation: "core_data_save")
        defer { measurement.finish(threshold: 2.0) } // 2秒を超えたら警告
        
        do {
            try save()
            LoggingService.shared.logDataOperation("save", entityType: "context", success: true)
        } catch let error as NSError {
            let repositoryError = CoreDataErrorHandler.shared.convertCoreDataError(
                error,
                operation: "save",
                entityName: "context"
            )
            throw repositoryError
        }
    }
    
    /// 安全なfetch操作（エラーハンドリング付き）
    func safeFetch<T: NSFetchRequestResult>(_ request: NSFetchRequest<T>) throws -> [T] {
        let measurement = PerformanceMeasurement(operation: "core_data_fetch_\(request.entityName ?? "unknown")")
        defer { measurement.finish(threshold: 1.0) } // 1秒を超えたら警告
        
        do {
            let results = try fetch(request)
            
            // 大量データ取得の警告
            if results.count > 1000 {
                LoggingService.shared.logError(
                    PerformanceError.tooManyRecordsLoaded(results.count, 1000),
                    context: "Core Data Fetch"
                )
            }
            
            LoggingService.shared.logDataOperation(
                "fetch",
                entityType: request.entityName ?? "unknown",
                success: true
            )
            
            return results
            
        } catch let error as NSError {
            LoggingService.shared.logDataOperation(
                "fetch",
                entityType: request.entityName ?? "unknown",
                success: false
            )
            
            let repositoryError = CoreDataErrorHandler.shared.convertCoreDataError(
                error,
                operation: "fetch",
                entityName: request.entityName ?? "unknown"
            )
            throw repositoryError
        }
    }
    
    /// バックグラウンドコンテキストでの安全な操作
    func performAndWaitWithErrorHandling<T>(_ block: () throws -> T) throws -> T {
        var result: Result<T, Error>!
        
        performAndWait {
            do {
                let value = try block()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
        }
        
        return try result.get()
    }
    
    /// 非同期での安全な操作
    func performWithErrorHandling<T>(_ block: @escaping () throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            perform {
                do {
                    let value = try block()
                    continuation.resume(returning: value)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Repository操作のベースクラス

/// 共通のCore Data操作とエラーハンドリングを提供するベースクラス
class CoreDataBaseRepository {
    
    internal let context: NSManagedObjectContext
    internal let entityName: String
    
    init(context: NSManagedObjectContext, entityName: String) {
        self.context = context
        self.entityName = entityName
    }
    
    // MARK: - Safe Core Data Operations
    
    /// リトライ付きsave操作
    internal func saveWithRetry(maxRetries: Int = 3) async throws {
        for attempt in 0..<maxRetries {
            do {
                try await context.performWithErrorHandling {
                    try self.context.safeSave()
                }
                return // 成功したら終了
                
            } catch let error as RepositoryError {
                if case .coreDataError(let nsError) = error {
                    // 一時的なエラーかどうか判定
                    if isTemporaryError(nsError as NSError) && attempt < maxRetries - 1 {
                        let delay = TimeInterval(attempt + 1) // 1, 2, 3秒の段階的遅延
                        // iOS 15対応：nanosecond指定のTask.sleep使用
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                }
                
                // リトライ不可能なエラーまたは最終試行
                await MainActor.run {
                    RepositoryErrorHandler.handle(error, operation: "save")
                }
                throw error
            }
        }
    }
    
    /// リトライ付きfetch操作
    internal func fetchWithRetry<T: NSFetchRequestResult>(
        _ request: NSFetchRequest<T>,
        maxRetries: Int = 2
    ) async throws -> [T] {
        for attempt in 0..<maxRetries {
            do {
                return try await context.performWithErrorHandling {
                    return try self.context.safeFetch(request)
                }
                
            } catch let error as RepositoryError {
                if case .coreDataError(let nsError) = error {
                    if isTemporaryError(nsError as NSError) && attempt < maxRetries - 1 {
                        let delay = TimeInterval(attempt + 1)
                        // iOS 15対応：nanosecond指定のTask.sleep使用
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    }
                }
                
                await MainActor.run {
                    RepositoryErrorHandler.handle(error, operation: "fetch")
                }
                throw error
            }
        }
        
        throw RepositoryError.coreDataError(NSError(domain: "RetryExhausted", code: -1))
    }
    
    /// データ整合性チェック付きcreate操作
    internal func createWithValidation<T: NSManagedObject>(
        entityType: T.Type,
        configure: @escaping (T) throws -> Void
    ) async throws -> T {
        return try await context.performWithErrorHandling {
            guard let entity = NSEntityDescription.entity(
                forEntityName: self.entityName,
                in: self.context
            ) else {
                throw RepositoryError.invalidData
            }
            
            let object = T(entity: entity, insertInto: self.context)
            
            // データ設定
            try configure(object)
            
            // 保存前バリデーション
            try self.validateBeforeSaving(object)
            
            return object
        }
    }
    
    // MARK: - Helper Methods
    
    private func isTemporaryError(_ error: NSError) -> Bool {
        switch error.code {
        case NSManagedObjectContextLockingError,
             NSPersistentStoreCoordinatorLockingError:
            return true
        default:
            return false
        }
    }
    
    private func validateBeforeSaving<T: NSManagedObject>(_ object: T) throws {
        // 基本バリデーション
        try object.validateForInsert()
        
        // カスタムバリデーションロジック
        // 子クラスでオーバーライド可能
    }
}

// MARK: - Core Data Health Monitor

/// Core Dataの健康状態を監視するクラス
final class CoreDataHealthMonitor {
    
    static let shared = CoreDataHealthMonitor()
    private init() {}
    
    private var contextSaveCount: Int = 0
    private var contextFetchCount: Int = 0
    private var errorCount: Int = 0
    private let startTime = Date()
    
    func recordSaveOperation() {
        contextSaveCount += 1
        checkHealthThresholds()
    }
    
    func recordFetchOperation() {
        contextFetchCount += 1
        checkHealthThresholds()
    }
    
    func recordError() {
        errorCount += 1
        checkHealthThresholds()
    }
    
    private func checkHealthThresholds() {
        let runtime = Date().timeIntervalSince(startTime)
        let errorRate = Double(errorCount) / Double(contextSaveCount + contextFetchCount + 1)
        
        // エラー率が高い場合の警告
        if errorRate > 0.1 && runtime > 300 { // 5分経過後、10%を超える
            LoggingService.shared.logError(
                PerformanceError.backgroundProcessingDelay("Core Data high error rate"),
                context: "Core Data Health Monitor"
            )
        }
        
        // 操作回数による監視
        if contextSaveCount > 1000 || contextFetchCount > 5000 {
            LoggingService.shared.logPerformance(
                "core_data_operations",
                value: Double(contextSaveCount + contextFetchCount),
                threshold: 5000
            )
        }
    }
    
    func getHealthReport() -> (saves: Int, fetches: Int, errors: Int, errorRate: Double) {
        let totalOperations = contextSaveCount + contextFetchCount
        let errorRate = totalOperations > 0 ? Double(errorCount) / Double(totalOperations) : 0
        
        return (contextSaveCount, contextFetchCount, errorCount, errorRate)
    }
}
