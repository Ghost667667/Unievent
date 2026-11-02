/**
 * UniEvent Cloud Functions
 *
 * 1. onNotificationCreated  – turns every users/{uid}/notifications doc into
 *                             an FCM push to that user's registered devices.
 * 2. seatRescueScheduler    – every 30 min: sends confirmation requests ~24h
 *                             before an event and releases unconfirmed seats
 *                             6h before, promoting waitlisted students.
 * 3. eventReminders         – every 30 min: 1-day and 1-hour reminders.
 * 4. onRegistrationCancelled – safety-net waitlist promotion when a
 *                             registration is cancelled by any path.
 * 5. markEndedEvents        – flips status to "ended" after endTime so the
 *                             report and feedback unlock automatically.
 *
 * Deploy:  cd functions && npm install && npm run build && firebase deploy --only functions
 */
import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

type Notification = {
  title: string;
  body: string;
  eventId?: string | null;
  type?: string;
};

async function pushToUser(uid: string, n: Notification): Promise<void> {
  const userSnap = await db.doc(`users/${uid}`).get();
  if (!userSnap.exists) return;
  const user = userSnap.data()!;
  if (user.notificationsEnabled === false) return;
  const tokens: string[] = Array.isArray(user.fcmTokens) ? user.fcmTokens : [];
  if (tokens.length === 0) return;

  const res = await messaging.sendEachForMulticast({
    tokens,
    notification: { title: n.title, body: n.body },
    data: {
      eventId: n.eventId ?? "",
      type: n.type ?? "general",
      click_action: "FLUTTER_NOTIFICATION_CLICK",
    },
    android: { priority: "high", notification: { channelId: "unievent_default" } },
    apns: { payload: { aps: { sound: "default", badge: 1 } } },
  });

  // Prune dead tokens.
  const stale: string[] = [];
  res.responses.forEach((r, i) => {
    const code = r.error?.code ?? "";
    if (code.includes("registration-token-not-registered") || code.includes("invalid-argument")) {
      stale.push(tokens[i]);
    }
  });
  if (stale.length > 0) {
    await userSnap.ref.update({ fcmTokens: admin.firestore.FieldValue.arrayRemove(...stale) });
  }
}

