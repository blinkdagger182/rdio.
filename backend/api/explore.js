import { fetchRadioBrowser, sendError, sendJson } from './_radio-browser.js'

const COUNTRY_NAMES = {
  MY: 'Malaysia', SG: 'Singapore', ID: 'Indonesia', BN: 'Brunei',
  TH: 'Thailand', PH: 'Philippines', VN: 'Vietnam',
  JP: 'Japan', KR: 'South Korea', CN: 'China', IN: 'India',
  HK: 'Hong Kong', TW: 'Taiwan',
  US: 'United States', GB: 'United Kingdom', DE: 'Germany',
  FR: 'France', NL: 'Netherlands', ES: 'Spain', IT: 'Italy',
  PL: 'Poland', SE: 'Sweden', NO: 'Norway', CH: 'Switzerland',
  AT: 'Austria', BE: 'Belgium', RU: 'Russia', UA: 'Ukraine',
  AU: 'Australia', NZ: 'New Zealand',
  CA: 'Canada', MX: 'Mexico',
  BR: 'Brazil', AR: 'Argentina', CO: 'Colombia', CL: 'Chile', PE: 'Peru',
  ZA: 'South Africa', NG: 'Nigeria', KE: 'Kenya', GH: 'Ghana', ET: 'Ethiopia',
  AE: 'UAE', SA: 'Saudi Arabia', IR: 'Iran', TR: 'Turkey', EG: 'Egypt', IQ: 'Iraq', JO: 'Jordan',
  FJ: 'Fiji', PG: 'Papua New Guinea',
}

const LOCAL_CODES = ['MY', 'SG', 'ID', 'BN', 'TH', 'PH', 'VN']

const FEATURED_CODES = ['US', 'GB', 'JP', 'AU', 'DE', 'FR', 'KR', 'CA', 'NL', 'IN']

const REGIONS = [
  { name: 'Asia', codes: ['MY', 'SG', 'ID', 'TH', 'PH', 'JP', 'KR', 'CN', 'IN', 'VN', 'BN', 'HK', 'TW'] },
  { name: 'Europe', codes: ['GB', 'DE', 'FR', 'NL', 'ES', 'IT', 'PL', 'SE', 'NO', 'CH', 'AT', 'BE', 'RU', 'UA'] },
  { name: 'North America', codes: ['US', 'CA', 'MX'] },
  { name: 'South America', codes: ['BR', 'AR', 'CO', 'CL', 'PE'] },
  { name: 'Middle East', codes: ['AE', 'SA', 'IR', 'TR', 'EG', 'IQ', 'JO'] },
  { name: 'Africa', codes: ['ZA', 'NG', 'KE', 'GH', 'ET'] },
  { name: 'Oceania', codes: ['AU', 'NZ', 'FJ', 'PG'] },
]

const FEATURED_GENRE_NAMES = [
  'music', 'news', 'talk', 'pop', 'rock', 'jazz',
  'classical', 'hip-hop', 'electronic', 'sports',
  'islamic', 'business', 'culture', 'folk',
]

export default async function handler(request, response) {
  if (request.method !== 'GET') {
    return sendJson(response, 405, { error: 'Method not allowed' })
  }

  try {
    const [allTags, allCodes] = await Promise.all([
      fetchRadioBrowser('tags', new URLSearchParams({
        hidebroken: 'true', order: 'stationcount', reverse: 'true', limit: '100'
      })),
      fetchRadioBrowser('countrycodes', new URLSearchParams({
        hidebroken: 'true', order: 'stationcount', reverse: 'true', limit: '300'
      }))
    ])

    const countByCode = {}
    allCodes.forEach(c => { countByCode[c.name.toUpperCase()] = c.stationcount })

    const toCountry = (code) => ({
      code,
      name: COUNTRY_NAMES[code] || code,
      stationcount: countByCode[code] || 0
    })

    const tagMap = {}
    allTags.forEach(t => { tagMap[t.name.toLowerCase()] = t.stationcount })

    sendJson(response, 200, {
      localCountries: LOCAL_CODES.map(toCountry),
      featuredCountries: FEATURED_CODES.map(toCountry),
      regions: REGIONS.map(r => ({
        name: r.name,
        codes: r.codes,
        stationcount: r.codes.reduce((sum, c) => sum + (countByCode[c] || 0), 0)
      })),
      featuredTags: FEATURED_GENRE_NAMES.map(name => ({
        name,
        stationcount: tagMap[name] || 0
      }))
    })
  } catch (error) {
    sendError(response, error)
  }
}
