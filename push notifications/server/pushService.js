const webpush = require('web-push');
const Subscription = require('./Subscription');

webpush.setVapidDetails(
  process.env.VAPID_SUBJECT,
  process.env.VAPID_PUBLIC_KEY,
  process.env.VAPID_PRIVATE_KEY
);

async function saveSubscription(sub, userId = null) {
  return Subscription.findOneAndUpdate(
    { endpoint: sub.endpoint },
    { endpoint: sub.endpoint, keys: sub.keys, userId },
    { upsert: true, new: true }
  );
}

async function removeSubscription(endpoint) {
  return Subscription.deleteOne({ endpoint });
}

async function sendToSubscription(doc, payload) {
  try {
    await webpush.sendNotification(
      { endpoint: doc.endpoint, keys: doc.keys },
      JSON.stringify(payload)
    );
    return true;
  } catch (err) {
    // 404/410 = subscription expired or revoked, so clean it up
    if (err.statusCode === 404 || err.statusCode === 410) {
      await Subscription.deleteOne({ _id: doc._id });
    } else {
      console.error('Push failed:', err.statusCode, err.body);
    }
    return false;
  }
}

async function sendMany(subs, payload) {
  const results = await Promise.all(subs.map((s) => sendToSubscription(s, payload)));
  return { sent: results.filter(Boolean).length, total: subs.length };
}

// payload: { title, body, icon?, url?, tag? }
const sendToUser = async (userId, payload) =>
  sendMany(await Subscription.find({ userId }), payload);

const broadcast = async (payload) =>
  sendMany(await Subscription.find({}), payload);

module.exports = { saveSubscription, removeSubscription, sendToUser, broadcast };