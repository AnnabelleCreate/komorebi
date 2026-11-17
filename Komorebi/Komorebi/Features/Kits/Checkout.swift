import Foundation
import Observation

/// Holds one checkout from "How often" to "Confirmed".
/// Beta: payments run in test mode. Cards are validated for real, but no money moves.
@Observable
final class CheckoutModel {
    static let priceCents = 1800

    var plan: KitPlan = .once
    var address = ShippingAddress()
    var cardNumber = ""
    var expiry = ""
    var cvc = ""
    var cardName = ""
    var saveAddress = true

    var addressErrors: [String: String] = [:]
    var cardErrors: [String: String] = [:]
    var paymentFailure: String?
    var isPaying = false

    init(saved: ShippingAddress?) {
        if let saved { address = saved }
    }

    // MARK: Address

    static let states: Set<String> = ["AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY", "PR"]

    func validateAddress() -> Bool {
        var e: [String: String] = [:]
        let a = address
        func blank(_ s: String) -> Bool { s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if a.name.trimmingCharacters(in: .whitespaces).count < 2 { e["name"] = "Add the name for the box." }
        if a.street.trimmingCharacters(in: .whitespaces).count < 4 || !a.street.contains(where: \.isNumber) {
            e["street"] = "Add a street address with a house or building number."
        }
        if blank(a.city) { e["city"] = "Add a city." }
        if !CheckoutModel.states.contains(a.state.uppercased().trimmingCharacters(in: .whitespaces)) { e["state"] = "Use a two-letter state, like PA." }
        let zip = a.zip.trimmingCharacters(in: .whitespaces)
        if zip.range(of: #"^\d{5}(-\d{4})?$"#, options: .regularExpression) == nil { e["zip"] = "Use a 5-digit ZIP code." }
        addressErrors = e
        if e.isEmpty { address.state = a.state.uppercased().trimmingCharacters(in: .whitespaces) }
        return e.isEmpty
    }

    // MARK: Card

    var cardDigits: String { cardNumber.filter(\.isNumber) }

    /// Formats as "4242 4242 4242 4242" while typing.
    func formatCardNumber() {
        let digits = String(cardDigits.prefix(19))
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && i % 4 == 0 { out.append(" ") }
            out.append(ch)
        }
        if out != cardNumber { cardNumber = out }
    }

    /// Formats as "MM/YY" while typing.
    func formatExpiry() {
        let digits = String(expiry.filter(\.isNumber).prefix(4))
        let out = digits.count > 2 ? "\(digits.prefix(2))/\(digits.dropFirst(2))" : digits
        if out != expiry { expiry = out }
    }

    static func luhn(_ digits: String) -> Bool {
        var sum = 0
        for (i, ch) in digits.reversed().enumerated() {
            guard var d = ch.wholeNumberValue else { return false }
            if i % 2 == 1 { d *= 2; if d > 9 { d -= 9 } }
            sum += d
        }
        return sum % 10 == 0
    }

    var cardBrand: String {
        let d = cardDigits
        if d.hasPrefix("4") { return "Visa" }
        if let two = Int(d.prefix(2)), (51...55).contains(two) { return "Mastercard" }
        if let four = Int(d.prefix(4)), (2221...2720).contains(four) { return "Mastercard" }
        if d.hasPrefix("34") || d.hasPrefix("37") { return "American Express" }
        if d.hasPrefix("6011") || d.hasPrefix("65") { return "Discover" }
        return "Card"
    }

    func validateCard(now: Date = Date()) -> Bool {
        var e: [String: String] = [:]
        let digits = cardDigits
        if digits.count < 13 || digits.count > 19 || !CheckoutModel.luhn(digits) {
            e["number"] = "That card number doesn’t look right. Check the digits."
        }
        let parts = expiry.split(separator: "/")
        if parts.count == 2, let mm = Int(parts[0]), let yy = Int(parts[1]), (1...12).contains(mm) {
            let cal = Calendar.current
            let year = 2000 + yy
            let thisYear = cal.component(.year, from: now), thisMonth = cal.component(.month, from: now)
            if year < thisYear || (year == thisYear && mm < thisMonth) { e["expiry"] = "This card has expired." }
            if year > thisYear + 20 { e["expiry"] = "Check the expiry year." }
        } else {
            e["expiry"] = "Use MM/YY, like 08/29."
        }
        let cvcDigits = cvc.filter(\.isNumber)
        let needed = cardBrand == "American Express" ? 4 : 3
        if cvcDigits.count != needed { e["cvc"] = "Use the \(needed)-digit code on your card." }
        if cardName.trimmingCharacters(in: .whitespaces).count < 2 { e["cardName"] = "Add the name on the card." }
        cardErrors = e
        return e.isEmpty
    }

    var paymentSummary: String { "\(cardBrand) ending \(String(cardDigits.suffix(4)))" }

    // MARK: Paying (test mode)

    /// Test cards behave like a real processor's test mode:
    /// 4000 0000 0000 0002 is declined, 4000 0000 0000 9995 has insufficient funds.
    func pay(completion: @escaping (KitOrder?) -> Void) {
        guard !isPaying else { return }
        paymentFailure = nil
        isPaying = true
        let digits = cardDigits
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            self.isPaying = false
            if digits == "4000000000000002" {
                self.paymentFailure = "Your card was declined. Nothing was charged. Try another card."
                completion(nil)
                return
            }
            if digits == "4000000000009995" {
                self.paymentFailure = "The card doesn’t have enough funds. Nothing was charged."
                completion(nil)
                return
            }
            let order = KitOrder(
                number: "KM-\(Int.random(in: 20000...99999))",
                placedAt: Date(),
                plan: self.plan,
                isActive: self.plan == .monthly,
                address: self.address,
                paymentSummary: self.paymentSummary,
                totalCents: CheckoutModel.priceCents)
            completion(order)
        }
    }
}

extension Int {
    var dollars: String { String(format: "$%d.%02d", self / 100, self % 100) }
}
