# データバリデーション仕様書（お得チェッカー用簡素版）

## 1. 概要

### 1.1 目的
お得チェッカーの特性に最適化した最小限のデータバリデーションを実装し、ユーザビリティを重視したシンプルな入力チェック機能を提供する。

### 1.2 設計方針
お得チェッカーは個人使用の商品価格比較アプリであり、以下の特性に基づいて簡素化：

#### アプリ特性
- **用途**: 日常商品の価格比較（買い物中の短時間利用）
- **ユーザー**: 30-50代、シンプル操作を重視
- **データ性質**: 商品名・価格・容量（機密性：低）
- **入力頻度**: 1日数回程度
- **使用環境**: 片手操作、時間制約あり

### 1.3 簡素化原則
- **最小限チェック**: 入力ミス防止に必要な検証のみ
- **即座のフィードバック**: リアルタイムでの簡潔なエラー表示
- **日本語重視**: 分かりやすい日本語エラーメッセージ
- **パフォーマンス優先**: 軽量で高速な処理

### 1.4 ディレクトリ構造とファイル構成

#### 追加されるディレクトリ構造
```
20_Source/OtokuChecker/OtokuChecker/
├── Validation/                    # 新規作成
│   ├── Validators/               # バリデーター群
│   │   ├── ProductNameValidator.swift
│   │   ├── PriceValidator.swift
│   │   ├── QuantityValidator.swift
│   │   └── ComparisonValidator.swift
│   ├── Models/                   # バリデーション関連モデル
│   │   ├── ValidationResult.swift
│   │   └── ValidationError.swift
│   └── Extensions/               # Core Data拡張
│       └── ProductRecord+Validation.swift
└── Views/                        # 既存ディレクトリ
    └── Components/              # 既存または新規
        └── ValidatedTextField.swift  # バリデーション付き入力フィールド
```

#### 新規作成ファイル一覧

**Phase 1: 基本バリデーション実装 (6ファイル)**
1. `Validation/Models/ValidationResult.swift`
   - バリデーション結果を表現するenum型
   - success/failureパターンマッチング
   
2. `Validation/Models/ValidationError.swift`
   - エラー種別とメッセージ定義
   - LocalizedErrorプロトコル準拠
   
3. `Validation/Validators/ProductNameValidator.swift`
   - 商品名の基本チェック（空文字・長さ制限）
   - 日本語商品名対応
   
4. `Validation/Validators/PriceValidator.swift`
   - 価格フォーマット・範囲チェック
   - 円記号・カンマ除去処理
   
5. `Validation/Validators/QuantityValidator.swift`
   - 数量の基本チェック・単位別検証
   - 個数系単位の整数チェック
   
6. `Validation/Validators/ComparisonValidator.swift`
   - 単位互換性チェック
   - 重量・容量・個数の分類判定

**Phase 2: UI統合 (1ファイル)**
7. `Views/Components/ValidatedTextField.swift`
   - SwiftUIカスタムコンポーネント
   - リアルタイムバリデーション機能
   - エラー表示付きテキストフィールド

**Phase 3: データ層統合 (1ファイル)**
8. `Validation/Extensions/ProductRecord+Validation.swift`
   - Core Data Entity拡張
   - 保存時バリデーション実装

#### 変更されるファイル

**既存ファイルの修正内容**
- `Models/ProductRecord.swift` (Core Dataモデル)
  - バリデーション拡張のimport追加
  - 必要に応じてプロパティ調整

- 商品入力関連のView群
  - ValidatedTextFieldコンポーネントの導入
  - バリデーションエラー表示の追加

#### ファイル追加の段階的スケジュール

**Week 1: バリデーションコア実装**
- Day 1-2: ValidationResult, ValidationError
- Day 3-4: 基本バリデーター群（ProductName, Price, Quantity）
- Day 5: ComparisonValidator, 単体テスト

**Week 2: UI・データ統合**
- Day 1-2: ValidatedTextField実装
- Day 3: Core Data拡張実装
- Day 4-5: 既存View統合・動作確認

