import { fetchRadioBrowser, sendError, sendJson } from './_radio-browser.js'

export default async function handler(request, response) {
  if (request.method !== 'GET') {
    return sendJson(response, 405, { error: 'Method not allowed' })
  }

  try {
    const stats = await fetchRadioBrowser('stats')
    sendJson(response, 200, { ok: true, stats })
  } catch (error) {
    sendError(response, error)
  }
}
