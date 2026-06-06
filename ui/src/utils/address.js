// Shorten an Ethereum address for display: 0x1234…cdef
export function shortAddress(addr) {
  if (!addr) return '—'
  return `${addr.slice(0, 6)}…${addr.slice(-4)}`
}
