# Thiết kế và mô phỏng hệ thống cảnh báo vật cản bằng Verilog

## 1. Mục tiêu

Đo khoảng cách đến vật cản bằng cảm biến siêu âm HC-SR04 và cảnh báo bằng ba LED cùng một còi chủ động. Thiết kế mặc định dùng clock 50 MHz, reset đồng bộ mức cao và hai ngưỡng 20 cm, 50 cm. Mã RTL có thể dùng làm top-level khi triển khai trên FPGA.

| Trạng thái | Điều kiện | `level` | LED sáng | Còi | `valid` |
|---|---|---|---|---|---|
| An toàn | 50 < d ≤ 400 cm | 00 | Xanh | Tắt | 1 |
| Cảnh báo | 20 < d ≤ 50 cm | 01 | Vàng | Tắt | 1 |
| Nguy hiểm | 2 ≤ d ≤ 20 cm | 10 | Đỏ | Bật | 1 |
| Lỗi/chưa có phép đo | Reset, timeout, Echo kẹt cao hoặc ngoài dải 2–400 cm | 11 | Vàng và đỏ | Tắt | 0 |

## 2. Nguyên lý và thiết kế

```text
      FPGA                                  Cảm biến
  [FSM phát xung] ──────── Trig ──────────> [HC-SR04]
                                                │
                                                │ Echo
                                                v
  [LED / còi] <── [Phân mức] <── [Bộ đếm] <── [Đồng bộ Echo]
```

