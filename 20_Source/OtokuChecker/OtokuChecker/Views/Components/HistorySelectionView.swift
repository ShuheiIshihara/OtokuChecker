//
//  HistorySelectionView.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/24.
//

import SwiftUI
import CoreData

/// 履歴から商品を選択するためのビューコンポーネント
struct HistorySelectionView: View {
    
    // MARK: - Properties
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    /// 商品選択時のコールバック
    let onProductSelected: (HistoryProduct) -> Void
    
    /// 検索テキスト
    @State private var searchText = ""
    
    /// 履歴データ（ProductRecordベース）
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ProductRecord.purchaseDate, ascending: false)],
        animation: .default
    )
    private var productRecords: FetchedResults<ProductRecord>
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 検索バー
                searchBarView
                
                // 履歴リスト
                historyListView
            }
            .navigationTitle("過去の記録から選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Views
    
    /// 検索バー
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.secondaryText)
            
            TextField("商品名で検索", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
        .background(AppColors.secondaryBackground)
    }
    
    /// 履歴リスト
    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredRecords.isEmpty {
                    emptyStateView
                } else {
                    ForEach(filteredRecords, id: \.entityID) { record in
                        HistoryRecordRow(record: record) {
                            let historyProduct = convertToHistoryProduct(record)
                            onProductSelected(historyProduct)
                            dismiss()
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    /// 空白状態の表示
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(AppColors.secondaryText)
            
            Text(searchText.isEmpty ? "履歴がありません" : "該当する商品が見つかりません")
                .font(.headline)
                .foregroundColor(AppColors.primaryText)
            
            Text(searchText.isEmpty ?
                 "比較した商品を保存すると、ここに履歴が表示されます。" :
                 "別のキーワードで検索してみてください。"
            )
                .font(.subheadline)
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - Computed Properties
    
    /// 検索でフィルタリングされた履歴
    private var filteredRecords: [ProductRecord] {
        if searchText.isEmpty {
            return Array(productRecords.prefix(50)) // パフォーマンスのため最大50件
        } else {
            return productRecords.filter { record in
                guard let productName = record.productName else { return false }
                return productName.localizedCaseInsensitiveContains(searchText)
            }.prefix(50).map { $0 }
        }
    }
    
    // MARK: - Helper Methods
    
    /// ProductRecordをHistoryProductに変換
    private func convertToHistoryProduct(_ record: ProductRecord) -> HistoryProduct {
        return HistoryProduct(
            id: record.entityID ?? UUID(),
            productName: record.productName ?? "",
            price: record.finalPrice?.decimalValue ?? record.originalPrice?.decimalValue ?? 0,
            quantity: record.quantity?.decimalValue ?? 0,
            unit: Unit(rawValue: record.unitType ?? "") ?? .gram,
            storeName: record.storeName ?? "",
            recordDate: record.purchaseDate ?? Date()
        )
    }
}

// MARK: - History Record Row

/// 履歴レコードの行表示
struct HistoryRecordRow: View {
    let record: ProductRecord
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    // 商品名
                    Text(record.productName ?? "不明な商品")
                        .font(.headline)
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(1)
                    
                    // 価格と数量
                    HStack {
                        Text("¥\(formattedPrice)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.primary)
                        
                        Text("/ \(formattedQuantity)")
                            .font(.subheadline)
                            .foregroundColor(AppColors.secondaryText)
                    }
                    
                    // 店舗名と日付
                    HStack {
                        if let storeName = record.storeName, !storeName.isEmpty {
                            Text(storeName)
                                .font(.caption)
                                .foregroundColor(AppColors.secondaryText)
                        }
                        
                        Spacer()
                        
                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(AppColors.secondaryText)
                    }
                }
                
                Spacer()
                
                // 選択インジケーター
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
        .background(AppColors.cardBackground)
        .cornerRadius(8)
    }
    
    // MARK: - Computed Properties
    
    private var formattedPrice: String {
        let price = record.finalPrice?.decimalValue ?? record.originalPrice?.decimalValue ?? 0
        return NumberFormatter.currency.string(from: price as NSDecimalNumber) ?? "¥0"
    }
    
    private var formattedQuantity: String {
        let quantity = record.quantity?.decimalValue ?? 0
        let unit = record.unitType ?? ""
        return "\(quantity)\(unit)"
    }
    
    private var formattedDate: String {
        guard let date = record.purchaseDate else { return "" }
        return DateFormatter.shortDate.string(from: date)
    }
}

// MARK: - History Product Model

/// 履歴から選択された商品を表すモデル
struct HistoryProduct {
    let id: UUID
    let productName: String
    let price: Decimal
    let quantity: Decimal
    let unit: Unit
    let storeName: String
    let recordDate: Date
}

// MARK: - Formatter Extensions

extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter
    }()
}

// MARK: - Preview

#Preview("履歴あり") {
    HistorySelectionView { product in
        print("Selected: \(product.productName)")
    }
}

#Preview("履歴なし") {
    HistorySelectionView { product in
        print("Selected: \(product.productName)")
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}