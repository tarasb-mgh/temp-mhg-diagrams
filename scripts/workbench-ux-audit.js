#!/usr/bin/env node
/* eslint-disable no-console */
const fs = require("fs/promises");
const path = require("path");

async function ensurePlaywright() {
  try {
    return require("playwright");
  } catch (_error) {
    console.error(
      "Playwright is not installed. Run: npm i -D playwright && npx playwright install chromium",
    );
    process.exit(1);
  }
}

function nowStamp() {
  const d = new Date();
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  const hh = String(d.getHours()).padStart(2, "0");
  const mi = String(d.getMinutes()).padStart(2, "0");
  const ss = String(d.getSeconds()).padStart(2, "0");
  return `${yyyy}${mm}${dd}-${hh}${mi}${ss}`;
}

function pickOtp(messages) {
  for (let i = messages.length - 1; i >= 0; i -= 1) {
    const m = messages[i];
    if (!/otp|code|one.?time/i.test(m.text)) continue;
    const found = m.text.match(/\b(\d{4,8})\b/);
    if (found) return found[1];
  }
  return null;
}

async function clickFirst(page, labels) {
  for (const label of labels) {
    const candidate = page.getByRole("button", { name: label }).first();
    if (await candidate.isVisible().catch(() => false)) {
      await candidate.click({ timeout: 5000 });
      return true;
    }
  }
  return false;
}

async function clickNavItem(page, labels) {
  for (const label of labels) {
    const regex = new RegExp(label, "i");
    const byRole = page.getByRole("link", { name: regex }).first();
    if (await byRole.isVisible().catch(() => false)) {
      await byRole.click({ timeout: 5000 });
      return label;
    }
    const byText = page.getByText(regex).first();
    if (await byText.isVisible().catch(() => false)) {
      await byText.click({ timeout: 5000 });
      return label;
    }
  }
  return null;
}

async function maybeFillOtp(page, otp, artifacts) {
  if (!otp) return false;
  const singleInput = page
    .locator('input[type="text"], input[type="tel"], input[inputmode="numeric"]')
    .filter({ hasNotText: "" })
    .first();

  const otpInputs = page.locator(
    'input[autocomplete="one-time-code"], input[name*="otp" i], input[id*="otp" i], input[name*="code" i], input[id*="code" i]',
  );
  const count = await otpInputs.count();
  if (count > 0) {
    try {
      await otpInputs.first().fill(otp, { timeout: 5000 });
      artifacts.actions.push(`filled_otp_named_input:${otp}`);
      return true;
    } catch (_e) {}
  }

  const multiBoxes = page.locator('input[maxlength="1"]');
  const boxesCount = await multiBoxes.count();
  if (boxesCount >= 4) {
    const digits = otp.split("");
    for (let i = 0; i < Math.min(boxesCount, digits.length); i += 1) {
      await multiBoxes.nth(i).fill(digits[i]);
    }
    artifacts.actions.push(`filled_otp_multibox:${otp}`);
    return true;
  }

  if (await singleInput.isVisible().catch(() => false)) {
    try {
      await singleInput.fill(otp, { timeout: 5000 });
      artifacts.actions.push(`filled_otp_generic_input:${otp}`);
      return true;
    } catch (_e) {}
  }

  return false;
}

async function locateEmailInput(page) {
  const selectors = [
    'input[type="email"]',
    'input[name*="email" i]',
    'input[id*="email" i]',
    'input[placeholder*="email" i]',
    'input[autocomplete="email"]',
    "input",
  ];
  for (const s of selectors) {
    const el = page.locator(s).first();
    if (await el.isVisible().catch(() => false)) return el;
  }
  return null;
}

async function enterLoginScreen(page, artifacts) {
  const signInTriggers = [
    /sign in to start/i,
    /sign in/i,
    /log in/i,
    /continue/i,
    /start/i,
  ];
  for (const trigger of signInTriggers) {
    const button = page.getByRole("button", { name: trigger }).first();
    if (await button.isVisible().catch(() => false)) {
      await button.click({ timeout: 5000 });
      artifacts.actions.push(`clicked_signin_trigger:${trigger}`);
      await page.waitForTimeout(1500);
      return true;
    }
  }
  return false;
}

