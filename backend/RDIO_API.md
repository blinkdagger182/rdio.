# rdio Radio API

This folder now contains deployable Vercel API routes in `api/`.

## Endpoints

```txt
GET /api/health
GET /api/stations?limit=50&offset=0
GET /api/stations?search=jazz&limit=50&offset=0
GET /api/stations?countrycode=US&limit=50&offset=0
GET /api/stations?country=Japan&limit=50&offset=0
GET /api/stations?language=english&limit=50&offset=0
GET /api/stations?tag=lofi&limit=50&offset=0
GET /api/countries
GET /api/tags
GET /api/languages
```

`/api/stations` returns app-ready station objects:

```json
{
  "stations": [],
  "limit": 50,
  "offset": 0,
  "nextOffset": 50
}
```

## Local Run

```sh
cd backend
vercel dev
```

Then test:

```sh
curl 'http://localhost:3000/api/stations?tag=jazz&limit=10'
```

## Deploy

```sh
cd backend
vercel
```

Set this optional environment variable in Vercel:

```txt
RADIO_BROWSER_USER_AGENT=rdio-app/1.0 your-email-or-site
```

After deployment, point the iOS app at:

```txt
https://<your-vercel-project>.vercel.app/api/stations
```

Do not load all Radio Browser stations on launch. Use `limit` and `offset`, and apply `search`, `countrycode`, `language`, or `tag` filters from the app UI.
