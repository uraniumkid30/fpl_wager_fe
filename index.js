// The Flutter web build used hash URLs ("/#/join/CODE", "/#/payments/callback?...").
// Links and redirects that still carry them are moved onto the path before the
// router reads the address.
if (typeof window !== 'undefined' && window.location && window.location.hash.startsWith('#/')) {
  const target = window.location.hash.slice(1);
  const [path, hashQuery] = target.split('?');
  const query = [window.location.search.replace(/^\?/, ''), hashQuery].filter(Boolean).join('&');
  window.history.replaceState(null, '', `${path}${query ? `?${query}` : ''}`);
}

require('expo-router/entry');
