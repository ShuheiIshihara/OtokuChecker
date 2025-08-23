//
//  PrivacyInfoView.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/23.
//

import SwiftUI

struct PrivacyInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var privacyText: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ヘッダー情報
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "shield.checkerboard")
                                .foregroundColor(.blue)
                                .font(.system(size: 24))
                            
                            Text("プライバシー情報")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Text("お得チェッカーでのデータの取り扱いについてご説明します")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // プライバシーポリシー本文
                    VStack(alignment: .leading, spacing: 16) {
                        if privacyText.isEmpty {
                            // ローディング状態
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("読み込み中...")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                        } else {
                            Text(privacyText)
                                .font(.body)
                                .lineSpacing(6)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 最下部の余白
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("プライバシー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadPrivacyPolicy()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadPrivacyPolicy() {
        guard let url = Bundle.main.url(forResource: "PrivacyPolicy", withExtension: "txt") else {
            privacyText = """
            プライバシーポリシーの読み込みに失敗しました。
            
            お得チェッカーは、お客様が入力された商品情報をお使いのデバイス内にのみ保存し、外部に送信することはありません。
            
            詳細についてご質問がある場合は、App Storeのレビュー機能からお問い合わせください。
            """
            return
        }
        
        do {
            privacyText = try String(contentsOf: url, encoding: .utf8)
        } catch {
            privacyText = """
            プライバシーポリシーの読み込み中にエラーが発生しました。
            
            お得チェッカーは、お客様のプライバシーを尊重し、入力された商品価格等の情報をお使いのデバイス内にのみ保存いたします。
            
            ご不明な点がございましたら、App Storeのレビュー機能からお問い合わせください。
            
            エラー詳細: \(error.localizedDescription)
            """
        }
    }
}

// MARK: - Preview

#Preview {
    PrivacyInfoView()
}

#Preview("ダークモード") {
    PrivacyInfoView()
        .preferredColorScheme(.dark)
}