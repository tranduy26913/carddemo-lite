# 09. Tính lãi

**Mục đích:** Tính lãi hàng tháng trên số dư theo từng danh mục giao dịch.

**Quy tắc:**
- Lãi suất lấy theo nhóm công bố (disclosure group) của tài khoản + loại/danh mục giao dịch; không có thì dùng nhóm `DEFAULT`.
- Lãi tháng = Số dư danh mục × Lãi suất năm / 1200.
- Tổng lãi được ghi thành giao dịch lãi (loại 01, danh mục 05) và cộng vào số dư tài khoản; reset phát sinh nợ/có của chu kỳ.

**Chương trình:** CBACT04C – job INTCALC.
