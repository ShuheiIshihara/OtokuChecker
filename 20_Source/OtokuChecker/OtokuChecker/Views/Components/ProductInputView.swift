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
    @State private var showingHistorySelection = false
    @State private var selectedHistoryProduct: HistoryProduct? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // ヘッダー
            HStack {
                Text("\(icon) \(title)")
                    .sectionTitleStyle()
                
                Spacer()
                
                Button(action: {
                    showingHistorySelection = true
                }) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.title2)
                        .foregroundColor(AppColors.primary)
                }
                .accessibilityLabel("履歴参照")
                .accessibilityHint("過去の商品記録から選択します")
            }
            
            // 入力フィールド
            VStack(spacing: 12) {
                // 商品名
                VStack(alignment: .leading, spacing: 4) {
                    Text("商品名")
                        .fieldLabelStyle()
                    
                    TextField("商品名を入力", text: $product.name)
                        .inputFieldStyle()
                }
                
                // 価格
                VStack(alignment: .leading, spacing: 4) {
                    Text("価格")
                        .fieldLabelStyle()
                    
                    HStack {
                        TextField("価格", text: $priceText)
                            .inputFieldStyle()
                            .keyboardType(.decimalPad)
                            .onChange(of: priceText) { newValue in
                                updatePrice(from: newValue)
                            }
                        
                        Text("円")
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                // 容量
                VStack(alignment: .leading, spacing: 4) {
                    Text("容量")
                        .fieldLabelStyle()
                    
                    HStack {
                        TextField("容量", text: $quantityText)
                            .inputFieldStyle()
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
            .cardStyle()
            
            // 履歴から選択された商品の表示
            if let historyProduct = selectedHistoryProduct {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                        .foregroundColor(AppColors.info)
                    
                    Text("履歴から選択: \(historyProduct.storeName) (\(formattedDate(historyProduct.recordDate)))")
                        .font(.caption)
                        .foregroundColor(AppColors.secondaryText)
                    
                    Spacer()
                    
                    Button("クリア") {
                        selectedHistoryProduct = nil
                        clearProduct()
                    }
                    .font(.caption)
                    .foregroundColor(AppColors.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.info.opacity(0.1))
                .cornerRadius(6)
            }
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
        .sheet(isPresented: $showingHistorySelection) {
            HistorySelectionView { historyProduct in
                selectedHistoryProduct = historyProduct
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
    
    /// 履歴から選択された商品を現在の商品に適用
    private func applyHistoryProduct(_ historyProduct: HistoryProduct) {
        product.name = historyProduct.productName
        product.price = historyProduct.price
        product.quantity = historyProduct.quantity
        product.unit = historyProduct.unit
        
        // テキストフィールドも更新
        updatePriceText()
        updateQuantityText()
    }
    
    /// 商品情報をクリア
    private func clearProduct() {
        product.name = ""
        product.price = 0
        product.quantity = 0
        product.unit = .gram
        priceText = ""
        quantityText = ""
    }
    
    /// 日付をフォーマット
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
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