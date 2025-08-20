//
//  ProductGroup+CoreDataProperties.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/20.
//

import Foundation
import CoreData

extension ProductGroup {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ProductGroup> {
        return NSFetchRequest<ProductGroup>(entityName: "ProductGroup")
    }

    @NSManaged public var entityID: UUID
    @NSManaged public var productName: String?
    @NSManaged public var normalizedName: String?
    @NSManaged public var productType: String?
    @NSManaged public var recordCount: Int32
    @NSManaged public var averageUnitPrice: NSDecimalNumber?
    @NSManaged public var lowestUnitPrice: NSDecimalNumber?
    @NSManaged public var lowestPriceStoreName: String?
    @NSManaged public var lastRecordDate: Date?
    @NSManaged public var deletedFlag: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var category: ProductCategory?
    @NSManaged public var records: NSSet?

}

// MARK: Generated accessors for records
extension ProductGroup {

    @objc(addRecordsObject:)
    @NSManaged public func addToRecords(_ value: ProductRecord)

    @objc(removeRecordsObject:)
    @NSManaged public func removeFromRecords(_ value: ProductRecord)

    @objc(addRecords:)
    @NSManaged public func addToRecords(_ values: NSSet)

    @objc(removeRecords:)
    @NSManaged public func removeFromRecords(_ values: NSSet)

}

extension ProductGroup : Identifiable {

}