## 2. 簡素版バリデーション対象

### 2.1 商品名バリデーション

#### 商品名の基本チェック
```swift
struct ProductNameValidator {
    static let maxLength = 50  // 簡素化：50文字で十分
    
    static func validate(_ name: String) -> ValidationResult<String> {
        // 空文字チェック
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failure(.productName(.empty))
        }
        
        // 長さチェック（日常商品名は50文字以内）
        if trimmed.count > maxLength {
            return .failure(.productName(.tooLong))
        }
        
        return .success(trimmed)
    }
}
```

### 2.2 価格バリデーション

#### 価格の基本チェック
```swift
struct PriceValidator {
    static let maxValue: Decimal = 99_999  // 簡素化：日常商品は10万円以内
    
    static func validate(_ input: String) -> ValidationResult<Decimal> {
        // 空文字チェック
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failure(.price(.empty))
        }
        
        // 基本的なクリーンアップ（円記号・カンマ除去）
        let cleaned = trimmed
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "円", with: "")
            .replacingOccurrences(of: ",", with: "")
        
        // 数値変換
        guard let decimal = Decimal(string: cleaned) else {
            return .failure(.price(.invalidFormat))
        }
        
        // 基本的な範囲チェック
        if decimal <= 0 {
            return .failure(.price(.negativeOrZero))
        }
        
        if decimal > maxValue {
            return .failure(.price(.tooLarge))
        }
        
        return .success(decimal)
    }
}
```

### 2.3 容量・重量バリデーション

#### 容量・重量の基本チェック
```swift
struct QuantityValidator {
    static let maxValue: Decimal = 99_999  // 簡素化：日常商品の現実的な範囲
    
    static func validate(_ input: String, unit: Unit) -> ValidationResult<Decimal> {
        // 空文字チェック
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return .failure(.quantity(.empty))
        }
        
        // 基本的なクリーンアップ
        let cleaned = trimmed.replacingOccurrences(of: ",", with: "")
        
        // 数値変換
        guard let decimal = Decimal(string: cleaned) else {
            return .failure(.quantity(.invalidFormat))
        }
        
        // 基本的な範囲チェック
        if decimal <= 0 {
            return .failure(.quantity(.negativeOrZero))
        }
        
        if decimal > maxValue {
            return .failure(.quantity(.tooLarge))
        }
        
        // 個数系単位の整数チェック（簡素版）
        if [Unit.piece, .pack, .box].contains(unit) {
            if decimal.truncatingRemainder(dividingBy: 1) != 0 {
                return .failure(.quantity(.mustBeInteger))
            }
        }
        
        return .success(decimal)
    }
}
```

## 3. 比較バリデーション（簡素版）

### 3.1 単位互換性チェック
```swift
struct ComparisonValidator {
    
    // 基本的な単位互換性チェックのみ
    static func areUnitsCompatible(_ unitA: Unit, _ unitB: Unit) -> Bool {
        let weightUnits: Set<Unit> = [.gram, .kilogram]
        let volumeUnits: Set<Unit> = [.milliliter, .liter]
        let countUnits: Set<Unit> = [.piece, .pack, .box]
        
        // 同じカテゴリ内での比較のみ許可
        return (weightUnits.contains(unitA) && weightUnits.contains(unitB)) ||
               (volumeUnits.contains(unitA) && volumeUnits.contains(unitB)) ||
               (countUnits.contains(unitA) && countUnits.contains(unitB))
    }
}
```

## 4. エラーハンドリング（簡素版）

