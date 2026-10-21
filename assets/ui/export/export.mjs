// Convertit assets/ui/*.svg et assets/ui/icons/*.svg en PNG dans assets/ui/png/.
// Icônes : 256 px ; logo : 1024 px de large ; halo : 128 px. Polices du logo : export/fonts (OFL).
import { Resvg } from "@resvg/resvg-js";
import { readFileSync, readdirSync, writeFileSync, mkdirSync } from "node:fs";
import { join, basename, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const ui = join(here, "..");
const out = join(ui, "png");
mkdirSync(out, { recursive: true });
const fontFiles = readdirSync(join(here, "fonts")).filter((f) => f.endsWith(".ttf")).map((f) => join(here, "fonts", f));

const jobs = [
  ...readdirSync(join(ui, "icons")).filter((f) => f.endsWith(".svg")).map((f) => ({ src: join(ui, "icons", f), width: 256 })),
  { src: join(ui, "logo.svg"), width: 1024 },
  { src: join(ui, "glow.svg"), width: 128 },
];

for (const job of jobs) {
  const svg = readFileSync(job.src, "utf8");
  const resvg = new Resvg(svg, {
    fitTo: { mode: "width", value: job.width },
    background: "rgba(0,0,0,0)",
    font: { fontFiles, loadSystemFonts: false, defaultFontFamily: "Roboto Condensed" },
  });
  const png = resvg.render().asPng();
  const name = basename(job.src, ".svg") + ".png";
  writeFileSync(join(out, name), png);
  console.log(`${name}  ${png.length} octets`);
}
