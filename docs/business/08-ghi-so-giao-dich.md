# 08. Ghi sổ giao dịch hằng ngày (Posting)

**Mục đích:** Xử lý file giao dịch phát sinh trong ngày và cập nhật vào hệ thống.

**Luồng:**
1. Đọc từng giao dịch trong file daily.
2. Kiểm tra hợp lệ; nếu sai → ghi vào file reject kèm mã lỗi.
3. Nếu hợp lệ → ghi vào file giao dịch, cập nhật số dư tài khoản và số dư theo danh mục giao dịch.

**Lý do từ chối:**
- 100: số thẻ không tồn tại
- 101: không tìm thấy tài khoản
- 102: vượt hạn mức tín dụng
- 103: giao dịch sau ngày hết hạn tài khoản

**Chương trình:** CBTRN02C (kiểm tra và ghi sổ) – job POSTTRAN.
