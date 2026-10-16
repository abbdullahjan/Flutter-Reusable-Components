const router = require('express').Router();
const push = require('./pushService');

router.get('/vapid-public-key', (req, res) =>
  res.json({ key: process.env.VAPID_PUBLIC_KEY })
);

router.post('/subscribe', async (req, res) => {
  const { subscription, userId } = req.body;
  if (!subscription?.endpoint) return res.status(400).json({ error: 'Invalid subscription' });
  await push.saveSubscription(subscription, userId);
  res.status(201).json({ ok: true });
});

router.post('/unsubscribe', async (req, res) => {
  await push.removeSubscription(req.body.endpoint);
  res.json({ ok: true });
});

// Send to one user: { userId, title, body, url }
router.post('/send', async (req, res) => {
  const { userId, ...payload } = req.body;
  res.json(await push.sendToUser(userId, payload));
});

// Send to everyone: { title, body, url }
router.post('/broadcast', async (req, res) => {
  res.json(await push.broadcast(req.body));
});

module.exports = router;