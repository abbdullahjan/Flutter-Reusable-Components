const express = require('express');
const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp({
  credential: applicationDefault(),
});

const app = express();
const tokensByUser = new Map();

app.use(express.json({ limit: '1mb' }));

function removeToken(token) {
  for (const [userId, tokens] of tokensByUser) {
    tokens.delete(token);
    if (tokens.size === 0) tokensByUser.delete(userId);
  }
}

async function sendToUser(userId, { title, body, data = {} }) {
  const tokens = [...(tokensByUser.get(userId) ?? [])];
  if (tokens.length === 0) {
    return { sent: 0, failed: 0, note: 'no tokens for user' };
  }

  let sent = 0;
  let failed = 0;
  for (let offset = 0; offset < tokens.length; offset += 500) {
    const batch = tokens.slice(offset, offset + 500);
    const result = await getMessaging().sendEachForMulticast({
      tokens: batch,
      notification: { title, body },
      data,
      android: { priority: 'high' },
    });

    sent += result.successCount;
    failed += result.failureCount;
    result.responses.forEach((response, index) => {
      const code = response.error?.code;
      if (
        !response.success &&
        (code === 'messaging/registration-token-not-registered' ||
          code === 'messaging/invalid-registration-token')
      ) {
        removeToken(batch[index]);
      } else if (!response.success) {
        console.error('FCM send failed:', code ?? response.error?.message);
      }
    });
  }

  return { sent, failed };
}

app.post('/api/push/register', (req, res) => {
  const { userId, token } = req.body ?? {};
  if (
    typeof userId !== 'string' ||
    userId.trim().length === 0 ||
    typeof token !== 'string' ||
    token.trim().length === 0
  ) {
    return res.status(400).json({ error: 'userId and token are required strings' });
  }

  if (!tokensByUser.has(userId)) tokensByUser.set(userId, new Set());
  tokensByUser.get(userId).add(token);
  console.log(`Registered token for ${userId}`);
  return res.status(201).json({ ok: true });
});

app.post('/api/push/send', async (req, res, next) => {
  const { userId, title, body, data = {}, delay = 0 } = req.body ?? {};
  if (
    typeof userId !== 'string' ||
    userId.trim().length === 0 ||
    typeof title !== 'string' ||
    title.trim().length === 0 ||
    typeof body !== 'string' ||
    body.trim().length === 0
  ) {
    return res.status(400).json({
      error: 'userId, title, and body are required non-empty strings',
    });
  }
  if (
    typeof delay !== 'number' ||
    !Number.isInteger(delay) ||
    delay < 0 ||
    delay > 300000
  ) {
    return res.status(400).json({ error: 'delay must be an integer from 0 to 300000' });
  }
  if (
    data === null ||
    typeof data !== 'object' ||
    Array.isArray(data) ||
    Object.values(data).some((value) => typeof value !== 'string')
  ) {
    return res.status(400).json({ error: 'data must contain only string values' });
  }

  const payload = { title, body, data };
  if (delay > 0) {
    const timer = setTimeout(() => {
      sendToUser(userId, payload).catch((error) => {
        console.error('Scheduled FCM send failed:', error);
      });
    }, delay);
    timer.unref();
    return res.status(202).json({ scheduled: true, inMs: delay });
  }

  try {
    return res.json(await sendToUser(userId, payload));
  } catch (error) {
    return next(error);
  }
});

app.use((error, req, res, next) => {
  console.error('Request failed:', error);
  if (res.headersSent) return next(error);
  return res.status(500).json({ error: 'Push request failed' });
});

if (require.main === module) {
  const port = Number(process.env.PORT ?? 3000);
  app.listen(port, '0.0.0.0', () => {
    console.log(`FCM test server listening on http://0.0.0.0:${port}`);
  });
}

module.exports = { app, sendToUser };
