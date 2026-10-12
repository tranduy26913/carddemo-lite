# 01. Đăng nhập & phân quyền

**Mục đích:** Xác thực người dùng và điều hướng theo vai trò.

**Luồng:**
1. Người dùng nhập User ID + mật khẩu.
2. Hệ thống đối chiếu với file người dùng (USRSEC).
3. Admin → Menu quản trị; User thường → Menu chính.

**Quy tắc:** Sai ID/mật khẩu thì báo lỗi, không cho vào.

**Chương trình:** CC00 / COSGN00C, CM00 / COMEN01C (menu chính), CA00 / COADM01C (menu admin).
