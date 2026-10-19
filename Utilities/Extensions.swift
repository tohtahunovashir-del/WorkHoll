import Foundation
import SwiftUI

extension Double {
    var formattedCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 0
        let numberString = formatter.string(from: NSNumber(value: self)) ?? "\(Int(self))"
        return "\(numberString) ₽"
    }
}

extension Date {
    var shortRussianTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }

    var russianDateTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: self)
    }
}
