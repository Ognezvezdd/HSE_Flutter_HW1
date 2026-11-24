"""Small adb helper for acceptance checks; no runtime dependency of the app."""

from pathlib import Path
import re
import subprocess
import time
import xml.etree.ElementTree as ET

PACKAGE = "com.HSE_study.cat_tinder"


class AndroidUI:
    def __init__(self, adb, serial, output):
        self.adb = [str(adb), "-s", serial]
        self.output = Path(output)
        self.output.mkdir(parents=True, exist_ok=True)

    def shell(self, *args):
        return subprocess.check_output(self.adb + ["shell", *map(str, args)], timeout=30).decode().strip()

    def snapshot(self, label):
        self.shell("uiautomator", "dump", "/sdcard/hw1-acceptance.xml")
        xml = subprocess.check_output(self.adb + ["exec-out", "cat", "/sdcard/hw1-acceptance.xml"], timeout=15)
        (self.output / (label + ".xml")).write_bytes(xml)
        return ET.fromstring(xml)

    def screenshot(self, label):
        data = subprocess.check_output(self.adb + ["exec-out", "screencap", "-p"], timeout=15)
        (self.output / (label + ".png")).write_bytes(data)

    @staticmethod
    def nodes(root):
        return [n.attrib for n in root.iter("node") if n.attrib.get("package") == PACKAGE]

    def has(self, root, text):
        return any(text in (n.get("content-desc", "") + n.get("text", "")) for n in self.nodes(root))

    def identified(self, root, identifier):
        return next((n for n in self.nodes(root) if n.get("resource-id") == identifier), None)

    def tap_node(self, node):
        assert node is not None, "Expected UI element was not found"
        x1, y1, x2, y2 = map(int, re.findall(r"\d+", node["bounds"]))
        self.shell("input", "tap", (x1+x2)//2, (y1+y2)//2)

    def tap(self, root, identifier):
        self.tap_node(self.identified(root, identifier))

    def tap_text(self, root, text):
        self.tap_node(next((n for n in self.nodes(root) if text in n.get("content-desc", "")), None))

    def wait(self, predicate, label, timeout=35):
        deadline = time.monotonic() + timeout
        while True:
            root = self.snapshot(label)
            if predicate(root):
                self.screenshot(label)
                return root
            if time.monotonic() >= deadline:
                self.screenshot(label + "-FAILED")
                raise AssertionError(f"Timed out waiting for {label}: {self.nodes(root)}")

    def ready(self, label):
        return self.wait(lambda root: self.identified(root, "cat_card") is not None, label)

    def likes(self, root):
        counter = self.identified(root, "like_counter")
        assert counter is not None
        return int(re.search(r"\d+", counter.get("content-desc", "")).group())

    def restart(self):
        self.shell("am", "force-stop", PACKAGE)
        self.shell("am", "start", "-W", "-n", PACKAGE + "/.MainActivity")

    def network_ready(self, timeout=30):
        # Enabling radios is asynchronous. Wait for Android to validate its
        # default network before testing the application's Retry button.
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            status = self.shell("dumpsys", "connectivity")
            active = re.search(r"Active default network: (\d+)", status)
            if active:
                for line in status.splitlines():
                    if ("NetworkAgentInfo" in line and
                            f"network{{{active.group(1)}}}" in line and
                            re.search(r"Capabilities:.*[ &]VALIDATED[ &]", line)):
                        return
            time.sleep(0.25)
        raise AssertionError("Android did not restore a validated default network")
