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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    @State private var productA = Product()
    @State private var productB = Product()
    @State private var comparisonResult: ComparisonResult?
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    private let comparisonService = ComparisonService()
    
    // レスポンシブレイアウト判定
    private var isLandscape: Bool {
        verticalSizeClass == .compact
    }
    
    private var useCompactLayout: Bool {
        isLandscape || horizontalSizeClass == .compact
    }

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ScrollView {
                    if isLandscape {
                        landscapeLayout
                            .frame(minWidth: geometry.size.width)
                    } else {
                        portraitLayout
                            .frame(minWidth: geometry.size.width)
                    }
                }
                .navigationTitle("お得チェッカー")
                .navigationBarTitleDisplayMode(isLandscape ? .inline : .large)
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
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("エラー", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // 縦向きレイアウト
    private var portraitLayout: some View {
        VStack(spacing: 20) {
            productInputsView
            actionButtonsView
            Divider()
            comparisonResultView
            Spacer(minLength: 50)
        }
        .padding()
    }
    
    // 横向きレイアウト（商品並列+下部結果）
    private var landscapeLayout: some View {
        VStack(spacing: 16) {
            // 商品入力を横並びで表示
            HStack(alignment: .top, spacing: 16) {
                // 商品A
                ProductInputView(
                    title: "商品A",
                    icon: "🏪",
                    product: $productA,
                    onHistoryTap: {
                        // TODO: 履歴参照機能を実装
                    }
                )
                .frame(maxWidth: .infinity)
                
                // 商品B
                ProductInputView(
                    title: "商品B",
                    icon: "🛒",
                    product: $productB,
                    onHistoryTap: {
                        // TODO: 履歴参照機能を実装
                    }
                )
                .frame(maxWidth: .infinity)
            }
            
            // 比較ボタン（中央配置）
            HStack {
                Spacer()
                Button(action: performComparison) {
                    HStack {
                        Image(systemName: "lightbulb")
                        Text("比較する")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 12)
                    .background(
                        canPerformComparison ? Color.blue : Color.gray
                    )
                    .cornerRadius(10)
                }
                .disabled(!canPerformComparison)
                Spacer()
            }
            
            // 区切り線
            Divider()
            
            // 比較結果（下部表示）
            comparisonResultView
            
            Spacer(minLength: 20)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // 商品入力セクション
    private var productInputsView: some View {
        VStack(spacing: isLandscape ? 12 : 20) {
            ProductInputView(
                title: "商品A",
                icon: "🏪",
                product: $productA,
                onHistoryTap: {
                    // TODO: 履歴参照機能を実装
                }
            )
            
            ProductInputView(
                title: "商品B",
                icon: "🛒",
                product: $productB,
                onHistoryTap: {
                    // TODO: 履歴参照機能を実装
                }
            )
        }
    }
    
    // アクションボタンセクション
    private var actionButtonsView: some View {
        Button(action: performComparison) {
            HStack {
                Image(systemName: "lightbulb")
                Text("比較する")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(isLandscape ? 12 : 16)
            .background(
                canPerformComparison ? Color.blue : Color.gray
            )
            .cornerRadius(10)
        }
        .disabled(!canPerformComparison)
    }
    
    // 比較結果セクション
    private var comparisonResultView: some View {
        ComparisonResultView(
            result: comparisonResult,
            onSaveProductA: {
                // TODO: 商品A保存機能を実装
            },
            onSaveProductB: {
                // TODO: 商品B保存機能を実装
            }
        )
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
