// Rendu d'aperçu d'un personnage : planche face / 3-4 / dos + portrait, ou portrait seul.
//
//   lune run assets/visuals/export-characters -- --json /tmp/bc-json
//   cd assets/visuals/preview && npm install
//   node render.mjs /tmp/bc-json/B09_Cherry_Look01.json ../previews/B09_Cherry_Look01.png "BADDIE — CHERRY SUMMER"
//   node render.mjs --portrait /tmp/bc-json/B09_Cherry_Look01.json ../portraits/B09_Cherry_Look01.png
//
// Les pièces Roblox (bloc, boule, cylindre, ellipsoïde SpecialMesh, coin) sont redessinées avec three.js
// dans Chromium sans écran : ce n'est qu'un aperçu, la référence reste le rendu dans Studio.
import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";

const require = createRequire(import.meta.url);
const { chromium } = require("playwright");
const args = process.argv.slice(2);
const portrait = args[0] === "--portrait";
const lineup = args[0] === "--lineup";
if (portrait || lineup) args.shift();
// --lineup <out.png> <a.json> <b.json> … : tous les modèles côte à côte, de face
const [jsonPath, outPath, title = ""] = lineup ? [args[1], args[0]] : args;
if (!jsonPath || !outPath) {
  console.error("usage: node render.mjs [--portrait] <model.json> <out.png> [titre]\n       node render.mjs --lineup <out.png> <a.json> <b.json> …");
  process.exit(1);
}
const lineupFiles = lineup ? args.slice(1) : [];
const COLS = Math.min(lineupFiles.length, 9) || 1;
const ROWS = Math.ceil(lineupFiles.length / COLS) || 1;
const SPACING = 3.1;
const ROW_DEPTH = 7.2;
let parts = JSON.parse(fs.readFileSync(jsonPath, "utf8"));
const lineupNames = [];
if (lineup) {
  parts = [];
  lineupFiles.forEach((file, i) => {
    const col = i % COLS, row = Math.floor(i / COLS);
    const dx = -(col - (COLS - 1) / 2) * SPACING, dy = -row * ROW_DEPTH; // +X est à gauche de l'image
    lineupNames.push(path.basename(file, ".json"));
    for (const p of JSON.parse(fs.readFileSync(file, "utf8"))) {
      const cf = p.cf.slice(); cf[0] += dx; cf[1] += dy;
      parts.push({ ...p, cf });
    }
  });
}
const threePath = path.join(path.dirname(require.resolve("three")), "three.min.js");
const W = portrait ? 512 : lineup ? COLS * 200 : 1536;
const H = portrait ? 512 : lineup ? ROWS * 430 : 1024;

const html = `<!doctype html><html><body style="margin:0;background:#bdb6b8;overflow:hidden">
<canvas id="c" width="${W}" height="${H}" style="display:block"></canvas>
<div id="labels" style="position:absolute;inset:0;font:italic 900 30px Arial Black,Arial,sans-serif;color:#2b2b2e"></div>
</body></html>`;

