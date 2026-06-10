import {
  Environment,
  SignedDataVerifier,
} from "npm:@apple/app-store-server-library@1.6.0";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

type NotificationPayload = {
  notificationType?: string;
  subtype?: string;
  data?: {
    bundleId?: string;
    environment?: string;
    signedTransactionInfo?: string;
    signedRenewalInfo?: string;
  };
};

type TransactionPayload = {
  appAccountToken?: string;
  originalTransactionId?: string;
  transactionId?: string;
  productId?: string;
  expiresDate?: number;
  revocationDate?: number;
};

type RenewalPayload = {
  autoRenewStatus?: number;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const bundleId = Deno.env.get("APPLE_BUNDLE_ID") ?? "com.washdesk.manager";
const environmentName =
  (Deno.env.get("APPLE_ENVIRONMENT") ?? "PRODUCTION").toUpperCase();
const appleRootCaPem = Deno.env.get("APPLE_ROOT_CA_PEM") ?? "";

const environment =
  environmentName === "SANDBOX" ? Environment.SANDBOX : Environment.PRODUCTION;

const supabase = createClient(supabaseUrl, serviceRoleKey, {
  auth: { persistSession: false },
});

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  if (!appleRootCaPem.trim()) {
    return json({ error: "APPLE_ROOT_CA_PEM is not configured" }, 500);
  }

  const body = await request.json().catch(() => null);
  const signedPayload = body?.signedPayload;
  if (typeof signedPayload !== "string" || signedPayload.trim() === "") {
    return json({ error: "Missing signedPayload" }, 400);
  }

  const verifier = new SignedDataVerifier(
    [new TextEncoder().encode(appleRootCaPem)],
    true,
    environment,
    bundleId,
  );

  let notification: NotificationPayload;
  let transaction: TransactionPayload | null = null;
  let renewal: RenewalPayload | null = null;

  try {
    notification = await verifier.verifyAndDecodeNotification(signedPayload);
    const signedTransaction = notification.data?.signedTransactionInfo;
    const signedRenewal = notification.data?.signedRenewalInfo;
    if (signedTransaction) {
      transaction = await verifier.verifyAndDecodeTransaction(
        signedTransaction,
      );
    }
    if (signedRenewal) {
      renewal = await verifier.verifyAndDecodeRenewalInfo(signedRenewal);
    }
  } catch (error) {
    console.error("Apple notification verification failed", error);
    return json({ error: "Invalid signed payload" }, 401);
  }

  const notificationType = notification.notificationType ?? "UNKNOWN";
  const subtype = notification.subtype ?? null;
  let userId = transaction?.appAccountToken ?? null;
  const status = entitlementStatus(notificationType, transaction);
  const expiresAt = transaction?.expiresDate
    ? new Date(transaction.expiresDate).toISOString()
    : null;

  let businessId: string | null = null;

  if (!userId && transaction?.originalTransactionId) {
    const { data: entitlement } = await supabase
      .from("subscription_entitlements")
      .select("user_id,business_id")
      .or(
        [
          `original_transaction_id.eq.${transaction.originalTransactionId}`,
          `transaction_id.eq.${transaction.originalTransactionId}`,
        ].join(","),
      )
      .maybeSingle();
    userId = entitlement?.user_id ?? null;
    businessId = entitlement?.business_id ?? null;
  }

  if (userId && !businessId) {
    const { data: business } = await supabase
      .from("businesses")
      .select("id")
      .eq("owner_user_id", userId)
      .maybeSingle();
    businessId = business?.id ?? null;
  }

  await supabase.from("subscription_events").insert({
    user_id: userId,
    business_id: businessId,
    product_id: transaction?.productId ?? null,
    original_transaction_id: transaction?.originalTransactionId ?? null,
    transaction_id: transaction?.transactionId ?? null,
    status,
    environment: notification.data?.environment ?? environmentName,
    notification_type: notificationType,
    notification_subtype: subtype,
    raw_payload: {
      notification,
      transaction,
      renewal,
    },
  });

  if (userId && transaction?.productId) {
    await supabase.from("subscription_entitlements").upsert(
      {
        user_id: userId,
        business_id: businessId,
        product_id: transaction.productId,
        status,
        source: "app_store_notification",
        environment: notification.data?.environment ?? environmentName,
        original_transaction_id: transaction.originalTransactionId ?? null,
        transaction_id: transaction.transactionId ?? null,
        expires_at: expiresAt,
        auto_renew_status: renewal?.autoRenewStatus?.toString() ?? null,
        last_notification_type: notificationType,
        last_notification_subtype: subtype,
        raw_payload: {
          notification,
          transaction,
          renewal,
        },
        updated_at: new Date().toISOString(),
      },
      { onConflict: "user_id" },
    );
  }

  return json({ ok: true });
});

function entitlementStatus(
  notificationType: string,
  transaction: TransactionPayload | null,
) {
  if (transaction?.revocationDate) return "revoked";
  switch (notificationType) {
    case "SUBSCRIBED":
    case "DID_RENEW":
    case "DID_RECOVER":
      return "active";
    case "DID_FAIL_TO_RENEW":
      return "billing_retry";
    case "GRACE_PERIOD_EXPIRED":
    case "EXPIRED":
      return "expired";
    case "REFUND":
    case "REVOKE":
      return "revoked";
    default:
      return "pending_verification";
  }
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}