async function attemptGoogleLogin(page, context, email, artifacts, shotsOut) {
  const frames = [page.mainFrame(), ...page.frames()];
  let googleBtn = null;
  let source = page;
  for (const frame of frames) {
    const candidates = [
      frame.getByRole("button", { name: /google/i }).first(),
      frame.getByText(/google/i).first(),
      frame.locator('[aria-label*="google" i]').first(),
    ];
    for (const candidate of candidates) {
      if (await candidate.isVisible().catch(() => false)) {
        googleBtn = candidate;
        source = frame.page ? frame.page() : page;
        break;
      }
    }
    if (googleBtn) break;
  }
  if (!googleBtn) return { attempted: false };

  let authPage = page;
  const popupPromise = context.waitForEvent("page", { timeout: 6000 }).catch(() => null);
  await googleBtn.click({ timeout: 5000 });
  const popup = await popupPromise;
  if (popup) {
    authPage = popup;
    await authPage.waitForLoadState("domcontentloaded", { timeout: 15000 }).catch(() => {});
  } else {
    await source.waitForLoadState("domcontentloaded", { timeout: 15000 }).catch(() => {});
  }

  artifacts.actions.push("clicked_google_signin");
  const scopePage = authPage || page;
  const shot = path.join(shotsOut, `${email.replace(/[@.]/g, "_")}-01c-google-auth.png`);
  await scopePage.screenshot({ path: shot, fullPage: true }).catch(() => {});
  artifacts.screenshots.push(shot);

  const googleEmail = scopePage.locator('input[type="email"]').first();
  if (!(await googleEmail.isVisible().catch(() => false))) {
    return { attempted: true, status: "blocked", reason: "Google auth page did not show email input." };
  }

  await googleEmail.fill(email);
  await scopePage.keyboard.press("Enter").catch(() => {});
  const nextBtn = scopePage.getByRole("button", { name: /next/i }).first();
  if (await nextBtn.isVisible().catch(() => false)) {
    await nextBtn.click().catch(() => {});
  }
  await scopePage.waitForTimeout(2500);
  const shotAfterSubmit = path.join(
    shotsOut,
    `${email.replace(/[@.]/g, "_")}-01d-google-after-submit.png`,
  );
  await scopePage.screenshot({ path: shotAfterSubmit, fullPage: true }).catch(() => {});
  artifacts.screenshots.push(shotAfterSubmit);

  const passwordInput = scopePage.locator('input[type="password"]').first();
  if (await passwordInput.isVisible().catch(() => false)) {
    return { attempted: true, status: "blocked", reason: "Google account accepted email but requires password." };
  }

  const body = ((await scopePage.textContent("body")) || "").toLowerCase();
  if (/couldn.?t find your google account|no account found|find your google account/.test(body)) {
    return { attempted: true, status: "failed", reason: "Google account not found for provided email." };
  }
  if (/try again|something went wrong|denied|blocked/.test(body)) {
    return { attempted: true, status: "blocked", reason: "Google auth interrupted or blocked." };
  }

  return { attempted: true, status: "blocked", reason: "Google auth flow started but did not return an app session." };
}

async function detectLoginSuccess(page) {
  const url = page.url();
  if (!/login|sign|auth|otp/i.test(url)) return true;

  const nav = page.locator("nav, [role='navigation'], aside");
  if (await nav.first().isVisible().catch(() => false)) return true;

  const userMenu = page
    .locator('[aria-label*="profile" i], [aria-label*="account" i], [data-testid*="avatar" i]')
    .first();
  return userMenu.isVisible().catch(() => false);
}

async function ensureLoginPage(page, targetUrl, artifacts) {
  const loginUrl = new URL("/login", targetUrl).toString();
  if (!/\/login/i.test(page.url())) {
    await page.goto(loginUrl, { waitUntil: "domcontentloaded", timeout: 30000 });
    await page.waitForTimeout(1200);
    artifacts.actions.push("navigated_to_login_page");
  }
}

