# SevaCare Marketing Website

Static site — no build step. Lives inside the Flutter project at
`sevacare-flutter/website/` until a domain is purchased.

## Preview

- Open `index.html` directly in a browser, or
- Serve it: `cd sevacare-flutter/website && python3 -m http.server 8099 --bind 0.0.0.0`
  - Local: http://localhost:8099
  - Mobile (same Wi-Fi): http://<Mac-LAN-IP>:8099

## Assets

Already in place: founder photos (`founder-sravani.jpg`, `founder-rajasekhar.jpg`)
and the four product shots cropped from `sevacare-flutter/Photos/Hospital seva care.png`
(`shot-appointments.png`, `shot-doctors.png`, `shot-onboarding.png`, `shot-dashboard.png`).

Still placeholder (drop in with this exact name when ready — the page falls
back gracefully to a letter mark if missing):

- `assets/logo.png` — company logo (nav + footer, ~64×64px works well)

## Deploying

Any static host works — drag-and-drop the folder onto Netlify, or serve via
GitHub Pages / Vercel / S3 once the domain is bought.
