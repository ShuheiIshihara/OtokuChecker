import SwiftUI

// ViewModelからenumをインポート
typealias TaxType = DataEntryViewModel.TaxType
typealias OriginType = DataEntryViewModel.OriginType

struct DataEntryView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = DataEntryViewModel()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 商品情報セクション
                    ProductInfoSection(
                        productName: $viewModel.productName,
                        productType: $viewModel.productType,
                        selectedCategory: $viewModel.selectedCategory
                    )
                    
                    // 価格情報セクション
                    PriceInfoSection(
                        price: $viewModel.price,
                        taxType: $viewModel.taxType,
                        taxRate: $viewModel.taxRate
                    )
                    
                    // 容量・重量セクション
                    QuantitySection(
                        quantity: $viewModel.quantity,
                        selectedUnit: $viewModel.selectedUnit
                    )
                    
                    // 原産地セクション
                    OriginSection(
                        origin: $viewModel.origin
                    )
                    
                    // その他情報セクション
                    OtherInfoSection(
                        storeName: $viewModel.storeName,
                        registrationDate: $viewModel.registrationDate,
                        memo: $viewModel.memo
                    )
                    
                    // 計算結果セクション
                    CalculationResultSection(
                        unitPrice: viewModel.unitPrice
                    )
                    
                    // 登録ボタン
                    RegisterButton {
                        viewModel.registerProduct()
                    }
                    .disabled(!viewModel.isFormValid)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 12) {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.pink)
                                .font(.title2)
                        }
                        
                        Image(systemName: "cart.fill")
                            .foregroundColor(.pink)
                            .font(.title2)
                        
                        Text("商品を保存")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden()
    }
}

// MARK: - 商品情報セクション
struct ProductInfoSection: View {
    @Binding var productName: String
    @Binding var productType: String
    @Binding var selectedCategory: String
    
    private let categories = ["食料品", "日用品", "衣料品", "電子機器", "書籍", "その他"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "pencil")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("商品情報")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("比較結果から引き継ぎ")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("商品名")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                TextField("商品名を入力", text: $productName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 16))
                    .accessibilityLabel("商品名入力フィールド")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("品目")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                TextField("品目を入力", text: $productType)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 16))
                    .accessibilityLabel("品目入力フィールド")
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("カテゴリ")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Menu {
                    ForEach(categories, id: \.self) { category in
                        Button(category) {
                            selectedCategory = category
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedCategory.isEmpty ? "カテゴリを選択" : selectedCategory)
                            .font(.system(size: 16))
                            .foregroundColor(selectedCategory.isEmpty ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .accessibilityLabel("カテゴリ選択メニュー")
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

// MARK: - 価格情報セクション
struct PriceInfoSection: View {
    @Binding var price: String
    @Binding var taxType: TaxType
    @Binding var taxRate: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "yensign.circle")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    )
                
                Text("価格情報")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("価格")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    TextField("1,400", text: $price)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 16))
                    
                    Text("円")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("税区分")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 24) {
                    Button(action: {
                        taxType = .inclusive
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: taxType == .inclusive ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(taxType == .inclusive ? .green : .gray)
                                .font(.system(size: 20))
                            Text("税込")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Button(action: {
                        taxType = .exclusive
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: taxType == .exclusive ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(taxType == .exclusive ? .green : .gray)
                                .font(.system(size: 20))
                            Text("税別")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            
            if taxType == .exclusive {
                VStack(alignment: .leading, spacing: 12) {
                    Text("税率")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        TextField("10", text: $taxRate)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 16))
                        
                        Text("%")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
        )
    }
}

// MARK: - 容量・重量セクション
struct QuantitySection: View {
    @Binding var quantity: String
    @Binding var selectedUnit: String
    
    private let units = ["kg", "g", "L", "ml", "個", "本", "枚"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "scalemass")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    )
                
                Text("容量・重量")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("容量")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    TextField("5", text: $quantity)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 16))
                    
                    Menu {
                        ForEach(units, id: \.self) { unit in
                            Button(unit) {
                                selectedUnit = unit
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedUnit.isEmpty ? "単位" : selectedUnit)
                                .font(.system(size: 16))
                                .foregroundColor(selectedUnit.isEmpty ? .secondary : .primary)
                            Image(systemName: "chevron.down")
                                .foregroundColor(.purple)
                                .font(.system(size: 14))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(minWidth: 80)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.1))
        )
    }
}

// MARK: - 原産地セクション
struct OriginSection: View {
    @Binding var origin: OriginType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.orange)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "flag")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    )
                
                Text("原産地")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack(spacing: 24) {
                Button(action: {
                    origin = .domestic
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: origin == .domestic ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(origin == .domestic ? .orange : .gray)
                            .font(.system(size: 20))
                        Text("国産")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .foregroundColor(origin == .domestic ? Color.orange.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(origin == .domestic ? Color.orange : Color.gray.opacity(0.3), lineWidth: 2)
                    )
                }
                
                Button(action: {
                    origin = .imported
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: origin == .imported ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(origin == .imported ? .orange : .gray)
                            .font(.system(size: 20))
                        Text("輸入")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .foregroundColor(origin == .imported ? Color.orange.opacity(0.1) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(origin == .imported ? Color.orange : Color.gray.opacity(0.3), lineWidth: 2)
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

// MARK: - その他情報セクション
struct OtherInfoSection: View {
    @Binding var storeName: String
    @Binding var registrationDate: Date
    @Binding var memo: String
    
    @State private var showDatePicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "info.circle")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("その他")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("任意入力")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("店舗名")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                TextField("店舗名を入力（任意）", text: $storeName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("登録日")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Button(action: {
                    showDatePicker.toggle()
                }) {
                    HStack {
                        Text(DateFormatter.shortDate.string(from: registrationDate))
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "calendar")
                            .foregroundColor(.cyan)
                            .font(.system(size: 16))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .sheet(isPresented: $showDatePicker) {
                    DatePicker(
                        "登録日",
                        selection: $registrationDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(WheelDatePickerStyle())
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("メモ")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                VStack(spacing: 8) {
                    TextEditor(text: Binding(
                        get: { memo },
                        set: { newValue in
                            memo = String(newValue.prefix(500))
                        }
                    ))
                        .frame(minHeight: 80)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .font(.system(size: 16))
                    
                    HStack {
                        Spacer()
                        Text("\(memo.count)/500文字")
                            .font(.system(size: 12))
                            .foregroundColor(memo.count > 500 ? .red : .secondary)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cyan.opacity(0.1))
        )
    }
}

// MARK: - 計算結果セクション
struct CalculationResultSection: View {
    let unitPrice: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.pink)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "function")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    )
                
                Text("計算結果")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                Text("単価")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(unitPrice)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.pink)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .foregroundColor(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.pink.opacity(0.3), lineWidth: 2)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.pink.opacity(0.1))
        )
    }
}

// MARK: - 登録ボタン
struct RegisterButton: View {
    let action: () -> Void
    @Environment(\.isEnabled) var isEnabled
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .semibold))
                Text("登録する")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isEnabled ? [Color.pink, Color.orange] : [Color.gray, Color.gray],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(!isEnabled)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .accessibilityLabel(isEnabled ? "商品を登録" : "入力が不完全のため登録できません")
        .accessibilityHint(isEnabled ? "タップして商品を保存します" : "必須項目をすべて入力してください")
    }
}


#Preview {
    DataEntryView()
}