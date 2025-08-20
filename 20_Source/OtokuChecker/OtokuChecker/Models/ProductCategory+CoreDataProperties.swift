//
//  ProductCategory+CoreDataProperties.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/20.
//

import Foundation
import CoreData

extension ProductCategory {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProductCategory> {
        return NSFetchRequest<ProductCategory>(entityName: "ProductCategory")
    }

    @NSManaged public var entityID: UUID
    @NSManaged public var name: String?
    @NSManaged public var icon: String?
    @NSManaged public var colorHex: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var averageUnitPrice: NSDecimalNumber?
    @NSManaged public var productCount: Int32
    @NSManaged public var deletedFlag: Bool
    @NSManaged public var isSystemCategory: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var lastUpdated: Date?
    @NSManaged public var productGroups: NSSet?
    @NSManaged public var productRecords: NSSet?

}

// MARK: Generated accessors for productGroups
extension ProductCategory {

    @objc(addProductGroupsObject:)
    @NSManaged public func addToProductGroups(_ value: ProductGroup)

    @objc(removeProductGroupsObject:)
    @NSManaged public func removeFromProductGroups(_ value: ProductGroup)

    @objc(addProductGroups:)
    @NSManaged public func addToProductGroups(_ values: NSSet)

    @objc(removeProductGroups:)
    @NSManaged public func removeFromProductGroups(_ values: NSSet)

}

// MARK: Generated accessors for productRecords
extension ProductCategory {

    @objc(addProductRecordsObject:)
    @NSManaged public func addToProductRecords(_ value: ProductRecord)

    @objc(removeProductRecordsObject:)
    @NSManaged public func removeFromProductRecords(_ value: ProductRecord)

    @objc(addProductRecords:)
    @NSManaged public func addToProductRecords(_ values: NSSet)

    @objc(removeProductRecords:)
    @NSManaged public func removeFromProductRecords(_ values: NSSet)

}

extension ProductCategory : Identifiable {

}