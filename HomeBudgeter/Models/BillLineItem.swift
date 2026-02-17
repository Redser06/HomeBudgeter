//
//  BillLineItem.swift
//  HomeBudgeter
//
//  Created by Home Budgeter Team
//

import Foundation
import SwiftData

@Model
final class BillLineItem {
    @Attribute(.unique) var id: UUID
    var billType: BillType
    var amount: Decimal
    var label: String?

    var transaction: Transaction?

    init(
        billType: BillType,
        amount: Decimal,
        label: String? = nil,
        transaction: Transaction? = nil
    ) {
        self.id = UUID()
        self.billType = billType
        self.amount = amount
        self.label = label
        self.transaction = transaction
    }
}
