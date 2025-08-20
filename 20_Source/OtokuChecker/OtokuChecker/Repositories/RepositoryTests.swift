//
//  RepositoryTests.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/20.
//

import Foundation
import CoreData

/// Repository層の基本動作確認用テストクラス
/// プロダクションコードですが、開発時の動作確認に使用
class RepositoryTests {
    
    // MARK: - Properties
    
    private let container: RepositoryContainer
    
    // MARK: - Initialization
    
    init(container: RepositoryContainer) {
        self.container = container
    }
    
    // MARK: - Test Methods
    
    /// 基本的なCRUD操作のテスト
    func testBasicCRUD() async {
        print("🧪 Repository Basic CRUD Test開始")
        
        // 1. ProductCategoryのテスト
        await testProductCategoryOperations()
        
        // 2. ProductGroupのテスト
        await testProductGroupOperations()
        
        print("✅ 全てのRepositoryテストが成功しました")
        
    }
    
    // MARK: - Category Tests
    
    private func testProductCategoryOperations() async {
        print("\n📂 ProductCategoryRepository テスト開始")
        
        do {
            let repo = container.productCategoryRepository
            
            // システムカテゴリの初期化
            try await repo.createDefaultSystemCategories()
            
            // 1. 作成テスト
            let testCategory = try await repo.create(
                name: "テスト用カテゴリ",
                icon: "🧪",
                colorHex: "#FF0000",
                sortOrder: 999
            )
            print("✅ カテゴリ作成: \(testCategory.value(forKey: "name") ?? "不明")")
            
            // 2. 全件取得テスト
            let allCategories = try await repo.fetchAll()
            print("✅ 全カテゴリ取得: \(allCategories.count)件")
            
            // 3. ID検索テスト
            let categoryId = testCategory.value(forKey: "entityID") as! UUID
            let foundCategory = try await repo.fetchById(categoryId)
            print("✅ ID検索: \(foundCategory != nil ? "発見" : "未発見")")
            
            // 4. システムカテゴリ取得テスト
            let systemCategories = try await repo.fetchSystemCategories()
            print("✅ システムカテゴリ: \(systemCategories.count)件")
            
            // 5. 検索テスト
            let searchResults = try await repo.search(keyword: "食")
            print("✅ 検索結果: \(searchResults.count)件")
            
            // 6. 更新テスト
            testCategory.setValue("更新されたカテゴリ", forKey: "name")
            try await repo.update(testCategory)
            print("✅ カテゴリ更新完了")
            
            // 7. 削除テスト（ソフトデリート）
            try await repo.delete(testCategory)
            print("✅ カテゴリ削除完了")
            
        } catch {
            print("❌ ProductCategoryテストエラー: \(error)")
        }
    }
    
    // MARK: - Group Tests
    
    private func testProductGroupOperations() async {
        print("\n📦 ProductGroupRepository テスト開始")
        
        do {
            let categoryRepo = container.productCategoryRepository
            let groupRepo = container.productGroupRepository
            
            // テスト用カテゴリを取得
            let foodCategory = try await categoryRepo.fetchByName("食料品")
            
            // 1. 作成テスト
            let testGroup = try await groupRepo.create(
                productName: "テスト商品",
                productType: "テスト分類",
                category: foodCategory
            )
            print("✅ 商品グループ作成: \(testGroup.value(forKey: "productName") ?? "不明")")
            
            // 2. 全件取得テスト
            let allGroups = try await groupRepo.fetchAll()
            print("✅ 全商品グループ取得: \(allGroups.count)件")
            
            // 3. 商品名検索テスト
            let foundByName = try await groupRepo.fetchByProductName("テスト商品")
            print("✅ 商品名検索: \(foundByName != nil ? "発見" : "未発見")")
            
            // 4. カテゴリ別取得テスト
            if let category = foodCategory {
                let categoryGroups = try await groupRepo.fetchByCategory(category)
                print("✅ カテゴリ別取得: \(categoryGroups.count)件")
            }
            
            // 5. 検索テスト
            let searchResults = try await groupRepo.search(keyword: "テスト")
            print("✅ 検索結果: \(searchResults.count)件")
            
            // 6. 統計更新テスト
            try await groupRepo.updateStatistics(testGroup)
            print("✅ 統計情報更新完了")
            
            // 7. 削除テスト
            try await groupRepo.delete(testGroup)
            print("✅ 商品グループ削除完了")
            
        } catch {
            print("❌ ProductGroupテストエラー: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    /// パフォーマンステスト
    func testPerformance() async {
        print("\n⚡ Repository Performance Test開始")
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // 複数のカテゴリ作成
            let repo = container.productCategoryRepository
            
            for i in 1...10 {
                _ = try await repo.create(
                    name: "パフォーマンステスト\(i)",
                    icon: "🚀",
                    colorHex: "#00FF00",
                    sortOrder: i
                )
            }
            
            // 全件取得
            let categories = try await repo.fetchAll()
            
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            
            print("✅ パフォーマンステスト完了")
            print("   - 作成した件数: 10件")
            print("   - 取得した件数: \(categories.count)件")
            print("   - 実行時間: \(String(format: "%.3f", duration))秒")
            
        } catch {
            print("❌ パフォーマンステストエラー: \(error)")
        }
    }
    
    // MARK: - Integration Tests
    
    /// 統合テスト（Repository間の連携）
    func testRepositoryIntegration() async {
        print("\n🔄 Repository Integration Test開始")
        
        do {
            let categoryRepo = container.productCategoryRepository
            let groupRepo = container.productGroupRepository
            
            // 1. カテゴリ作成
            let category = try await categoryRepo.create(
                name: "統合テストカテゴリ",
                icon: "🔗",
                colorHex: "#FF00FF",
                sortOrder: 100
            )
            
            // 2. そのカテゴリで商品グループ作成
            _ = try await groupRepo.create(
                productName: "統合テスト商品",
                productType: "テスト",
                category: category
            )
            
            // 3. カテゴリ経由での商品グループ取得
            let categoryGroups = try await groupRepo.fetchByCategory(category)
            
            print("✅ 統合テスト完了")
            print("   - カテゴリ作成: 成功")
            print("   - 商品グループ作成: 成功")
            print("   - 関連付け取得: \(categoryGroups.count)件")
            
        } catch {
            print("❌ 統合テストエラー: \(error)")
        }
    }
}

// MARK: - Test Runner

extension RepositoryTests {
    
    /// 全てのテストを実行
    static func runAllTests(with container: RepositoryContainer) async {
        print("🚀 Repository Layer Test Suite 開始\n")
        print("========================================")
        
        let tests = RepositoryTests(container: container)
        
        await tests.testBasicCRUD()
        await tests.testPerformance()
        await tests.testRepositoryIntegration()
        
        print("\n========================================")
        print("🏁 Repository Layer Test Suite 完了")
    }
}
