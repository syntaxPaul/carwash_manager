import Flutter
import StoreKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    configureStoreKitChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureStoreKitChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "washdesk/storekit",
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "purchaseSubscription" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let args = call.arguments as? [String: Any],
        let productId = args["productId"] as? String,
        let appAccountToken = args["appAccountToken"] as? String
      else {
        result(
          FlutterError(
            code: "bad_arguments",
            message: "Missing productId or appAccountToken.",
            details: nil
          )
        )
        return
      }

      Task {
        await self?.purchaseSubscription(
          productId: productId,
          appAccountToken: appAccountToken,
          result: result
        )
      }
    }
  }

  private func purchaseSubscription(
    productId: String,
    appAccountToken: String,
    result: @escaping FlutterResult
  ) async {
    do {
      let products = try await Product.products(for: [productId])
      guard let product = products.first else {
        result(
          FlutterError(
            code: "product_not_found",
            message: "The WashDesk subscription is not available from the App Store yet.",
            details: nil
          )
        )
        return
      }

      var options: Set<Product.PurchaseOption> = []
      if let uuid = UUID(uuidString: appAccountToken) {
        options.insert(.appAccountToken(uuid))
      }

      let purchaseResult = try await product.purchase(options: options)
      switch purchaseResult {
      case .success(let verification):
        switch verification {
        case .verified(let transaction):
          await transaction.finish()
          result([
            "status": "purchased",
            "productId": transaction.productID,
            "transactionId": String(transaction.id),
            "originalTransactionId": String(transaction.originalID),
            "verificationData": String(
              data: transaction.jsonRepresentation,
              encoding: .utf8
            ) ?? ""
          ])
        case .unverified(_, let error):
          result(
            FlutterError(
              code: "unverified_transaction",
              message: "Apple returned an unverified transaction: \(error.localizedDescription)",
              details: nil
            )
          )
        }
      case .pending:
        result(["status": "pending"])
      case .userCancelled:
        result(["status": "cancelled"])
      @unknown default:
        result(
          FlutterError(
            code: "unknown_purchase_result",
            message: "Apple returned an unknown purchase result.",
            details: nil
          )
        )
      }
    } catch {
      result(
        FlutterError(
          code: "storekit_error",
          message: error.localizedDescription,
          details: nil
        )
      )
    }
  }
}
