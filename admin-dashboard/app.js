const SUPABASE_URL = "https://thiaeudcwpbmhnbukous.supabase.co";
const SUPABASE_ANON_KEY =
  "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoaWFldWRjd3BibWhuYnVrb3VzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg0OTU3NTgsImV4cCI6MjA5NDA3MTc1OH0.mbz6dMLd3fwpfV6P4TBcUM_9vEqJWw9ukRxY2aYk9bE";

const client = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const els = {
  loginPanel: document.querySelector("#loginPanel"),
  loginForm: document.querySelector("#loginForm"),
  emailInput: document.querySelector("#emailInput"),
  passwordInput: document.querySelector("#passwordInput"),
  magicLinkButton: document.querySelector("#magicLinkButton"),
  status: document.querySelector("#status"),
  dashboard: document.querySelector("#dashboard"),
  refreshButton: document.querySelector("#refreshButton"),
  signOutButton: document.querySelector("#signOutButton"),
  statsGrid: document.querySelector("#statsGrid"),
  attentionRows: document.querySelector("#attentionRows"),
  businessRows: document.querySelector("#businessRows"),
  errorList: document.querySelector("#errorList"),
  subscriptionList: document.querySelector("#subscriptionList"),
};

const statLabels = [
  ["businesses_total", "Businesses"],
  ["subscriptions_active", "Active subscriptions", "good"],
  ["trials_running", "Running trials"],
  ["subscriptions_pending_verification", "Pending verification", "warning"],
  ["subscriptions_expired_or_retry", "Expired or retrying", "bad"],
  ["trials_expired_without_subscription", "Expired trials", "warning"],
  ["backup_failed", "Failed backups", "bad"],
  ["backup_missing_or_stale", "Missing or stale backups", "warning"],
  ["errors_24h", "Errors in 24h", "bad"],
];

function setStatus(message, isError = false) {
  els.status.textContent = message || "";
  els.status.classList.toggle("error", isError);
}

