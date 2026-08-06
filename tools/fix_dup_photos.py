# One-off: replace duplicate within-unit landmark photos with distinct images.
# For each target slot, gathers candidate photos (same pipeline as
# fetch_landmark_photos) and uploads the first whose final JPEG bytes differ
# from every OTHER slot's current photo in that unit — guaranteeing distinctness.
import hashlib, io, json, sys, time, urllib.request
sys.argv = [sys.argv[0]]  # keep imported module from parsing our args
import fetch_landmark_photos as F

STORE = ("https://pqyceostpukueydwuiut.supabase.co/storage/v1/object/public/"
         "path-assets/L{L}/U{U}/photo_{S}.jpg")

# (slug, slot-to-replace)
TARGETS = [('weifang', 2), ('jingdezhen', 3), ('lianyungang', 2),
           ('puer', 2), ('xianyang', 1)]


def stored_hash(L, U, S):
    try:
        req = urllib.request.Request(STORE.format(L=L, U=U, S=S),
                                     headers={'User-Agent': F.UA})
        return hashlib.md5(urllib.request.urlopen(req, timeout=30).read()).hexdigest()
    except Exception:
        return None


def gather(lm):
    subject = f"{lm['nameEn']} {lm['icon']}"
    cands = []
    for q in F.queries(lm):
        cands += F.wiki_lead_images(q, subject, lm['pinyin'])
        time.sleep(0.3)
    cands = [c for c in cands if c.get('_city')] + [c for c in cands if not c.get('_city')]
    for q in F.queries(lm):
        got = F.pick(F.commons_search(q), subject)
        time.sleep(0.4)
        if got:
            _p, ii = got
            cands.append({'thumburl': ii.get('thumburl'), 'url': ii.get('url'),
                          'title': _p.get('title')})
    return cands


def main():
    lms = {(l['slug'], l['slot']): l for l in F.load_landmarks()}
    for slug, slot in TARGETS:
        lm = lms[(slug, slot)]
        L, U = lm['level'], lm['unit']
        avoid = {stored_hash(L, U, s) for s in range(4) if s != slot}
        avoid.discard(None)
        print(f"\n== {slug} L{L}U{U} slot{slot} '{lm['nameEn']}' — avoid {len(avoid)} sibling imgs ==")
        picked = None
        for c in gather(lm):
            try:
                data = F.fetch_jpeg({'thumburl': c.get('thumburl'), 'url': c.get('url')})
            except Exception as e:
                continue
            hh = hashlib.md5(data).hexdigest()
            if hh in avoid:
                print(f"   skip (same as sibling): {c.get('title')}")
                continue
            url = F.upload(data, L, U, slot)
            print(f"   UPLOADED: {c.get('title')}\n      -> {url}")
            picked = c
            break
        if not picked:
            print(f"   !! no distinct candidate found for {slug} slot{slot}")


if __name__ == '__main__':
    main()
