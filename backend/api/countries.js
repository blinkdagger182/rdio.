import { fetchRadioBrowser, sendError, sendJson } from './_radio-browser.js'

// Clean short names for countries whose Radio Browser names are long or official-only.
// Falls back to the Radio Browser name for anything not listed here.
const SHORT_NAMES = {
  AF: 'Afghanistan', AL: 'Albania', DZ: 'Algeria', AD: 'Andorra', AO: 'Angola',
  AG: 'Antigua & Barbuda', AR: 'Argentina', AM: 'Armenia', AU: 'Australia',
  AT: 'Austria', AZ: 'Azerbaijan', BS: 'Bahamas', BH: 'Bahrain', BD: 'Bangladesh',
  BB: 'Barbados', BY: 'Belarus', BE: 'Belgium', BZ: 'Belize', BJ: 'Benin',
  BT: 'Bhutan', BO: 'Bolivia', BA: 'Bosnia & Herzegovina', BW: 'Botswana',
  BR: 'Brazil', BN: 'Brunei', BG: 'Bulgaria', BF: 'Burkina Faso', BI: 'Burundi',
  CV: 'Cape Verde', KH: 'Cambodia', CM: 'Cameroon', CA: 'Canada',
  CF: 'Central African Rep.', TD: 'Chad', CL: 'Chile', CN: 'China', CO: 'Colombia',
  KM: 'Comoros', CD: 'DR Congo', CG: 'Republic of Congo', CR: 'Costa Rica',
  HR: 'Croatia', CU: 'Cuba', CY: 'Cyprus', CZ: 'Czech Republic', DK: 'Denmark',
  DJ: 'Djibouti', DM: 'Dominica', DO: 'Dominican Republic', EC: 'Ecuador',
  EG: 'Egypt', SV: 'El Salvador', GQ: 'Equatorial Guinea', ER: 'Eritrea',
  EE: 'Estonia', SZ: 'Eswatini', ET: 'Ethiopia', FJ: 'Fiji', FI: 'Finland',
  FR: 'France', GA: 'Gabon', GM: 'Gambia', GE: 'Georgia', DE: 'Germany',
  GH: 'Ghana', GR: 'Greece', GD: 'Grenada', GT: 'Guatemala', GN: 'Guinea',
  GW: 'Guinea-Bissau', GY: 'Guyana', HT: 'Haiti', HN: 'Honduras', HU: 'Hungary',
  IS: 'Iceland', IN: 'India', ID: 'Indonesia', IR: 'Iran', IQ: 'Iraq',
  IE: 'Ireland', IL: 'Israel', IT: 'Italy', JM: 'Jamaica', JP: 'Japan',
  JO: 'Jordan', KZ: 'Kazakhstan', KE: 'Kenya', KI: 'Kiribati', KP: 'North Korea',
  KR: 'South Korea', KW: 'Kuwait', KG: 'Kyrgyzstan', LA: 'Laos', LV: 'Latvia',
  LB: 'Lebanon', LS: 'Lesotho', LR: 'Liberia', LY: 'Libya', LI: 'Liechtenstein',
  LT: 'Lithuania', LU: 'Luxembourg', MG: 'Madagascar', MW: 'Malawi', MY: 'Malaysia',
  MV: 'Maldives', ML: 'Mali', MT: 'Malta', MH: 'Marshall Islands', MR: 'Mauritania',
  MU: 'Mauritius', MX: 'Mexico', FM: 'Micronesia', MD: 'Moldova', MC: 'Monaco',
  MN: 'Mongolia', ME: 'Montenegro', MA: 'Morocco', MZ: 'Mozambique', MM: 'Myanmar',
  NA: 'Namibia', NR: 'Nauru', NP: 'Nepal', NL: 'Netherlands', NZ: 'New Zealand',
  NI: 'Nicaragua', NE: 'Niger', NG: 'Nigeria', NO: 'Norway', OM: 'Oman',
  PK: 'Pakistan', PW: 'Palau', PA: 'Panama', PG: 'Papua New Guinea', PY: 'Paraguay',
  PE: 'Peru', PH: 'Philippines', PL: 'Poland', PT: 'Portugal', QA: 'Qatar',
  RO: 'Romania', RU: 'Russia', RW: 'Rwanda', KN: 'St Kitts & Nevis',
  LC: 'St Lucia', VC: 'St Vincent & Grenadines', WS: 'Samoa', SM: 'San Marino',
  ST: 'São Tomé & Príncipe', SA: 'Saudi Arabia', SN: 'Senegal', RS: 'Serbia',
  SC: 'Seychelles', SL: 'Sierra Leone', SG: 'Singapore', SK: 'Slovakia',
  SI: 'Slovenia', SB: 'Solomon Islands', SO: 'Somalia', ZA: 'South Africa',
  SS: 'South Sudan', ES: 'Spain', LK: 'Sri Lanka', SD: 'Sudan', SR: 'Suriname',
  SE: 'Sweden', CH: 'Switzerland', SY: 'Syria', TW: 'Taiwan', TJ: 'Tajikistan',
  TZ: 'Tanzania', TH: 'Thailand', TL: 'Timor-Leste', TG: 'Togo', TO: 'Tonga',
  TT: 'Trinidad & Tobago', TN: 'Tunisia', TR: 'Turkey', TM: 'Turkmenistan',
  TV: 'Tuvalu', UG: 'Uganda', UA: 'Ukraine', AE: 'UAE',
  GB: 'United Kingdom', US: 'United States', UY: 'Uruguay', UZ: 'Uzbekistan',
  VU: 'Vanuatu', VE: 'Venezuela', VN: 'Vietnam', YE: 'Yemen', ZM: 'Zambia',
  ZW: 'Zimbabwe', HK: 'Hong Kong', MO: 'Macao', BN_: 'Brunei',
  XK: 'Kosovo', TF: 'French Southern Territories', NC: 'New Caledonia',
  PF: 'French Polynesia', GP: 'Guadeloupe', MQ: 'Martinique', RE: 'Réunion',
  YT: 'Mayotte', PM: 'St Pierre & Miquelon', WF: 'Wallis & Futuna',
  GF: 'French Guiana', BL: 'Saint Barthélemy', MF: 'Saint Martin',
  AW: 'Aruba', CW: 'Curaçao', SX: 'Sint Maarten', BQ: 'Caribbean Netherlands',
  AI: 'Anguilla', KY: 'Cayman Islands', MS: 'Montserrat', TC: 'Turks & Caicos',
  VG: 'British Virgin Islands', VI: 'US Virgin Islands', PR: 'Puerto Rico',
  GU: 'Guam', MP: 'N. Mariana Islands', AS: 'American Samoa',
  UM: 'US Minor Outlying Islands', FK: 'Falkland Islands', GI: 'Gibraltar',
  IM: 'Isle of Man', JE: 'Jersey', GG: 'Guernsey', SH: 'Saint Helena',
  IO: 'British Indian Ocean Terr.', CX: 'Christmas Island',
  CC: 'Cocos Islands', NF: 'Norfolk Island', HM: 'Heard Island',
  GS: 'S. Georgia & S. Sandwich Islands', PN: 'Pitcairn Islands',
  EH: 'Western Sahara', AX: 'Åland Islands', FO: 'Faroe Islands',
  GL: 'Greenland', SJ: 'Svalbard & Jan Mayen', BV: 'Bouvet Island',
  MK: 'North Macedonia', BA_2: 'Bosnia', CG_2: 'Congo',
}

export default async function handler(request, response) {
  if (request.method !== 'GET') {
    return sendJson(response, 405, { error: 'Method not allowed' })
  }

  try {
    const limit = Math.min(300, Math.max(1, parseInt(request.query?.limit) || 300))
    const params = new URLSearchParams({
      hidebroken: 'true',
      order: 'stationcount',
      reverse: 'true',
      limit: String(limit)
    })
    const raw = await fetchRadioBrowser('countries', params)

    const countries = raw
      .filter(c => c.iso_3166_1 && c.iso_3166_1.length === 2)
      .map(c => {
        const code = c.iso_3166_1.toUpperCase()
        return {
          code,
          name: SHORT_NAMES[code] || c.name,
          stationcount: c.stationcount
        }
      })

    sendJson(response, 200, { countries })
  } catch (error) {
    sendError(response, error)
  }
}
