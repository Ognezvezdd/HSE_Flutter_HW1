"""Run release Android checks against api_server.py via a trusted HTTPS URL.

The APK must be built with CAT_API_KEY=acceptance-test-key and the fixture URL.
Results and screenshots stay in the supplied output directory, outside Git.
"""

import argparse
import json
from pathlib import Path
import time

from android_ui import AndroidUI


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("group", choices=["feed", "errors", "catalog", "lifecycle", "network"])
    parser.add_argument("--adb", required=True)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--state", type=Path, required=True)
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    ui = AndroidUI(args.adb, args.serial, args.output)
    public_url = json.loads(args.state.read_text())["public_url"]

    def mode(**fields):
        temporary = args.state.with_suffix(".tmp")
        temporary.write_text(json.dumps({"public_url": public_url, **fields}))
        temporary.replace(args.state)

    def hits(category):
        if not args.log.exists():
            return 0
        return sum(json.loads(line)["category"] == category for line in args.log.read_text().splitlines())

    def passed(name, **evidence):
        record = {"case": name, "status": "passed", **evidence}
        with (args.output / "results.jsonl").open("a") as output:
            output.write(json.dumps(record, ensure_ascii=False) + "\n")
        print(json.dumps(record, ensure_ascii=False), flush=True)

    mode()
    ui.restart()
    root = ui.ready(args.group + "-start")

    if args.group == "feed":
        n, requests = ui.likes(root), hits("cats")
        mode(cats_mode="slow", delay=3)
        for _ in range(6):
            ui.tap(root, "like_button")
        root = ui.ready("rapid-taps")
        assert ui.likes(root) == n + 1 and hits("cats") == requests + 1
        passed("six rapid taps accept one like and one request", likes=ui.likes(root))
        n, requests = ui.likes(root), hits("cats")
        ui.shell("input", "swipe", 210, 1000, 990, 1000, 300)
        for _ in range(3):
            ui.tap(root, "like_button")
        root = ui.ready("swipe-and-taps")
        assert ui.likes(root) == n + 1 and hits("cats") == requests + 1
        passed("right swipe and rapid button taps accept one vote", likes=ui.likes(root))
        mode()
        breed = ui.identified(root, "cat_breed_name")["content-desc"]
        n, requests, photos = ui.likes(root), hits("cats"), hits("photos")
        ui.tap_text(root, "Открыть сведения")
        root = ui.wait(lambda r: ui.has(r, "Назад"), "details")
        assert ui.has(root, breed)
        ui.shell("input", "keyevent", "KEYCODE_BACK")
        root = ui.ready("back")
        assert ui.likes(root) == n and ui.has(root, breed)
        assert hits("cats") == requests and hits("photos") == photos
        ui.restart()
        root = ui.ready("restart")
        assert ui.likes(root) == n and ui.has(root, breed) and hits("cats") == requests
        passed("details Back and restart preserve cat without another search", likes=n)

    if args.group == "errors":
        cases = [
            ("cats", "http500", "временно недоступен"),
            ("cats", "http429", "Слишком много запросов"),
            ("cats", "empty", "прочитать данные кота"),
            ("cats", "bad-json", "прочитать данные кота"),
            ("cats", "wrong-root", "прочитать данные кота"),
            ("cats", "no-breed", "без породы"),
            ("cats", "slow", "отвечает слишком долго"),
            ("photos", "http404", "открыть фотографию"),
            ("photos", "bad-image", "открыть фотографию"),
            ("photos", "slow", "Фотография загружается слишком долго"),
            ("cats", "http401", "Ключ API не принят"),
            ("cats", "http403", "Ключ API не принят"),
        ]
        for category, fault, message in cases:
            mode(**{category + "_mode": fault})
            n, requests = ui.likes(root), hits("cats")
            started = time.monotonic()
            ui.tap(root, "like_button")
            label = category + "-" + fault
            root = ui.wait(lambda r: ui.has(r, message), label)
            elapsed = round(time.monotonic() - started, 1)
            assert ui.likes(root) == n + 1 and hits("cats") == requests + 1
            auth = fault in ("http401", "http403")
            assert (ui.identified(root, "retry_button") is None) == auth
            if fault == "slow":
                assert 8 <= elapsed <= 25
            mode()
            if auth:
                ui.restart()
            else:
                ui.tap(root, "retry_button")
            root = ui.ready(label + "-recovered")
            assert ui.likes(root) == n + 1
            assert hits("cats") == requests + (1 if category == "photos" else 2)
            passed(label + " error and recovery", likes=ui.likes(root), error_after_seconds=elapsed)

    if args.group == "catalog":
        for fault in ("http500", "bad-json", "empty"):
            mode(breeds_mode=fault)
            n, requests = ui.likes(root), hits("cats")
            ui.restart()
            root = ui.snapshot("catalog-" + fault + "-home")
            ui.tap(root, "breeds_tab")
            expected = "Пород пока нет" if fault == "empty" else "Каталог пока недоступен"
            root = ui.wait(lambda r: ui.has(r, expected), "catalog-" + fault)
            assert ui.likes(root) == n and ui.identified(root, "retry_button") is not None
            mode()
            ui.tap(root, "retry_button")
            root = ui.wait(lambda r: ui.has(r, "Acceptance Longhair"), "catalog-" + fault + "-recovered")
            assert ui.likes(root) == n and hits("cats") == requests
            ui.tap_text(root, "Коты\n")
            root = ui.snapshot("catalog-" + fault + "-feed")
            if ui.identified(root, "retry_button") is not None:
                ui.tap(root, "retry_button")
            root = ui.ready("catalog-" + fault + "-ready")
            assert ui.likes(root) == n and hits("cats") == requests
            passed("catalog " + fault + " and recovery preserve feed", likes=n)

    if args.group == "lifecycle":
        n, requests = ui.likes(root), hits("cats")
        mode(cats_mode="slow", delay=5)
        ui.tap(root, "like_button")
        ui.shell("input", "keyevent", "KEYCODE_HOME")
        time.sleep(6)
        ui.shell("am", "start", "-W", "-n", "com.HSE_study.cat_tinder/.MainActivity")
        root = ui.ready("return-during-request")
        assert ui.likes(root) == n + 1 and hits("cats") == requests + 1
        passed("leaving during request and returning is safe", likes=ui.likes(root))

    if args.group == "network":
        wifi = ui.shell("settings", "get", "global", "wifi_on")
        data = ui.shell("settings", "get", "global", "mobile_data")

        def radios(restore=False):
            ui.shell("svc", "wifi", "enable" if restore and wifi == "1" else "disable")
            ui.shell("svc", "data", "enable" if restore and data == "1" else "disable")
            if restore:
                ui.network_ready()

        n = ui.likes(root)
        try:
            radios()
            root = ui.snapshot("radios-disabled")
            ui.tap(root, "like_button")
            root = ui.wait(lambda r: ui.identified(r, "retry_button") is not None, "offline-after-vote")
            assert ui.likes(root) == n + 1
            ui.tap(root, "breeds_tab")
            root = ui.wait(lambda r: ui.has(r, "Acceptance Longhair"), "offline-catalog")
            assert ui.likes(root) == n + 1
            ui.tap_text(root, "Коты\n")
            root = ui.wait(lambda r: ui.identified(r, "retry_button") is not None, "offline-feed")
        finally:
            radios(restore=True)
        ui.tap(root, "retry_button")
        root = ui.ready("network-recovered")
        assert ui.likes(root) == n + 1
        passed("network loss preserves vote and catalog; retry does not double like", likes=ui.likes(root))
        n, requests = ui.likes(root), hits("cats")
        breed = ui.identified(root, "cat_breed_name")["content-desc"]
        try:
            radios()
            ui.snapshot("radios-disabled-before-start")
            ui.restart()
            root = ui.wait(lambda r: ui.identified(r, "retry_button") is not None, "offline-start")
            assert ui.likes(root) == n
        finally:
            radios(restore=True)
        ui.tap(root, "retry_button")
        root = ui.ready("offline-start-recovered")
        assert ui.likes(root) == n and ui.has(root, breed) and hits("cats") == requests
        passed("offline startup and recovery preserve saved cat and likes", likes=n)
    mode()


if __name__ == "__main__":
    main()