async function waitForOtpFromConsole(artifacts, timeoutMs = 12000) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    const otp = pickOtp(artifacts.console);
    if (otp) return otp;
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  return null;
}

async function clickOtpPrimaryIfPresent(page, artifacts) {
  const clicked = await clickFirst(page, [/primary sign-in method/i, /otp/i, /email code/i]);
  if (clicked) {
    artifacts.actions.push("clicked_otp_primary_hint");
    await page.waitForTimeout(600);
  }
}

async function run() {
  const { chromium } = await ensurePlaywright();
  const targetUrl = process.env.TARGET_URL || "https://workbench.dev.mentalhelp.chat";
  const envEmails = process.env.AUDIT_EMAILS
    ? process.env.AUDIT_EMAILS.split(",").map((v) => v.trim()).filter(Boolean)
    : null;
  const delayBetweenAccountsMs = Number(process.env.AUDIT_DELAY_MS || 0);
  const emails = envEmails && envEmails.length > 0
    ? envEmails
    : [
        "e2e-group-admin@test.local",
        "e2e-moderator@test.local",
        "e2e-owner@test.local",
        "e2e-qa@test.local",
        "e2e-researcher@test.local",
      ];

  const stamp = nowStamp();
  const rootOut = path.resolve(process.cwd(), "artifacts", `workbench-ux-audit-${stamp}`);
  const shotsOut = path.join(rootOut, "screenshots");
  await fs.mkdir(shotsOut, { recursive: true });

  const browser = await chromium.launch({ headless: true });
  const results = [];

  for (const email of emails) {
    const context = await browser.newContext({ viewport: { width: 1440, height: 960 } });
    const page = await context.newPage();

    const artifacts = {
      account: email,
      status: "unknown",
      reason: "",
      screenshots: [],
      deepFlowLabel: null,
      console: [],
      network: [],
      actions: [],
      finalUrl: "",
    };

    page.on("console", (msg) => {
      const type = msg.type();
      const text = msg.text();
      artifacts.console.push({ type, text });
    });

    page.on("response", async (res) => {
      const status = res.status();
      if (status < 400) return;
      artifacts.network.push({
        status,
        method: res.request().method(),
        url: res.url(),
      });
    });

    try {
      await page.goto(targetUrl, { waitUntil: "domcontentloaded", timeout: 30000 });
      await page.waitForTimeout(1500);
      const landing = path.join(shotsOut, `${email.replace(/[@.]/g, "_")}-01-landing.png`);
      await page.screenshot({ path: landing, fullPage: true });
      artifacts.screenshots.push(landing);

      await ensureLoginPage(page, targetUrl, artifacts);
      await clickOtpPrimaryIfPresent(page, artifacts);

      let emailInput = await locateEmailInput(page);
      if (!emailInput) {
        const entered = await enterLoginScreen(page, artifacts);
        if (entered) {
          const loginScreen = path.join(
            shotsOut,
            `${email.replace(/[@.]/g, "_")}-01b-login-form.png`,
          );
          await page.screenshot({ path: loginScreen, fullPage: true });
          artifacts.screenshots.push(loginScreen);
          await clickOtpPrimaryIfPresent(page, artifacts);
          emailInput = await locateEmailInput(page);
        }
      }

      if (!emailInput) {
        artifacts.status = "blocked";
        const googleAttempt = await attemptGoogleLogin(
          page,
          context,
          email,
          artifacts,
          shotsOut,
        );
        if (googleAttempt.attempted) {
          artifacts.status = googleAttempt.status;
          artifacts.reason = googleAttempt.reason;
        } else {
          artifacts.reason = "No visible email input after opening sign-in flow.";
        }
        artifacts.finalUrl = page.url();
        results.push(artifacts);
        await context.close();
        continue;
      }

      await emailInput.fill(email);
      artifacts.actions.push("filled_email");
      const clickedSubmit = await clickFirst(page, [/continue/i, /sign in/i, /log in/i, /next/i, /send/i]);
      if (!clickedSubmit) {
        await emailInput.press("Enter");
        artifacts.actions.push("submitted_email_enter");
      } else {
        artifacts.actions.push("submitted_email_button");
      }

      await page.waitForTimeout(2500);
      let otp = await waitForOtpFromConsole(artifacts, 14000);

      if (otp) {
        const otpFilled = await maybeFillOtp(page, otp, artifacts);
        if (otpFilled) {
          const clickedVerify = await clickFirst(page, [/verify/i, /continue/i, /sign in/i, /log in/i, /next/i]);
          if (!clickedVerify) {
            await page.keyboard.press("Enter");
          }
          artifacts.actions.push("submitted_otp");
          await page.waitForTimeout(3500);
        }
      } else {
        artifacts.actions.push("otp_not_found_in_console");
      }

      const success = await detectLoginSuccess(page);
      artifacts.finalUrl = page.url();
      if (!success) {
        const lowerBody = ((await page.textContent("body")) || "").toLowerCase();
        if (/approval|pending|await/.test(lowerBody)) {
          artifacts.status = "blocked";
          artifacts.reason = "Awaiting approval or access grant.";
        } else if (/invalid|incorrect|expired|failed|error/.test(lowerBody)) {
          artifacts.status = "failed";
          artifacts.reason = "Login rejected or verification failed.";
        } else {
          artifacts.status = "failed";
          artifacts.reason = "Login did not reach authenticated area.";
        }
        results.push(artifacts);
        await context.close();
        continue;
      }

      artifacts.status = "succeeded";
      const sidebar = path.join(shotsOut, `${email.replace(/[@.]/g, "_")}-02-sidebar.png`);
      await page.screenshot({ path: sidebar, fullPage: true });
      artifacts.screenshots.push(sidebar);

      const deepFlowClicked = await clickNavItem(page, [
        "Survey Instances",
        "Surveys",
        "Group Management",
        "Groups",
        "Review",
        "Members",
      ]);
      if (deepFlowClicked) {
        artifacts.deepFlowLabel = deepFlowClicked;
        artifacts.actions.push(`opened_deep_flow:${deepFlowClicked}`);
        await page.waitForLoadState("domcontentloaded");
        await page.waitForTimeout(1500);

        const rowDetail = page.getByRole("button", { name: /details|view|open|edit/i }).first();
        if (await rowDetail.isVisible().catch(() => false)) {
          await rowDetail.click().catch(() => {});
          await page.waitForTimeout(1000);
        } else {
          const firstRow = page.locator("table tbody tr").first();
          if (await firstRow.isVisible().catch(() => false)) {
            await firstRow.click().catch(() => {});
            await page.waitForTimeout(1000);
          }
        }
      } else {
        artifacts.actions.push("no_deep_flow_menu_found");
      }

      const deep = path.join(shotsOut, `${email.replace(/[@.]/g, "_")}-03-deep-flow.png`);
      await page.screenshot({ path: deep, fullPage: true });
      artifacts.screenshots.push(deep);

      results.push(artifacts);
      await context.close();
      if (delayBetweenAccountsMs > 0 && email !== emails[emails.length - 1]) {
        await new Promise((resolve) => setTimeout(resolve, delayBetweenAccountsMs));
      }
    } catch (error) {
      artifacts.status = "failed";
      artifacts.reason = `Automation error: ${error.message}`;
      artifacts.finalUrl = page.url();
      results.push(artifacts);
      await context.close();
      if (delayBetweenAccountsMs > 0 && email !== emails[emails.length - 1]) {
        await new Promise((resolve) => setTimeout(resolve, delayBetweenAccountsMs));
      }
    }
  }

  await browser.close();

  const reportPath = path.join(rootOut, "results.json");
  await fs.writeFile(reportPath, JSON.stringify({ targetUrl, generatedAt: new Date().toISOString(), results }, null, 2));
  console.log(`UX audit complete. Results: ${reportPath}`);
}

run().catch((error) => {
  console.error(error);
  process.exit(1);
});
