import { fetchRadioBrowser, sendError, sendJson } from './_radio-browser.js'

export default async function handler(request, response) {
  if (request.method !== 'GET') {
    return sendJson(response, 405, { error: 'Method not allowed' })
  }

  try {
    const params = new URLSearchParams({
      hidebroken: 'true',
      order: 'stationcount',
      reverse: 'true'
    })
    const countries = await fetchRadioBrowser('countries', params)
    sendJson(response, 200, { countries })
  } catch (error) {
    sendError(response, error)
  }
}
