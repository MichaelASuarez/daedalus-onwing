# Daedalus onWing — Company Website

Static website for [daedalus-onwing.com](https://daedalus-onwing.com). Four pages: Home, RetireMint product, Minder.ai product, About.

## File Structure

```
website/
├── index.html                      ← Home page
├── about.html                      ← About Michael Suarez
├── products/
│   ├── retiremint.html             ← RetireMint product page
│   └── minder-ai.html              ← Minder.ai product page
├── assets/
│   ├── css/main.css                ← Single stylesheet (all pages)
│   ├── js/main.js                  ← Nav, scroll, animations
│   ├── svg/                        ← SVG logos
│   └── images/                     ← App screenshots & logos
└── README.md
```

---

## Local Testing

**Do not open `index.html` directly in a browser** — `file://` protocol breaks root-relative paths (`/assets/css/main.css`). Always use a local server:

```bash
cd /Users/msuarez/Library/CloudStorage/Dropbox/Daedalus/website
python3 -m http.server 8080
```

Then open: **http://localhost:8080**

To stop the server: `Ctrl+C`

### Test Checklist

- [ ] Home, RetireMint, Minder.ai, and About pages all load without console errors
- [ ] Products dropdown opens on hover (desktop)
- [ ] Mobile hamburger opens/closes at 375px width
- [ ] All images load (no broken icons)
- [ ] No horizontal scroll at 375px
- [ ] Scroll animations fade in correctly
- [ ] Nav goes glass-morphism after scrolling ~60px

---

## Deploying to GitHub Pages

### Step 1 — Initialize git

```bash
cd /Users/msuarez/Library/CloudStorage/Dropbox/Daedalus/website
git init
git branch -M main
```

### Step 2 — Create GitHub repo and push

```bash
gh repo create daedalus-onwing --public --source=. --remote=origin
git add .
git commit -m "Initial Daedalus onWing website"
git push -u origin main
```

> If you don't have the `gh` CLI: create the repo at github.com, then:
> ```bash
> git remote add origin https://github.com/MichaelASuarez/daedalus-onwing.git
> git push -u origin main
> ```

### Step 3 — Enable GitHub Pages

**Via GitHub web UI:**
1. Go to: `https://github.com/MichaelASuarez/daedalus-onwing/settings/pages`
2. Source: **Deploy from a branch**
3. Branch: `main`, Folder: `/ (root)`
4. Click **Save**

Site publishes at: `https://MichaelASuarez.github.io/daedalus-onwing/`

> **Important — subdirectory path:** Before the custom domain is active, the site lives at `/daedalus-onwing/`. Add this line to each page's `<head>` so assets resolve correctly:
> ```html
> <base href="/daedalus-onwing/">
> ```
> Remove it once the custom domain is live.

### Step 4 — Connect Custom Domain

**In GitHub Pages settings:**
- Custom domain: `daedalus-onwing.com`
- Check **Enforce HTTPS** (after DNS propagates)

**DNS records at your registrar:**

| Type  | Host  | Value                        |
|-------|-------|------------------------------|
| A     | @     | 185.199.108.153              |
| A     | @     | 185.199.109.153              |
| A     | @     | 185.199.110.153              |
| A     | @     | 185.199.111.153              |
| CNAME | www   | MichaelASuarez.github.io     |

DNS propagates in 10 min – 48 hours. Check status:
```bash
dig daedalus-onwing.com +short
```

Once the custom domain is active, remove any `<base href>` tags from the HTML files.

---

## Ongoing Updates

After making changes:

```bash
git add .
git commit -m "Update: describe what changed"
git push
```

GitHub Pages auto-deploys on every push to `main`. Usually live within 60 seconds.

---

## App Store Links

Update these placeholders once the apps are live:

| App | File | Placeholder to replace |
|-----|------|------------------------|
| RetireMint | `products/retiremint.html` | `https://apps.apple.com/us/app/retiremint/id6505041195` |
| Minder.ai  | `products/minder-ai.html`  | `https://apps.apple.com/` |