function formatDate(value) {
  if (!value) return "None";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Unknown";
  return new Intl.DateTimeFormat("en-ZA", {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function badge(value) {
  const text = String(value || "unknown");
  const bad = ["expired", "billing_retry", "revoked", "failed", "app_error"];
  const warn = ["pending_verification", "backup", "subscription", "unknown"];
  const className = bad.includes(text)
    ? "bad"
    : warn.includes(text)
      ? "warn"
      : "";
  return `<span class="badge ${className}">${escapeHtml(text)}</span>`;
}

function emptyRow(colspan, text) {
  return `<tr><td colspan="${colspan}">${escapeHtml(text)}</td></tr>`;
}

function renderStats(stats) {
  els.statsGrid.innerHTML = statLabels
    .map(([key, label, className = ""]) => {
      return `
        <article class="stat ${className}">
          <span>${escapeHtml(label)}</span>
          <strong>${Number(stats?.[key] || 0).toLocaleString("en-ZA")}</strong>
        </article>
      `;
    })
    .join("");
}

function renderAttention(rows) {
  if (!rows?.length) {
    els.attentionRows.innerHTML = emptyRow(5, "No businesses need attention.");
    return;
  }

  els.attentionRows.innerHTML = rows
    .map(
      (row) => `
        <tr>
          <td>
            <strong>${escapeHtml(row.business_name || "Unnamed business")}</strong><br />
            ${escapeHtml(row.email || "")}
          </td>
          <td>${badge(row.attention_type)}</td>
          <td>${badge(row.entitlement_status)}<br />${formatDate(row.expires_at)}</td>
          <td>${badge(row.backup_status)}<br />${formatDate(row.last_backup_at)}</td>
          <td>${Number(row.errors_24h || 0)}</td>
        </tr>
      `,
    )
    .join("");
}

function renderBusinesses(rows) {
  if (!rows?.length) {
    els.businessRows.innerHTML = emptyRow(6, "No businesses found yet.");
    return;
  }

  els.businessRows.innerHTML = rows
    .map(
      (row) => `
        <tr>
          <td><strong>${escapeHtml(row.business_name || "Unnamed business")}</strong></td>
          <td>${escapeHtml(row.owner_name || "")}</td>
          <td>${escapeHtml(row.email || "")}</td>
          <td>${badge(row.entitlement_status)}</td>
          <td>${formatDate(row.trial_end_at)}</td>
          <td>${formatDate(row.last_backup_at)}</td>
        </tr>
      `,
    )
    .join("");
}

function renderList(el, rows, emptyText, renderItem) {
  if (!rows?.length) {
    el.innerHTML = `<div class="list-item"><p>${escapeHtml(emptyText)}</p></div>`;
    return;
  }

  el.innerHTML = rows.map(renderItem).join("");
}

function renderDashboard(data) {
  renderStats(data.stats || {});
  renderAttention(data.attention || []);
  renderBusinesses(data.businesses || []);
  renderList(
    els.errorList,
    data.recent_errors || [],
    "No app errors recorded.",
    (row) => `
      <article class="list-item">
        <strong>${badge(row.severity)} ${escapeHtml(row.context || "App")}</strong>
        <p>${escapeHtml(row.business_name || row.email || "Unknown business")}</p>
        <p>${escapeHtml(row.message || "")}</p>
        <p>${formatDate(row.created_at)}</p>
      </article>
    `,
  );
  renderList(
    els.subscriptionList,
    data.recent_subscription_events || [],
    "No subscription events recorded.",
    (row) => `
      <article class="list-item">
        <strong>${badge(row.status)} ${escapeHtml(row.notification_type || "Purchase event")}</strong>
        <p>${escapeHtml(row.business_name || row.email || "Unknown business")}</p>
        <p>${escapeHtml(row.product_id || "")} ${escapeHtml(row.environment || "")}</p>
        <p>${formatDate(row.event_at)}</p>
      </article>
    `,
  );
}

async function loadDashboard() {
  setStatus("Loading dashboard...");
  const { data, error } = await client.rpc("admin_get_dashboard");
  if (error) {
    const message = error.message?.includes("Not authorized")
      ? "This Supabase user is not listed in public.admin_users."
      : error.message || "Could not load dashboard.";
    setStatus(message, true);
    return;
  }

  els.loginPanel.hidden = true;
  els.dashboard.hidden = false;
  els.refreshButton.hidden = false;
  els.signOutButton.hidden = false;
  renderDashboard(data);
  setStatus(`Last refreshed ${formatDate(data.generated_at)}`);
}

els.loginForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  setStatus("Signing in...");
  const { error } = await client.auth.signInWithPassword({
    email: els.emailInput.value.trim(),
    password: els.passwordInput.value,
  });

  if (error) {
    const message = error.message?.includes("Invalid login credentials")
      ? "Invalid login credentials. This must be a WashDesk Supabase Auth user, not your Supabase dashboard or GitHub login."
      : error.message || "Sign in failed.";
    setStatus(message, true);
    return;
  }

  await loadDashboard();
});

els.magicLinkButton.addEventListener("click", async () => {
  const email = els.emailInput.value.trim();
  if (!email) {
    setStatus("Enter your admin email first.", true);
    els.emailInput.focus();
    return;
  }

  setStatus("Sending sign-in link...");
  const { error } = await client.auth.signInWithOtp({
    email,
    options: {
      emailRedirectTo: window.location.href,
      shouldCreateUser: true,
    },
  });

  if (error) {
    setStatus(error.message || "Could not send sign-in link.", true);
    return;
  }

  setStatus("Check your email for the WashDesk dashboard sign-in link.");
});

els.refreshButton.addEventListener("click", loadDashboard);

els.signOutButton.addEventListener("click", async () => {
  await client.auth.signOut();
  els.dashboard.hidden = true;
  els.refreshButton.hidden = true;
  els.signOutButton.hidden = true;
  els.loginPanel.hidden = false;
  setStatus("Signed out.");
});

client.auth.getSession().then(({ data }) => {
  if (data.session) {
    loadDashboard();
  }
});
