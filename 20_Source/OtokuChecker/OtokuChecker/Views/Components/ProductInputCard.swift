//
//  ProductInputCard.swift
//  OtokuChecker
//
//  Created by Claude on 2025/08/24.
//

import SwiftUI

struct ProductInputCard: View {
    let title: String
    let icon: String
    @Binding var product: Product
    let backgroundColor: Color
    let onHistoryTap: () -> Void
    
    @State private var priceText: String = ""
    @State private var quantityText: String = ""
    @State private var showingHistorySelection = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // ヘッダー
            HStack {
                Text("\(icon) \(title)")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    showingHistorySelection = true
                }) {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        )
                }
                .accessibilityLabel("履歴参照")
            }
            
            // 商品名入力
            VStack(alignment: .leading, spacing: 8) {
                Text("商品名")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                TextField("商品名（任意）", text: $product.name)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            
            // 価格入力
            VStack(alignment: .leading, spacing: 8) {
                Text("価格")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                HStack {
                    TextField("1400", text: $priceText)
                        .font(.body)
                        .keyboardType(.decimalPad)
                        .onChange(of: priceText) { newValue in
                            updatePrice(from: newValue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    
                    Text("円")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
            }
            
            // 容量入力
            VStack(alignment: .leading, spacing: 8) {
                Text("容量")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    TextField("5", text: $quantityText)
                        .font(.body)
                        .keyboardType(.decimalPad)
                        .onChange(of: quantityText) { newValue in
                            updateQuantity(from: newValue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    
                    // 単位選択
                    Menu {
                        ForEach(Unit.allCases, id: \.self) { unit in
                            Button(unit.rawValue) {
                                product.unit = unit
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(product.unit.rawValue)
                                .font(.body)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .frame(width: 100)
                }
            }
        }
        .padding(20)
        .background(backgroundColor)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .onAppear {
            initializeTextFields()
        }
        .onChange(of: product.price) { _ in
            updatePriceText()
        }
        .onChange(of: product.quantity) { _ in
            updateQuantityText()
        }
        .sheet(isPresented: $showingHistorySelection) {
            HistorySelectionView { historyProduct in
                applyHistoryProduct(historyProduct)
            }
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
    
    private func applyHistoryProduct(_ historyProduct: HistoryProduct) {
        product.name = historyProduct.productName
        product.price = historyProduct.price
        product.quantity = historyProduct.quantity
        product.unit = historyProduct.unit
        
        updatePriceText()
        updateQuantityText()
    }
}

struct ProductInputCard_Previews: PreviewProvider {
    static var previews: some View {
        ProductInputCard(
            title: "商品A",
            icon: "🏪",
            product: .constant(Product(name: "コシヒカリ 5kg", price: 1400, quantity: 5, unit: .kilogram)),
            backgroundColor: Color(red: 0.98, green: 0.92, blue: 1.0),
            onHistoryTap: {}
        )
        .padding()
    }
}