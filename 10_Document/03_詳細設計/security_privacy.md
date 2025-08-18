# セキュリティ・プライバシー対応詳細設計

## 1. セキュリティ方針

### 1.1 基本方針
- **データ最小化**: 必要最小限のデータのみ収集・保存
- **ローカル完結**: Phase 1では全データをデバイス内で処理
- **暗号化原則**: 機密性の高いデータは暗号化して保存
- **アクセス制御**: 不正アクセスの防止
- **透明性**: ユーザーに対するデータ取り扱いの明示

### 1.2 セキュリティレベル分類

#### レベル1: 公開データ（暗号化不要）
- システムカテゴリ情報
- アプリ設定情報（税率、単位等）
- 使用統計（個人特定不可）

#### レベル2: 個人データ（暗号化推奨）
- 商品記録データ
- 比較履歴
- カスタムカテゴリ
- 店舗名情報

#### レベル3: 機密データ（暗号化必須）
- 価格情報
- 購入履歴
- 位置情報（将来実装時）
- ユーザー固有の分析データ

## 2. データ暗号化実装

### 2.1 Core Data暗号化
```swift
import CoreData
import CryptoKit

class SecurePersistentContainer: NSPersistentContainer {
    
    override func loadPersistentStores(completionHandler block: @escaping (NSPersistentStoreDescription, Error?) -> Void) {
        
        // SQLite暗号化設定
        guard let description = persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve a persistent store description.")
        }
        
        // データベース暗号化を有効化
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // FileProtectionKey設定（iOS標準暗号化）
        description.setOption(FileProtectionType.complete as NSString, 
                            forKey: NSPersistentStoreFileProtectionKey)
        
        super.loadPersistentStores(completionHandler: block)
    }
}

// 機密データ用の追加暗号化
class DataEncryptionService {
    private let key: SymmetricKey
    
    init() {
        // キーチェーンから暗号化キーを取得、なければ新規生成
        if let keyData = KeychainService.shared.getData(for: "encryption_key") {
            self.key = SymmetricKey(data: keyData)
        } else {
            self.key = SymmetricKey(size: .bits256)
            let keyData = key.withUnsafeBytes { Data($0) }
            KeychainService.shared.setData(keyData, for: "encryption_key")
        }
    }
    
    func encrypt(_ data: String) throws -> Data {
        let dataToEncrypt = data.data(using: .utf8)!
        let sealedBox = try AES.GCM.seal(dataToEncrypt, using: key)
        return sealedBox.combined!
    }
    
    func decrypt(_ encryptedData: Data) throws -> String {
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: key)
        return String(data: decryptedData, encoding: .utf8)!
    }
}
```

### 2.2 キーチェーン管理
```swift
import Security

class KeychainService {
    static let shared = KeychainService()
    private init() {}
    
    private let service = "com.yourapp.otoku-checker"
    
    func setData(_ data: Data, for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // 既存項目を削除してから新規追加
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func getData(for key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        
        return nil
    }
    
    func deleteData(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
```

## 3. プライバシー保護実装

### 3.1 データ収集の最小化
```swift
// ProductRecordの個人情報最小化
extension ProductRecord {
    // 店舗名の匿名化オプション
    var anonymizedStoreName: String {
        if UserDefaults.standard.bool(forKey: "anonymize_store_names") {
            return "店舗\(abs(storeName.hashValue) % 100)"
        }
        return storeName
    }
    
    // 位置情報の削除
    func removeLocationData() {
        self.storeLocation = ""
        self.updatedAt = Date()
    }
    
    // 個人特定可能な情報のクリア
    func anonymize() {
        self.storeName = anonymizedStoreName
        self.storeLocation = ""
        self.memo = memo.isEmpty ? "" : "メモあり"
        self.updatedAt = Date()
    }
}
```

