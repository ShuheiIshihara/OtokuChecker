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
                .font(.headline)
                .foregroundColor(.primary)
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
                            .foregroundColor(result.winner == .tie ? .orange : .green)
                        Spacer()
                    }
                    
                    // 単価の詳細
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("商品A:")
                                .fontWeight(.medium)
                            Text(result.productA.formattedUnitPrice)
                                .foregroundColor(result.winner == .productA ? .green : .primary)
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
                                .foregroundColor(result.winner == .productB ? .green : .primary)
                                .fontWeight(result.winner == .productB ? .bold : .regular)
                            if result.winner == .productB {
                                Text("🏆")
                            }
                            Spacer()
                        }
                        
                        if result.winner != .tie {
                            Text(result.formattedPriceDifference)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(result.winner == .productA ? Color.green : Color.blue)
                            .cornerRadius(8)
                        }
                        
                        Button(action: onSaveProductB) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("商品Bを保存")
                                if result.winner == .productB {
                                    Text("★")
                                        .foregroundColor(.yellow)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(result.winner == .productB ? Color.green : Color.blue)
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .cornerRadius(12)
            } else {
                // 比較前の表示
                VStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.title)
                        .foregroundColor(.gray)
                    
                    Text("商品情報を入力して比較ボタンを押してください")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
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