### 4.1 基本エラー定義
```swift
enum ValidationError: LocalizedError {
    case productName(ProductNameError)
    case price(PriceError)
    case quantity(QuantityError)
    case comparison(ComparisonError)
    
    enum ProductNameError {
        case empty
        case tooLong
    }
    
    enum PriceError {
        case empty
        case invalidFormat
        case negativeOrZero
        case tooLarge
    }
    
    enum QuantityError {
        case empty
        case invalidFormat
        case negativeOrZero
        case tooLarge
        case mustBeInteger
    }
    
    enum ComparisonError {
        case incompatibleUnits
        case invalidProducts
    }
    
    var errorDescription: String? {
        switch self {
        case .productName(.empty):
            return "商品名を入力してください"
        case .productName(.tooLong):
            return "商品名は50文字以内で入力してください"
        case .price(.empty):
            return "価格を入力してください"
        case .price(.invalidFormat):
            return "正しい数値を入力してください"
        case .price(.negativeOrZero):
            return "価格は0より大きい値を入力してください"
        case .price(.tooLarge):
            return "価格は99,999円以下で入力してください"
        case .quantity(.empty):
            return "数量を入力してください"
        case .quantity(.invalidFormat):
            return "正しい数値を入力してください"
        case .quantity(.negativeOrZero):
            return "数量は0より大きい値を入力してください"
        case .quantity(.tooLarge):
            return "数量は99,999以下で入力してください"
        case .quantity(.mustBeInteger):
            return "個数は整数で入力してください"
        case .comparison(.incompatibleUnits):
            return "異なる種類の単位は比較できません"
        case .comparison(.invalidProducts):
            return "商品情報に不備があります"
        }
    }
}
```

## 5. SwiftUIでの基本的なバリデーション

### 5.1 入力時リアルタイムチェック
```swift
struct ProductInputView: View {
    @State private var productName = ""
    @State private var price = ""
    @State private var quantity = ""
    @State private var nameError: String?
    @State private var priceError: String?
    @State private var quantityError: String?
    
    var body: some View {
        VStack {
            TextField("商品名", text: $productName)
                .onChange(of: productName) { _ in
                    validateProductName()
                }
            if let error = nameError {
                Text(error).foregroundColor(.red).font(.caption)
            }
            
            TextField("価格", text: $price)
                .keyboardType(.decimalPad)
                .onChange(of: price) { _ in
                    validatePrice()
                }
            if let error = priceError {
                Text(error).foregroundColor(.red).font(.caption)
            }
            
            TextField("数量", text: $quantity)
                .keyboardType(.decimalPad)
                .onChange(of: quantity) { _ in
                    validateQuantity()
                }
            if let error = quantityError {
                Text(error).foregroundColor(.red).font(.caption)
            }
        }
    }
    
    private func validateProductName() {
        let result = ProductNameValidator.validate(productName)
        nameError = result.isFailure ? result.errorMessage : nil
    }
    
    private func validatePrice() {
        let result = PriceValidator.validate(price)
        priceError = result.isFailure ? result.errorMessage : nil
    }
    
    private func validateQuantity() {
        let result = QuantityValidator.validate(quantity, unit: .gram)
        quantityError = result.isFailure ? result.errorMessage : nil
    }
}
```

## 6. データ保存時の基本チェック

### 6.1 Core Data 基本バリデーション
```swift
extension ProductRecord {
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try validateBasics()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try validateBasics()
    }
    
    private func validateBasics() throws {
        // 必須フィールドのチェックのみ
        guard let name = productName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.productName(.empty)
        }
        
        if price <= 0 {
            throw ValidationError.price(.negativeOrZero)
        }
        
        if quantity <= 0 {
            throw ValidationError.quantity(.negativeOrZero)
        }
    }
}
```

## 7. 基本的なバリデーション結果型

### 7.1 シンプルな結果型
```swift
enum ValidationResult<T> {
    case success(T)
    case failure(ValidationError)
    
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
    
    var isFailure: Bool {
        !isSuccess
    }
    
    var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error.errorDescription
        }
    }
}
```

## 8. 基本テスト（簡素版）

