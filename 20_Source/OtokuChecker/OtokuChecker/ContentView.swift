//
//  ContentView.swift
//  OtokuChecker
//
//  Created by 石原脩平 on 2025/08/19.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var productA = Product()
    @State private var productB = Product()
    @State private var comparisonResult: ComparisonResult?
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    private let comparisonService = ComparisonService.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 商品A入力
                    ProductInputView(
                        title: "商品A",
                        icon: "🏪",
                        product: $productA,
                        onHistoryTap: {
                            // TODO: 履歴参照機能を実装
                        }
                    )
                    
                    // 商品B入力
                    ProductInputView(
                        title: "商品B",
                        icon: "🛒",
                        product: $productB,
                        onHistoryTap: {
                            // TODO: 履歴参照機能を実装
                        }
                    )
                    
                    // 比較ボタン
                    Button(action: performComparison) {
                        HStack {
                            Image(systemName: "lightbulb")
                            Text("比較する")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            canPerformComparison ? Color.blue : Color.gray
                        )
                        .cornerRadius(10)
                    }
                    .disabled(!canPerformComparison)
                    
                    Divider()
                    
                    // 比較結果
                    ComparisonResultView(
                        result: comparisonResult,
                        onSaveProductA: {
                            // TODO: 商品A保存機能を実装
                        },
                        onSaveProductB: {
                            // TODO: 商品B保存機能を実装
                        }
                    )
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("お得チェッカー")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        // TODO: 履歴画面への遷移
                    }) {
                        Image(systemName: "chart.bar")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // TODO: 設定画面への遷移
                    }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
        }
        .alert("エラー", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private var canPerformComparison: Bool {
        let validation = comparisonService.canCompareProducts(productA, productB)
        return validation.canCompare
    }
    
    private func performComparison() {
        let validation = comparisonService.canCompareProducts(productA, productB)
        
        guard validation.canCompare else {
            errorMessage = validation.reason
            showingErrorAlert = true
            return
        }
        
        comparisonResult = comparisonService.compareProducts(productA, productB)
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