### 3.2 データ保持期間の管理
```swift
class DataRetentionService {
    private let repository: ProductRepository
    
    init(repository: ProductRepository) {
        self.repository = repository
    }
    
    // 古いデータの自動削除
    func cleanupOldData() async throws {
        let retentionSettings = DataRetentionSettings.current
        
        // 比較履歴のクリーンアップ
        try await repository.cleanupOldComparisonHistory(
            keepCount: retentionSettings.comparisonHistoryRetentionCount
        )
        
        // 古い商品記録の論理削除
        let cutoffDate = Calendar.current.date(
            byAdding: .month, 
            value: -retentionSettings.productRecordRetentionMonths, 
            to: Date()
        ) ?? Date()
        
        try await repository.archiveOldProductRecords(before: cutoffDate)
    }
    
    // ユーザー主導のデータ削除
    func deleteAllUserData() async throws {
        try await repository.deleteAllData()
        
        // キーチェーンデータも削除
        KeychainService.shared.deleteData(for: "encryption_key")
        
        // ユーザー設定もリセット
        UserDefaults.standard.removePersistentDomain(
            forName: Bundle.main.bundleIdentifier!
        )
    }
}

struct DataRetentionSettings {
    let comparisonHistoryRetentionCount: Int
    let productRecordRetentionMonths: Int
    let automaticCleanupEnabled: Bool
    
    static var current: DataRetentionSettings {
        return DataRetentionSettings(
            comparisonHistoryRetentionCount: UserDefaults.standard.integer(forKey: "retention_comparison_count") != 0 
                ? UserDefaults.standard.integer(forKey: "retention_comparison_count") : 100,
            productRecordRetentionMonths: UserDefaults.standard.integer(forKey: "retention_months") != 0 
                ? UserDefaults.standard.integer(forKey: "retention_months") : 24,
            automaticCleanupEnabled: UserDefaults.standard.bool(forKey: "auto_cleanup_enabled")
        )
    }
}
```

## 4. アクセス制御

### 4.1 アプリレベルのアクセス制御
```swift
import LocalAuthentication

class BiometricAuthService {
    func authenticateUser() async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        
        // 生体認証の利用可能性確認
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw AuthenticationError.biometricNotAvailable
        }
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "価格データにアクセスするために認証が必要です"
            )
            return success
        } catch {
            throw AuthenticationError.authenticationFailed
        }
    }
}

// アプリ起動時の認証チェック
class AppSecurityManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var requiresAuthentication = false
    
    private let biometricAuth = BiometricAuthService()
    
    init() {
        requiresAuthentication = UserDefaults.standard.bool(forKey: "require_authentication")
    }
    
    func checkAuthenticationRequired() {
        if requiresAuthentication && !isAuthenticated {
            requestAuthentication()
        } else {
            isAuthenticated = true
        }
    }
    
    private func requestAuthentication() {
        Task {
            do {
                let success = try await biometricAuth.authenticateUser()
                await MainActor.run {
                    isAuthenticated = success
                }
            } catch {
                // 認証失敗時の処理
                await MainActor.run {
                    isAuthenticated = false
                }
            }
        }
    }
}

enum AuthenticationError: LocalizedError {
    case biometricNotAvailable
    case authenticationFailed
    
    var errorDescription: String? {
        switch self {
        case .biometricNotAvailable:
            return "生体認証が利用できません"
        case .authenticationFailed:
            return "認証に失敗しました"
        }
    }
}
```

