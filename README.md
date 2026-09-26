# Body Atlas 3D

Interactive **real 3D** human anatomy app for Android (Godot 4.4.1). Orbit, pinch-zoom, peel layers Skin → Muscle → Organs → Skeleton, tap structures for names, and focus / go inside a procedural heart.

> Not a photoreal clinical scan — educational Z-Anatomy meshes + procedural organs.

## Controls

| Gesture / UI | Action |
|---|---|
| One-finger drag | Orbit camera |
| Pinch | Zoom |
| Two-finger drag | Pan |
| Tap a mesh | Highlight + name / note panel |
| **Skin \| Muscle \| Organs \| Skeleton** | Peel outer layers to reveal deeper |
| **Focus Heart** | Zoom to chest / heart (organs layer) |
| **Go Inside** | Heart cutaway with RA / LA / RV / LV + valve labels |
| **Overview** | Reset to full-body Skin view |
| Hotspots (Brain, Lungs, Heart, Digestion, Kidney) | Camera focus on region |
| **Credits** | Attribution |

## Layers

1. **Skin** — stylized procedural semi-opaque shell  
2. **Muscle** — Z-Anatomy / Dare-MSA `body.glb` muscle meshes  
3. **Organs** — procedural heart (chambers + valves), lungs, liver, stomach, kidneys, brain proxies; muscles peel aside  
4. **Skeleton** — bone / cartilage meshes from `body.glb`

## Attribution (CC BY-SA)

- **Z-Anatomy** — libre 3D atlas of anatomy, [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)  
- **body.glb** packaging / simplification — [Dare-MSA / hpfrei body-anatomy-3d-viewer](https://github.com/Dare-MSA/body-anatomy-3d-viewer) (CC BY-SA 4.0)  
- Lineage includes **BodyParts3D** (CC BY-SA 2.1 JP)  
- Heart chambers & organ proxies — procedural meshes created for this app  
- Skin shell — procedural capsule humanoid for peel UX  

Attribution is also shown in-app under **Credits**.

## Build

```bash
export ANDROID_HOME=/workspace/android-sdk
/home/box/.local/bin/godot --headless --path /workspace/body-atlas-3d --import
/home/box/.local/bin/godot --headless --path /workspace/body-atlas-3d \
  --export-debug "Android" /workspace/artifacts/BodyAtlas3D-debug.apk
```

- Package id: `com.sumit.bodyatlas3d`  
- Display name: **Body Atlas 3D**  
- Renderer: GL Compatibility (mobile)

## Project layout

- `assets/models/body.glb` — anatomy model (~8 MB)  
- `assets/catalog.json` — mesh name → common / anatomical / student note  
- `scripts/` — orbit camera, layer peel, picking, procedural organs, UI  
- `scenes/main.tscn` — main scene  

## Known gaps

- Organs (except heart cutaway detail) are stylized proxies, not Z-Anatomy visceral meshes (the shipped `body.glb` is muscles + bones).  
- Skin is a capsule humanoid envelope, not a scanned dermis.  
- Heart is procedural (no reliable free multi-chamber GLB was available at build time).  
- Very dense meshes: tap uses AABB + limited triangle tests — fine for study, not surgical precision.
