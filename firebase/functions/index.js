const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// ---------------------------------------------------------------------------
// ADIM 11: AI Credit Management
// ---------------------------------------------------------------------------

exports.grantAiCredits = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");

  const { amount } = request.data;
  if (!amount || amount <= 0 || amount > 50) {
    throw new HttpsError("invalid-argument", "Invalid credit amount.");
  }

  const uid = request.auth.uid;
  const userRef = db.collection("users").doc(uid);
  const userSnap = await userRef.get();
  if (!userSnap.exists) throw new HttpsError("not-found", "User not found.");

  const currentCredits = userSnap.data().aiCredits ?? 0;
  const MAX_CREDITS = 50;
  const newCredits = Math.min(currentCredits + amount, MAX_CREDITS);

  await userRef.update({ aiCredits: newCredits });
  return { aiCredits: newCredits };
});

exports.decrementAiCredits = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");

  const uid = request.auth.uid;
  const userRef = db.collection("users").doc(uid);

  const result = await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new HttpsError("not-found", "User not found.");

    const credits = snap.data().aiCredits ?? 0;
    if (credits <= 0) throw new HttpsError("resource-exhausted", "No AI credits remaining.");

    tx.update(userRef, { aiCredits: FieldValue.increment(-1) });
    return { aiCredits: credits - 1 };
  });

  return result;
});

// Runs daily at midnight UTC — resets free users to 5 credits.
exports.refreshDailyCredits = onSchedule("0 0 * * *", async () => {
  const snapshot = await db
    .collection("users")
    .where("isPremium", "==", false)
    .get();

  const DAILY_FREE_CREDITS = 5;
  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.update(doc.ref, { aiCredits: DAILY_FREE_CREDITS });
  });
  await batch.commit();
  console.log(`Refreshed credits for ${snapshot.size} free users.`);
});

// ---------------------------------------------------------------------------
// ADIM 11: Leaderboard Aggregation (every 30 minutes)
// ---------------------------------------------------------------------------

exports.aggregateLeaderboard = onSchedule("*/30 * * * *", async () => {
  const snapshot = await db
    .collection("users")
    .orderBy("stats.totalScore", "desc")
    .limit(50)
    .get();

  const topUsers = snapshot.docs.map((doc, index) => ({
    rank: index + 1,
    uid: doc.id,
    displayName: doc.data().displayName,
    photoUrl: doc.data().photoUrl,
    hskLevel: doc.data().hskLevel,
    totalScore: doc.data().stats?.totalScore ?? 0,
  }));

  await db.collection("leaderboard").doc("global").set({
    updatedAt: new Date(),
    topUsers,
  });
  console.log(`Leaderboard updated with ${topUsers.length} users.`);
});

// ---------------------------------------------------------------------------
// ADIM 11: GDPR — Delete User Data
// ---------------------------------------------------------------------------

exports.deleteUserData = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");

  const uid = request.auth.uid;
  const batch = db.batch();

  // Delete user document
  batch.delete(db.collection("users").doc(uid));

  // Delete user's posts
  const posts = await db.collection("posts").where("authorId", "==", uid).get();
  posts.docs.forEach((doc) => batch.delete(doc.ref));

  await batch.commit();
  console.log(`Deleted all data for user ${uid}.`);
  return { success: true };
});

// ---------------------------------------------------------------------------
// ADIM 11: GDPR — Export User Data
// ---------------------------------------------------------------------------

exports.exportUserData = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");

  const uid = request.auth.uid;

  const [userSnap, postsSnap] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("posts").where("authorId", "==", uid).get(),
  ]);

  const exportData = {
    profile: userSnap.data() ?? {},
    posts: postsSnap.docs.map((d) => d.data()),
    exportedAt: new Date().toISOString(),
  };

  // In production: write to Firebase Storage and return a signed URL.
  // For now, return inline (suitable for small datasets).
  return { data: exportData };
});

// ---------------------------------------------------------------------------
// ADIM 12: FCM — Match created → notify both players
// ---------------------------------------------------------------------------

