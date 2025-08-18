# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**OtokuChecker** is an iOS shopping comparison app that helps users instantly compare product unit prices to make optimal purchasing decisions while shopping.

### Core Features
- **Simple Comparison**: Compare unit prices between two products with instant value judgment
- **Historical Data Reference**: Compare against previously saved product data
- **Data Persistence**: Detailed product records with purchase history
- **Category Management**: Product categorization with custom category support

## Development Environment & Commands

### Xcode Project Location
- Project file: `20_Source/OtokuChecker/OtokuChecker.xcodeproj`
- Working directory: `20_Source/OtokuChecker/`

### Development Commands
```bash
# Open the project
open 20_Source/OtokuChecker/OtokuChecker.xcodeproj

# Build and run in Xcode
# Cmd+R to run in simulator
# Cmd+B to build only
# Cmd+U to run unit tests
```

Note: This is an iOS project, so primary development is done through Xcode IDE rather than command line tools.

## Architecture

### Tech Stack
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Database**: Core Data
- **Minimum iOS**: 15.0+
- **Target Device**: iPhone only

### Project Structure
```
OtokuChecker/
├── 10_Document/              # Design documentation (Japanese)
│   ├── 01_要件定義/          # Requirements
│   ├── 02_基本設計/          # Basic design & wireframes
│   └── 03_詳細設計/          # Detailed design & database schema
└── 20_Source/
    └── OtokuChecker/         # Xcode project
        ├── OtokuChecker/     # Main app target
        ├── OtokuCheckerTests/
        └── OtokuCheckerUITests/
```

### Current State
The project is in initial stages with basic Core Data setup. Currently contains:
- Basic app structure with SwiftUI
- Core Data stack with simple `Item` entity (placeholder)
- Standard iOS project template structure

### Planned Architecture
Based on design documents, the app will implement:

#### Core Data Entities
- **ProductGroup**: Groups multiple records of the same product
- **ProductRecord**: Individual product purchase records with price, quantity, store info
- **Category**: Product categorization (system + custom categories)
- **ComparisonHistory**: Records of product comparisons performed

#### Key Design Principles
- **Comparison-first UI**: Main screen dedicated to product comparison
- **One-handed operation**: Optimized for shopping scenarios
- **iOS standard compliance**: Follows Apple's design guidelines

## Important Technical Specifications

### Unit Conversion System
- Supports multiple units (g/kg, ml/L, pieces, etc.)
- Automatic conversion to base units for accurate price comparison
- Unit compatibility checking (weight vs volume vs count)

### Soft Delete Pattern
- Uses `isDeleted` boolean flags instead of physical deletion
- Maintains data integrity for historical comparisons
- Enables data recovery and audit trails

### Search Normalization
- Product names normalized for better search (hiragana→katakana, full-width→half-width)
- Improves fuzzy matching capabilities for Japanese product names

### Performance Optimizations
- Core Data indexes for frequent queries
- Batch size limits for large datasets
- Denormalized statistics in ProductGroup for fast display

## Development Guidelines

### Localization
- UI text in Japanese (target market is Japan)
- Error messages in Japanese
- Comments can be in Japanese for business logic
- Variable/function names in English
- Git commit messages in Japanese (per global config)

### SwiftUI Best Practices
- Use proper state management (@State, @StateObject, @ObservedObject)
- Pass Core Data context via Environment
- Follow SwiftUI lifecycle patterns
- Maintain view-model separation

### Core Data Usage
- Heavy operations on background contexts
- Main context for UI updates only
- Proper NSFetchRequest configuration with batchSize
- Careful relationship management to avoid retain cycles

## File Organization

### Current Files
- `OtokuCheckerApp.swift`: App entry point with Core Data environment setup
- `ContentView.swift`: Main view (currently placeholder implementation)
- `Persistence.swift`: Core Data stack configuration
- `OtokuChecker.xcdatamodeld`: Core Data model (minimal setup)

### Planned Structure
- `Views/`: SwiftUI views organized by feature
- `Models/`: Core Data entity extensions and business logic
- `Services/`: Business logic and data manipulation
- `Utils/`: Shared utilities and extensions
- `Resources/`: Localizable strings and assets

## Key Business Logic

### Price Comparison Algorithm
1. Normalize units to common base (grams for weight, ml for volume)
2. Calculate unit price (price ÷ quantity)
3. Compare unit prices with percentage difference
4. Handle edge cases (same price, invalid inputs)

### Japanese Market Considerations
- Tax calculation (内税/外税 - tax-inclusive/exclusive pricing)
- Common Japanese product units and packaging
- Store chain recognition for historical data
- Japanese product naming conventions