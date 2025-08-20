//
//  ComparisonHistory+CoreDataProperties.swift
//  OtokuChecker
//
//  Created by Claude Code on 2025/08/20.
//

import Foundation
import CoreData

extension ComparisonHistory {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ComparisonHistory> {
        return NSFetchRequest<ComparisonHistory>(entityName: "ComparisonHistory")
    }

    @NSManaged public var entityID: UUID
    @NSManaged public var comparisonType: String?
    @NSManaged public var comparisonContext: String?
    @NSManaged public var productAName: String?
    @NSManaged public var productAPrice: NSDecimalNumber?
    @NSManaged public var productAQuantity: NSDecimalNumber?
    @NSManaged public var productAUnitType: String?
    @NSManaged public var productAUnitPrice: NSDecimalNumber?
    @NSManaged public var productBName: String?
    @NSManaged public var productBPrice: NSDecimalNumber?
    @NSManaged public var productBQuantity: NSDecimalNumber?
    @NSManaged public var productBUnitType: String?
    @NSManaged public var productBUnitPrice: NSDecimalNumber?
    @NSManaged public var winnerProduct: String?
    @NSManaged public var priceDifference: NSDecimalNumber?
    @NSManaged public var percentageDifference: NSDecimalNumber?
    @NSManaged public var userChoice: String?
    @NSManaged public var wasDataSaved: Bool
    @NSManaged public var deletedFlag: Bool
    @NSManaged public var createdAt: Date?

}

extension ComparisonHistory : Identifiable {

}