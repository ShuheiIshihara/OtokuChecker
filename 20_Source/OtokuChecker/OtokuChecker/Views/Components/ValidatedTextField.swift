//
//  ValidatedTextField.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/23.
//

import SwiftUI

/// バリデーション機能付きのテキストフィールドコンポーネント
struct ValidatedTextField: View {
    
    /// バリデーションのタイプ
    enum ValidationType {
        case productName
        case price
        case quantity(Unit)
    }
    
    // MARK: - Properties
    
    let title: String
    let placeholder: String
    let validationType: ValidationType
    @Binding var text: String
    @Binding var isValid: Bool
    
    @State private var errorMessage: String?
    @State private var warningMessage: String?
    @State private var validationTask: Task<Void, Never>?
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ラベル
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if hasError {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                if isValid && !text.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
                
                Spacer()
                
                // 文字数カウンター（商品名の場合のみ）
                if case .productName = validationType {
                    let (current, max, isOver) = ProductNameValidator.checkLength(text)
                    Text("\(current)/\(max)")
                        .font(.caption2)
                        .foregroundColor(isOver ? .red : .secondary)
                }
            }
            
            // テキストフィールド
            TextField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: hasError ? 2 : 1)
                )
                .keyboardType(keyboardType)
                .onChange(of: text) { _ in
                    validateWithDebounce()
                }
                .onAppear {
                    validateImmediately()
                }
            
            // エラーメッセージ
            if let errorMessage = errorMessage {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
            }
            
            // 警告メッセージ
            if let warningMessage = warningMessage, errorMessage == nil {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    
                    Text(warningMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var hasError: Bool {
        errorMessage != nil
    }
    
    private var borderColor: Color {
        if hasError {
            return .red
        } else if isValid && !text.isEmpty {
            return .green
        } else {
            return Color(.systemGray4)
        }
    }
    
    private var keyboardType: UIKeyboardType {
        switch validationType {
        case .productName:
            return .default
        case .price, .quantity:
            return .decimalPad
        }
    }
    
    // MARK: - Methods
    
    private func validateWithDebounce() {
        // 前回のタスクをキャンセル
        validationTask?.cancel()
        
        // デバウンス処理（300ms後にバリデーション実行）
        validationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            guard !Task.isCancelled else { return }
            performValidation()
        }
    }
    
    private func validateImmediately() {
        validationTask?.cancel()
        performValidation()
    }
    
    private func performValidation() {
        switch validationType {
        case .productName:
            validateProductName()
        case .price:
            validatePrice()
        case .quantity(let unit):
            validateQuantity(unit: unit)
        }
    }
    
    private func validateProductName() {
        let result = ProductNameValidator.validate(text)
        
        switch result {
        case .success:
            errorMessage = nil
            warningMessage = nil
            isValid = true
        case .failure(let error):
            errorMessage = error.errorDescription
            warningMessage = nil
            isValid = false
        }
    }
    
    private func validatePrice() {
        let (cleaned, error, warning) = PriceValidator.checkRealtime(text)
        
        if let error = error {
            errorMessage = error.errorDescription
            warningMessage = nil
            isValid = false
        } else {
            errorMessage = nil
            warningMessage = warning
            isValid = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        // クリーンアップされた値で更新（無限ループを避けるため注意深く）
        if let cleaned = cleaned, cleaned != text && text.trimmingCharacters(in: .whitespacesAndNewlines) != cleaned {
            DispatchQueue.main.async {
                self.text = cleaned
            }
        }
    }
    
    private func validateQuantity(unit: Unit) {
        let (cleaned, error, warning) = QuantityValidator.checkRealtime(text, unit: unit)
        
        if let error = error {
            errorMessage = error.errorDescription
            warningMessage = nil
            isValid = false
        } else {
            errorMessage = nil
            warningMessage = warning
            isValid = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        // クリーンアップされた値で更新
        if let cleaned = cleaned, cleaned != text && text.trimmingCharacters(in: .whitespacesAndNewlines) != cleaned {
            DispatchQueue.main.async {
                self.text = cleaned
            }
        }
    }
}

// MARK: - Convenience Initializers

extension ValidatedTextField {
    
    /// 商品名用のテキストフィールドを作成
    static func forProductName(
        text: Binding<String>,
        isValid: Binding<Bool>
    ) -> ValidatedTextField {
        ValidatedTextField(
            title: "商品名",
            placeholder: "例: 牛乳、りんご、パン",
            validationType: .productName,
            text: text,
            isValid: isValid
        )
    }
    
    /// 価格用のテキストフィールドを作成
    static func forPrice(
        text: Binding<String>,
        isValid: Binding<Bool>
    ) -> ValidatedTextField {
        ValidatedTextField(
            title: "価格",
            placeholder: "例: 198, 1980",
            validationType: .price,
            text: text,
            isValid: isValid
        )
    }
    
    /// 数量用のテキストフィールドを作成
    static func forQuantity(
        text: Binding<String>,
        unit: Unit,
        isValid: Binding<Bool>
    ) -> ValidatedTextField {
        ValidatedTextField(
            title: "数量",
            placeholder: QuantityValidator.getPlaceholderExample(for: unit),
            validationType: .quantity(unit),
            text: text,
            isValid: isValid
        )
    }
}

// MARK: - Preview

#Preview("商品名入力") {
    VStack(spacing: 20) {
        ValidatedTextField.forProductName(
            text: .constant(""),
            isValid: .constant(false)
        )
        
        ValidatedTextField.forProductName(
            text: .constant("牛乳"),
            isValid: .constant(true)
        )
        
        ValidatedTextField.forProductName(
            text: .constant("このような非常に長い商品名を入力した場合はエラーになります"),
            isValid: .constant(false)
        )
    }
    .padding()
}

#Preview("価格入力") {
    VStack(spacing: 20) {
        ValidatedTextField.forPrice(
            text: .constant(""),
            isValid: .constant(false)
        )
        
        ValidatedTextField.forPrice(
            text: .constant("198"),
            isValid: .constant(true)
        )
        
        ValidatedTextField.forPrice(
            text: .constant("abc"),
            isValid: .constant(false)
        )
    }
    .padding()
}

#Preview("数量入力") {
    VStack(spacing: 20) {
        ValidatedTextField.forQuantity(
            text: .constant(""),
            unit: .gram,
            isValid: .constant(false)
        )
        
        ValidatedTextField.forQuantity(
            text: .constant("500"),
            unit: .gram,
            isValid: .constant(true)
        )
        
        ValidatedTextField.forQuantity(
            text: .constant("1.5"),
            unit: .piece,
            isValid: .constant(false)
        )
    }
    .padding()
}