const browser = await chromium.launch({ args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"] });
const page = await browser.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: 1 });
page.on("console", (m) => { if (m.type() === "error") console.error("[page]", m.text()); });
await page.setContent(html);
await page.addScriptTag({ path: threePath });
await page.evaluate(({ parts, portrait, lineup, lineupNames, COLS, ROWS, SPACING, ROW_DEPTH, title, W, H }) => {
  const THREE = window.THREE;
  const canvas = document.getElementById("c");
  const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, preserveDrawingBuffer: true });
  renderer.setSize(W, H, false);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  const scene = new THREE.Scene();
  const bg = new THREE.Color("#bdb6b8");
  renderer.setClearColor(bg);

  const sphere = new THREE.SphereGeometry(0.5, 40, 28);
  const box = new THREE.BoxGeometry(1, 1, 1);
  const cyl = new THREE.CylinderGeometry(0.5, 0.5, 1, 40);
  cyl.rotateZ(Math.PI / 2); // axe X, comme un cylindre Roblox
  const wedge = new THREE.BufferGeometry();
  // WedgePart Roblox : pente montant vers +Z, face verticale à +Z
  const v = [-0.5,-0.5,-0.5, 0.5,-0.5,-0.5, 0.5,-0.5,0.5, -0.5,-0.5,0.5, -0.5,0.5,0.5, 0.5,0.5,0.5];
  wedge.setAttribute("position", new THREE.Float32BufferAttribute(v, 3));
  wedge.setIndex([0,1,2, 0,2,3, 3,2,5, 3,5,4, 0,4,5, 0,5,1, 0,3,4, 1,5,2]);
  wedge.computeVertexNormals();

  let minY = Infinity, maxY = -Infinity;
  for (const p of parts) {
    const [sx, sy, sz] = p.size;
    let geometry = box, scale = [sx, sy, sz];
    if (p.shape === "ball") { const d = Math.min(sx, sy, sz); geometry = sphere; scale = [d, d, d]; }
    else if (p.shape === "ell") { geometry = sphere; }
    else if (p.shape === "cyl") { const d = Math.min(sy, sz); geometry = cyl; scale = [sx, d, d]; }
    else if (p.shape === "wedge") { geometry = wedge; }
    const color = new THREE.Color(p.color);
    const material = p.neon
      ? new THREE.MeshBasicMaterial({ color })
      : new THREE.MeshStandardMaterial({ color, roughness: p.metal ? 0.3 : 0.62, metalness: p.metal ? 0.7 : 0.0, transparent: p.transparency > 0, opacity: 1 - p.transparency });
    const mesh = new THREE.Mesh(geometry, material);
    const c = p.cf;
    const m = new THREE.Matrix4().set(c[3], c[4], c[5], c[0], c[6], c[7], c[8], c[1], c[9], c[10], c[11], c[2], 0, 0, 0, 1);
    m.multiply(new THREE.Matrix4().makeScale(scale[0], scale[1], scale[2]));
    mesh.matrixAutoUpdate = false;
    mesh.matrix.copy(m);
    mesh.castShadow = true;
    mesh.receiveShadow = true;
    scene.add(mesh);
    const r = Math.max(sx, sy, sz) / 2;
    minY = Math.min(minY, c[1] - r); maxY = Math.max(maxY, c[1] + r);
  }
  const floorY = 0; // pieds à Y = 0 (repère du builder)
  const ground = new THREE.Mesh(new THREE.PlaneGeometry(200, 200), new THREE.ShadowMaterial({ opacity: 0.22 }));
  ground.rotation.x = -Math.PI / 2; ground.position.y = floorY; ground.receiveShadow = true;
  scene.add(ground);

  scene.add(new THREE.HemisphereLight(0xffffff, 0x8f8a92, 1.15));
  const key = new THREE.DirectionalLight(0xfff4ea, 1.9);
  key.castShadow = true; key.shadow.mapSize.set(2048, 2048);
  key.shadow.camera.left = -6; key.shadow.camera.right = 6; key.shadow.camera.top = 8; key.shadow.camera.bottom = -4;
  key.shadow.bias = -0.0015; key.shadow.normalBias = 0.02;
  scene.add(key); scene.add(key.target);
  const fill = new THREE.DirectionalLight(0xdfe6ff, 0.55);
  scene.add(fill); scene.add(fill.target);

  function view(x, y, w, h, azimuthDeg, target, distance, fov, elevation = 0.04) {
    const camera = new THREE.PerspectiveCamera(fov, w / h, 0.1, 200);
    const a = (azimuthDeg * Math.PI) / 180;
    // azimut 0 = de face (caméra en -Z) ; positif = caméra vers la droite du personnage (+X)
    const dir = new THREE.Vector3(Math.sin(a), elevation, -Math.cos(a)).normalize();
    camera.position.copy(target).addScaledVector(dir, distance);
    camera.lookAt(target);
    const right = new THREE.Vector3().crossVectors(new THREE.Vector3(0, 1, 0), dir).normalize();
    key.position.copy(target).addScaledVector(dir, 6).addScaledVector(right, 3.2).add(new THREE.Vector3(0, 6, 0));
    key.target.position.copy(target);
    fill.position.copy(target).addScaledVector(dir, 4).addScaledVector(right, -5).add(new THREE.Vector3(0, 1, 0));
    fill.target.position.copy(target);
    renderer.setViewport(x, H - y - h, w, h);
    renderer.setScissor(x, H - y - h, w, h);
    renderer.setScissorTest(true);
    renderer.render(scene, camera);
  }

  const mid = (minY + maxY) / 2;
  const height = maxY - minY;
  renderer.clear();
  if (lineup) {
    ground.visible = false;
    const labels = document.getElementById("labels");
    const span = COLS * SPACING, tall = ROWS * ROW_DEPTH;
    const camera = new THREE.OrthographicCamera(-span / 2, span / 2, 6.6, 6.6 - tall, 0.1, 200);
    // caméra orthographique de face : même cadrage pour chaque personnage
    camera.position.set(0, 0, -50); camera.lookAt(0, 0, 0);
    key.position.set(-20, 30, -40); key.target.position.set(0, 0, 0); key.castShadow = false;
    fill.position.set(30, 5, -30); fill.target.position.set(0, 0, 0);
    renderer.setViewport(0, 0, W, H); renderer.setScissorTest(false);
    renderer.render(scene, camera);
    lineupNames.forEach((name, i) => {
      const d = document.createElement("div");
      d.textContent = name.replace(/_/g, " ");
      d.style.cssText = "position:absolute;left:" + ((i % COLS) + 0.5) * (W / COLS) + "px;top:" + ((Math.floor(i / COLS) + 1) * (H / ROWS) - 22) + "px;font:700 13px Arial,sans-serif;transform:translateX(-50%);white-space:nowrap";
      labels.appendChild(d);
    });
  } else if (portrait) {
    renderer.setClearColor(0x000000, 0);
    view(0, 0, W, H, 22, new THREE.Vector3(0, 4.74, 0), 3.5, 30, 0.02);
  } else {
    const body = new THREE.Vector3(0, mid, 0.1);
    const dist = height * 2.55;
    view(0, 60, 500, H - 110, 0, body, dist, 24);
    view(470, 60, 500, H - 110, 38, body, dist, 24);
    view(940, 60, 380, H - 110, 180, body, dist, 24);
    view(W - 300, 50, 270, 300, 28, new THREE.Vector3(0, 4.76, 0), 3.0, 30, 0.0);
    const labels = document.getElementById("labels");
    const tag = (text, x, y, size) => {
      const d = document.createElement("div");
      d.textContent = text;
      d.style.cssText = "position:absolute;left:" + x + "px;top:" + y + "px;font-size:" + size + "px;letter-spacing:1px;transform:translateX(-50%);white-space:nowrap";
      labels.appendChild(d);
    };
    const t = document.createElement("div");
    t.textContent = title; t.style.cssText = "position:absolute;left:36px;top:14px;font-size:34px";
    labels.appendChild(t);
    tag("FRONT", 250, H - 46, 20); tag("3/4", 720, H - 46, 20); tag("BACK", 1130, H - 46, 20);
    const frame = document.createElement("div");
    frame.style.cssText = "position:absolute;left:" + (W - 300) + "px;top:50px;width:270px;height:300px;border:2px solid #2b2b2e;box-sizing:border-box";
    labels.appendChild(frame);
  }
}, { parts, portrait, lineup, lineupNames, COLS, ROWS, SPACING, ROW_DEPTH, title, W, H });

fs.mkdirSync(path.dirname(path.resolve(outPath)), { recursive: true });
await page.screenshot({ path: outPath, omitBackground: portrait });
await browser.close();
console.log(`écrit : ${outPath} (${parts.length} pièces)`);
