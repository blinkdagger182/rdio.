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
  {
    name: 'Southeast Asia',
    codes: ['MY', 'SG', 'ID', 'TH', 'PH', 'VN', 'BN', 'KH', 'LA', 'MM', 'TL'],
  },
  {
    name: 'East Asia',
    codes: ['JP', 'KR', 'CN', 'HK', 'TW', 'MO', 'MN', 'KP'],
  },
  {
    name: 'South Asia',
    codes: ['IN', 'PK', 'BD', 'LK', 'NP', 'BT', 'MV', 'AF'],
  },
  {
    name: 'Central Asia',
    codes: ['KZ', 'UZ', 'TM', 'KG', 'TJ'],
  },
  {
    name: 'Caucasus',
    codes: ['GE', 'AM', 'AZ'],
  },
  {
    name: 'Western Europe',
    codes: ['GB', 'DE', 'FR', 'NL', 'BE', 'LU', 'CH', 'AT', 'IE', 'PT', 'ES', 'IT', 'MC', 'SM', 'MT', 'LI', 'AD', 'VA', 'GI'],
  },
  {
    name: 'Northern Europe',
    codes: ['SE', 'NO', 'FI', 'DK', 'IS', 'EE', 'LV', 'LT', 'FO', 'AX', 'SJ', 'IM', 'GG', 'GL'],
  },
  {
    name: 'Eastern Europe',
    codes: ['RU', 'UA', 'BY', 'PL', 'CZ', 'SK', 'HU', 'RO', 'BG', 'MD', 'RS', 'HR', 'SI', 'BA', 'ME', 'MK', 'AL', 'XK', 'GR', 'CY'],
  },
  {
    name: 'North America',
    codes: ['US', 'CA', 'MX', 'GT', 'BZ', 'HN', 'SV', 'NI', 'CR', 'PA'],
  },
  {
    name: 'Caribbean',
    codes: ['CU', 'JM', 'HT', 'DO', 'PR', 'TT', 'BB', 'LC', 'VC', 'GD', 'AG', 'DM', 'KN', 'BS', 'TC', 'KY', 'BM', 'AI', 'MS', 'VG', 'VI', 'CW', 'AW', 'BQ', 'GP', 'MQ', 'PM'],
  },
  {
    name: 'South America',
    codes: ['BR', 'AR', 'CO', 'CL', 'PE', 'VE', 'EC', 'BO', 'PY', 'UY', 'GY', 'SR', 'GF'],
  },
  {
    name: 'Middle East',
    codes: ['AE', 'SA', 'IR', 'TR', 'IQ', 'EG', 'JO', 'SY', 'LB', 'IL', 'KW', 'QA', 'BH', 'OM', 'YE', 'PS'],
  },
  {
    name: 'North Africa',
    codes: ['MA', 'DZ', 'TN', 'LY', 'SD', 'SS', 'ER', 'DJ', 'SO'],
  },
  {
    name: 'West Africa',
    codes: ['NG', 'GH', 'SN', 'CI', 'CM', 'ML', 'BF', 'GN', 'BJ', 'TG', 'SL', 'LR', 'MR', 'GW', 'GM', 'CV', 'NE'],
  },
  {
    name: 'Central Africa',
    codes: ['ET', 'KE', 'TZ', 'UG', 'RW', 'BI', 'CD', 'CG', 'CF', 'TD', 'GA', 'GQ', 'ST', 'CM'],
  },
  {
    name: 'Southern Africa',
    codes: ['ZA', 'ZW', 'ZM', 'MZ', 'MW', 'NA', 'BW', 'AO', 'SZ', 'LS', 'MG', 'MU', 'SC', 'KM', 'RE', 'YT'],
  },
  {
    name: 'Oceania',
    codes: ['AU', 'NZ', 'PG', 'FJ', 'SB', 'VU', 'WS', 'TO', 'KI', 'TV', 'NR', 'PW', 'FM', 'MH', 'CK', 'NC', 'PF', 'GU', 'AS', 'WF', 'NU'],
  },
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
