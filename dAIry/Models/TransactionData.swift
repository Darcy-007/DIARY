import Foundation

struct TransactionData {
    let merchantName: String
    let amount: Decimal
    let date: Date
}

struct TransactionSummary: Codable {
    let merchantName: String
    let amount: Decimal
    let date: Date
}
