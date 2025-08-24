//
//  ComparisonResultView.swift
//  OtokuChecker
//
//  Created by Claude on 2025/08/19.
//

import SwiftUI

struct ComparisonResultView: View {
    let result: ComparisonResult?
    let onSaveProductA: () -> Void
    let onSaveProductB: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("💡 比較結果")
                .sectionTitleStyle()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let result = result {
                // 比較結果の表示
                VStack(spacing: 12) {
                    // 勝者の表示
                    HStack {
                        Text(result.winner.emoji)
                            .font(.title)
                        Text(result.winner.displayText)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(result.winner == .tie ? AppColors.warning : AppColors.success)
                        Spacer()
                    }
                    
                    // 単価の詳細
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("商品A:")
                                .fontWeight(.medium)
                            Text(result.productA.formattedUnitPrice)
                                .foregroundColor(result.winner == .productA ? AppColors.success : AppColors.primaryText)
                                .fontWeight(result.winner == .productA ? .bold : .regular)
                            if result.winner == .productA {
                                Text("🏆")
                            }
                            Spacer()
                        }
                        
                        HStack {
                            Text("商品B:")
                                .fontWeight(.medium)
                            Text(result.productB.formattedUnitPrice)
                                .foregroundColor(result.winner == .productB ? AppColors.success : AppColors.primaryText)
                                .fontWeight(result.winner == .productB ? .bold : .regular)
                            if result.winner == .productB {
                                Text("🏆")
                            }
                            Spacer()
                        }
                        
                        if result.winner != .tie {
                            Text(result.formattedPriceDifference)
                                .font(.subheadline)
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // 保存ボタン
                    HStack(spacing: 12) {
                        Button(action: onSaveProductA) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("商品Aを保存")
                                if result.winner == .productA {
                                    Text("★")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        .smallActionButtonStyle()
                        
                        Button(action: onSaveProductB) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("商品Bを保存")
                                if result.winner == .productB {
                                    Text("★")
                                        .foregroundColor(.yellow)
                                }
                            }
                        }
                        .smallActionButtonStyle()
                    }
                }
                .padding(16)
                .background(AppColors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.border, lineWidth: 1)
                )
                .cornerRadius(12)
            } else {
                // 比較前の表示（初回利用者向けガイダンス）
                VStack(spacing: 16) {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.primary)
                        .padding(.bottom, 8)
                    
                    Text("🛍️ お得な商品を見つけよう！")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("①")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(AppColors.primary)
                                .clipShape(Circle())
                            Text("商品Aと商品Bの情報を入力")
                                .font(.subheadline)
                                .foregroundColor(AppColors.secondaryText)
                            Spacer()
                        }
                        
                        HStack {
                            Text("②")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(AppColors.primary)
                                .clipShape(Circle())
                            Text("「💡 比較する」ボタンをタップ")
                                .font(.subheadline)
                                .foregroundColor(AppColors.secondaryText)
                            Spacer()
                        }
                        
                        HStack {
                            Text("③")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 20, height: 20)
                                .background(AppColors.primary)
                                .clipShape(Circle())
                            Text("お得な商品がすぐわかる！")
                                .font(.subheadline)
                                .foregroundColor(AppColors.secondaryText)
                            Spacer()
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [AppColors.cardBackground, AppColors.lightBackground]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(12)
            }
        }
    }
}

struct ComparisonResultView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // 比較結果ありの場合
            ComparisonResultView(
                result: ComparisonResult(
                    productA: Product(name: "コシヒカリ 5kg", price: 1400, quantity: 5, unit: .kilogram),
                    productB: Product(name: "コシヒカリ 2kg", price: 650, quantity: 2, unit: .kilogram),
                    winner: .productA,
                    priceDifference: 45,
                    percentageDifference: 13.8
                ),
                onSaveProductA: {},
                onSaveProductB: {}
            )
            
            // 比較結果なしの場合
            ComparisonResultView(
                result: nil,
                onSaveProductA: {},
                onSaveProductB: {}
            )
        }
        .padding()
    }
}