### 4.2 データアクセス監査
```swift
class DataAccessAuditService {
    private let auditLog: [DataAccessEvent] = []
    
    func logDataAccess(
        operation: DataOperation,
        dataType: DataType,
        recordCount: Int = 1,
        userInitiated: Bool = true
    ) {
        let event = DataAccessEvent(
            timestamp: Date(),
            operation: operation,
            dataType: dataType,
            recordCount: recordCount,
            userInitiated: userInitiated,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        )
        
        // ログの記録（暗号化して保存）
        saveAuditEvent(event)
        
        // 異常なアクセスパターンの検出
        detectAnomalousAccess(event)
    }
    
    private func detectAnomalousAccess(_ event: DataAccessEvent) {
        // 大量データアクセスの検出
        if event.recordCount > 1000 {
            reportSecurityIncident(.massDataAccess, event: event)
        }
        
        // 短時間での大量アクセスの検出
        let recentEvents = getRecentEvents(timeWindow: 60) // 1分間
        let totalRecords = recentEvents.reduce(0) { $0 + $1.recordCount }
        
        if totalRecords > 500 {
            reportSecurityIncident(.rapidDataAccess, event: event)
        }
    }
    
    private func reportSecurityIncident(_ type: SecurityIncidentType, event: DataAccessEvent) {
        // セキュリティインシデントの記録・通知
        #if DEBUG
        print("⚠️ Security Incident: \(type) - \(event)")
        #endif
        
        // 将来的にはリモートログ送信等を実装
    }
}

struct DataAccessEvent {
    let timestamp: Date
    let operation: DataOperation
    let dataType: DataType
    let recordCount: Int
    let userInitiated: Bool
    let appVersion: String
}

enum DataOperation {
    case create, read, update, delete, export, import
}

enum DataType {
    case productRecord, productGroup, category, comparisonHistory, userSettings
}

enum SecurityIncidentType {
    case massDataAccess, rapidDataAccess, unauthorizedAccess
}
```

## 5. プライバシーポリシー・利用規約

### 5.1 プライバシーポリシー（要点）
```markdown
# プライバシーポリシー

## 1. 収集する情報
当アプリは以下の情報を収集・保存します：

### 自動収集情報
- アプリの使用統計（クラッシュレポート、パフォーマンス指標）
- デバイス情報（iOS版号、機種情報）

### ユーザー入力情報
- 商品名、価格、容量情報
- 店舗名（任意）
- カテゴリ情報
- 比較履歴

## 2. 情報の利用目的
- アプリ機能の提供（商品比較、履歴管理）
- アプリの改善・最適化
- 技術的サポートの提供

## 3. 情報の保存・管理
- 全データはユーザーのデバイス内にのみ保存
- データの暗号化による保護
- ユーザーによる完全削除が可能

## 4. 第三者への提供
- ユーザーデータを第三者に提供しません
- 匿名化された統計データのみアプリ改善に使用

## 5. データの削除
- ユーザーはいつでも全データを削除可能
- アプリ削除時に全データが自動削除
```

