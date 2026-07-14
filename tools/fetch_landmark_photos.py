# Fetch a real, high-quality photo for every landmark in kCityLandmarks from
# Wikimedia Commons and upload it to the path-assets photo slots (kind='photo',
# slot 0-3) via the admin-asset edge fn. The info panel prefers these admin
# URLs over the bundled flat icons, so the panel switches to real photography
# without an app deploy. Resumable: already-logged slots are skipped.
#
#   python tools/fetch_landmark_photos.py            # full run (resumes)
#   python tools/fetch_landmark_photos.py chengdu    # one city
#   python tools/fetch_landmark_photos.py --retry    # re-run logged misses
#
# Attribution (artist + license per image) lands in tools/landmark_photos_log.jsonl.
import io
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CITIES_DART = ROOT / 'lib' / 'core' / 'constants' / 'cities.dart'
LOG = ROOT / 'tools' / 'landmark_photos_log.jsonl'
EDGE = 'https://pqyceostpukueydwuiut.supabase.co/functions/v1/admin-asset'
GUARD = 'sinoma-admin-asset-2026'
UA = 'SinomaLandmarkFetcher/1.0 (educational app; murat.erhan.38@gmail.com)'
API = 'https://commons.wikimedia.org/w/api.php'

BAD_TITLE = re.compile(
    r'map|locator|logo|flag|coat[_ ]of[_ ]arms|diagram|chart|plan[_ ]|banner|'
    r'montage|collage|seal[_ ]of|emblem|icon|drawing|sketch',
    re.I)

DART_STR = r"(?:'((?:[^'\\]|\\.)*)'|\"((?:[^\"\\]|\\.)*)\")"


def _s(m, a, b):
    v = m.group(a) if m.group(a) is not None else m.group(b)
    return v.replace("\\'", "'").replace('\\"', '"').replace('\\\\', '\\')


def load_landmarks():
    src = CITIES_DART.read_text(encoding='utf-8')
    cities = re.search(r'const List<City> kChineseCities = \[(.*?)\n\];', src,
                       re.S).group(1)
    order = [
        _s(m, 1, 2) for m in re.finditer(
            r"City\('[^']*',\s*" + DART_STR + r'\)', cities)
    ]
    slugs = [re.sub(r'[^a-z0-9]', '', p.lower()) for p in order]

    lm_block = re.search(
        r'const Map<String, List<Landmark>> kCityLandmarks = \{(.*)\n\};', src,
        re.S).group(1)
    out = []
    for cm in re.finditer(r"'([a-z0-9]+)':\s*\[(.*?)\n  \],", lm_block, re.S):
        slug, body = cm.group(1), cm.group(2)
        if slug not in slugs:
            print(f'!! {slug}: not in kChineseCities, skipped')
            continue
        idx = slugs.index(slug)
        if idx < 96:
            level, unit = idx % 4 + 1, idx // 4 + 1
        else:
            level, unit = 5 + (idx - 96) // 24, (idx - 96) % 24 + 1
        for i, lm in enumerate(re.finditer(r'Landmark\((.*?)\),?\s*(?=Landmark\(|$)',
                                           body, re.S)):
            f = lm.group(1)

            def field(name):
                m = re.search(name + r':\s*' + DART_STR, f)
                return _s(m, 1, 2) if m else ''

            out.append({
                'slug': slug, 'pinyin': order[idx], 'level': level,
                'unit': unit, 'slot': i, 'icon': field('icon'),
                'nameTr': field('nameTr'), 'nameEn': field('nameEn'),
            })
    return out


