self.addEventListener('push', (e) => {
  const d = e.data ? e.data.json() : {};
  e.waitUntil(
    self.registration.showNotification(d.title || 'Notification', {
      body: d.body,
      icon: d.icon || '/icon-192.png',
      tag: d.tag,
      data: { url: d.url || '/' },
    })
  );
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const url = e.notification.data.url;
  e.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const c of list) if (c.url.includes(url) && 'focus' in c) return c.focus();
      return clients.openWindow(url);
    })
  );
});