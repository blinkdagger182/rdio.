import { fetchRadioBrowser, normalizeStation, sendError, sendJson } from './_radio-browser.js'

export default async function handler(request, response) {
  if (request.method !== 'GET') {
    return sendJson(response, 405, { error: 'Method not allowed' })
  }
  try {
    const limit = Math.min(50, Math.max(1, parseInt(request.query?.limit) || 20))
    const params = new URLSearchParams({
      hidebroken: 'true', order: 'votes', reverse: 'true', limit: String(limit)
    })
    const stations = await fetchRadioBrowser('stations/search', params)
    sendJson(response, 200, {
      stations: stations.filter(s => s.name && (s.url_resolved || s.url)).map(normalizeStation)
    })
  } catch (error) {
    sendError(response, error)
  }
}
