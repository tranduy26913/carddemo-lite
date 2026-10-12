# 06. Báo cáo giao dịch

**Mục đích:** Lập báo cáo giao dịch theo kỳ.

**Luồng:**
1. Người dùng chọn kỳ báo cáo: tháng, năm hoặc khoảng ngày tùy chọn.
2. Hệ thống gửi job batch để in báo cáo.
3. Batch lọc giao dịch theo khoảng ngày, nhóm theo thẻ/tài khoản, có tổng theo trang, theo tài khoản và tổng chung.

**Chương trình:** CR00 / CORPT00C (online), CBTRN03C (batch, job TRANREPT).
