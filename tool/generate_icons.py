"""Generate platform icons from the original SVG. Not part of the Flutter build.

Requires CairoSVG (tool/requirements-icons.txt) and the system Cairo library.
Run from any directory: python tool/generate_icons.py.
"""

from copy import deepcopy
from pathlib import Path
import xml.etree.ElementTree as ET

import cairosvg

ROOT = Path(__file__).resolve().parents[1]
SVG_NS = "http://www.w3.org/2000/svg"
ANDROID_NS = "http://schemas.android.com/apk/res/android"
ET.register_namespace("", SVG_NS)
ET.register_namespace("android", ANDROID_NS)
source = ET.parse(ROOT / "assets/branding/app_icon.svg").getroot()
background = next(node for node in source if node.attrib.get("id") == "background")
paths = [node for node in source if node.tag == f"{{{SVG_NS}}}path"]


def write_xml(path, element):
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    ET.indent(element)
    ET.ElementTree(element).write(target, encoding="utf-8", xml_declaration=True)


def png(path, size, *, maskable=False, desktop=False):
    svg = deepcopy(source)
    if maskable:
        next(node for node in svg if node.attrib.get("id") == "background").attrib.pop("rx")
    if desktop:
        group = ET.Element(f"{{{SVG_NS}}}g", {"transform": "translate(82 82) scale(0.84)"})
        for node in list(svg):
            svg.remove(node)
            group.append(node)
        svg.append(group)
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    cairosvg.svg2png(bytestring=ET.tostring(svg), write_to=str(target), output_width=size, output_height=size)


png("assets/branding/app_icon.png", 192)
for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    png(f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", size)
for size in (192, 512):
    png(f"web/icons/Icon-{size}.png", size)
    png(f"web/icons/Icon-maskable-{size}.png", size, maskable=True)
png("web/favicon.png", 32)
for size in (16, 32, 64, 128, 256, 512, 1024):
    png(f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png", size, desktop=True)

vector_attributes = {f"{{{ANDROID_NS}}}{key}": value for key, value in {
    "width": "108dp", "height": "108dp", "viewportWidth": "1024", "viewportHeight": "1024",
}.items()}
foreground = ET.Element("vector", vector_attributes)
for node in paths:
    ET.SubElement(foreground, "path", {
        f"{{{ANDROID_NS}}}fillColor": node.attrib["fill"],
        f"{{{ANDROID_NS}}}pathData": node.attrib["d"],
    })
write_xml("android/app/src/main/res/drawable/ic_launcher_foreground.xml", foreground)
monochrome = ET.Element("vector", vector_attributes)
ET.SubElement(monochrome, "path", {
    f"{{{ANDROID_NS}}}fillColor": "#FFFFFF",
    f"{{{ANDROID_NS}}}fillType": "evenOdd",
    f"{{{ANDROID_NS}}}pathData": " ".join(node.attrib["d"] for node in paths),
})
write_xml("android/app/src/main/res/drawable/ic_launcher_monochrome.xml", monochrome)
colors = ET.Element("resources")
ET.SubElement(colors, "color", {"name": "ic_launcher_background"}).text = background.attrib["fill"]
write_xml("android/app/src/main/res/values/icon_colors.xml", colors)
for version in (26, 33):
    icon = ET.Element("adaptive-icon")
    ET.SubElement(icon, "background", {f"{{{ANDROID_NS}}}drawable": "@color/ic_launcher_background"})
    ET.SubElement(icon, "foreground", {f"{{{ANDROID_NS}}}drawable": "@drawable/ic_launcher_foreground"})
    if version >= 33:
        ET.SubElement(icon, "monochrome", {f"{{{ANDROID_NS}}}drawable": "@drawable/ic_launcher_monochrome"})
    write_xml(f"android/app/src/main/res/mipmap-anydpi-v{version}/ic_launcher.xml", icon)
print("Generated Android, Web, macOS and in-app icons from assets/branding/app_icon.svg")
