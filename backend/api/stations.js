import {
  fetchRadioBrowser,
  normalizeStation,
  parseStationsQuery,
  sendError,
  sendJson
} from './_radio-browser.js'

export default async function handler(request, response) {
  if (request.method !== 'GET') {
    return sendJson(response, 405, { error: 'Method not allowed' })
  }

  try {
    const { params, limit, offset } = parseStationsQuery(request.query)
    const stations = await fetchRadioBrowser('stations/search', params)
    const normalized = stations
      .filter((station) => station.name && (station.url_resolved || station.url))
      .map(normalizeStation)

    sendJson(response, 200, {
      stations: normalized,
      limit,
      offset,
      nextOffset: normalized.length === limit ? offset + limit : null
    })
  } catch (error) {
    sendError(response, error)
  }
}
