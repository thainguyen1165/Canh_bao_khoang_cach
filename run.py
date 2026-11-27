"""Run the Verilog dashboard or the regression testbench on macOS and Windows."""

import argparse
from functools import partial
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
from urllib.parse import parse_qs, urlsplit
import webbrowser


ROOT = Path(__file__).resolve().parent


def compile_simulation(iverilog, top, target, clock=None):
    args = [iverilog, "-g2012", "-Wall", "-s", top]
    if clock is not None:
        args.append(f"-P{top}.CLK_MHZ={clock}")
    subprocess.run(
        [*args, "-o", str(target), "rtl/obstacle_warning.v", f"sim/{top}.v"],
        cwd=ROOT, check=True, timeout=60,
    )


def measure(vvp, binary, distance, no_echo):
    run = subprocess.run(
        [vvp, str(binary), f"+distance_cm={distance}", f"+no_echo={int(no_echo)}"],
        cwd=ROOT, capture_output=True, text=True, check=True, timeout=5,
    )
    result = next(line for line in run.stdout.splitlines() if line.startswith("RESULT "))
    _, level, valid, green, yellow, red, buzzer = result.split()
    return {
        "level": int(level),
        "valid": valid == "1",
        "outputs": [bit == "1" for bit in (green, yellow, red, buzzer)],
        "echo_us": distance * 58 if valid == "1" else None,
    }


class DashboardHandler(BaseHTTPRequestHandler):
    def __init__(self, *args, page, vvp, binary, **kwargs):
        self.page = page
        self.vvp = vvp
        self.binary = binary
        super().__init__(*args, **kwargs)

    def reply(self, status, data, mime):
        self.send_response(status)
        self.send_header("Content-Type", mime + "; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def json_reply(self, status, data):
        self.reply(status, json.dumps(data, ensure_ascii=False).encode(), "application/json")

    def do_GET(self):
        if self.headers.get("Host") != f"127.0.0.1:{self.server.server_port}":
            self.send_error(403)
            return
        url = urlsplit(self.path)
        if url.path == "/":
            self.reply(200, self.page, "text/html")
            return
        if url.path != "/api/measure":
            self.send_error(404)
            return
        args = parse_qs(url.query)
        try:
            distance = int(args.get("distance", [""])[0])
            no_echo = args.get("no_echo", ["0"])[0]
            if not 2 <= distance <= 400 or no_echo not in ("0", "1"):
                raise ValueError
        except ValueError:
            self.json_reply(400, {"error": "Nhập khoảng cách nguyên từ 2 đến 400 cm."})
            return
        try:
            data = measure(self.vvp, self.binary, distance, no_echo == "1")
        except (OSError, subprocess.SubprocessError, StopIteration, ValueError) as error:
            self.log_error("%s", error)
            self.json_reply(500, {"error": "Icarus Verilog không trả về kết quả."})
            return
        self.json_reply(200, data)

    def log_request(self, code="-", size="-"):
        if str(code) not in {"200", "404"}:
            super().log_request(code, size)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--test", action="store_true", help="run the 14 regression scenarios")
    parser.add_argument("--clock", type=int, choices=(1, 50), default=1, help="test clock in MHz")
    parser.add_argument("--no-browser", action="store_true", help="print the URL without opening it")
    options = parser.parse_args()

    iverilog, vvp = shutil.which("iverilog"), shutil.which("vvp")
    if not iverilog or not vvp:
        parser.exit(1, "Không tìm thấy iverilog hoặc vvp trong PATH. Xem README.md.\n")

    try:
        if options.test:
            build = ROOT / "build"
            build.mkdir(exist_ok=True)
            binary = build / "sim.vvp"
            compile_simulation(iverilog, "tb_obstacle_warning", binary, options.clock)
            subprocess.run([vvp, str(binary)], cwd=ROOT, check=True, timeout=180)
            return

        with tempfile.TemporaryDirectory(prefix="verilog-gui-") as build:
            binary = Path(build) / "gui.vvp"
            compile_simulation(iverilog, "tb_obstacle_gui", binary)
            page = (ROOT / "gui" / "index.html").read_bytes()
            handler = partial(DashboardHandler, page=page, vvp=vvp, binary=binary)
            with ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
                url = f"http://127.0.0.1:{server.server_port}/"
                print(f"Mở giao diện tại {url} · Nhấn Ctrl+C để dừng.", flush=True)
                if not options.no_browser:
                    webbrowser.open(url)
                server.serve_forever()
    except KeyboardInterrupt:
        print("\nĐã dừng mô phỏng.")
    except (OSError, subprocess.SubprocessError) as error:
        parser.exit(1, f"Không chạy được dự án. {error}\n")


if __name__ == "__main__":
    main()
