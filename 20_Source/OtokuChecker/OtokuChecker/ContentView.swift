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
    @State private var hasHistorySelection = false
    
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
                            Image(systemName: "list.clipboard")
                                .foregroundColor(AppColors.primary)
                        }
                        .accessibilityLabel("履歴")
                        .accessibilityHint("過去の比較履歴を確認します")
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            // TODO: 設定画面への遷移
                        }) {
                            Image(systemName: "gear")
                                .foregroundColor(AppColors.primary)
                        }
                        .accessibilityLabel("設定")
                        .accessibilityHint("アプリの設定を変更します")
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("比較エラー", isPresented: $showingErrorAlert) {
            Button("確認") {
                // エラークリア時に結果をリセット
                comparisonResult = nil
            }
        } message: {
            VStack(alignment: .leading, spacing: 8) {
                Text(errorMessage ?? "予期しないエラーが発生しました")
                Text("商品情報を確認して、再度お試しください。")
                    .font(.caption)
                    .foregroundColor(AppColors.secondaryText)
            }
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
                    }
                }
                .primaryButtonStyle(isEnabled: canPerformComparison)
                .disabled(!canPerformComparison)
                .padding(.horizontal, 40)
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
            }
        }
        .primaryButtonStyle(isEnabled: canPerformComparison)
        .disabled(!canPerformComparison)
        .padding(isLandscape ? 12 : 16)
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
        let comparisonProductA = ComparisonProduct(
            name: productA.name,
            price: productA.price,
            quantity: productA.quantity,
            unit: productA.unit,
            taxIncluded: true,
            taxRate: Decimal(0.10)
        )
        let comparisonProductB = ComparisonProduct(
            name: productB.name,
            price: productB.price,
            quantity: productB.quantity,
            unit: productB.unit,
            taxIncluded: true,
            taxRate: Decimal(0.10)
        )
        
        let validation = comparisonService.canCompareProducts(comparisonProductA, comparisonProductB)
        return validation.canCompare
    }
    
    /// エラーメッセージをユーザーフレンドリーに変換
    private func convertToUserFriendlyMessage(_ error: String) -> String {
        if error.contains("unit") || error.contains("単位") {
            return "商品の単位が比較できません。同じ種類の単位（重さ、容量など）で入力してください。"
        } else if error.contains("price") || error.contains("価格") {
            return "価格が正しく入力されていません。数字で入力してください。"
        } else if error.contains("quantity") || error.contains("数量") {
            return "数量が正しく入力されていません。0より大きい数字で入力してください。"
        } else if error.contains("name") || error.contains("商品名") {
            return "商品名が入力されていません。比較する商品の名前を入力してください。"
        } else {
            return "入力内容を確認してください。すべての項目を正しく入力する必要があります。"
        }
    }
    
    /// 履歴から選択された商品があるかチェック
    private func checkForHistorySelection() -> Bool {
        // ProductInputView内の履歴選択状態は、ここでは直接取得できないため、
        // 商品名が設定されているかで判断（簡易実装）
        return !productA.name.isEmpty || !productB.name.isEmpty
    }
    
    private func performComparison() {
        // 結果をクリアしてから比較開始
        comparisonResult = nil
        
        // 履歴選択の状態を更新
        hasHistorySelection = checkForHistorySelection()
        
        let comparisonProductA = ComparisonProduct(
            name: productA.name,
            price: productA.price,
            quantity: productA.quantity,
            unit: productA.unit,
            taxIncluded: true,
            taxRate: Decimal(0.10)
        )
        let comparisonProductB = ComparisonProduct(
            name: productB.name,
            price: productB.price,
            quantity: productB.quantity,
            unit: productB.unit,
            taxIncluded: true,
            taxRate: Decimal(0.10)
        )
        
        let validation = comparisonService.canCompareProducts(comparisonProductA, comparisonProductB)
        
        guard validation.canCompare else {
            // ユーザーフレンドリーなエラーメッセージに変換
            errorMessage = convertToUserFriendlyMessage(validation.reason ?? "比較できません")
            comparisonResult = nil
            showingErrorAlert = true
            return
        }
        
        do {
            let result = try comparisonService.compare(productA: comparisonProductA, productB: comparisonProductB)
            // Convert ExtendedComparisonResult to ComparisonResult for compatibility
            let winner: ComparisonResult.Winner = {
                switch result.winner {
                case .productA: return .productA
                case .productB: return .productB
                case .tie: return .tie
                }
            }()
            
            comparisonResult = ComparisonResult(
                productA: productA,
                productB: productB,
                winner: winner,
                priceDifference: result.comparisonDetails.priceDifference,
                percentageDifference: result.comparisonDetails.percentageDifference
            )
            
            // 正常な比較が完了した場合、エラー状態をクリア
            if showingErrorAlert {
                showingErrorAlert = false
            }
        } catch {
            errorMessage = convertToUserFriendlyMessage(error.localizedDescription)
            comparisonResult = nil
            showingErrorAlert = true
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