exports.onMatchCreated = onDocumentCreated("matches/{matchId}", async (event) => {
  const match = event.data.data();
  const { player1Uid, player2Uid, hskLevel, matchId } = match;

  const [snap1, snap2] = await Promise.all([
    db.collection("users").doc(player1Uid).get(),
    db.collection("users").doc(player2Uid).get(),
  ]);

  const token1 = snap1.data()?.fcmToken;
  const token2 = snap2.data()?.fcmToken;
  const name1 = snap1.data()?.displayName ?? "Player";
  const name2 = snap2.data()?.displayName ?? "Player";

  const messages = [];
  if (token1) {
    messages.push({
      token: token1,
      notification: { title: "Match Found!", body: `You matched with ${name2} at HSK ${hskLevel}` },
      data: { route: "/games/duel", matchId },
    });
  }
  if (token2) {
    messages.push({
      token: token2,
      notification: { title: "Match Found!", body: `You matched with ${name1} at HSK ${hskLevel}` },
      data: { route: "/games/duel", matchId },
    });
  }

  if (messages.length > 0) {
    await getMessaging().sendEach(messages);
    console.log(`Match ${matchId}: sent ${messages.length} FCM notifications.`);
  }
});

// ---------------------------------------------------------------------------
// ADIM 12: FCM — Game request → notify challenged player
// ---------------------------------------------------------------------------

exports.onGameRequestCreated = onDocumentCreated("gameRequests/{requestId}", async (event) => {
  const req = event.data.data();
  const { fromUid, toUid, hskLevel } = req;

  const [fromSnap, toSnap] = await Promise.all([
    db.collection("users").doc(fromUid).get(),
    db.collection("users").doc(toUid).get(),
  ]);

  const token = toSnap.data()?.fcmToken;
  if (!token) return;

  const challenger = fromSnap.data()?.displayName ?? "Someone";
  await getMessaging().send({
    token,
    notification: {
      title: "Game Challenge!",
      body: `${challenger} challenged you to a Mandarin Duel (HSK ${hskLevel})`,
    },
    data: { route: "/social" },
  });
  console.log(`Game request: notified ${toUid} about challenge from ${fromUid}.`);
});

// ---------------------------------------------------------------------------
// ADIM 12: FCM — Daily streak reminder (18:00 UTC)
// ---------------------------------------------------------------------------

exports.sendStreakReminder = onSchedule("0 18 * * *", async () => {
  const snapshot = await db
    .collection("users")
    .where("stats.currentStreak", ">", 0)
    .get();

  if (snapshot.empty) return;

  const messages = snapshot.docs
    .map((doc) => {
      const token = doc.data().fcmToken;
      const streak = doc.data().stats?.currentStreak ?? 0;
      if (!token) return null;
      return {
        token,
        notification: {
          title: "Don't break your streak! 🔥",
          body: `You have a ${streak}-day streak. Watch a video today to keep it going.`,
        },
        data: { route: "/home" },
      };
    })
    .filter(Boolean);

  if (messages.length === 0) return;

  const batchSize = 500;
  for (let i = 0; i < messages.length; i += batchSize) {
    await getMessaging().sendEach(messages.slice(i, i + batchSize));
  }
  console.log(`Streak reminders sent to ${messages.length} users.`);
});

// ---------------------------------------------------------------------------
// ADIM 11: Matchmaking
// ---------------------------------------------------------------------------

// Finds an opponent within ±1 HSK level. If no one is waiting, adds the
// caller to matchQueue. Returns { matched, matchId?, opponentId?, hskLevel? }.
exports.matchGame = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");

  const uid = request.auth.uid;
  const { hskLevel } = request.data;

  if (!hskLevel || hskLevel < 1 || hskLevel > 6) {
    throw new HttpsError("invalid-argument", "hskLevel must be 1–6.");
  }

  const minLevel = Math.max(1, hskLevel - 1);
  const maxLevel = Math.min(6, hskLevel + 1);

  // Look for the oldest waiting opponent (±1 HSK, not self)
  const queueSnap = await db
    .collection("matchQueue")
    .where("hskLevel", ">=", minLevel)
    .where("hskLevel", "<=", maxLevel)
    .orderBy("hskLevel")
    .orderBy("joinedAt")
    .limit(10)
    .get();

  const opponent = queueSnap.docs.find((doc) => doc.id !== uid);

  if (opponent) {
    const matchId = db.collection("matches").doc().id;
    const matchRef = db.collection("matches").doc(matchId);
    const opponentData = opponent.data();

    const resolvedHskLevel = Math.round((hskLevel + opponentData.hskLevel) / 2);

    const batch = db.batch();
    batch.set(matchRef, {
      matchId,
      player1Uid: uid,
      player2Uid: opponent.id,
      hskLevel: resolvedHskLevel,
      status: "waiting",
      createdAt: Timestamp.now(),
    });
    batch.delete(opponent.ref);
    // Also remove caller if they were somehow already in queue
    batch.delete(db.collection("matchQueue").doc(uid));
    await batch.commit();

    return { matched: true, matchId, opponentId: opponent.id, hskLevel: resolvedHskLevel };
  }

  // No opponent found — join the queue (upsert to handle re-queuing)
  await db.collection("matchQueue").doc(uid).set({
    uid,
    hskLevel,
    joinedAt: Timestamp.now(),
  });

  return { matched: false };
});

