const DEFAULT_LIMIT = 50
const MAX_LIMIT = 100
const DEFAULT_ORDER = 'clickcount'
const FALLBACK_BASE_URL = 'https://de1.api.radio-browser.info'

let cachedBaseUrl

export async function resolveBaseUrl() {
  if (cachedBaseUrl) return cachedBaseUrl

  try {
    const response = await fetch(
      'https://all.api.radio-browser.info/json/servers',
      { headers: requestHeaders() }
    )
    if (!response.ok) throw new Error(`server resolver ${response.status}`)
    const servers = await response.json()
    const server = servers.find((item) => item && item.name)
    cachedBaseUrl = server ? `https://${server.name}` : FALLBACK_BASE_URL
  } catch {
    cachedBaseUrl = FALLBACK_BASE_URL
  }

  return cachedBaseUrl
}

export function requestHeaders() {
  return {
    'user-agent': process.env.RADIO_BROWSER_USER_AGENT || 'rdio-app/1.0'
  }
}

export function parseStationsQuery(query = {}) {
  const limit = clampNumber(query.limit, DEFAULT_LIMIT, 1, MAX_LIMIT)
  const offset = clampNumber(query.offset, 0, 0, 100000)
  const order = stringValue(query.order) || DEFAULT_ORDER
  const reverse = stringValue(query.reverse) ?? 'true'

  const params = new URLSearchParams({
    hidebroken: 'true',
    limit: String(limit),
    offset: String(offset),
    order,
    reverse
  })

  appendIfPresent(params, 'name', query.search || query.name)
  appendIfPresent(params, 'countrycode', uppercase(query.countrycode))
  appendIfPresent(params, 'country', query.country)
  appendIfPresent(params, 'language', query.language)
  appendIfPresent(params, 'tag', query.tag)
  appendIfPresent(params, 'codec', query.codec)

  return { params, limit, offset }
}

export async function fetchRadioBrowser(path, params = new URLSearchParams()) {
  const baseUrl = await resolveBaseUrl()
  const url = new URL(`/json/${path}`, baseUrl)
  url.search = params.toString()

  const response = await fetch(url, { headers: requestHeaders() })
  if (!response.ok) {
    throw new Error(`Radio Browser ${response.status} for ${url.pathname}`)
  }
  return response.json()
}

export function normalizeStation(station) {
  const streamURL = station.url_resolved || station.url
  const description = [
    station.country,
    station.state,
    station.language
  ].filter(Boolean).join(' - ')

  return {
    id: station.stationuuid,
    name: station.name,
    website: station.homepage || null,
    streamURL,
    imageURL: station.favicon || '',
    desc: description || 'Radio Browser',
    longDesc: station.tags || description || 'Radio Browser',
    country: station.country || '',
    countryCode: station.countrycode || '',
    language: station.language || '',
    tags: station.tags || '',
    codec: station.codec || '',
    bitrate: station.bitrate || 0,
    votes: station.votes || 0,
    clickCount: station.clickcount || 0
  }
}

export function sendJson(response, status, payload) {
  response.status(status)
  response.setHeader('content-type', 'application/json; charset=utf-8')
  response.setHeader('cache-control', 's-maxage=300, stale-while-revalidate=3600')
  response.json(payload)
}

export function sendError(response, error) {
  sendJson(response, 502, {
    error: error instanceof Error ? error.message : 'Radio Browser request failed'
  })
}

function appendIfPresent(params, key, value) {
  const normalized = stringValue(value)
  if (normalized) params.set(key, normalized)
}

function clampNumber(value, fallback, min, max) {
  const parsed = Number.parseInt(String(value ?? ''), 10)
  if (Number.isNaN(parsed)) return fallback
  return Math.min(Math.max(parsed, min), max)
}

function stringValue(value) {
  if (Array.isArray(value)) return value[0] ? String(value[0]) : undefined
  if (value === undefined || value === null) return undefined
  const text = String(value).trim()
  return text.length > 0 ? text : undefined
}

function uppercase(value) {
  return value ? String(value).toUpperCase() : value
}
