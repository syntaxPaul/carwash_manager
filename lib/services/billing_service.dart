import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../utils/store_names.dart';

import 'manager_auth.dart';

class BillingService extends ChangeNotifier {
  BillingService._();
  static final BillingService instance = BillingService._();

  static const Duration _storeTimeout = Duration(seconds: 15);
  static const Duration _purchaseUpdateTimeout = Duration(seconds: 60);
  static const MethodChannel _storeKitChannel =
      MethodChannel('washdesk/storekit');

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Timer? _purchaseWatchdog;

  bool _started = false;
  bool _storeAvailable = false;
  bool _loading = false;
  bool _purchasePending = false;
  DateTime? _loadingStartedAt;
  ProductDetails? _monthlyProduct;
  String? _message;

  bool get storeAvailable => _storeAvailable;
  bool get loading => _loading;
  bool get purchasePending => _purchasePending;
  ProductDetails? get monthlyProduct => _monthlyProduct;
  String? get message => _message;
  bool get canPurchase {
    if (_purchasePending) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) return true;
    return _storeAvailable && _monthlyProduct != null;
  }

  void start() {
    _startListening();
    unawaited(loadProducts());
  }

  void _startListening() {
    if (_started) return;
    _started = true;
    _purchaseSubscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        _purchasePending = false;
        _message = 'Store purchase update failed: $error';
        notifyListeners();
      },
    );
  }

  Future<void> loadProducts({bool force = false}) async {
    _startListening();
    if (_loading) {
      final started = _loadingStartedAt;
      final isStale =
          started == null || DateTime.now().difference(started) > _storeTimeout;
      if (!force && !isStale) return;
      _loading = false;
    }
    _loading = true;
    _loadingStartedAt = DateTime.now();
    _message = null;
    notifyListeners();

    late final bool available;
    try {
      available = await _iap.isAvailable().timeout(_storeTimeout);
    } on TimeoutException {
      _storeAvailable = false;
      _loading = false;
      _loadingStartedAt = null;
      _monthlyProduct = null;
      _message =
          'The $storeName is taking too long to respond. Check your connection and try again.';
      notifyListeners();
      return;
    } catch (error) {
      _storeAvailable = false;
      _loading = false;
      _loadingStartedAt = null;
      _monthlyProduct = null;
      _message = 'The $storeName could not be reached: $error';
      notifyListeners();
      return;
    }
    _storeAvailable = available;
    if (!available) {
      _loading = false;
      _loadingStartedAt = null;
      _monthlyProduct = null;
      _message = 'The App Store or Play Store is not available on this device.';
      notifyListeners();
      return;
    }

    late final ProductDetailsResponse response;
    try {
      response = await _iap.queryProductDetails(
          const {managerMonthlyProductId}).timeout(_storeTimeout);
    } on TimeoutException {
      _loading = false;
      _loadingStartedAt = null;
      _monthlyProduct = null;
      _message =
          'The $storeName is taking too long to load the monthly plan. Try again.';
      notifyListeners();
      return;
    } catch (error) {
      _loading = false;
      _loadingStartedAt = null;
      _monthlyProduct = null;
      _message =
          'The monthly plan could not be loaded from the $storeName: $error';
      notifyListeners();
      return;
    }
    _loading = false;
    _loadingStartedAt = null;
    if (response.error != null) {
      _monthlyProduct = null;
      _message = response.error!.message;
      notifyListeners();
      return;
    }
    if (response.notFoundIDs.contains(managerMonthlyProductId) ||
        response.productDetails.isEmpty) {
      _monthlyProduct = null;
      _message =
          'The monthly plan is not available from the $storeName yet. Try again later.';
      notifyListeners();
      return;
    }

    final products = response.productDetails.cast<ProductDetails>();
    final matchingProducts =
        products.where((product) => product.id == managerMonthlyProductId);
    _monthlyProduct =
        matchingProducts.isNotEmpty ? matchingProducts.first : products.first;
    notifyListeners();
  }

  Future<void> buyMonthly() async {
    start();
    final account = ManagerAuth.instance.current;
    if (account == null) {
      throw StateError('Sign in before subscribing.');
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _buyMonthlyWithStoreKit(account);
      return;
    }

    var product = _monthlyProduct;
    if (product == null) {
      await loadProducts(force: true);
      product = _monthlyProduct;
    }
    if (product == null) {
      throw StateError(_message ?? 'The monthly plan is not available yet.');
    }

    _purchasePending = true;
    _message = null;
    notifyListeners();

    final purchaseParam = PurchaseParam(
      productDetails: product,
      applicationUserName: account.id,
    );
    late final bool launched;
    try {
      launched = await _iap
          .buyNonConsumable(purchaseParam: purchaseParam)
          .timeout(_storeTimeout);
    } on TimeoutException {
      _purchasePending = false;
      _message = 'The $storeName is taking too long to start the purchase.';
      notifyListeners();
      return;
    } catch (error) {
      _purchasePending = false;
      _message = 'The $storeName could not start the purchase: $error';
      notifyListeners();
      return;
    }
    if (!launched) {
      _purchasePending = false;
      _message = 'The store could not start the purchase.';
      notifyListeners();
      return;
    }
    _message = 'Confirm the subscription in the $storeName sheet.';
    _startPurchaseWatchdog();
    notifyListeners();
  }

  Future<void> _buyMonthlyWithStoreKit(ManagerAccount account) async {
    _loading = false;
    _purchasePending = true;
    _message = 'Opening the App Store subscription sheet...';
    _startPurchaseWatchdog();
    notifyListeners();

    late final Map<Object?, Object?> result;
    try {
      final response = await _storeKitChannel.invokeMapMethod<Object?, Object?>(
        'purchaseSubscription',
        {
          'productId': managerMonthlyProductId,
          'appAccountToken': account.id,
        },
      ).timeout(_purchaseUpdateTimeout);
      result = response ?? const <Object?, Object?>{};
    } on TimeoutException {
      _purchasePending = false;
      _purchaseWatchdog?.cancel();
      _message =
          'The App Store did not open in time. Check your connection and try again.';
      notifyListeners();
      return;
    } on PlatformException catch (error) {
      _purchasePending = false;
      _purchaseWatchdog?.cancel();
      _message = error.message ?? 'The App Store could not start the purchase.';
      notifyListeners();
      return;
    } catch (error) {
      _purchasePending = false;
      _purchaseWatchdog?.cancel();
      _message = 'The $storeName could not start the purchase: $error';
      notifyListeners();
      return;
    }

    final status = result['status']?.toString();
    switch (status) {
      case 'purchased':
      case 'restored':
        try {
          await ManagerAuth.instance.activateSubscription(
            productId:
                result['productId']?.toString() ?? managerMonthlyProductId,
            purchaseId: result['transactionId']?.toString(),
            verificationSource: 'storekit2',
            verificationData: result['verificationData']?.toString() ?? '',
          );
          _purchasePending = false;
          _purchaseWatchdog?.cancel();
          _message = 'Subscription active.';
          notifyListeners();
        } on StateError catch (error) {
          _purchasePending = false;
          _purchaseWatchdog?.cancel();
          _message = error.message;
          notifyListeners();
        }
        break;
      case 'pending':
        _purchasePending = false;
        _purchaseWatchdog?.cancel();
        _message =
            'Purchase pending. Apple will finish it after payment approval.';
        notifyListeners();
        break;
      case 'cancelled':
        _purchasePending = false;
        _purchaseWatchdog?.cancel();
        _message = 'Purchase cancelled.';
        notifyListeners();
        break;
      default:
        _purchasePending = false;
        _purchaseWatchdog?.cancel();
        _message = 'The App Store did not return a completed subscription.';
        notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    start();
    _purchasePending = true;
    _message = null;
    _startPurchaseWatchdog();
    notifyListeners();
    try {
      await _iap
          .restorePurchases(
            applicationUserName: ManagerAuth.instance.current?.id,
          )
          .timeout(_storeTimeout);
    } on TimeoutException {
      _purchasePending = false;
      _purchaseWatchdog?.cancel();
      _message = 'The $storeName is taking too long to restore purchases.';
      notifyListeners();
    } catch (error) {
      _purchasePending = false;
      _purchaseWatchdog?.cancel();
      _message = 'Could not restore purchases: $error';
      notifyListeners();
    }
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchases,
  ) async {
    if (purchases.isEmpty) {
      _purchasePending = false;
      _purchaseWatchdog?.cancel();
      _message = 'No WashDesk subscription was found to restore.';
      notifyListeners();
      return;
    }

    for (final purchase in purchases) {
      _purchaseWatchdog?.cancel();
      if (purchase.productID != managerMonthlyProductId) {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        continue;
      }

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _purchasePending = true;
          _message =
              'Purchase pending. We will unlock WashDesk once it clears.';
          notifyListeners();
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          try {
            await _deliverSubscription(purchase);
          } on StateError catch (error) {
            _purchasePending = false;
            _message = error.message;
            notifyListeners();
          }
          break;
        case PurchaseStatus.error:
          _purchasePending = false;
          _message = purchase.error?.message ?? 'The purchase failed.';
          notifyListeners();
          break;
        case PurchaseStatus.canceled:
          _purchasePending = false;
          _message = 'Purchase cancelled.';
          notifyListeners();
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _deliverSubscription(PurchaseDetails purchase) async {
    final verificationData = purchase.verificationData.serverVerificationData;
    await ManagerAuth.instance.activateSubscription(
      productId: purchase.productID,
      purchaseId: purchase.purchaseID,
      verificationSource: purchase.verificationData.source,
      verificationData: verificationData.isEmpty
          ? purchase.verificationData.localVerificationData
          : verificationData,
    );
    _purchasePending = false;
    _message = purchase.status == PurchaseStatus.restored
        ? 'Subscription restored.'
        : 'Subscription active.';
    notifyListeners();
  }

  void _startPurchaseWatchdog() {
    _purchaseWatchdog?.cancel();
    _purchaseWatchdog = Timer(_purchaseUpdateTimeout, () {
      if (!_purchasePending) return;
      _purchasePending = false;
      _message =
          'The $storeName did not finish the subscription request. Try again or use Restore purchase.';
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _purchaseWatchdog?.cancel();
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