def api_get(params, api=API):
    qs = urllib.parse.urlencode({**params, 'format': 'json'})
    req = urllib.request.Request(f'{api}?{qs}', headers={'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


WIKI_API = 'https://en.wikipedia.org/w/api.php'


STOP = {'the', 'of', 'and', 'a', 'in', 'city', 'china', 'chinese'}

# Articles/files about disasters, transit stops and other off-subject pages
# that happen to share a word with the landmark ("Shilaoren Beach STATION",
# "Liuyang fireworks factory EXPLOSION", "Huanan Seafood WHOLESALE market").
NEG_WORDS = {
    'station', 'metro', 'explosion', 'accident', 'disaster', 'incident',
    'crash', 'collapse', 'massacre', 'riot', 'protest', 'outbreak',
    'pandemic', 'bombing', 'attack', 'earthquake', 'murder', 'death',
    'funeral', 'cemetery', 'wholesale', 'stampede', 'fire',
    # Event/sport/philately articles about the landmark, not the landmark:
    # "Great Wall MARATHON", "Sailing at the 2008 OLYMPICS" (a stamp sheet).
    'marathon', 'olympic', 'championship', 'stamp', 'tournament', 'race',
}


def words(s):
    return {w.rstrip('s') for w in re.findall(r'[a-z]+', s.lower())
            if w not in STOP and len(w) > 2}


def neg_for(subject_words):
    neg = NEG_WORDS - subject_words
    # A rail-themed landmark legitimately lives on "... railway station" pages.
    if {'railway', 'train', 'rail', 'metro'} & subject_words:
        neg.discard('station')
    if {'firework', 'fireworks'} & subject_words:
        neg.discard('fire')
    return neg


# Same-subject photos from the wrong country (drying peppers in Turkey,
# Sydney fireworks) — penalised, only acceptable as a last resort.
FOREIGN = {
    'turkey', 'india', 'mexico', 'japan', 'korea', 'thailand', 'vietnam',
    'italy', 'spain', 'france', 'germany', 'america', 'australia', 'sydney',
    'london', 'francisco', 'york', 'paris', 'tokyo', 'singapore', 'malaysia',
    'indonesia', 'russia', 'brazil', 'egypt', 'canada', 'african', 'europe',
}


# Lead images of Wikipedia articles are editor-curated and almost always show
# the subject itself — far more reliable than raw Commons relevance search
# (which happily returns metro platforms and street portraits). The article
# title / lead-image filename must share a word with the landmark, otherwise
# the search drifts to the city/province article and its generic skyline.
def wiki_lead_images(query, subject, city):
    cw = words(city)
    # The subject is matched on its DISTINCTIVE words: "Beijing Opera" must
    # match on "opera", or the bare "Beijing" city article slips through.
    sw = words(subject) - cw
    neg = neg_for(sw)
    try:
        data = api_get({
            'action': 'query', 'generator': 'search', 'gsrsearch': query,
            'gsrlimit': 6, 'prop': 'pageimages|extracts',
            'piprop': 'thumbnail|name', 'pithumbsize': 1200,
            'exintro': 1, 'explaintext': 1, 'exchars': 600, 'exlimit': 'max',
        }, WIKI_API)
    except Exception as e:
        print(f'   wiki error: {e}')
        return []
    pages = (data.get('query') or {}).get('pages') or {}
    out = []
    for idx, p in enumerate(sorted(pages.values(),
                                   key=lambda p: p.get('index', 99))):
        th = p.get('thumbnail')
        name = p.get('pageimage', '')
        tw = words(p.get('title', ''))
        hay = tw | words(name)
        # The article INTRO anchors geography — "The Bund … in central
        # Shanghai" — where title and filename often name neither the city
        # nor the country.
        intro = (p.get('extract') or '').lower()
        is_city = bool(cw & hay) or city.lower() in intro
        # 350: portrait tower shots thumb narrow at a fixed height.
        if not th or th.get('width', 0) < 350:
            continue
        if BAD_TITLE.search(name) or (hay & neg):
            continue
        if sw and not (sw & hay):
            continue
        if (hay & FOREIGN) and not is_city:
            continue
        # More shared subject words = the right landmark, not a lookalike
        # ("Oriental Pearl Tower" 3 hits beats "Jin Mao Tower" 1 hit) and
        # outweighs the city bonus (Temple of HEAVEN beats Beijing Dongyue
        # Temple); a title with no words beyond the subject beats
        # "<subject> Sightseeing Tunnel"-style neighbours.
        score = (1.0 if is_city else 0.0) + 1.5 * len(sw & hay) \
            + (0.8 if not (tw - sw - cw) else 0.0) - idx * 0.15
        out.append({'thumburl': th['source'], 'url': th['source'],
                    'title': f"wiki:{p.get('title')} ({name})",
                    'source': 'https://en.wikipedia.org/wiki/'
                              + urllib.parse.quote(p.get('title', '')),
                    'license': 'via Wikipedia lead image',
                    '_city': 1 if is_city else 0, '_score': score})
    out.sort(key=lambda c: -c['_score'])
    return out


def commons_search(query):
    try:
        data = api_get({
            'action': 'query', 'generator': 'search',
            'gsrsearch': f'{query} filetype:bitmap', 'gsrnamespace': 6,
            'gsrlimit': 10, 'prop': 'imageinfo',
            'iiprop': 'url|size|mime|extmetadata', 'iiurlwidth': 640,
        })
    except Exception as e:
        print(f'   search error: {e}')
        return []
    pages = (data.get('query') or {}).get('pages') or {}
    return sorted(pages.values(), key=lambda p: p.get('index', 99))


def pick(pages, subject=''):
    sw = words(subject)
    neg = neg_for(sw)
    best, best_score = None, -1
    for rank, p in enumerate(pages):
        ii = (p.get('imageinfo') or [{}])[0]
        w, h = ii.get('width', 0), ii.get('height', 0)
        mime = ii.get('mime', '')
        title = p.get('title', '')
        if mime not in ('image/jpeg', 'image/png'):
            continue
        if w < 640 or h < 420:
            continue
        ratio = w / max(h, 1)
        if not 0.6 <= ratio <= 2.6:
            continue
        if BAD_TITLE.search(title) or (words(title) & neg):
            continue
        meta = ii.get('extmetadata') or {}
        assess = str(meta.get('Assessments', {}).get('value', ''))
        score = min(w, 3000) / 3000 + (1.0 - rank * 0.09)
        if assess:  # featured/quality/valued images float to the top
            score += 0.6
        # Filenames naming the subject beat big-but-unrelated shots.
        if sw:
            score += 0.9 if (sw & words(title)) else -0.5
        if words(title) & FOREIGN:
            score -= 1.2
        if score > best_score:
            best, best_score = (p, ii), score
    return best


def fetch_jpeg(ii):
    url = ii.get('thumburl') or ii['url']
    req = urllib.request.Request(url, headers={'User-Agent': UA})
    raw = None
    for attempt in range(2):  # flaky thumb servers: one retry before rejecting
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                raw = r.read()
            break
        except Exception:
            if attempt:
                raise
            time.sleep(1.5)
    img = Image.open(io.BytesIO(raw)).convert('RGB')
    # Reject near-grayscale shots (news/street photography, old B&W scans) —
    # the panel needs colour photos of the subject.
    hsv = img.convert('HSV').resize((64, 64))
    sat = sum(hsv.getdata(1)) / (64 * 64)
    if sat < 18:
        raise ValueError(f'grayscale-ish (sat {sat:.0f})')
    img.thumbnail((640, 640))
    buf = io.BytesIO()
    img.save(buf, 'JPEG', quality=82, optimize=True)
    return buf.getvalue()


def upload(data, level, unit, slot):
    qs = urllib.parse.urlencode({
        'level': level, 'unit': unit, 'kind': 'photo', 'slot': slot,
        'ext': 'jpg'
    })
    req = urllib.request.Request(
        f'{EDGE}?{qs}', data=data, method='POST',
        headers={'x-backfill-guard': GUARD, 'Content-Type': 'image/jpeg'})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)['url']


def queries(lm):
    name, city = lm['nameEn'], lm['pinyin']
    qs = []
    if city.lower() not in name.lower():
        qs.append(f'{name} {city}')
    qs.append(name if len(name) > 8 else f'{name} China')
    qs.append(f'{city} {lm["icon"]}')
    return qs


def main():
    arg = sys.argv[1] if len(sys.argv) > 1 else None
    retry = arg == '--retry'
    landmarks = load_landmarks()
    print(f'{len(landmarks)} landmarks across '
          f'{len({l["slug"] for l in landmarks})} cities')

    done = {}
    if LOG.exists():
        for line in LOG.read_text(encoding='utf-8').splitlines():
            e = json.loads(line)
            done[(e['slug'], e['slot'])] = e

    ok = miss = skip = 0
    with LOG.open('a', encoding='utf-8') as logf:
        for lm in landmarks:
            key = (lm['slug'], lm['slot'])
            if arg and not retry and lm['slug'] != arg:
                continue
            prev = done.get(key)
            if prev and (prev.get('ok') or not retry and not arg):
                skip += 1
                continue
            tag = f"{lm['slug']}/{lm['icon']} L{lm['level']}U{lm['unit']}s{lm['slot']}"
            # Priority: city-anchored Wikipedia lead image → Commons search →
            # generic same-subject Wikipedia image (a fireworks photo from
            # anywhere beats an empty slot, but never beats a local one).
            subject = f"{lm['nameEn']} {lm['icon']}"
            wiki = []
            for q in queries(lm):
                wiki += wiki_lead_images(q, subject, lm['pinyin'])
                time.sleep(0.4)
                if len(wiki) >= 3:
                    break
            candidates = [c for c in wiki if c['_city']]
            for q in queries(lm):
                got = pick(commons_search(q), subject)
                time.sleep(0.5)
                if got:
                    page, ii = got
                    meta = ii.get('extmetadata') or {}
                    candidates.append({
                        'thumburl': ii.get('thumburl'), 'url': ii.get('url'),
                        'title': page.get('title'),
                        'source': ii.get('descriptionurl'),
                        'artist': re.sub(r'<[^>]+>', '', str(
                            meta.get('Artist', {}).get('value', '')))[:120],
                        'license': str(meta.get('LicenseShortName', {})
                                       .get('value', '')),
                    })
                    break
            candidates += [c for c in wiki if not c['_city']]
            entry = {**{k: lm[k] for k in ('slug', 'slot', 'icon', 'level',
                                           'unit', 'nameEn')}}
            entry['ok'] = False
            for cand in candidates:
                try:
                    data = fetch_jpeg(cand)
                    url = upload(data, lm['level'], lm['unit'], lm['slot'])
                    entry.update(ok=True, title=cand.get('title'), url=url,
                                 source=cand.get('source'),
                                 artist=cand.get('artist', ''),
                                 license=cand.get('license', ''))
                    print(f'OK   {tag}  {len(data)//1024}KB  {cand.get("title")}')
                    ok += 1
                    break
                except Exception as e:
                    print(f'   cand rejected ({cand.get("title")}): {e}')
            if not entry['ok']:
                print(f'MISS {tag}')
                miss += 1
            logf.write(json.dumps(entry, ensure_ascii=False) + '\n')
            logf.flush()
    print(f'\nok={ok} miss={miss} skipped={skip}')


if __name__ == '__main__':
    main()
