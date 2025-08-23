//
//  ValidationResult.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/23.
//

import Foundation

/// バリデーション結果を表現するenum型
enum ValidationResult<T> {
    case success(T)
    case failure(ValidationInputError)
    
    /// バリデーションが成功したかどうか
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    /// バリデーションが失敗したかどうか
    var isFailure: Bool {
        return !isSuccess
    }
    
    /// 成功時の値を取得（失敗時はnil）
    var value: T? {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return nil
        }
    }
    
    /// エラーメッセージを取得（成功時はnil）
    var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error.errorDescription
        }
    }
    
    /// 結果を変換する
    func map<U>(_ transform: (T) throws -> U) rethrows -> ValidationResult<U> {
        switch self {
        case .success(let value):
            return .success(try transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// エラーを変換する
    func mapError(_ transform: (ValidationInputError) -> ValidationInputError) -> ValidationResult<T> {
        switch self {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            return .failure(transform(error))
        }
    }
}

// MARK: - Convenience Extensions

extension ValidationResult {
    /// 複数のバリデーション結果をまとめる
    static func combine<A, B>(_ resultA: ValidationResult<A>, _ resultB: ValidationResult<B>) -> ValidationResult<(A, B)> {
        switch (resultA, resultB) {
        case (.success(let a), .success(let b)):
            return .success((a, b))
        case (.failure(let error), _):
            return .failure(error)
        case (_, .failure(let error)):
            return .failure(error)
        }
    }
    
    /// 3つのバリデーション結果をまとめる
    static func combine<A, B, C>(
        _ resultA: ValidationResult<A>,
        _ resultB: ValidationResult<B>,
        _ resultC: ValidationResult<C>
    ) -> ValidationResult<(A, B, C)> {
        switch (resultA, resultB, resultC) {
        case (.success(let a), .success(let b), .success(let c)):
            return .success((a, b, c))
        case (.failure(let error), _, _):
            return .failure(error)
        case (_, .failure(let error), _):
            return .failure(error)
        case (_, _, .failure(let error)):
            return .failure(error)
        }
    }
}