### 5.2 データ取り扱い同意の実装
```swift
class PrivacyConsentManager: ObservableObject {
    @Published var hasConsentedToDataCollection = false
    @Published var hasConsentedToAnalytics = false
    @Published var showConsentSheet = false
    
    private let currentPolicyVersion = "1.0"
    
    init() {
        checkConsentStatus()
    }
    
    private func checkConsentStatus() {
        let agreedVersion = UserDefaults.standard.string(forKey: "agreed_policy_version")
        let hasBasicConsent = UserDefaults.standard.bool(forKey: "consented_data_collection")
        
        // ポリシー更新時は再同意を求める
        if agreedVersion != currentPolicyVersion || !hasBasicConsent {
            showConsentSheet = true
        } else {
            hasConsentedToDataCollection = true
            hasConsentedToAnalytics = UserDefaults.standard.bool(forKey: "consented_analytics")
        }
    }
    
    func grantConsent(dataCollection: Bool, analytics: Bool) {
        hasConsentedToDataCollection = dataCollection
        hasConsentedToAnalytics = analytics
        
        UserDefaults.standard.set(dataCollection, forKey: "consented_data_collection")
        UserDefaults.standard.set(analytics, forKey: "consented_analytics")
        UserDefaults.standard.set(currentPolicyVersion, forKey: "agreed_policy_version")
        UserDefaults.standard.set(Date(), forKey: "consent_date")
        
        showConsentSheet = false
    }
    
    func revokeConsent() {
        hasConsentedToDataCollection = false
        hasConsentedToAnalytics = false
        
        UserDefaults.standard.removeObject(forKey: "consented_data_collection")
        UserDefaults.standard.removeObject(forKey: "consented_analytics")
        UserDefaults.standard.removeObject(forKey: "agreed_policy_version")
    }
}

// プライバシー同意画面
struct PrivacyConsentSheet: View {
    @ObservedObject var consentManager: PrivacyConsentManager
    @State private var agreeToDataCollection = false
    @State private var agreeToAnalytics = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("プライバシーポリシー")
                    .font(.title)
                    .fontWeight(.bold)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // プライバシーポリシーの内容表示
                        PrivacyPolicyContent()
                    }
                    .padding()
                }
                
                VStack(spacing: 12) {
                    Toggle("基本機能の利用に同意する", isOn: $agreeToDataCollection)
                        .font(.system(size: 16, weight: .medium))
                    
                    Toggle("匿名利用統計の収集に同意する（任意）", isOn: $agreeToAnalytics)
                        .font(.system(size: 14))
                }
                .padding()
                
                Button("同意してアプリを使用する") {
                    consentManager.grantConsent(
                        dataCollection: agreeToDataCollection,
                        analytics: agreeToAnalytics
                    )
                }
                .disabled(!agreeToDataCollection)
                .buttonStyle(.borderedProminent)
                .disabled(!agreeToDataCollection)
                
                Button("アプリを終了する") {
                    exit(0)
                }
                .foregroundColor(.red)
            }
            .padding()
            .navigationBarHidden(true)
        }
        .interactiveDismissDisabled()
    }
}
```

## 6. データエクスポート・削除機能

### 6.1 GDPRコンプライアンス対応
```swift
class DataPortabilityService {
    private let repository: ProductRepository
    private let encryptionService: DataEncryptionService
    
    init(repository: ProductRepository, encryptionService: DataEncryptionService) {
        self.repository = repository
        self.encryptionService = encryptionService
    }
    
    // ユーザーデータの完全エクスポート
    func exportAllUserData() async throws -> Data {
        let exportData = UserDataExport(
            productGroups: try await repository.fetchProductGroups(),
            productRecords: try await fetchAllProductRecords(),
            categories: try await repository.fetchCategories(includeSystem: false),
            comparisonHistories: try await repository.fetchComparisonHistory(),
            userSettings: extractUserSettings(),
            exportMetadata: ExportMetadata(
                exportDate: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                dataFormat: "JSON",
                encryptionUsed: false
            )
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        return try encoder.encode(exportData)
    }
    
    // 暗号化されたデータエクスポート
    func exportEncryptedUserData(password: String) async throws -> Data {
        let rawData = try await exportAllUserData()
        
        // パスワードベースの暗号化
        let passwordKey = try deriveKeyFromPassword(password)
        let encryptedData = try encryptWithPassword(rawData, key: passwordKey)
        
        return encryptedData
    }
    
    // データの完全削除（消去権の実装）
    func deleteAllUserData() async throws {
        // リポジトリからのデータ削除
        try await repository.deleteAllData()
        
        // 暗号化キーの削除
        KeychainService.shared.deleteData(for: "encryption_key")
        
        // ユーザー設定の削除
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }
        
        // キャッシュファイルの削除
        try deleteAppCacheFiles()
        
        // アクティビティログの記録
        logDataDeletion()
    }
    
    private func extractUserSettings() -> [String: Any] {
        let userDefaults = UserDefaults.standard
        var settings: [String: Any] = [:]
        
        // エクスポート対象の設定項目
        let exportKeys = [
            "default_tax_rate",
            "default_unit",
            "require_authentication",
            "anonymize_store_names",
            "retention_months",
            "auto_cleanup_enabled"
        ]
        
        for key in exportKeys {
            if let value = userDefaults.object(forKey: key) {
                settings[key] = value
            }
        }
        
        return settings
    }
    
    private func deleteAppCacheFiles() throws {
        let fileManager = FileManager.default
        let cacheDirectory = try fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        
        let appCacheDirectory = cacheDirectory.appendingPathComponent(
            Bundle.main.bundleIdentifier ?? "unknown"
        )
        
        if fileManager.fileExists(atPath: appCacheDirectory.path) {
            try fileManager.removeItem(at: appCacheDirectory)
        }
    }
    
    private func logDataDeletion() {
        let deletionLog = DataDeletionLog(
            timestamp: Date(),
            userInitiated: true,
            dataTypesDeleted: [.all],
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        )
        
        // セキュアログとして記録（個人情報は含まない）
        #if DEBUG
        print("🗑️ User data deletion completed: \(deletionLog)")
        #endif
    }
}

struct UserDataExport: Codable {
    let productGroups: [ProductGroupDTO]
    let productRecords: [ProductRecordDTO]
    let categories: [CategoryDTO]
    let comparisonHistories: [ComparisonHistoryDTO]
    let userSettings: [String: AnyCodable]
    let exportMetadata: ExportMetadata
}

struct ExportMetadata: Codable {
    let exportDate: Date
    let appVersion: String
    let dataFormat: String
    let encryptionUsed: Bool
}

struct DataDeletionLog {
    let timestamp: Date
    let userInitiated: Bool
    let dataTypesDeleted: [DataType]
    let appVersion: String
    
    enum DataType {
        case all, productRecords, categories, comparisonHistory, userSettings
    }
}

// Any型をCodableに対応させるヘルパー
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            throw DecodingError.typeMismatch(
                AnyCodable.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let stringValue as String:
            try container.encode(stringValue)
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }
}
```

