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
            ZStack {
                Color(red: 0.98, green: 0.92, blue: 1.0)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // ヘッダー部分
                        headerView
                        
                        // 商品入力エリア - レスポンシブレイアウト
                        if isLandscape {
                            // 横向き: 商品AとBを並列表示
                            HStack(spacing: 16) {
                                ProductInputCard(
                                    title: "商品A",
                                    icon: "🏪",
                                    product: $productA,
                                    backgroundColor: Color.white,
                                    onHistoryTap: {
                                        // TODO: 履歴参照機能を実装
                                    }
                                )
                                .frame(maxWidth: .infinity)
                                
                                ProductInputCard(
                                    title: "商品B",
                                    icon: "🛒",
                                    product: $productB,
                                    backgroundColor: Color.white,
                                    onHistoryTap: {
                                        // TODO: 履歴参照機能を実装
                                    }
                                )
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            // 縦向き: 商品AとBを縦並び表示
                            VStack(spacing: 20) {
                                ProductInputCard(
                                    title: "商品A",
                                    icon: "🏪",
                                    product: $productA,
                                    backgroundColor: Color.white,
                                    onHistoryTap: {
                                        // TODO: 履歴参照機能を実装
                                    }
                                )
                                
                                ProductInputCard(
                                    title: "商品B",
                                    icon: "🛒",
                                    product: $productB,
                                    backgroundColor: Color.white,
                                    onHistoryTap: {
                                        // TODO: 履歴参照機能を実装
                                    }
                                )
                            }
                        }
                        
                        // 比較ボタン
                        comparisonButton
                        
                        // 比較結果
                        if comparisonResult != nil {
                            comparisonResultCard
                        }
                        
                        Spacer(minLength: 300)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("比較エラー", isPresented: $showingErrorAlert) {
            Button("確認") {
                comparisonResult = nil
            }
        } message: {
            VStack(alignment: .leading, spacing: 8) {
                Text(errorMessage ?? "予期しないエラーが発生しました")
                Text("商品情報を確認して、再度お試しください。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // ヘッダービュー
    private var headerView: some View {
        HStack {
            Text("おとくのおとも")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Spacer()
            
            HStack(spacing: 12) {
                // 統計ボタン
                Button(action: {
                    // TODO: 統計画面への遷移
                }) {
                    Circle()
                        .fill(Color(red: 0.95, green: 0.9, blue: 1.0))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(Color(red: 0.8, green: 0.4, blue: 1.0))
                        )
                }
                .accessibilityLabel("統計")
                
                // 設定ボタン
                Button(action: {
                    // TODO: 設定画面への遷移
                }) {
                    Circle()
                        .fill(Color(red: 0.85, green: 0.85, blue: 1.0))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(Color(red: 0.5, green: 0.4, blue: 1.0))
                        )
                }
                .accessibilityLabel("設定")
            }
        }
        .padding(.horizontal, 4)
    }
    
    // 比較ボタン
    private var comparisonButton: some View {
        Button(action: {
            // キーボードを下げる
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            // 比較処理を実行
            performComparison()
        }) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.white)
                Text("比較する")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.9, green: 0.3, blue: 0.8),
                        Color(red: 0.6, green: 0.3, blue: 0.9)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color(red: 0.7, green: 0.3, blue: 0.8).opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(!canPerformComparison)
        .opacity(canPerformComparison ? 1.0 : 0.6)
    }
    
    // 比較結果カード
    private var comparisonResultCard: some View {
        VStack(spacing: 20) {
            resultHeader
            
            if let result = comparisonResult {
                resultContent(for: result)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // 結果ヘッダー
    private var resultHeader: some View {
        HStack {
            Circle()
                .fill(Color.yellow.opacity(0.8))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                )
            
            Text("比較結果")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
    
    // 結果コンテンツ
    private func resultContent(for result: ComparisonResult) -> some View {
        VStack(spacing: 16) {
            winnerHeader(for: result)
            priceDetails(for: result)
            saveButtons(for: result)
        }
    }
    
    // 勝者ヘッダー
    private func winnerHeader(for result: ComparisonResult) -> some View {
        HStack {
            Circle()
                .fill(Color.yellow.opacity(0.8))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                )
            
            Text(winnerText(for: result))
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
        }
    }
    
    // 価格詳細
    private func priceDetails(for result: ComparisonResult) -> some View {
        VStack(spacing: 12) {
            productARow(for: result)
            productBRow(for: result)
            
            if result.winner != .tie {
                differenceRow(for: result)
            }
        }
    }
    
    // 商品A価格行
    private func productARow(for result: ComparisonResult) -> some View {
        let displayUnit = Unit.getLargerUnit(result.productA.unit, result.productB.unit)
        let unitPriceA = result.productA.unit.convertValue(result.productA.price / result.productA.quantity, to: displayUnit)
        
        return HStack {
            Text(getProductDisplayName(result.productA, defaultName: "商品A") + ":")
                .fontWeight(.medium)
            Spacer()
            Text(formatDisplayUnitPrice(unitPriceA, displayUnit.rawValue))
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // 商品B価格行
    private func productBRow(for result: ComparisonResult) -> some View {
        let displayUnit = Unit.getLargerUnit(result.productA.unit, result.productB.unit)
        let unitPriceB = result.productB.unit.convertValue(result.productB.price / result.productB.quantity, to: displayUnit)
        
        return HStack {
            Text(getProductDisplayName(result.productB, defaultName: "商品B") + ":")
                .fontWeight(.medium)
            Spacer()
            Text(formatDisplayUnitPrice(unitPriceB, displayUnit.rawValue))
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    // 差額表示行
    private func differenceRow(for result: ComparisonResult) -> some View {
        let displayUnit = Unit.getLargerUnit(result.productA.unit, result.productB.unit)
        
        return HStack {
            Image(systemName: "arrow.right")
                .foregroundColor(.green)
            Text("\(formatPrice(abs(result.priceDifference)))/\(displayUnit.rawValue)の差 (\(String(format: "%.1f", Double(truncating: abs(result.percentageDifference) as NSDecimalNumber)))%お得)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.green)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
    
    // 保存ボタン
    private func saveButtons(for result: ComparisonResult) -> some View {
        HStack(spacing: 12) {
            if result.winner == .tie {
                // 同じ値段の場合は両方とも目立つ色にする
                saveButtonA(for: result, isWinner: true)
                saveButtonB(for: result, isWinner: true)
            } else {
                saveButtonA(for: result, isWinner: result.winner == .productA)
                saveButtonB(for: result, isWinner: result.winner == .productB)
            }
        }
    }
    
    // 商品A保存ボタン
    private func saveButtonA(for result: ComparisonResult, isWinner: Bool) -> some View {
        let productName = getProductDisplayName(result.productA, defaultName: "商品A")
        let textColor: Color = isWinner ? .white : .gray
        let backgroundColor = isWinner ? saveButtonGradient : AnyView(Color.gray.opacity(0.2))
        
        return Button(action: {
            // TODO: 商品A保存機能を実装
        }) {
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .foregroundColor(textColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(productName)を")
                        .font(.caption)
                        .foregroundColor(textColor)
                    Text("保存")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)
                }
                if isWinner {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor)
            .cornerRadius(12)
        }
    }
    
    // 商品B保存ボタン
    private func saveButtonB(for result: ComparisonResult, isWinner: Bool) -> some View {
        let productName = getProductDisplayName(result.productB, defaultName: "商品B")
        let textColor: Color = isWinner ? .white : .gray
        let backgroundColor = isWinner ? saveButtonGradient : AnyView(Color.gray.opacity(0.2))
        
        return Button(action: {
            // TODO: 商品B保存機能を実装
        }) {
            HStack {
                Image(systemName: "square.and.arrow.down")
                    .foregroundColor(textColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(productName)を")
                        .font(.caption)
                        .foregroundColor(textColor)
                    Text("保存")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(textColor)
                }
                if isWinner {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor)
            .cornerRadius(12)
        }
    }
    
    // 保存ボタンのグラデーション
    private var saveButtonGradient: AnyView {
        AnyView(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.9, green: 0.3, blue: 0.8),
                    Color(red: 0.6, green: 0.3, blue: 0.9)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
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
        } else {
            return "入力内容を確認してください。価格と数量を正しく入力する必要があります。"
        }
    }
    
    /// 履歴から選択された商品があるかチェック
    private func checkForHistorySelection() -> Bool {
        // ProductInputView内の履歴選択状態は、ここでは直接取得できないため、
        // 商品名が設定されているかで判断（簡易実装）
        return !productA.name.isEmpty || !productB.name.isEmpty
    }
    
    /// 勝者テキストを生成
    private func winnerText(for result: ComparisonResult) -> String {
        switch result.winner {
        case .productA:
            return getProductDisplayName(result.productA, defaultName: "商品A") + "がお得！"
        case .productB:
            return getProductDisplayName(result.productB, defaultName: "商品B") + "がお得！"
        case .tie:
            return "同じお得度です"
        }
    }
    
    /// 商品の表示名を取得（空の場合はデフォルト名を使用）
    private func getProductDisplayName(_ product: Product, defaultName: String) -> String {
        let trimmedName = product.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? defaultName : trimmedName
    }
    
    /// 単位価格をフォーマット
    private func formatUnitPrice(_ price: Decimal, _ quantity: Decimal, _ unit: String) -> String {
        let unitPrice = price / quantity
        return "\(formatPrice(unitPrice))/\(unit)"
    }
    
    /// 表示用単位価格をフォーマット
    private func formatDisplayUnitPrice(_ unitPrice: Decimal, _ unit: String) -> String {
        return "\(formatPrice(unitPrice))/\(unit)"
    }
    
    /// 価格をフォーマット
    private func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        let nsDecimal = price as NSDecimalNumber
        return "\(formatter.string(from: nsDecimal) ?? "0")円"
    }
    
    private func performComparison() {
        comparisonResult = nil
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
            errorMessage = convertToUserFriendlyMessage(validation.reason ?? "比較できません")
            comparisonResult = nil
            showingErrorAlert = true
            return
        }
        
        do {
            let result = try comparisonService.compare(productA: comparisonProductA, productB: comparisonProductB)
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
