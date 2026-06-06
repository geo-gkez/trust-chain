const SUBGRAPH_URL = import.meta.env.VITE_SUBGRAPH_URL

export async function gql(query, variables = {}, { timeout = 15000 } = {}) {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeout)

  let res
  try {
    res = await fetch(SUBGRAPH_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ query, variables }),
      signal: controller.signal,
    })
  } catch (err) {
    throw new Error(
      err.name === 'AbortError'
        ? 'Subgraph request timed out.'
        : `Subgraph request failed: ${err.message}`,
    )
  } finally {
    clearTimeout(timer)
  }

  // Surface HTTP-level failures (rate limits, 5xx) with a clear message instead
  // of letting res.json() throw a cryptic parse error on a non-JSON body.
  if (!res.ok) throw new Error(`Subgraph error: HTTP ${res.status} ${res.statusText}`)

  const { data, errors } = await res.json()
  if (errors) throw new Error(errors[0].message)
  return data
}