## 7. セキュリティ監査・モニタリング

### 7.1 セキュリティ監査チェックリスト
```swift
class SecurityAuditService {
    func performSecurityAudit() async -> SecurityAuditReport {
        var findings: [SecurityFinding] = []
        
        // 1. データ暗号化状況の確認
        findings.append(contentsOf: await auditDataEncryption())
        
        // 2. アクセス制御の確認
        findings.append(contentsOf: await auditAccessControls())
        
        // 3. データ保持期間の確認
        findings.append(contentsOf: await auditDataRetention())
        
        // 4. プライバシー設定の確認
        findings.append(contentsOf: await auditPrivacySettings())
        
        // 5. セキュアコーディングの確認
        findings.append(contentsOf: await auditSecureCoding())
        
        return SecurityAuditReport(
            auditDate: Date(),
            findings: findings,
            overallScore: calculateSecurityScore(findings),
            recommendations: generateRecommendations(findings)
        )
    }
    
    private func auditDataEncryption() async -> [SecurityFinding] {
        var findings: [SecurityFinding] = []
        
        // Core Data暗号化確認
        if !isCoreDataEncrypted() {
            findings.append(SecurityFinding(
                category: .dataProtection,
                severity: .high,
                title: "Core Data暗号化未設定",
                description: "データベースの暗号化が有効になっていません",
                recommendation: "FileProtectionKeyの設定を確認してください"
            ))
        }
        
        // キーチェーン使用確認
        if !isUsingKeychain() {
            findings.append(SecurityFinding(
                category: .dataProtection,
                severity: .medium,
                title: "機密データのキーチェーン未使用",
                description: "暗号化キーがキーチェーンに保存されていません",
                recommendation: "暗号化キーはキーチェーンに保存してください"
            ))
        }
        
        return findings
    }
    
    private func auditAccessControls() async -> [SecurityFinding] {
        var findings: [SecurityFinding] = []
        
        // 生体認証設定確認
        if !isBiometricAuthEnabled() && hassensitiveData() {
            findings.append(SecurityFinding(
                category: .accessControl,
                severity: .medium,
                title: "生体認証未設定",
                description: "機密データが保存されていますが生体認証が無効です",
                recommendation: "生体認証の有効化を検討してください"
            ))
        }
        
        return findings
    }
    
    private func calculateSecurityScore(_ findings: [SecurityFinding]) -> Int {
        let baseScore = 100
        let highSeverityPenalty = findings.filter { $0.severity == .high }.count * 20
        let mediumSeverityPenalty = findings.filter { $0.severity == .medium }.count * 10
        let lowSeverityPenalty = findings.filter { $0.severity == .low }.count * 5
        
        return max(0, baseScore - highSeverityPenalty - mediumSeverityPenalty - lowSeverityPenalty)
    }
}

struct SecurityAuditReport {
    let auditDate: Date
    let findings: [SecurityFinding]
    let overallScore: Int
    let recommendations: [String]
    
    var criticalIssuesCount: Int {
        findings.filter { $0.severity == .high }.count
    }
    
    var isSecure: Bool {
        criticalIssuesCount == 0 && overallScore >= 80
    }
}

struct SecurityFinding {
    let category: SecurityCategory
    let severity: Severity
    let title: String
    let description: String
    let recommendation: String
    
    enum SecurityCategory {
        case dataProtection, accessControl, dataRetention, privacy, secureCoding
    }
    
    enum Severity {
        case low, medium, high, critical
    }
}
```

