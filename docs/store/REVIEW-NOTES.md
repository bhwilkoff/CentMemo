# App Review notes (CentMemo 1.0)

Set in App Store Connect once Ben gives a contact phone (+country code; App
Store Connect refuses the review details without one). Contact: Ben Wilkoff,
hello@centmemo.com. Demo account: not required (Sign in with Apple).

Sign in: Sign in with Apple only. Please use your own Apple ID; there is no password account.

Sample data: a new account starts empty. To see CentMemo with purchases, sign in at https://centmemo.com, choose Import, and pick this synthetic Apple Card export: https://centmemo.com/review/applecard-sample.csv (22 made-up purchases). The iPhone app shows the same data right away. On the iPhone, Settings > Import Apple Card export also takes the file from Files.

Apple Wallet (FinanceKit): Settings > Connect Apple Wallet. It needs an Apple Card, Apple Cash, or Savings account in Wallet on the review device; without one, Settings says Wallet data isn't on this device. A short explanation of what is read is shown before access is asked. Turning access off in iOS Settings deletes the synced Wallet data the next time CentMemo opens.

Account deletion: Settings > Delete account, confirmed in an alert. It removes everything at once.

Claude connector (optional, on the web): people may let their own Claude read their memos and imported purchases (https://centmemo.com/connect/). It is read-only, off unless the person connects it, and never includes Apple Wallet (FinanceKit) data.

The attached screen recording walks the app on a physical iPhone.
