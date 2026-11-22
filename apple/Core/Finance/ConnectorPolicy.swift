import Foundation

/// Whether the Claude connector shares Apple Wallet (FinanceKit) data. Mirrors
/// SHARE_FINANCEKIT in supabase/functions/mcp/index.ts; tests/connector_policy.test.mjs
/// fails if the two, or any page that promises either way, disagree. Turn on only
/// with Apple's written permission (Addendum 3.2; docs/store/WALLET-IN-CONNECTOR.md).
enum ConnectorPolicy {
    static let sharesWallet = false

    /// Shown before FinanceKit access is asked (Addendum 3.3).
    static var walletDisclosure: String {
        sharesWallet
            ? "If you connect Claude, it can read them too, and never change them."
            : "Claude never sees them."
    }
}