## 8. インシデント対応

### 8.1 セキュリティインシデント対応フロー
```swift
class SecurityIncidentManager {
    private let logger: SecurityLogger
    
    init(logger: SecurityLogger) {
        self.logger = logger
    }
    
    func handleSecurityIncident(_ incident: SecurityIncident) {
        // 1. インシデントの記録
        logger.logIncident(incident)
        
        // 2. 重要度に応じた対応
        switch incident.severity {
        case .critical:
            handleCriticalIncident(incident)
        case .high:
            handleHighSeverityIncident(incident)
        case .medium, .low:
            handleLowSeverityIncident(incident)
        }
        
        // 3. ユーザーへの通知（必要に応じて）
        if incident.requiresUserNotification {
            notifyUser(incident)
        }
        
        // 4. 自動対応措置
        executeAutomaticResponse(incident)
    }
    
    private func handleCriticalIncident(_ incident: SecurityIncident) {
        // クリティカルインシデントの対応
        switch incident.type {
        case .unauthorizedDataAccess:
            // データアクセスの一時停止
            suspendDataAccess()
            
        case .dataCorruption:
            // データバックアップからの復旧
            initiateDataRecovery()
            
        case .maliciousActivity:
            // アプリの一時停止
            suspendAppOperation()
        }
    }
    
    private func notifyUser(_ incident: SecurityIncident) {
        let notification = SecurityNotification(
            title: "セキュリティに関する重要なお知らせ",
            message: incident.userMessage,
            actionRequired: incident.requiresUserAction
        )
        
        // ローカル通知で表示
        scheduleSecurityNotification(notification)
    }
}

struct SecurityIncident {
    let id: UUID = UUID()
    let timestamp: Date = Date()
    let type: IncidentType
    let severity: Severity
    let description: String
    let affectedData: [DataType]
    let requiresUserNotification: Bool
    let requiresUserAction: Bool
    let userMessage: String
    
    enum IncidentType {
        case unauthorizedDataAccess
        case dataCorruption
        case maliciousActivity
        case privacyViolation
        case dataLeak
    }
    
    enum Severity {
        case low, medium, high, critical
    }
}
```

## 9. セキュアコーディングガイドライン