HC-SR04 nhận xung Trig 10 µs và trả về xung Echo có độ rộng gần bằng 58 µs cho mỗi cm. Dải danh định là 2–400 cm. RTL so sánh trực tiếp số chu kỳ clock của xung Echo với các ngưỡng, giúp tránh phép chia trong mạch. [Datasheet HC-SR04](https://cdn.sparkfun.com/datasheets/Sensors/Proximity/HCSR04.pdf)

Với clock 50 MHz, một chu kỳ dài 20 ns. Xung Trig dài 500 chu kỳ, ngưỡng 20 cm ứng với 58.000 chu kỳ và ngưỡng 50 cm ứng với 145.000 chu kỳ. Ví dụ, vật cản cách 35 cm cho xung Echo khoảng 2.030 µs (101.500 chu kỳ), nên LED vàng sáng.

| Trạng thái FSM | Hoạt động và chuyển trạng thái |
|---|---|
| `IDLE` | Chờ hết khoảng cách tối thiểu 65 ms tính từ lần phát trước. Nếu Echo đang thấp thì bắt đầu phát Trig. Nếu Echo vẫn cao thì báo lỗi và kiểm tra lại ở kỳ sau. |
| `TRIGGER` | Giữ Trig cao 10 µs, sau đó chuyển sang chờ Echo. |
| `WAIT_RISE` | Chờ Echo lên cao sau đồng bộ. Nếu hết 30 ms mà Echo chưa lên, phát kết quả lỗi. |
| `MEASURE` | Đếm thời gian Echo cao. Khi Echo xuống, kiểm tra dải và cập nhật mức. Nếu Echo vẫn cao hết 30 ms thì phát kết quả lỗi. |

Mỗi lần có kết quả, kể cả lỗi, `result_ready` lên cao một chu kỳ clock. `level` và `valid` giữ giá trị đến lần cập nhật sau. Sau reset, hệ thống hiển thị trạng thái chưa có phép đo. Hai flip-flop nối tiếp giảm nguy cơ siêu ổn định khi lấy mẫu Echo bất đồng bộ. Phép đo có sai số lượng tử theo chu kỳ clock và công thức khoảng cách chỉ là xấp xỉ.

## 3. Giao diện đồ họa trên macOS và Windows

Giải nén hoặc clone repository, rồi mở Terminal/PowerShell tại thư mục chứa `run.py`. Cần Python 3.9 trở lên và Icarus Verilog. Xác nhận hai lệnh `iverilog -V` và `vvp -V` chạy được trong cửa sổ hiện tại.

| Hệ điều hành | Cài công cụ | Mở giao diện |
|---|---|---|
| macOS | Cài Python 3 nếu cần. Với Homebrew, chạy `brew install icarus-verilog`. | `python3 run.py` |
| Windows | Cài Python và Icarus Verilog cho Windows. Thêm thư mục `bin` của Icarus vào PATH khi cài, rồi mở lại PowerShell. | `py run.py` |

- [Python cho Windows](https://www.python.org/downloads/windows/) và [Python cho macOS](https://www.python.org/downloads/macos/)
- [Bộ cài Icarus Verilog cho Windows](https://bleyer.org/icarus/) và [gói Homebrew cho macOS](https://formulae.brew.sh/formula/icarus-verilog)

Trình duyệt mặc định sẽ mở giao diện. Nếu cần, mở địa chỉ `http://127.0.0.1:…/` hiện trong Terminal. Kéo thanh trượt hoặc nhập khoảng cách từ 2 đến 400 cm rồi nhấn Enter. Mỗi phép đo gọi Icarus Verilog tại 1 MHz và đọc trạng thái LED, còi trực tiếp từ mạch. Chọn **Giả lập mất Echo** để thử báo lỗi. Nhấn Ctrl+C trong Terminal để dừng.

GitHub lưu mã nguồn dự án. Sau khi tải mã về, chạy `run.py` trên máy để có cả giao diện lẫn trình mô phỏng. Giao diện SwiftUI riêng trên macOS vẫn có thể mở bằng `make gui` nếu có Xcode Command Line Tools và macOS 14 trở lên.

## 4. Chạy mô phỏng kiểm thử

Trên macOS, chạy `python3 run.py --test`. Trên Windows, chạy `py run.py --test`. Thêm `--clock 50` để kiểm thử ở 50 MHz.

Nếu có Make, bạn cũng có thể chạy từ thư mục dự án:

```sh
make sim                 # Chạy nhanh ở 1 MHz
make sim CLK_MHZ=50      # Mô phỏng cấu hình FPGA mặc định
```

Testbench tạo xung Echo theo độ rộng được chỉ định và tự kiểm tra trạng thái, LED, còi, cờ hợp lệ, reset, thời gian Trig và độ dài cờ kết quả. Có 14 kịch bản, gồm các mốc biên, ngay ngoài các mốc, mất Echo, Echo kẹt cao và phục hồi. Bộ mô phỏng trả lỗi nếu kiểm tra thất bại.

Mở `build/obstacle_warning.vcd` bằng GTKWave hoặc trình xem VCD. Các tín hiệu cần đối chiếu là `trig`, `echo`, `result_ready`, `level`, `valid`, ba LED và `buzzer`. Xung `result_ready` chỉ dài 20 ns ở 50 MHz, nên phóng to quanh thời điểm kết quả nếu xung chưa hiện rõ trên màn hình.

## 5. Kết quả mô phỏng

Icarus Verilog 13.0 chạy đạt 14/14 kịch bản ở cả 1 MHz và 50 MHz, cùng các kiểm tra reset và thời gian xung Trig. Ví dụ, tại 20 cm LED đỏ và còi bật. Khi tăng độ rộng Echo thêm 1 µs, mạch chuyển sang LED vàng và tắt còi. Sau lỗi Echo kẹt cao, phép đo tiếp theo ở 35 cm trở về mức cảnh báo.

- [Nhật ký mô phỏng 1 MHz](ket-qua/mo-phong-1MHz.txt) và [dạng sóng VCD 1 MHz](ket-qua/obstacle_warning_1MHz.vcd)
- [Nhật ký mô phỏng 50 MHz](ket-qua/mo-phong-50MHz.txt)
- [Dạng sóng VCD 50 MHz](ket-qua/obstacle_warning_50MHz.vcd)
- [Mã RTL](rtl/obstacle_warning.v) và [testbench](sim/tb_obstacle_warning.v)

## 6. Ghép với FPGA

- Dùng `obstacle_warning` làm module top-level. Đặt `CLK_MHZ` theo clock thực tế tính bằng MHz nguyên. Khi đổi ngưỡng, chọn các số nguyên thỏa 2 ≤ `DANGER_CM` < `WARNING_CM` ≤ 400.
- Tạo ràng buộc chân và clock theo sơ đồ board. Ở 50 MHz, chu kỳ clock phải được khai báo là 20 ns.
- Cấp 5 V cho HC-SR04 và nối chung GND với FPGA. Dùng mạch chuyển mức phù hợp giữa Echo và ngõ vào FPGA nếu FPGA không chịu được 5 V. Đối chiếu mức logic Trig của cảm biến với mức ngõ ra của board.
- Các ngõ ra LED và còi là mức cao tích cực. Dùng điện trở hạn dòng cho LED ngoài và tầng đệm phù hợp nếu còi vượt khả năng cấp dòng của chân FPGA. Nếu dùng còi thụ động, cần thêm mạch tạo tần số âm.

Phạm vi dự án là thiết kế RTL và mô phỏng chức năng với tín hiệu Echo giả lập. Việc gán chân, tổng hợp và thử trên phần cứng phụ thuộc board được chọn.
