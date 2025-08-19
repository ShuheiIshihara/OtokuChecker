//
//  ProductInputView.swift
//  OtokuChecker
//
//  Created by Claude on 2025/08/19.
//

import SwiftUI

struct ProductInputView: View {
    let title: String
    let icon: String
    @Binding var product: Product
    let onHistoryTap: () -> Void
    
    @State private var priceText: String = ""
    @State private var quantityText: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            HStack {
                Text("\(icon) \(title)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onHistoryTap) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            // 入力フィールド
            VStack(spacing: 12) {
                // 商品名
                VStack(alignment: .leading, spacing: 4) {
                    Text("商品名")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("商品名を入力", text: $product.name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // 価格
                VStack(alignment: .leading, spacing: 4) {
                    Text("価格")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("価格", text: $priceText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .onChange(of: priceText) { newValue in
                                updatePrice(from: newValue)
                            }
                        
                        Text("円")
                            .foregroundColor(.secondary)
                    }
                }
                
                // 容量
                VStack(alignment: .leading, spacing: 4) {
                    Text("容量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("容量", text: $quantityText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .onChange(of: quantityText) { newValue in
                                updateQuantity(from: newValue)
                            }
                        
                        Picker("単位", selection: $product.unit) {
                            ForEach(Unit.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 80)
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .onAppear {
            initializeTextFields()
        }
        .onChange(of: product.price) { _ in
            updatePriceText()
        }
        .onChange(of: product.quantity) { _ in
            updateQuantityText()
        }
    }
    
    private func initializeTextFields() {
        updatePriceText()
        updateQuantityText()
    }
    
    private func updatePriceText() {
        if product.price > 0 {
            priceText = NSDecimalNumber(decimal: product.price).stringValue
        }
    }
    
    private func updateQuantityText() {
        if product.quantity > 0 {
            quantityText = NSDecimalNumber(decimal: product.quantity).stringValue
        }
    }
    
    private func updatePrice(from text: String) {
        if let decimal = Decimal(string: text) {
            product.price = decimal
        } else if text.isEmpty {
            product.price = 0
        }
    }
    
    private func updateQuantity(from text: String) {
        if let decimal = Decimal(string: text) {
            product.quantity = decimal
        } else if text.isEmpty {
            product.quantity = 0
        }
    }
}

struct ProductInputView_Previews: PreviewProvider {
    static var previews: some View {
        ProductInputView(
            title: "商品A",
            icon: "🏪",
            product: .constant(Product(name: "コシヒカリ 5kg", price: 1400, quantity: 5, unit: .kilogram)),
            onHistoryTap: {}
        )
        .padding()
    }
}