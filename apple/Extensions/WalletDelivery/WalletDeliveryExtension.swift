import ExtensionFoundation
import FinanceKit

/// F2: FinanceKit launches this when Wallet data changes, so new purchases
/// reach CentMemo without the person opening the app. It only syncs; it never
/// notifies (FinanceKit terms: no transaction details in notifications).
@main
final class WalletDeliveryExtension: BackgroundDeliveryExtension {
    required init() {}

    func didReceiveData(for types: [FinanceStore.BackgroundDataType]) async {
        guard types.contains(.transactions) || types.contains(.accounts) else { return }
        await FinanceBackgroundSync.run()
    }

    func willTerminate() async {}
}