// ---------------------------------------------------------------------------
// ADIM 21: IAP Receipt Verification
// ---------------------------------------------------------------------------

// Verifies a Google Play subscription purchase token server-side and sets
// isPremium=true on the user document. Uses the Google Play Developer API.
// The service account needs "Financial data viewer" role in Play Console.
exports.verifyPurchase = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");

  const { productId, purchaseToken, source } = request.data;
  if (!productId || !purchaseToken) {
    throw new HttpsError("invalid-argument", "productId and purchaseToken are required.");
  }

  const VALID_PRODUCTS = [
    "mandarin_academy_premium_monthly",
    "mandarin_academy_premium_annual",
  ];
  if (!VALID_PRODUCTS.includes(productId)) {
    throw new HttpsError("invalid-argument", "Unknown productId.");
  }

  const uid = request.auth.uid;

  // For Google Play (source == "google_play"), verify via Play Developer API.
  // For App Store (source == "app_store"), verification logic would go here.
  if (source === "google_play") {
    const { google } = require("googleapis");
    const auth = new google.auth.GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    const authClient = await auth.getClient();
    const androidPublisher = google.androidpublisher({ version: "v3", auth: authClient });

    const packageName = "app.mandarinacademy";
    let verificationResult;
    try {
      verificationResult = await androidPublisher.purchases.subscriptions.get({
        packageName,
        subscriptionId: productId,
        token: purchaseToken,
      });
    } catch (e) {
      console.error("Play API error:", e.message);
      throw new HttpsError("internal", "Could not verify purchase with Google Play.");
    }

    const subscription = verificationResult.data;
    // paymentState 1 = payment received, 2 = free trial
    const isPaid = subscription.paymentState === 1 || subscription.paymentState === 2;
    const isActive = subscription.cancelReason === undefined ||
      new Date(parseInt(subscription.expiryTimeMillis, 10)) > new Date();

    if (!isPaid || !isActive) {
      throw new HttpsError("failed-precondition", "Subscription not active.");
    }
  }
  // For restored/offline verification, trust the completed purchase signal
  // (In production, add App Store receipt validation here for iOS.)

  await db.collection("users").doc(uid).update({ isPremium: true });
  console.log(`verifyPurchase: set isPremium=true for ${uid} (${productId})`);
  return { success: true };
});

// ---------------------------------------------------------------------------
// ADIM 11: HSK Level Advancement
// ---------------------------------------------------------------------------

// Validates prerequisites then advances a user's HSK level by 1.
// Client sends { newLevel } — CF verifies currentLevel + 1 == newLevel.
// Prerequisites: stats.videosWatched >= 20 AND learnedWords.length >= 50.
exports.updateHskLevel = onCall(async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Sign in required.");

  const uid = request.auth.uid;
  const { newLevel } = request.data;

  if (!newLevel || newLevel < 2 || newLevel > 6) {
    throw new HttpsError("invalid-argument", "newLevel must be 2–6.");
  }

  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    if (!snap.exists) throw new HttpsError("not-found", "User not found.");

    const data = snap.data();
    const currentLevel = data.hskLevel ?? 1;

    if (newLevel !== currentLevel + 1) {
      throw new HttpsError(
        "failed-precondition",
        `Can only advance one level at a time. Current: ${currentLevel}.`
      );
    }

    const videosWatched = data.stats?.videosWatched ?? 0;
    const learnedCount = (data.learnedWords ?? []).length;
    const VIDEOS_REQUIRED = 20;
    const WORDS_REQUIRED = 50;

    if (videosWatched < VIDEOS_REQUIRED) {
      throw new HttpsError(
        "failed-precondition",
        `Need ${VIDEOS_REQUIRED} videos watched (have ${videosWatched}).`
      );
    }
    if (learnedCount < WORDS_REQUIRED) {
      throw new HttpsError(
        "failed-precondition",
        `Need ${WORDS_REQUIRED} learned words (have ${learnedCount}).`
      );
    }

    tx.update(userRef, { hskLevel: newLevel });
  });

  return { hskLevel: newLevel };
});
