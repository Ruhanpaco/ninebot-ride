//
//  Item.swift
//  Open Ninebot Ride
//
//  Created by Ruhan Pacolli on 31.5.26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