async function notifyMany(uids: string[], n: Notification): Promise<void> {
  const unique = Array.from(new Set(uids));
  const batchSize = 400;
  for (let i = 0; i < unique.length; i += batchSize) {
    const batch = db.batch();
    for (const uid of unique.slice(i, i + batchSize)) {
      batch.set(db.collection(`users/${uid}/notifications`).doc(), {
        ...n,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

// ───────────────────── 1. In-app notification → FCM ─────────────────────
export const onNotificationCreated = onDocumentCreated(
  "users/{uid}/notifications/{nid}",
  async (event) => {
    const data = event.data?.data() as Notification | undefined;
    if (!data) return;
    try {
      await pushToUser(event.params.uid, data);
    } catch (e) {
      logger.warn("Push failed", { uid: event.params.uid, error: String(e) });
    }
  },
);

// ───────────────────── 2. Seat Rescue ─────────────────────
export const seatRescueScheduler = onSchedule(
  { schedule: "every 30 minutes", timeZone: "Asia/Kuala_Lumpur" },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const horizon = admin.firestore.Timestamp.fromMillis(now.toMillis() + 48 * 3600 * 1000);
    const events = await db
      .collection("events")
      .where("startTime", ">", now)
      .where("startTime", "<", horizon)
      .get();

    for (const doc of events.docs) {
      const e = doc.data();
      if (e.status === "cancelled") continue;
      const start: admin.firestore.Timestamp = e.startTime;
      const hoursBefore = e.seatRescueHoursBefore ?? 24;
      const deadlineHours = e.seatRescueDeadlineHours ?? 6;
      const sendAt = start.toMillis() - hoursBefore * 3600 * 1000;
      const releaseAt = start.toMillis() - deadlineHours * 3600 * 1000;

      // Step 1: send confirmation requests.
      if (!e.seatRescueSentAt && now.toMillis() >= sendAt) {
        const regs = await db
          .collection("registrations")
          .where("eventId", "==", doc.id)
          .where("status", "==", "registered")
          .get();
        const targets = regs.docs.filter((r) => !r.data().confirmed);
        const batch = db.batch();
        for (const r of targets) {
          batch.update(r.ref, { confirmationRequestedAt: admin.firestore.FieldValue.serverTimestamp() });
        }
        batch.update(doc.ref, { seatRescueSentAt: admin.firestore.FieldValue.serverTimestamp() });
        await batch.commit();
        await notifyMany(
          targets.map((r) => r.data().studentId),
          {
            title: `Still coming to ${e.title}?`,
            body: `Please confirm your attendance in My Events. Unconfirmed seats are released to the waitlist ${deadlineHours}h before the event.`,
            eventId: doc.id,
            type: "seat_rescue",
          },
        );
        logger.info("Seat Rescue requests sent", { event: doc.id, count: targets.length });
      }

      // Step 2: release unconfirmed seats and promote the waitlist.
      if (e.seatRescueSentAt && !e.seatRescueReleasedAt && now.toMillis() >= releaseAt) {
        const regs = await db.collection("registrations").where("eventId", "==", doc.id).get();
        const unconfirmed = regs.docs.filter(
          (r) => r.data().status === "registered" && !r.data().confirmed && r.data().confirmationRequestedAt,
        );
        const waitlisted = regs.docs
          .filter((r) => r.data().status === "waitlisted")
          .sort((a, b) => (a.data().createdAt?.toMillis() ?? 0) - (b.data().createdAt?.toMillis() ?? 0));

        const freed = unconfirmed.length;
        const free = Math.max(0, e.capacity - (e.registeredCount - freed));
        const promoted = waitlisted.slice(0, Math.min(free, waitlisted.length));

        const batch = db.batch();
        for (const r of unconfirmed) {
          batch.update(r.ref, {
            status: "cancelled",
            cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
            cancelledReason: "seat_rescue_unconfirmed",
          });
        }
        for (const r of promoted) {
          batch.update(r.ref, {
            status: "registered",
            waitlistPosition: null,
            promotedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        batch.update(doc.ref, {
          registeredCount: admin.firestore.FieldValue.increment(-freed + promoted.length),
          waitlistCount: admin.firestore.FieldValue.increment(-promoted.length),
          seatRescueReleasedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await batch.commit();

        await notifyMany(unconfirmed.map((r) => r.data().studentId), {
          title: `Your seat for ${e.title} was released`,
          body: "You did not confirm attendance in time, so your seat went to a waitlisted student.",
          eventId: doc.id,
          type: "seat_rescue",
        });
        await notifyMany(promoted.map((r) => r.data().studentId), {
          title: "A seat opened up! 🎉",
          body: `You are now registered for ${e.title}. Your QR ticket is ready in My Events.`,
          eventId: doc.id,
          type: "waitlist",
        });
        logger.info("Seat Rescue release", { event: doc.id, released: freed, promoted: promoted.length });
      }
    }
  },
);

// ───────────────────── 3. Reminders (1 day / 1 hour) ─────────────────────
export const eventReminders = onSchedule(
  { schedule: "every 30 minutes", timeZone: "Asia/Kuala_Lumpur" },
  async () => {
    const now = Date.now();
    const windows: Array<{ key: string; ms: number; label: string; pref: string }> = [
      { key: "reminder1dSentAt", ms: 24 * 3600 * 1000, label: "tomorrow", pref: "reminderOneDay" },
      { key: "reminder1hSentAt", ms: 1 * 3600 * 1000, label: "in 1 hour", pref: "reminderOneHour" },
    ];
    const upcoming = await db
      .collection("events")
      .where("startTime", ">", admin.firestore.Timestamp.now())
      .where("startTime", "<", admin.firestore.Timestamp.fromMillis(now + 25 * 3600 * 1000))
      .get();

    for (const doc of upcoming.docs) {
      const e = doc.data();
      if (e.status === "cancelled") continue;
      const start = (e.startTime as admin.firestore.Timestamp).toMillis();
      for (const w of windows) {
        if (e[w.key]) continue;
        if (start - now > w.ms) continue; // not yet in window
        const regs = await db
          .collection("registrations")
          .where("eventId", "==", doc.id)
          .where("status", "==", "registered")
          .get();
        const uids: string[] = [];
        for (const r of regs.docs) {
          const u = await db.doc(`users/${r.data().studentId}`).get();
          if (u.exists && u.data()![w.pref] !== false) uids.push(r.data().studentId);
        }
        await notifyMany(uids, {
          title: `${e.title} starts ${w.label}`,
          body: `${e.venue}. Have your QR ticket ready in My Events.`,
          eventId: doc.id,
          type: "reminder",
        });
        await doc.ref.update({ [w.key]: admin.firestore.FieldValue.serverTimestamp() });
      }
    }
  },
);

// ───────────────────── 4. Waitlist safety net ─────────────────────
export const onRegistrationCancelled = onDocumentUpdated("registrations/{regId}", async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;
  if (before.status !== "registered" || after.status !== "cancelled") return;
  if (after.cancelledReason === "seat_rescue_unconfirmed") return; // handled above

  const eventRef = db.doc(`events/${after.eventId}`);
  await db.runTransaction(async (tx) => {
    const eSnap = await tx.get(eventRef);
    if (!eSnap.exists) return;
    const e = eSnap.data()!;
    if (e.registeredCount >= e.capacity) return; // no free seat (client already promoted)
    const next = await tx.get(
      db
        .collection("registrations")
        .where("eventId", "==", after.eventId)
        .where("status", "==", "waitlisted")
        .orderBy("createdAt")
        .limit(1),
    );
    if (next.empty) return;
    const cand = next.docs[0];
    tx.update(cand.ref, {
      status: "registered",
      waitlistPosition: null,
      promotedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(eventRef, {
      registeredCount: admin.firestore.FieldValue.increment(1),
      waitlistCount: admin.firestore.FieldValue.increment(-1),
    });
    await notifyMany([cand.data().studentId], {
      title: "A seat opened up! 🎉",
      body: `You are now registered for ${e.title}.`,
      eventId: after.eventId,
      type: "waitlist",
    });
  });
});

// ───────────────────── 5. Auto-end events ─────────────────────
export const markEndedEvents = onSchedule(
  { schedule: "every 60 minutes", timeZone: "Asia/Kuala_Lumpur" },
  async () => {
    const ended = await db
      .collection("events")
      .where("endTime", "<", admin.firestore.Timestamp.now())
      .where("status", "in", ["upcoming", "check_in_open", "live", "delayed"])
      .get();
    const batch = db.batch();
    for (const d of ended.docs) batch.update(d.ref, { status: "ended" });
    if (!ended.empty) await batch.commit();

    // Prompt attendees for feedback.
    for (const d of ended.docs) {
      const regs = await db
        .collection("registrations")
        .where("eventId", "==", d.id)
        .where("status", "==", "attended")
        .get();
      await notifyMany(regs.docs.map((r) => r.data().studentId), {
        title: `How was ${d.data().title}?`,
        body: "Rate the event and the vendors you ordered from — it takes 10 seconds.",
        eventId: d.id,
        type: "feedback",
      });
    }
  },
);
