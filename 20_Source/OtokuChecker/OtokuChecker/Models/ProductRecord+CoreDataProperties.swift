//
//  ProductRecord+CoreDataProperties.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/20.
//

import Foundation
import CoreData

extension ProductRecord {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProductRecord> {
        return NSFetchRequest<ProductRecord>(entityName: "ProductRecord")
    }

    @NSManaged public var entityID: UUID
    @NSManaged public var productName: String?
    @NSManaged public var productType: String?
    @NSManaged public var originalPrice: NSDecimalNumber?
    @NSManaged public var finalPrice: NSDecimalNumber?
    @NSManaged public var taxIncluded: Bool
    @NSManaged public var taxRate: NSDecimalNumber?
    @NSManaged public var quantity: NSDecimalNumber?
    @NSManaged public var unitType: String?
    @NSManaged public var unitPrice: NSDecimalNumber?
    @NSManaged public var storeName: String?
    @NSManaged public var storeLocation: String?
    @NSManaged public var purchaseDate: Date?
    @NSManaged public var memo: String?
    @NSManaged public var deletedFlag: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var category: ProductCategory?
    @NSManaged public var productGroup: ProductGroup?

}

extension ProductRecord : Identifiable {

}