//
//  SettingsViewModel.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/21.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class SettingsViewModel: BaseViewModel {
    
    // MARK: - Dependencies
    
    private let categoryManagementUseCase: CategoryManagementUseCaseProtocol
    
    // MARK: - Published Properties - Categories
    
    @Published var categories: [ProductCategory] = []
    @Published var systemCategories: [ProductCategory] = []
    @Published var customCategories: [ProductCategory] = []
    
    // MARK: - Published Properties - UI State
    
    @Published var showingCategoryManager: Bool = false
    @Published var showingDataExport: Bool = false
    @Published var showingDataImport: Bool = false
    @Published var showingAbout: Bool = false
    
    // MARK: - Published Properties - Settings
    
    @Published var enableNotifications: Bool = true
    @Published var enableHapticFeedback: Bool = true
    @Published var preferredTheme: AppTheme = .system
    @Published var defaultUnit: Unit = .gram
    @Published var showPriceWithTax: Bool = true
    @Published var defaultTaxRate: Double = 10.0
    
    // MARK: - Initialization
    
    init(categoryManagementUseCase: CategoryManagementUseCaseProtocol) {
        self.categoryManagementUseCase = categoryManagementUseCase
        
        super.init()
        
        loadSettings()
        loadCategories()
    }
    
    // MARK: - Public Methods - Data Management
    
    func loadCategories() {
        executeVoidTask {
            async let allCategories = self.categoryManagementUseCase.fetchAllCategories()
            async let systemCategories = self.categoryManagementUseCase.fetchSystemCategories()
            async let customCategories = self.categoryManagementUseCase.fetchCustomCategories()
            
            self.categories = try await allCategories
            self.systemCategories = try await systemCategories
            self.customCategories = try await customCategories
        }
    }
    
    func initializeSystemCategories() {
        executeVoidTask {
            try await self.categoryManagementUseCase.initializeSystemCategories()
            await self.loadCategories()
        }
    }
    
    // MARK: - Public Methods - Category Management
    
    func createCustomCategory(name: String, icon: String, colorHex: String?) {
        executeVoidTask {
            _ = try await self.categoryManagementUseCase.createCustomCategory(
                name: name,
                icon: icon,
                colorHex: colorHex
            )
            await self.loadCategories()
        }
    }
    
    func updateCategory(_ category: ProductCategory) {
        executeVoidTask {
            try await self.categoryManagementUseCase.updateCategory(category)
            await self.loadCategories()
        }
    }
    
    func deleteCustomCategory(_ category: ProductCategory) {
        guard !category.isSystemCategory else { return }
        
        executeVoidTask {
            try await self.categoryManagementUseCase.deleteCategory(category)
            await self.loadCategories()
        }
    }
    
    // MARK: - Public Methods - Settings Management
    
    func updateTheme(_ theme: AppTheme) {
        preferredTheme = theme
        saveSettings()
    }
    
    func updateDefaultUnit(_ unit: Unit) {
        defaultUnit = unit
        saveSettings()
    }
    
    func updateTaxSettings(showWithTax: Bool, taxRate: Double) {
        showPriceWithTax = showWithTax
        defaultTaxRate = taxRate
        saveSettings()
    }
    
    func toggleNotifications() {
        enableNotifications.toggle()
        saveSettings()
        
        if enableNotifications {
            requestNotificationPermission()
        }
    }
    
    func toggleHapticFeedback() {
        enableHapticFeedback.toggle()
        saveSettings()
    }
    
    // MARK: - Public Methods - Data Management
    
    func exportData() -> URL? {
        // データエクスポート処理の実装
        // 実際の実装では、Core Dataからすべてのデータを取得してJSONまたはCSVで出力
        return nil
    }
    
    func importData(from url: URL) {
        executeVoidTask {
            // データインポート処理の実装
            // 実際の実装では、ファイルを読み込んでCore Dataに保存
        }
    }
    
    func clearAllData() {
        executeVoidTask {
            // 全データ削除処理の実装
            // 実際の実装では、確認ダイアログ後にCore Dataのすべてのエンティティを削除
        }
    }
    
    // MARK: - Private Methods
    
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        enableNotifications = defaults.bool(forKey: "enableNotifications")
        enableHapticFeedback = defaults.bool(forKey: "enableHapticFeedback")
        showPriceWithTax = defaults.bool(forKey: "showPriceWithTax")
        defaultTaxRate = defaults.double(forKey: "defaultTaxRate")
        
        if let themeRawValue = defaults.object(forKey: "preferredTheme") as? String,
           let theme = AppTheme(rawValue: themeRawValue) {
            preferredTheme = theme
        }
        
        if let unitRawValue = defaults.object(forKey: "defaultUnit") as? String,
           let unit = Unit(rawValue: unitRawValue) {
            defaultUnit = unit
        }
        
        // デフォルト値の設定（初回起動時）
        if !defaults.bool(forKey: "hasLaunchedBefore") {
            enableNotifications = true
            enableHapticFeedback = true
            showPriceWithTax = true
            defaultTaxRate = 10.0
            preferredTheme = .system
            defaultUnit = .gram
            
            defaults.set(true, forKey: "hasLaunchedBefore")
            saveSettings()
        }
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        
        defaults.set(enableNotifications, forKey: "enableNotifications")
        defaults.set(enableHapticFeedback, forKey: "enableHapticFeedback")
        defaults.set(showPriceWithTax, forKey: "showPriceWithTax")
        defaults.set(defaultTaxRate, forKey: "defaultTaxRate")
        defaults.set(preferredTheme.rawValue, forKey: "preferredTheme")
        defaults.set(defaultUnit.rawValue, forKey: "defaultUnit")
    }
    
    private func requestNotificationPermission() {
        // 通知許可の実装
        // 実際の実装ではUNUserNotificationCenterを使用
    }
    
    // MARK: - App Info
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    var appName: String {
        Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "OtokuChecker"
    }
}

// MARK: - Supporting Types

enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light:
            return "ライト"
        case .dark:
            return "ダーク"
        case .system:
            return "システム設定に従う"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
}