### 9.1 入力値検証
```swift
// 価格入力の厳密な検証
struct PriceValidator {
    static func validate(_ price: String) throws -> Decimal {
        // 1. 基本フォーマット確認
        guard !price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyInput
        }
        
        // 2. 数値変換確認
        guard let decimal = Decimal(string: price) else {
            throw ValidationError.invalidFormat
        }
        
        // 3. 範囲確認
        guard decimal > 0 else {
            throw ValidationError.negativeValue
        }
        
        guard decimal <= 1_000_000 else {
            throw ValidationError.excessiveValue
        }
        
        // 4. 精度確認（小数点以下2桁まで）
        let rounded = decimal.rounded(to: 2)
        guard decimal == rounded else {
            throw ValidationError.invalidPrecision
        }
        
        return decimal
    }
}

// SQL インジェクション対策
extension NSPredicate {
    static func safePredicate(format: String, arguments: [Any]) -> NSPredicate {
        // 引数を事前検証
        let sanitizedArguments = arguments.map { sanitizeArgument($0) }
        return NSPredicate(format: format, argumentArray: sanitizedArguments)
    }
    
    private static func sanitizeArgument(_ argument: Any) -> Any {
        if let string = argument as? String {
            // 特殊文字のエスケープ
            return string
                .replacingOccurrences(of: "'", with: "''")
                .replacingOccurrences(of: ";", with: "")
                .replacingOccurrences(of: "--", with: "")
        }
        return argument
    }
}
```

### 9.2 メモリ安全性
```swift
// メモリリーク防止
class SecureDataHandler {
    private var sensitiveData: Data?
    
    func processSensitiveData(_ data: Data) {
        // 処理用の一時領域を確保
        data.withUnsafeBytes { bytes in
            // データ処理...
        }
        // 処理後は自動的にメモリから消去
    }
    
    deinit {
        // 機密データを明示的にクリア
        if var data = sensitiveData {
            data.resetBytes(in: 0..<data.count)
            sensitiveData = nil
        }
    }
}

// 文字列の安全な処理
extension String {
    mutating func secureErase() {
        // 文字列をゼロ埋めして消去
        self = String(repeating: "\0", count: self.count)
        self = ""
    }
    
    func secureCopy() -> String {
        // セキュアな文字列コピー
        return String(self)
    }
}
```

## 10. セキュリティテスト

### 10.1 セキュリティテストスイート
```swift
class SecurityTests: XCTestCase {
    
    func testDataEncryption() {
        let service = DataEncryptionService()
        let originalData = "機密データ"
        
        do {
            let encrypted = try service.encrypt(originalData)
            let decrypted = try service.decrypt(encrypted)
            
            XCTAssertEqual(originalData, decrypted)
            XCTAssertNotEqual(originalData.data(using: .utf8), encrypted)
        } catch {
            XCTFail("暗号化/復号化に失敗: \(error)")
        }
    }
    
    func testInputValidation() {
        // SQLインジェクション攻撃のテスト
        let maliciousInputs = [
            "'; DROP TABLE ProductRecord; --",
            "1; DELETE FROM ProductGroup;",
            "' OR '1'='1",
            "<script>alert('XSS')</script>"
        ]
        
        for input in maliciousInputs {
            XCTAssertThrowsError(try PriceValidator.validate(input)) {
                error in
                XCTAssertTrue(error is ValidationError)
            }
        }
    }
    
    func testPrivacyCompliance() {
        let consentManager = PrivacyConsentManager()
        
        // 同意なしでのデータ処理禁止
        XCTAssertFalse(consentManager.hasConsentedToDataCollection)
        
        // 同意後のデータ処理許可
        consentManager.grantConsent(dataCollection: true, analytics: false)
        XCTAssertTrue(consentManager.hasConsentedToDataCollection)
        XCTAssertFalse(consentManager.hasConsentedToAnalytics)
    }
    
    func testDataDeletion() {
        let service = DataPortabilityService(
            repository: MockProductRepository(),
            encryptionService: DataEncryptionService()
        )
        
        // データ削除の実行
        XCTAssertNoThrow(try await service.deleteAllUserData())
        
        // 削除後の確認
        let remaining = try await service.exportAllUserData()
        XCTAssertTrue(remaining.isEmpty || isEmptyDataExport(remaining))
    }
}
```

このセキュリティ・プライバシー設計により、ユーザーデータの適切な保護と法的要件への準拠を実現し、安心して利用できるアプリを提供できます。