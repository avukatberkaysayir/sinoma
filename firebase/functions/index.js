const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

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
