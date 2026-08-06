# Orni Ünite Animasyon Promptları — Level 2 (HSK 2, 24 ünite) — v1

Standart şablon: `docs/bobo_unit_animation_prompts_level1.md` (v4) + prompt hafızası
[[project-mascot-prompt-template]]. Üniteye göre değişen: Expression arc, renk
yasakları satırı, izin verilen efekt, obje-kalıcılık ve COSTUME & ACTION.

**v1 EKLENEN (2026-07-15): REFERENCE FIDELITY & FRAMING bloğu.** L2 Ü3-4-5
üreteçte BÜST/yakın-çekim + kısa/şişman gövde çıkardı (bacaklar kenardan kırpıldı),
ilk 26 tam-boy klipten büyük göründü → node'da `scale=0.74` display override ile
küçültüldü. Kalıcı çözüm: her prompt'a artık "tam boy, iki ayak görünür, ~%70 kare
yüksekliği, büst/kırpık-bacak YASAK, referans ince/uzun orantı korunur" bloğu eklenir.
Bu blok aşağıdaki TÜM prompt'lara işlendi.

Fon: hepsi YEŞİL (#00FF00) — kostüm/proplar yeşil içermiyor. Referans PNG'yi her
üretimde ekle. Efekt satırında daima "PURE WHITE, never greenish/tinted".

L2 ünite→şehir sırası (`tools/gen_l2_cities.py`): 1 Shanghai · 2 Hangzhou ·
3 Chongqing · 4 Dalian · 5 Shenyang · 6 Hefei · 7 Foshan · 8 Guiyang · …

Durum: Ü1-Ü2 (2026-07-14) ve Ü3-Ü5 (2026-07-15, scale 0.74) yüklü. Ü6-Ü8 prompt
hazır, video bekliyor. İşleme: `python tools/process_mascot_video.py <video.mp4> --upload 2 <U>`.

---

## Unit 3 — Chongqing (Acılı Hotpot) — YEŞİL FON

```
Use the attached reference image as the EXACT character model: a chubby turquoise-teal cartoon platypus with a large orange duck bill, big round glossy black eyes with white sparkle highlights, rosy pink blush cheeks, dark brown webbed hands and feet, a flat teal tail, bold black outlines, flat 2D cel-shaded children's-sticker style. The character's body shape, proportions, colors, face, eyes, bill, blush, hands, feet and tail must stay 100% IDENTICAL to the reference in every frame — never redraw, restyle, recolor or re-proportion the character; only ADD the costume and props described below. PAY SPECIAL ATTENTION to the limb colors: the webbed HANDS and webbed FEET are DARK BROWN and must keep exactly this same dark brown color in every single frame of the video — they must never fade, lighten, change hue, or turn teal/turquoise like the body, no matter the pose, motion or lighting.

REFERENCE FIDELITY & FRAMING — CRITICAL: keep the reference's exact build and proportions — a fairly TALL, SLIM standing figure; do NOT make the character shorter, rounder, chunkier or bigger-headed than the reference. Frame the FULL BODY from the top of the head down to BOTH webbed feet, with a clear band of empty green background below the feet and above the head; the character stands small and centered and occupies AT MOST about 70% of the frame height. NEVER use a bust shot, a close-up, or any framing where the legs or feet are cropped by the frame edge.

ANATOMY — ABSOLUTE: the character has EXACTLY TWO arms with TWO hands and EXACTLY TWO legs with TWO feet in every single frame of the video. NO third hand, NO extra arm, NO duplicated, detached or disembodied limb may EVER appear — not from behind the body, not from behind the bowl, not from off-screen, not during any transition. There is only ONE prop in the whole video (the hotpot bowl) and BOTH hands hold it together the entire time — no hand ever lets go, reaches elsewhere or appears anywhere except on the bowl.

MOTION & LIFE — hand-animated cartoon feel, NEVER robotic:
- Soft, bouncy, organic 2D animation with gentle squash-and-stretch and ease-in/ease-out on every movement; no linear, stiff, mechanical or puppet-like motion, no frozen poses.
- The whole body participates: the round belly bounces subtly, the tail sways, the head tilts, and the arms follow through and settle naturally after each gesture.
- The face is ALIVE the whole time: the character blinks softly every 1–2 seconds, the eyes and brows react to the action, and the bill changes shape with the mood — always staying exactly on-model with the reference face.
- Expression arc: eager foodie delight with a comic spicy kick — it licks its bill before the sip, eyes squeeze shut in blissful "mmm" at the slurp, then pop WIDE as the numbing spice lands, cheeks flush a touch deeper with a single bead of sweat, softening into a happy satisfied sigh.

SCENE RULES — STRICT:
- The character is completely ALONE on a solid, perfectly uniform, evenly lit pure chroma-key green background (#00FF00) — one flat color across the entire frame, no gradient, no vignette, no texture; the background never changes.
- ABSOLUTELY NO shadows: no drop shadow, no contact shadow under the character, no shading, glow or reflection on the background — every background pixel stays pure #00FF00 — and no green light spill on the character or props.
- The costume and prop contain NO green or greenish colors: the diner bib is red-and-white checkered, the hotpot bowl is dark reddish clay and holds a bright bubbling red chili broth with floating red chili slices and tiny brown peppercorns — NO scallions, NO green herbs, no green anywhere.
- NO scenery, NO table, NO stove, NO kitchen, NO buildings, NO floor line, NO ground, NO horizon, NO other characters or animals, NO text, NO frame or border. Only allowed effect: two or three tiny PURE WHITE steam wisps rising from the broth and fading quickly — pure white, never greenish or tinted.
- Full body always fully visible and centered, nothing cropped; both feet and the bowl never touch the frame edges.
- OUTPUT FORMAT: 16:9 LANDSCAPE video (e.g. 1280x720). The character stands in the CENTER with generous empty green margin on ALL four sides — the body, arms, tail and the whole bowl stay far from the frame edges in every frame; nothing is ever cropped by the frame.
- The character is ANCHORED to a single spot for the entire animation: it never walks forward, travels, slides sideways, jumps away or drifts across the frame; every movement is performed standing in place and its feet always return to the same spot.
- OBJECT PERMANENCE & PHYSICS: the hotpot bowl stays held in BOTH hands near the bill for the ENTIRE video — it never leaves the hands, tips over, empties, spills, duplicates or changes size; the red broth stays in the bowl. Only the white steam wisps may fade in and out, rising from the broth, never popping out of empty space. Nothing else appears or vanishes; props move ONLY because the character moves them, with natural weight, gravity and follow-through.
- Camera completely STATIC: no zoom, no pan, no rotation, no shake.
- 4-second SEAMLESS LOOP: first and last frames identical, continuous motion, no jump cut. Gentle, cute, kids-app friendly.
- Completely SILENT video: NO music, NO sound effects, NO voice, NO audio of any kind.

COSTUME & ACTION: The platypus wears a small red-and-white checkered diner bib and cradles a steaming red Chongqing hotpot bowl in BOTH hands at bill level. Standing full-body in one fixed spot it blows gently across the bubbling broth, takes a happy little slurp, freezes for a beat as the numbing spice hits — eyes wide and watery, blush deepening, one bead of sweat — then relaxes into a satisfied grin and lifts the bowl for the next blow; feet planted, the bowl never leaving both hands. Blow, slurp, spice-kick, sigh: one cycle per loop.
```

## Unit 4 — Dalian (Futbol Şehri) — YEŞİL FON

```
Use the attached reference image as the EXACT character model: a chubby turquoise-teal cartoon platypus with a large orange duck bill, big round glossy black eyes with white sparkle highlights, rosy pink blush cheeks, dark brown webbed hands and feet, a flat teal tail, bold black outlines, flat 2D cel-shaded children's-sticker style. The character's body shape, proportions, colors, face, eyes, bill, blush, hands, feet and tail must stay 100% IDENTICAL to the reference in every frame — never redraw, restyle, recolor or re-proportion the character; only ADD the costume and props described below. PAY SPECIAL ATTENTION to the limb colors: the webbed HANDS and webbed FEET are DARK BROWN and must keep exactly this same dark brown color in every single frame of the video — they must never fade, lighten, change hue, or turn teal/turquoise like the body, no matter the pose, motion or lighting.

REFERENCE FIDELITY & FRAMING — CRITICAL: keep the reference's exact build and proportions — a fairly TALL, SLIM standing figure; do NOT make the character shorter, rounder, chunkier or bigger-headed than the reference. Frame the FULL BODY from the top of the head down to BOTH webbed feet, with a clear band of empty green background below the feet and above the head; the character stands small and centered and occupies AT MOST about 70% of the frame height. NEVER use a bust shot, a close-up, or any framing where the legs or feet are cropped by the frame edge.

ANATOMY — ABSOLUTE: the character has EXACTLY TWO arms with TWO hands and EXACTLY TWO legs with TWO feet in every single frame of the video. NO third hand, NO extra arm, NO third leg, NO duplicated, detached or disembodied limb may EVER appear — not from behind the body, not from off-screen, not during any transition. There is only ONE prop in the whole video (the football); the hands NEVER hold it — they stay free for balance — and the ball is touched only by the feet, knee and head. Only ONE foot taps the ball at a time while the other foot stays planted; there is never an extra foot or leg.

MOTION & LIFE — hand-animated cartoon feel, NEVER robotic:
- Soft, bouncy, organic 2D animation with gentle squash-and-stretch and ease-in/ease-out on every movement; no linear, stiff, mechanical or puppet-like motion, no frozen poses.
- The whole body participates: the round belly bounces subtly, the tail sways for counter-balance, the head tilts, and the arms follow through and settle naturally after each gesture.
- The face is ALIVE the whole time: the character blinks softly every 1–2 seconds, the eyes and brows react to the action, and the bill changes shape with the mood — always staying exactly on-model with the reference face.
- Expression arc: sporty focused joy — eyes track the ball up and down, a tongue-tip of concentration, brows lifting into a triumphant open-bill grin and a proud little eyebrow pump each time it keeps the ball aloft.

SCENE RULES — STRICT:
- The character is completely ALONE on a solid, perfectly uniform, evenly lit pure chroma-key green background (#00FF00) — one flat color across the entire frame, no gradient, no vignette, no texture; the background never changes.
- ABSOLUTELY NO shadows: no drop shadow, no contact shadow under the character, no shading, glow or reflection on the background — every background pixel stays pure #00FF00 — and no green light spill on the character or props.
- The costume and prop contain NO green or greenish colors: the football jersey is bright blue with white trim and white shorts, the football is a classic black-and-white pentagon-panel ball — no green anywhere on the kit or the ball.
- NO scenery, NO pitch, NO grass, NO field lines, NO goal, NO net, NO stadium, NO buildings, NO floor line, NO ground, NO horizon, NO other characters or animals, NO text, NO frame or border. NO extra effects: no motion lines, no sparkles, no dust.
- Full body always fully visible and centered, nothing cropped; both feet and the ball at its highest bounce never touch the frame edges.
- OUTPUT FORMAT: 16:9 LANDSCAPE video (e.g. 1280x720). The character stands in the CENTER with generous empty green margin on ALL four sides — the body, arms, tail and the ball's full bounce arc stay far from the frame edges in every frame; nothing is ever cropped by the frame.
- The character is ANCHORED to a single spot for the entire animation: it never walks forward, travels, slides sideways, jumps away or drifts across the frame; the juggling is done standing in place and its feet always return to the same spot.
- OBJECT PERMANENCE & PHYSICS: the football is the ONLY prop and stays in one continuous, physically believable juggling arc — bouncing between the character's foot, knee and head and back — obeying gravity and momentum (it eases up and eases down, never snaps); it never teleports, hovers, freezes mid-air, duplicates, disappears or changes size, and it never leaves the small space right in front of the character. The jersey stays on the body; nothing else appears or vanishes.
- Camera completely STATIC: no zoom, no pan, no rotation, no shake.
- 4-second SEAMLESS LOOP: first and last frames identical, continuous motion, no jump cut — the ball returns to the exact same height and position it started. Gentle, cute, kids-app friendly.
- Completely SILENT video: NO music, NO sound effects, NO voice, NO audio of any kind.

COSTUME & ACTION: The platypus wears a bright blue football jersey with white trim and white shorts and juggles a classic black-and-white football, keeping it aloft with light taps of one webbed foot, a soft bounce off the knee and a gentle header — arms out for balance, belly bouncing, tail counter-swinging — never moving from its spot, the planted foot always returning to the same place. Foot-tap, knee, header: one seamless juggling cycle per loop.
```

## Unit 5 — Shenyang (Mukden Sarayı / Qing Memuru) — YEŞİL FON

```
Use the attached reference image as the EXACT character model: a chubby turquoise-teal cartoon platypus with a large orange duck bill, big round glossy black eyes with white sparkle highlights, rosy pink blush cheeks, dark brown webbed hands and feet, a flat teal tail, bold black outlines, flat 2D cel-shaded children's-sticker style. The character's body shape, proportions, colors, face, eyes, bill, blush, hands, feet and tail must stay 100% IDENTICAL to the reference in every frame — never redraw, restyle, recolor or re-proportion the character; only ADD the costume described below. PAY SPECIAL ATTENTION to the limb colors: the webbed HANDS and webbed FEET are DARK BROWN and must keep exactly this same dark brown color in every single frame of the video — they must never fade, lighten, change hue, or turn teal/turquoise like the body, no matter the pose, motion or lighting.

REFERENCE FIDELITY & FRAMING — CRITICAL: keep the reference's exact build and proportions — a fairly TALL, SLIM standing figure; do NOT make the character shorter, rounder, chunkier or bigger-headed than the reference. Frame the FULL BODY from the top of the head down to BOTH webbed feet, with a clear band of empty green background below the feet and above the head; the character stands small and centered and occupies AT MOST about 70% of the frame height. NEVER use a bust shot, a close-up, or any framing where the legs or feet are cropped by the frame edge.

ANATOMY — ABSOLUTE: the character has EXACTLY TWO arms with TWO hands and EXACTLY TWO legs with TWO feet in every single frame of the video. NO third hand, NO extra arm, NO duplicated, detached or disembodied limb may EVER appear — not from behind the body, not from behind the sleeves, not from off-screen, not during any transition. There is NO prop at all in this video: both hands stay empty the entire time and only come together for the greeting gesture; they never hold, clone or spawn anything.

MOTION & LIFE — hand-animated cartoon feel, NEVER robotic:
- Soft, bouncy, organic 2D animation with gentle squash-and-stretch and ease-in/ease-out on every movement; no linear, stiff, mechanical or puppet-like motion, no frozen poses.
- The whole body participates: the round belly bounces subtly, the tail sways, the head tilts, and the arms follow through and settle naturally after each gesture.
- The face is ALIVE the whole time: the character blinks softly every 1–2 seconds, the eyes and brows react to the action, and the bill changes shape with the mood — always staying exactly on-model with the reference face.
- Expression arc: dignified imperial pride softening into warmth — chin lifted with a regal little smile and calm noble eyes, closing into a gracious closed-eye smile at the bottom of the bow, then reopening bright and welcoming as it rises.

SCENE RULES — STRICT:
- The character is completely ALONE on a solid, perfectly uniform, evenly lit pure chroma-key green background (#00FF00) — one flat color across the entire frame, no gradient, no vignette, no texture; the background never changes.
- ABSOLUTELY NO shadows: no drop shadow, no contact shadow under the character, no shading, glow or reflection on the background — every background pixel stays pure #00FF00 — and no green light spill on the character or costume.
- The costume contains NO green or greenish colors: the Qing court hat is black-domed with a red top-knot and red tassel and a single peacock-feather plume, the mandarin robe is deep imperial navy blue with a gold-embroidered square rank badge on the chest and white "horse-hoof" cuffs — no green anywhere.
- NO scenery, NO palace, NO throne, NO pillars, NO buildings, NO floor line, NO ground, NO horizon, NO other characters or animals, NO text, NO frame or border. NO extra effects: no sparkles, no stars, no motion lines.
- Full body always fully visible and centered, nothing cropped; both feet and the robe never touch the frame edges.
- OUTPUT FORMAT: 16:9 LANDSCAPE video (e.g. 1280x720). The character stands in the CENTER with generous empty green margin on ALL four sides — the body, arms, tail, hat plume and robe hem stay far from the frame edges in every frame; nothing is ever cropped by the frame.
- The character is ANCHORED to a single spot for the entire animation: it never walks forward, travels, slides sideways, jumps away or drifts across the frame; the bow is performed standing in place and its feet always return to the same spot.
- OBJECT PERMANENCE & PHYSICS: no prop exists to appear or vanish; the hat stays on the head and the robe stays on the body the ENTIRE video — nothing suddenly appears, disappears, duplicates, morphs or changes size. The red hat tassel, peacock plume and white sleeve cuffs swing and settle with natural cloth weight, gravity and follow-through as the character bows.
- Camera completely STATIC: no zoom, no pan, no rotation, no shake.
- 4-second SEAMLESS LOOP: first and last frames identical, continuous motion, no jump cut. Gentle, cute, kids-app friendly.
- Completely SILENT video: NO music, NO sound effects, NO voice, NO audio of any kind.

COSTUME & ACTION: The platypus wears the court dress of a Qing-dynasty official from Mukden Palace — a black domed hat with a red top-knot, red tassel and a single peacock feather, and a deep navy mandarin robe with a gold-embroidered square rank badge and white horse-hoof cuffs. Standing full-body in one fixed spot it performs the traditional Chinese fist-in-palm greeting (gong shou): it clasps one webbed hand over the other fist in front of its chest and bows forward respectfully, then rises with a warm welcoming smile — the hat tassel, feather plume and sleeve cuffs swinging and settling naturally, feet planted throughout. One greet-and-bow cycle per loop.
```

## Unit 6 — Hefei (Yargıç Bao / Bao Gong) — YEŞİL FON

```
Use the attached reference image as the EXACT character model: a chubby turquoise-teal cartoon platypus with a large orange duck bill, big round glossy black eyes with white sparkle highlights, rosy pink blush cheeks, dark brown webbed hands and feet, a flat teal tail, bold black outlines, flat 2D cel-shaded children's-sticker style. The character's body shape, proportions, colors, face, eyes, bill, blush, hands, feet and tail must stay 100% IDENTICAL to the reference in every frame — never redraw, restyle, recolor or re-proportion the character; only ADD the costume and prop described below. PAY SPECIAL ATTENTION to the limb colors: the webbed HANDS and webbed FEET are DARK BROWN and must keep exactly this same dark brown color in every single frame of the video — they must never fade, lighten, change hue, or turn teal/turquoise like the body, no matter the pose, motion or lighting.

REFERENCE FIDELITY & FRAMING — CRITICAL: keep the reference's exact build and proportions — a fairly TALL, SLIM standing figure; do NOT make the character shorter, rounder, chunkier or bigger-headed than the reference. Frame the FULL BODY from the top of the head down to BOTH webbed feet, with a clear band of empty green background below the feet and above the head; the character stands small and centered and occupies AT MOST about 70% of the frame height. NEVER use a bust shot, a close-up, or any framing where the legs or feet are cropped by the frame edge.

ANATOMY — ABSOLUTE: the character has EXACTLY TWO arms with TWO hands and EXACTLY TWO legs with TWO feet in every single frame of the video. NO third hand, NO extra arm, NO duplicated, detached or disembodied limb may EVER appear — not from behind the body, not from behind the sleeves, not from off-screen, not during any transition. There is only ONE prop in the whole video (the wooden gavel block); it is held in ONE hand the entire time and never swaps hands, clones or disappears; the other hand stays empty and open.

MOTION & LIFE — hand-animated cartoon feel, NEVER robotic:
- Soft, bouncy, organic 2D animation with gentle squash-and-stretch and ease-in/ease-out on every movement; no linear, stiff, mechanical or puppet-like motion, no frozen poses.
- The whole body participates: the round belly bounces subtly, the tail sways, the head tilts, and the arms follow through and settle naturally after each gesture.
- The face is ALIVE the whole time: the character blinks softly every 1–2 seconds, the eyes and brows react to the action, and the bill changes shape with the mood — always staying exactly on-model with the reference face.
- Expression arc: solemn upright-judge authority — brows knit in stern focus as the gavel rises, a firm decisive look at the tap, softening into a proud, fair little smile as justice is served.

SCENE RULES — STRICT:
- The character is completely ALONE on a solid, perfectly uniform, evenly lit pure chroma-key green background (#00FF00) — one flat color across the entire frame, no gradient, no vignette, no texture; the background never changes.
- ABSOLUTELY NO shadows: no drop shadow, no contact shadow under the character, no shading, glow or reflection on the background — every background pixel stays pure #00FF00 — and no green light spill on the character or prop.
- The costume and prop contain NO green or greenish colors: the judge's cap and official robe are deep black with gold trim, the crescent-moon mark on the forehead is pale ivory-white, the gavel block is warm brown wood.
- NO scenery, NO courtroom, NO desk, NO buildings, NO floor line, NO ground, NO horizon, NO other characters or animals, NO text, NO frame or border. Only allowed effect: a tiny PURE WHITE impact spark at the gavel tap that fades quickly — pure white, never greenish or tinted.
- Full body always fully visible and centered, nothing cropped; both feet and the whole robe stay well inside the frame and never touch the frame edges.
- OUTPUT FORMAT: 16:9 LANDSCAPE video (e.g. 1280x720). The character stands in the CENTER with generous empty green margin on ALL four sides — the body, arms, tail, cap wings and robe hem stay far from the frame edges in every frame; nothing is ever cropped by the frame.
- The character is ANCHORED to a single spot for the entire animation: it never walks forward, travels, slides sideways, jumps away or drifts across the frame; every movement is performed standing in place and its feet always return to the same spot.
- OBJECT PERMANENCE & PHYSICS: the cap stays on the head and the robe on the body the ENTIRE video; the wooden gavel stays in the same one hand and moves only along the arc that hand swings, with natural weight and momentum — it never teleports, duplicates, disappears or changes size. Only the white impact spark may fade in and out, exactly where the gavel meets the palm, never in empty space.
- Camera completely STATIC: no zoom, no pan, no rotation, no shake.
- 4-second SEAMLESS LOOP: first and last frames identical, continuous motion, no jump cut. Gentle, cute, kids-app friendly.
- Completely SILENT video: NO music, NO sound effects, NO voice, NO audio of any kind.

COSTUME & ACTION: The platypus is dressed as Lord Bao, the legendary upright Chinese judge — a black Song-dynasty gauze judge's cap with long flat horizontal side-wings, a black gold-trimmed official robe, and the iconic pale crescent-moon mark on its forehead. Standing full-body in one fixed spot it holds a small brown wooden gavel block in one hand, raises it with a stern focused look and taps it decisively down into its other open palm — a tiny white spark flashes — then gives a firm righteous nod that melts into a proud fair smile; the cap's side-wings and robe bob with the motion, feet planted. Raise, tap, nod: one verdict cycle per loop.
```

## Unit 7 — Foshan (Aslan Dansı) — YEŞİL FON

```
Use the attached reference image as the EXACT character model: a chubby turquoise-teal cartoon platypus with a large orange duck bill, big round glossy black eyes with white sparkle highlights, rosy pink blush cheeks, dark brown webbed hands and feet, a flat teal tail, bold black outlines, flat 2D cel-shaded children's-sticker style. The character's body shape, proportions, colors, face, eyes, bill, blush, hands, feet and tail must stay 100% IDENTICAL to the reference in every frame — never redraw, restyle, recolor or re-proportion the character; only ADD the costume and prop described below. PAY SPECIAL ATTENTION to the limb colors: the webbed HANDS and webbed FEET are DARK BROWN and must keep exactly this same dark brown color in every single frame of the video — they must never fade, lighten, change hue, or turn teal/turquoise like the body, no matter the pose, motion or lighting.

REFERENCE FIDELITY & FRAMING — CRITICAL: keep the reference's exact build and proportions — a fairly TALL, SLIM standing figure; do NOT make the character shorter, rounder, chunkier or bigger-headed than the reference. Frame the FULL BODY from the top of the head down to BOTH webbed feet, with a clear band of empty green background below the feet and above the head; the character stands small and centered and occupies AT MOST about 70% of the frame height. NEVER use a bust shot, a close-up, or any framing where the legs or feet are cropped by the frame edge.

ANATOMY — ABSOLUTE: the character has EXACTLY TWO arms with TWO hands and EXACTLY TWO legs with TWO feet in every single frame of the video. NO third hand, NO extra arm, NO duplicated, detached or disembodied limb may EVER appear — not from behind the body, not from behind the lion head, not from off-screen, not during any transition. There is only ONE prop in the whole video (the lion-dance head puppet) and BOTH hands hold its base together the entire time — no hand ever lets go, reaches elsewhere or appears anywhere except on the puppet. CRITICAL: the lion-dance head is a SEPARATE hand-held puppet; the platypus's OWN face stays fully visible, on-model and never hidden or replaced by the lion — the lion head is held up in front of the chest, not over the platypus's face.

MOTION & LIFE — hand-animated cartoon feel, NEVER robotic:
- Soft, bouncy, organic 2D animation with gentle squash-and-stretch and ease-in/ease-out on every movement; no linear, stiff, mechanical or puppet-like motion, no frozen poses.
- The whole body participates: the round belly bounces subtly, the tail sways, the head tilts, and the arms follow through and settle naturally after each gesture.
- The face is ALIVE the whole time: the character blinks softly every 1–2 seconds, the eyes and brows react to the action, and the bill changes shape with the mood — always staying exactly on-model with the reference face.
- Expression arc: gleeful festival excitement — a big proud open-bill grin, eyes bright and playful, bouncing along happily each time the lion head bobs and its mouth snaps open.

SCENE RULES — STRICT:
- The character is completely ALONE on a solid, perfectly uniform, evenly lit pure chroma-key green background (#00FF00) — one flat color across the entire frame, no gradient, no vignette, no texture; the background never changes.
- ABSOLUTELY NO shadows: no drop shadow, no contact shadow under the character, no shading, glow or reflection on the background — every background pixel stays pure #00FF00 — and no green light spill on the character or prop.
- The costume and prop contain NO green or greenish colors: the Foshan lion-dance head is bright red, gold and white with fluffy white fur trim, round mirror-gold eyes and a red pom-pom, and the platypus wears a small matching red-and-gold sash; no green anywhere.
- NO scenery, NO stage, NO drums, NO poles, NO buildings, NO floor line, NO ground, NO horizon, NO other characters or animals, NO text, NO frame or border. NO extra effects: no confetti, no sparkles, no motion lines.
- Full body always fully visible and centered, nothing cropped; both feet, the tail and the whole lion head stay well inside the frame and never touch the frame edges.
- OUTPUT FORMAT: 16:9 LANDSCAPE video (e.g. 1280x720). The character stands in the CENTER with generous empty green margin on ALL four sides — the body, arms, tail and the full lion-dance head stay far from the frame edges in every frame; nothing is ever cropped by the frame.
- The character is ANCHORED to a single spot for the entire animation: it never walks forward, travels, slides sideways, jumps away or drifts across the frame; every movement is performed standing in place and its feet always return to the same spot.
- OBJECT PERMANENCE & PHYSICS: the lion-dance head stays held in BOTH hands in front of the chest for the ENTIRE video — it never detaches, floats on its own, disappears, duplicates or changes size, and it never covers the platypus's face; its only motion is a lively bob and a mouth that opens and closes because the hands work it, with believable weight and momentum. The sash stays tied on the body; nothing else appears or vanishes.
- Camera completely STATIC: no zoom, no pan, no rotation, no shake.
- 4-second SEAMLESS LOOP: first and last frames identical, continuous motion, no jump cut. Gentle, cute, kids-app friendly.
- Completely SILENT video: NO music, NO sound effects, NO voice, NO audio of any kind.

COSTUME & ACTION: The platypus wears a small red-and-gold sash and holds up a colorful Foshan lion-dance head puppet — bright red, gold and white with fluffy fur trim, big round mirror eyes and a red pom-pom — gripping its base with BOTH hands in front of its chest, its own face fully visible and grinning above the puppet. Standing full-body in one fixed spot it makes the lion head bob up and down and snap its mouth open and shut in a lively festive rhythm, bouncing and swaying along, feet planted, the lion head never covering its face. Bob, mouth-open, sway: one lively cycle per loop.
```

## Unit 8 — Guiyang (Miao Gümüş Başlık Dansı) — YEŞİL FON

```
Use the attached reference image as the EXACT character model: a chubby turquoise-teal cartoon platypus with a large orange duck bill, big round glossy black eyes with white sparkle highlights, rosy pink blush cheeks, dark brown webbed hands and feet, a flat teal tail, bold black outlines, flat 2D cel-shaded children's-sticker style. The character's body shape, proportions, colors, face, eyes, bill, blush, hands, feet and tail must stay 100% IDENTICAL to the reference in every frame — never redraw, restyle, recolor or re-proportion the character; only ADD the costume described below. PAY SPECIAL ATTENTION to the limb colors: the webbed HANDS and webbed FEET are DARK BROWN and must keep exactly this same dark brown color in every single frame of the video — they must never fade, lighten, change hue, or turn teal/turquoise like the body, no matter the pose, motion or lighting.

REFERENCE FIDELITY & FRAMING — CRITICAL: keep the reference's exact build and proportions — a fairly TALL, SLIM standing figure; do NOT make the character shorter, rounder, chunkier or bigger-headed than the reference. Frame the FULL BODY from the top of the head (and silver crown) down to BOTH webbed feet, with a clear band of empty green background below the feet and above the crown; the character stands small and centered and occupies AT MOST about 70% of the frame height. NEVER use a bust shot, a close-up, or any framing where the legs or feet are cropped by the frame edge.

ANATOMY — ABSOLUTE: the character has EXACTLY TWO arms with TWO hands and EXACTLY TWO legs with TWO feet in every single frame of the video. NO third hand, NO extra arm, NO duplicated, detached or disembodied limb may EVER appear — not from behind the body, not from behind the sleeves, not from off-screen, not during any transition. There is NO prop at all in this video: both hands stay empty the entire time and move only for the dance; they never hold, clone or spawn anything.

MOTION & LIFE — hand-animated cartoon feel, NEVER robotic:
- Soft, bouncy, organic 2D animation with gentle squash-and-stretch and ease-in/ease-out on every movement; no linear, stiff, mechanical or puppet-like motion, no frozen poses.
- The whole body participates: the round belly bounces subtly, the tail sways, the head tilts, and the arms follow through and settle naturally after each gesture.
- The face is ALIVE the whole time: the character blinks softly every 1–2 seconds, the eyes and brows react to the action, and the bill changes shape with the mood — always staying exactly on-model with the reference face.
- Expression arc: graceful festive joy — a serene proud smile, eyes soft and happy, a gentle delighted tilt of the head each time the silver crown shimmers, lifting into a bright beam at the turn.

SCENE RULES — STRICT:
- The character is completely ALONE on a solid, perfectly uniform, evenly lit pure chroma-key green background (#00FF00) — one flat color across the entire frame, no gradient, no vignette, no texture; the background never changes.
- ABSOLUTELY NO shadows: no drop shadow, no contact shadow under the character, no shading, glow or reflection on the background — every background pixel stays pure #00FF00 — and no green light spill on the character or costume.
- The costume contains NO green or greenish colors: the tall horned Miao headdress and neck rings are bright polished SILVER, the dress is deep indigo blue with red, pink and white geometric embroidery; no green anywhere.
- NO scenery, NO village, NO stage, NO buildings, NO floor line, NO ground, NO horizon, NO other characters or animals, NO text, NO frame or border. Only allowed effect: two or three tiny PURE WHITE sparkles glinting off the silver crown and fading quickly — pure white, never greenish or tinted.
- Full body always fully visible and centered, nothing cropped; both feet, the tall silver crown and the dress hem stay well inside the frame and never touch the frame edges.
- OUTPUT FORMAT: 16:9 LANDSCAPE video (e.g. 1280x720). The character stands in the CENTER with generous empty green margin on ALL four sides — the body, arms, tail, silver crown and dress stay far from the frame edges in every frame; nothing is ever cropped by the frame.
- The character is ANCHORED to a single spot for the entire animation: it never walks forward, travels, slides sideways, jumps away or drifts across the frame; every movement is performed standing in place and its feet always return to the same spot.
- OBJECT PERMANENCE & PHYSICS: the silver crown stays on the head, the neck rings on the neck and the dress on the body the ENTIRE video — nothing suddenly appears, disappears, duplicates, morphs or changes size; the crown's horns and the dangling silver ornaments sway and settle with natural weight and momentum as the character dances. Only the white sparkles may fade in and out, glinting off the silver, never popping out of empty space.
- Camera completely STATIC: no zoom, no pan, no rotation, no shake.
- 4-second SEAMLESS LOOP: first and last frames identical, continuous motion, no jump cut. Gentle, cute, kids-app friendly.
- Completely SILENT video: NO music, NO sound effects, NO voice, NO audio of any kind.

COSTUME & ACTION: The platypus is dressed in Miao festival costume — a tall, ornate horned SILVER headdress with dangling silver ornaments, layered silver neck rings, and a deep indigo dress with bright red-pink-white geometric embroidery. Standing full-body in one fixed spot it performs a graceful Miao dance: it sways side to side, turns its wrists in soft flowing arcs and gives a gentle spin-tilt of the upper body, the silver crown and ornaments shimmering with tiny white sparkles — feet stepping lightly in place and always returning to the same spot. Sway, wrist-turn, shimmer: one graceful cycle per loop.
```