### 8.1 基本的なテスト
```swift
class ValidationTests: XCTestCase {
    
    // 商品名バリデーションテスト
    func testProductNameValidation() {
        let result1 = ProductNameValidator.validate("牛乳")
        XCTAssertTrue(result1.isSuccess)
        
        let result2 = ProductNameValidator.validate("")
        XCTAssertTrue(result2.isFailure)
        
        let longName = String(repeating: "あ", count: 51)
        let result3 = ProductNameValidator.validate(longName)
        XCTAssertTrue(result3.isFailure)
    }
    
    // 価格バリデーションテスト
    func testPriceValidation() {
        let result1 = PriceValidator.validate("198")
        XCTAssertTrue(result1.isSuccess)
        
        let result2 = PriceValidator.validate("0")
        XCTAssertTrue(result2.isFailure)
        
        let result3 = PriceValidator.validate("abc")
        XCTAssertTrue(result3.isFailure)
    }
    
    // 単位互換性テスト
    func testUnitCompatibility() {
        XCTAssertTrue(ComparisonValidator.areUnitsCompatible(.gram, .kilogram))
        XCTAssertTrue(ComparisonValidator.areUnitsCompatible(.milliliter, .liter))
        XCTAssertFalse(ComparisonValidator.areUnitsCompatible(.gram, .milliliter))
    }
}
```

## 9. 実装タスクまとめ

### 9.1 実装予定時間: 8-12時間

#### フェーズ1: 基本バリデーション実装 (4-6時間)
- `ProductNameValidator.swift`
- `PriceValidator.swift` 
- `QuantityValidator.swift`
- `ComparisonValidator.swift`
- `ValidationError.swift`
- `ValidationResult.swift`

#### フェーズ2: SwiftUI統合 (2-3時間)
- 入力フィールドでのリアルタイム検証
- エラーメッセージ表示
- バリデーション結果に応じたUI状態変更

#### フェーズ3: Core Data統合とテスト (2-3時間)
- Core Data保存時バリデーション
- 基本的な単体テスト作成
- バリデーション動作確認

### 9.2 除外した機能（オーバーエンジニアリング回避）

#### ❌ 除外した複雑なバリデーション機能
- **詳細な入力値検証**: 文字種チェック、正規表現による複雑なパターン検証
- **SQLインジェクション対策**: Core Dataが自動で処理するため不要
- **XSS対策**: iOSアプリではブラウザベースの攻撃は該当しない
- **高度なセキュリティバリデーション**: 商品価格情報には過剰

#### ❌ 除外した高機能UI
- **自動修正機能**: ユーザーの入力意図を変えてしまう可能性
- **複雑なエラー回復機能**: シンプルなエラーメッセージで十分
- **バリデーションキャッシュ**: 基本的な入力チェックにキャッシュは不要
- **非同期バリデーション**: 重い処理がないため同期処理で十分

#### ❌ 除外した監査・ログ機能
- **詳細な監査ログ**: 個人アプリには不要
- **バリデーションパターン分析**: 使用頻度が低い機能には過剰
- **ユーザビリティレポート**: エンタープライズ向け機能

### 除外理由
**お得チェッカーの特性**：
- データ機密性: 低（商品価格情報）
- 使用環境: 買い物中の片手操作
- ユーザー層: シンプル操作を重視
- 開発リソース: 限定的


## 10. まとめ

### 10.1 簡素化されたデータバリデーション仕様

**実装対象**：
- 必要最小限の入力チェック（空文字、範囲、フォーマット）
- 分かりやすい日本語エラーメッセージ
- SwiftUIでのリアルタイム検証表示
- Core Data保存時の基本チェック
- 単位互換性チェック

**期待される効果**：
1. **ユーザビリティ重視**: 買い物中の使いやすさを最優先
2. **開発効率**: 8-12時間で実装完了
3. **保守性**: シンプルな構成で障害要因を最小化
4. **拡張性**: 必要に応じて段階的に機能追加可能

**お得チェッカーに最適化**：
- 商品価格情報の特性に合わせた軽量バリデーション
- 片手操作を考慮したエラー表示
- 日本市場向けの価格・単位フォーマット対応

この簡素化仕様により、過度なエンジニアリングを避けながら、実用的で安全なデータバリデーション機能を提供します。