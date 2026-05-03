/**
 * Format a Date as a human-readable string.
 * @param {Date|null} d
 * @param {boolean} includeTime
 */
export function formatDate(d, includeTime = false) {
  if (!d) return '—'
  const opts = { day: '2-digit', month: 'short', year: 'numeric' }
  if (includeTime) Object.assign(opts, { hour: '2-digit', minute: '2-digit' })
  return d.toLocaleString('en-GB', opts)
}
