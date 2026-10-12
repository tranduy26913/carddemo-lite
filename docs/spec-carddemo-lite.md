# Spec: CardDemo Lite

> Phiên bản rút gọn của AWS CardDemo, giữ nguyên các chức năng nghiệp vụ cốt lõi và **toàn bộ độ phủ kỹ thuật** (COBOL / CICS / BMS / VSAM / JCL / ASM / LE) của bản gốc, loại bỏ các module trùng lặp, các màn hình cùng khuôn, tiện ích phụ trợ và module tùy chọn.
>
> Phạm vi rút gọn: **Mức cơ bản + Mức 1 + Mức 2**.
> - Mức cơ bản: loại tiện ích, chương trình trùng lặp, module tùy chọn.
> - Mức 1: gộp màn hình "xem" vào màn hình "cập nhật".
> - Mức 2: giữ `COCRDLIC` làm đại diện duy nhất cho mẫu màn hình danh sách.

---

## 1. Mục tiêu và nguyên tắc rút gọn

**Mục tiêu**

- Giảm số lượng source để dễ đọc, dễ phân tích, dễ chuyển đổi (modernization), nhưng vẫn là một hệ thống chạy được end-to-end: đăng nhập → tra cứu/cập nhật → ghi giao dịch → batch posting → tính lãi → báo cáo/sao kê.
- Không làm mất bất kỳ *kỹ thuật* nào mà bản gốc minh họa (xem ma trận ở mục 3.3).

**Nguyên tắc**

1. **Gộp theo độ tương đồng code**: các chương trình cùng khuôn (đo bằng so sánh dòng code đã bỏ comment, mức giống từ 60% trở lên) chỉ giữ một đại diện có độ phủ lớn nhất.
2. **Gộp theo chức năng**: chức năng "xem" được bao trọn bởi chức năng "cập nhật" cùng đối tượng thì bỏ chức năng "xem".
3. **Không loại bỏ chương trình có kỹ thuật duy nhất**, kể cả khi chức năng nghiệp vụ trùng (ví dụ `CBACT01C`, `CBSTM03A/B`, `COUSR03C`, `CORPT00C`).
4. **Hạn chế sửa logic COBOL** của chương trình được giữ. Chỉ được phép sửa: bảng menu (copybook dữ liệu), hằng số tên chương trình đích của XCTL, định nghĩa CSD, script, README.
5. Chỉ giữ một luồng công nghệ nền: **CICS + VSAM**. Các module IMS / DB2 / MQ bị loại toàn bộ.

### 1.1 Phân tích độ tương đồng (căn cứ gộp)

| Nhóm | Chương trình | Mức giống code | Quyết định |
|---|---|---|---|
| Màn hình "chỉ xem" | `COACTVWC` / `COCRDSLC` | 67% | Bỏ cả hai. Chức năng xem nằm trong `COACTUPC` / `COCRDUPC` |
| Màn hình danh sách (browse) | `COTRN00C` / `COUSR00C` (cùng khuôn với `COCRDLIC`) | 64% | Giữ `COCRDLIC` (lớn nhất, có lọc + phân trang 2 chiều + 2 hành động chọn) |
| Thêm user / sửa / xóa | `COUSR01C` / `COUSR02C` / `COUSR03C` | 55–71% | Bỏ `COUSR01C`. Giữ `COUSR02C` (REWRITE) và `COUSR03C` (DELETE duy nhất) |
| Đọc file rồi in | `CBACT02C` / `CBACT03C` / `CBCUS01C` | 67–73% | Bỏ cả ba. Giữ `CBACT01C` (nhiều kỹ thuật hơn) |
| Menu | `COMEN01C` / `COADM01C` | 67% | Giữ cả hai (gộp phải viết lại phân quyền) |
| Batch nghiệp vụ | `CBACT04C` / `CBTRN02C` | 56% | Giữ cả hai (chỉ giống phần mở/đóng file, logic nghiệp vụ khác nhau) |
| Report / xuất file | `CBTRN03C` / `CBSTM03A` / `CBACT01C` | < 40% | Giữ cả ba (code khác nhau, mỗi chương trình có kỹ thuật riêng) |

---

## 2. Tổng quan con số

| Thành phần | App chính (gốc) | Toàn repo (gồm module tùy chọn) | Bản Lite | Giảm so với app chính | Giảm so với toàn repo |
|---|---|---|---|---|---|
| Chương trình COBOL online | 17 | 22 | **12** | −29% | −45% |
| Chương trình COBOL batch + utility | 14 | 22 | **7** | −50% | −68% |
| Tổng chương trình COBOL | 31 | 44 | **19** | −39% | −57% |
| Dòng COBOL | 20.650 | 30.175 | **14.991** | −27% | −50% |
| BMS mapset | 17 | 21 | **12** | −29% | −43% |
| Assembler | 2 | 2 | **1** | −50% | −50% |
| Copybook dùng chung | 30 | — | **28** | −7% | — |
| JCL | 38 | — | **25** | −34% | — |
| Tổng dòng source (COBOL, copybook, BMS, ASM, JCL, PROC, CSD, DDL…) | 36.759 | ~50.950 | **~26.450** | **−28%** | **−48%** |
| Option menu user / admin | 10 / 4 | 11 / 6 | **7 / 2** | | |

*Số dòng đếm bằng `wc -l`, tính cả dòng comment và dòng trống.*

---

## 3. Kiến trúc được giữ lại

### 3.1 Sơ đồ tổng thể

```
                         ┌──────────────────────── CICS REGION ────────────────────────┐
 3270 Terminal ─ CC00 ─▶ │ COSGN00C (Sign-on, USRSEC)                                   │
                         │    ├── user  ─▶ COMEN01C (Main menu, bảng COMEN02Y)          │
                         │    │             ├ COACTUPC  Account view + update           │
                         │    │             ├ COCRDLIC  Card list ──S/U──▶ COCRDUPC     │
                         │    │             ├ COCRDUPC  Card view + update              │
                         │    │             ├ COTRN01C  Tran view (nhập Tran ID)        │
                         │    │             ├ COTRN02C  Tran add ──CALL──▶ CSUTLDTC     │
                         │    │             ├ CORPT00C  Report request ─┐               │
                         │    │             └ COBIL00C  Bill payment    │ WRITEQ TD JOBS│
                         │    └── admin ─▶ COADM01C (Admin menu, COADM02Y)│ (internal rdr)│
                         │                  ├ COUSR02C  User update (nhập User ID)      │
                         │                  └ COUSR03C  User delete (nhập User ID)      │
                         └───────────────┬───────────────────────────────┼──────────────┘
                                         │ VSAM KSDS / AIX (shared)      │
        ACCTDAT CUSTDAT CARDDAT CCXREF CXACAIX TRANSACT USRSEC           ▼
                                         │                     JES ─▶ TRANREPT (CBTRN03C)
                         ┌───────────────┴──────── BATCH (JCL) ────────────────────────┐
                         │ CLOSEFIL ─▶ load VSAM ─▶ POSTTRAN(CBTRN02C) ─▶ INTCALC        │
                         │ (CBACT04C) ─▶ TRANBKP ─▶ COMBTRAN(SORT) ─▶ TRANIDX ─▶          │
                         │ CREASTMT(CBSTM03A ─CALL─▶ CBSTM03B) ─▶ OPENFIL                 │
                         │ TRANREPT(SORT + CBTRN03C)   READACCT(CBACT01C ─CALL─▶ COBDATFT)│
                         └──────────────────────────────────────────────────────────────┘
```

### 3.2 Các mẫu kiến trúc bắt buộc giữ nguyên

| # | Mẫu kiến trúc | Thể hiện ở đâu trong bản Lite |
|---|---|---|
| A1 | **CICS pseudo-conversational**: `RETURN TRANSID ... COMMAREA`, mỗi lần nhấn phím là một task mới | Toàn bộ 12 chương trình online |
| A2 | **COMMAREA dùng chung** để truyền ngữ cảnh (user, account, card, chương trình gọi/đích) | `COCOM01Y` (CARDDEMO-COMMAREA) |
| A3 | **Điều hướng bằng XCTL** theo bảng menu dữ liệu, phân quyền user/admin | `COSGN00C` → `COMEN01C`/`COADM01C`, `COMEN02Y`, `COADM02Y` |
| A4 | **Kiểm tra chương trình có được cài không** trước khi XCTL (`INQUIRE PROGRAM`) | `COMEN01C` |
| A5 | **Mẫu List → Select → Detail/Update**: browse có lọc, phân trang 2 chiều (PF7/PF8), chọn dòng, XCTL kèm khóa qua COMMAREA | `COCRDLIC` → `COCRDUPC` |
| A6 | **Mẫu Key-entry → Fetch → Confirm → Action**: nhập khóa, đọc và hiển thị, xác nhận bằng PF key rồi mới ghi | `COTRN01C`, `COUSR02C`, `COUSR03C`, `COACTUPC`, `COCRDUPC` |
| A7 | **Cập nhật có khóa + optimistic check** (READ UPDATE, so sánh dữ liệu trước khi REWRITE, `SYNCPOINT ROLLBACK`) trên nhiều file trong một UOW | `COACTUPC` (ACCTDAT + CUSTDAT), `COCRDUPC`, `COBIL00C` |
| A8 | **Truy cập VSAM qua Alternate Index** | `CXACAIX` (xref theo account) trong `COACTUPC`, `COBIL00C`, `COTRN02C`; AIX + PATH định nghĩa trong `CARDFILE`, `XREFFILE`, `TRANFILE`, `TRANIDX` |
| A9 | **Online kích hoạt batch**: ghi JCL vào TDQ `JOBS` (extrapartition → internal reader) | `CORPT00C` → `TRANREPT` |
| A10 | **Chu trình batch đầy đủ**: đóng file CICS → nạp/backup → posting → tính lãi → gộp → tạo AIX → sao kê → mở file CICS | Chuỗi JCL ở mục 6 |
| A11 | **GDG** cho dữ liệu sinh theo chu kỳ (backup, reject, system tran, report) | `DEFGDGB`, `DALYREJS`, `REPTFILE` |
| A12 | **Batch sequential master/transaction update** + file lỗi (reject) có mã lý do | `CBTRN02C` |
| A13 | **Report có control break, phân trang, tổng nhóm/tổng cộng** | `CBTRN03C` |
| A14 | **Gọi chương trình con**: COBOL→COBOL (có I/O file) và COBOL→ASM, COBOL→LE API | `CBSTM03A`→`CBSTM03B`, `CBACT01C`→`COBDATFT`, `CSUTLDTC`→`CEEDAYS` |
| A15 | **Tách lớp dữ liệu bằng copybook**: record layout (CV*), BMS symbolic map (cpy-bms), message/hằng chung (CS*) | `app/cpy`, `app/cpy-bms` |

### 3.3 Ma trận độ phủ kỹ thuật (phải đạt 100%)

| Kỹ thuật | Bản gốc có ở | Bản Lite giữ ở |
|---|---|---|
| CICS `READ` / `READ UPDATE` / `REWRITE` | nhiều | `COACTUPC`, `COCRDUPC`, `COBIL00C`, `COUSR02C` |
| CICS `WRITE` | `COUSR01C`, `COTRN02C`, `COBIL00C` | `COTRN02C`, `COBIL00C` |
| CICS `DELETE` | `COUSR03C` (duy nhất) | `COUSR03C` |
| CICS `STARTBR` / `READNEXT` / `READPREV` / `ENDBR` (browse nhiều dòng, 2 chiều) | `COCRDLIC`, `COTRN00C`, `COUSR00C` | `COCRDLIC` |
| CICS `STARTBR` + `READPREV` để lấy khóa lớn nhất (sinh ID) | `COTRN02C`, `COBIL00C` | giữ cả 2 |
| CICS `SYNCPOINT` / `ROLLBACK` | `COACTUPC`, `COCRDUPC` | giữ cả 2 |
| CICS `HANDLE ABEND` / `ABEND` | `COACTUPC`, `COACTVWC`, `COCRDUPC`, `COCRDSLC` | `COACTUPC`, `COCRDUPC` |
| CICS `WRITEQ TD` | `CORPT00C` (duy nhất) | `CORPT00C` |
| CICS `ASKTIME` / `FORMATTIME` | `COBIL00C` | `COBIL00C` |
| CICS `ASSIGN`, `INQUIRE`, `SEND TEXT` | `COSGN00C`, `COMEN01C`, ... | giữ |
| BMS `SEND MAP` / `RECEIVE MAP`, thuộc tính field động (`CSSETATY`, `DFHBMSCA`) | tất cả online | giữ |
| Màn hình dạng lưới nhiều dòng (OCCURS trên map, chọn dòng) | `COCRDLIC`, `COTRN00C`, `COUSR00C` | `COCRDLIC` |
| VSAM KSDS + AIX + PATH | JCL load file | `ACCTFILE`, `CARDFILE`, `XREFFILE`, `TRANFILE`, `TRANIDX` |
| VSAM ESDS / RRDS | `ESDSRRDS` (duy nhất) | `ESDSRRDS` |
| File tuần tự record độ dài thay đổi (`RECORDING MODE V`, `RECORD VARYING`) | `CBACT01C` (duy nhất) | `CBACT01C` |
| `COMP`, `COMP-3`, `OCCURS` một chiều | `CBACT01C`, ... | `CBACT01C` |
| Bảng hai chiều `OCCURS ... OCCURS` | `CBSTM03A` (duy nhất) | `CBSTM03A` |
| `ALTER` / `GO TO` (code legacy) | `CBSTM03A` (duy nhất) | `CBSTM03A` |
| Đọc control block MVS (PSA/TCB/TIOT) bằng `POINTER` | `CBSTM03A` (duy nhất) | `CBSTM03A` |
| Output HTML | `CBSTM03A` (duy nhất) | `CBSTM03A` |
| Batch `CALL` subprogram có I/O | `CBSTM03A`→`CBSTM03B` | giữ |
| COBOL `CALL` Assembler | `CBACT01C`→`COBDATFT`, `COBSWAIT`→`MVSWAIT` | `CBACT01C`→`COBDATFT` |
| LE callable service (`CEEDAYS`, `CEE3ABD`) | `CSUTLDTC`, mọi batch | giữ |
| Utility IDCAMS / IEBGENER / IEFBR14 / SORT / SDSF | nhiều JCL | giữ trong JCL còn lại |
| JCL PROC + control card | `REPROC`, `TRANREPT.prc`, `REPROCT.ctl` | giữ |
| CSD + DFHCSDUP | `CARDDEMO.CSD`, `CBADMCDJ` | giữ |
| DB2 / IMS / MQ | module tùy chọn | **Loại bỏ có chủ đích** (xem 5.5) |

---

## 4. Module giữ lại

### 4.1 Chương trình online (CICS COBOL) — 12 chương trình

| Chương trình | TransID | Mapset | Công việc | File VSAM | Kỹ thuật tiêu biểu |
|---|---|---|---|---|---|
| `COSGN00C` | CC00 | COSGN00 | Màn hình đăng nhập. Xác thực user ID/password với USRSEC, phân luồng sang menu user hoặc admin theo loại user. | USRSEC (READ) | `ASSIGN`, XCTL theo vai trò, khởi tạo COMMAREA |
| `COMEN01C` | CM00 | COMEN01 | Menu chính cho user thường (7 option). Hiển thị option từ bảng `COMEN02Y`, kiểm tra chương trình đích đã cài chưa rồi XCTL. | — | Menu dữ liệu, `INQUIRE PROGRAM` |
| `COADM01C` | CA00 | COADM01 | Menu quản trị cho admin (2 option), dựa trên bảng `COADM02Y`. | — | Menu dữ liệu, phân quyền |
| `COACTUPC` | CAUP | COACTUP | **Xem và cập nhật** tài khoản + khách hàng. Nhập Account ID → tra xref theo account qua AIX → đọc và hiển thị account, customer → cho sửa (hạn mức, số dư, ngày, địa chỉ, SSN, điện thoại, FICO…) → xác nhận rồi ghi. Chương trình phức tạp nhất hệ thống. Trong bản Lite cũng đảm nhận chức năng "xem tài khoản" thay cho `COACTVWC`. | CXACAIX (READ), ACCTDAT, CUSTDAT (READ UPDATE / REWRITE) | Validate nhiều tầng (`CSUTLDPY`/`CSUTLDWY`, `CSLKPCDY`), state machine màn hình, khóa 2 file, optimistic check, `SYNCPOINT ROLLBACK`, `HANDLE ABEND` |
| `COCRDLIC` | CCLI | COCRDLI | **Danh sách thẻ** (đại diện duy nhất của mẫu màn hình danh sách). Hiển thị 7 thẻ mỗi trang (số tài khoản, số thẻ, trạng thái). Lọc tùy chọn theo Account ID (11 số) và/hoặc Card Number (16 số), validate kiểu số và tô đỏ ô lỗi. PF7/PF8 lùi/tới trang, lưu khóa đầu/cuối trang trong COMMAREA, đọc trước 1 bản ghi để biết còn trang sau. Chọn `S` hoặc `U` trên một dòng → XCTL sang `COCRDUPC` kèm account/card. PF3 về menu. | CARDDAT (browse) | `STARTBR/READNEXT/READPREV/ENDBR`, lọc trong chương trình, lưới nhiều dòng, phân trang 2 chiều |
| `COCRDUPC` | CCUP | COCRDUP | **Xem và cập nhật thẻ** (tên in trên thẻ, trạng thái, ngày hết hạn). Mở từ menu (nhập account + card) hoặc từ `COCRDLIC`. Trong bản Lite cũng đảm nhận chức năng "xem chi tiết thẻ" thay cho `COCRDSLC`. | CARDDAT (READ UPDATE / REWRITE) | Optimistic lock, `SYNCPOINT`, `HANDLE ABEND` |
| `COTRN01C` | CT01 | COTRN01 | **Xem chi tiết giao dịch.** Mở thẳng từ menu, người dùng nhập Transaction ID → đọc và hiển thị đầy đủ thông tin giao dịch. PF3 về menu, PF4 xóa màn hình. | TRANSACT (READ) | Mẫu Key-entry → Fetch |
| `COTRN02C` | CT02 | COTRN02 | **Thêm giao dịch thủ công**: validate account/card qua xref, validate ngày, sinh transaction ID mới (đọc bản ghi cuối + 1), xác nhận rồi ghi giao dịch. | CXACAIX, CCXREF, ACCTDAT, TRANSACT (READ, READPREV, WRITE) | `CALL CSUTLDTC`, sinh khóa tuần tự |
| `COBIL00C` | CB00 | COBIL00 | **Thanh toán toàn bộ dư nợ**: tạo giao dịch thanh toán, cập nhật số dư tài khoản về 0. | CXACAIX, ACCTDAT (READ UPDATE / REWRITE), TRANSACT (READPREV, WRITE) | Cập nhật nhiều file, `ASKTIME/FORMATTIME` |
| `CORPT00C` | CR00 | CORPT00 | **Yêu cầu in báo cáo giao dịch** (tháng / năm / khoảng ngày). Dựng JCL `TRANREPT` và submit qua TDQ `JOBS`. | — (TDQ JOBS) | **Cầu nối online → batch**, `WRITEQ TD`, `CALL CSUTLDTC` |
| `COUSR02C` | CU02 | COUSR02 | **Cập nhật user.** Mở thẳng từ menu admin. Nhập User ID + Enter → đọc và hiển thị first name, last name, password, user type. Sửa rồi PF5 (lưu) hoặc PF3 (lưu và thoát). Bắt buộc đủ 5 trường; không có thay đổi thì báo "Please modify to update" và không ghi; có thay đổi thì READ UPDATE + REWRITE. PF4 xóa màn hình, PF12 hủy. | USRSEC (READ UPDATE / REWRITE) | CRUD – Update, so sánh từng trường trước khi ghi |
| `COUSR03C` | CU03 | COUSR03 | **Xóa user.** Mở thẳng từ menu admin. Nhập User ID + Enter → hiển thị thông tin (không có password) để xác nhận → PF5 để READ UPDATE + DELETE. PF3 quay lại, PF4 xóa màn hình, PF12 hủy. | USRSEC (READ UPDATE, DELETE) | CRUD – Delete (**thao tác `DELETE` duy nhất của hệ thống**) |

### 4.2 Chương trình batch

| Chương trình | JCL | Công việc | Input → Output | Kỹ thuật tiêu biểu |
|---|---|---|---|---|
| `CBTRN02C` | POSTTRAN | **Posting giao dịch hằng ngày**, lõi của batch. Đọc DALYTRAN, validate (card có trong xref, account tồn tại, vượt hạn mức, thẻ hết hạn). Hợp lệ thì ghi TRANSACT, cập nhật TCATBAL (ghi mới hoặc ghi đè) và số dư ACCOUNT. Không hợp lệ thì ghi DALYREJS kèm mã lý do. | DALYTRAN, XREF, ACCOUNT, TCATBAL → TRANSACT, DALYREJS | Sequential update nhiều master, reject file, `RETURN-CODE` |
| `CBACT04C` | INTCALC | **Tính lãi hằng tháng.** Đọc TCATBAL tuần tự, ngắt nhóm theo account. Lấy lãi suất từ DISCGRP (fallback nhóm `DEFAULT`). Sinh giao dịch lãi vào file system transaction (GDG), cập nhật số dư tài khoản. | TCATBAL, XREF (AIX path), DISCGRP, ACCOUNT → TRANSACT (SYSTRAN), ACCOUNT | Control break, lookup có fallback, REWRITE |
| `CBTRN03C` | TRANREPT | **Báo cáo chi tiết giao dịch** (report đại diện). Lọc theo khoảng ngày (DATEPARM), tra XREF / TRANTYPE / TRANCATG để lấy mô tả. In theo trang, có tổng theo account, tổng theo trang, tổng cộng. Trong bản Lite đây cũng là cách duy nhất để xem danh sách giao dịch (thay cho `COTRN00C`). | TRANSACT (đã SORT), DATEPARM, XREF, TRANTYPE, TRANCATG → TRANREPT | Control break nhiều cấp, phân trang, lookup nhiều file |
| `CBSTM03A` | CREASTMT | **Sao kê tài khoản** dạng text và HTML. Gom giao dịch theo thẻ vào bảng hai chiều rồi in theo từng khách hàng/tài khoản. | (qua `CBSTM03B`) → STMTFILE, HTMLFILE | ALTER/GO TO, PSA/TCB/TIOT pointer, OCCURS 2 chiều, COMP/COMP-3, CALL subprogram |
| `CBSTM03B` | (được CALL) | Subprogram I/O cho `CBSTM03A`: open/read/close 4 file theo mã thao tác truyền qua LINKAGE. | TRNXFILE, XREFFILE, CUSTFILE, ACCTFILE | Truy cập file đóng gói trong subprogram |
| `CBACT01C` | READACCT | Đọc ACCOUNT KSDS và ghi ra 3 định dạng: file tuần tự cố định (COMP-3), file mảng (OCCURS), file record độ dài thay đổi. Gọi ASM để định dạng ngày. | ACCTFILE → OUTFILE, ARRYFILE, VBRCFILE | VB record, COMP-3, OCCURS, `CALL 'COBDATFT'` |

### 4.3 Utility / Assembler

| Thành phần | Công việc | Được gọi bởi |
|---|---|---|
| `CSUTLDTC` (COBOL) | Validate ngày bằng LE API `CEEDAYS`, trả về mã lỗi/message. | `COTRN02C`, `CORPT00C` |
| `COBDATFT` (ASM) + `maclib/COCDATFT.mac` | Chuyển đổi định dạng ngày. | `CBACT01C` |

### 4.4 Copybook

**Giữ toàn bộ** `app/cpy` trừ `CVEXPORT.cpy` và `UNUSED1Y.cpy`. **Giữ** các symbolic map trong `app/cpy-bms` tương ứng với 12 mapset còn lại: `COSGN00`, `COMEN01`, `COADM01`, `COACTUP`, `COCRDLI`, `COCRDUP`, `COTRN01`, `COTRN02`, `COBIL00`, `CORPT00`, `COUSR02`, `COUSR03`.

| Nhóm | Copybook | Vai trò |
|---|---|---|
| Ngữ cảnh / điều hướng | `COCOM01Y`, `COMEN02Y`, `COADM02Y` | COMMAREA, bảng menu user/admin |
| Hiển thị chung | `COTTL01Y`, `CSDAT01Y`, `CSMSG01Y`, `CSMSG02Y`, `CSSETATY`, `CSSTRPFY` | Tiêu đề, ngày giờ, message, set thuộc tính field, xử lý PF key |
| Bảo mật | `CSUSR01Y` | Layout USRSEC |
| Validate | `CSUTLDPY`, `CSUTLDWY`, `CSLKPCDY`, `CODATECN` | Validate ngày, tra mã vùng/bang, cấu trúc ngày cho ASM |
| Record master | `CVACT01Y` (account), `CVACT02Y` (card), `CVACT03Y` (xref), `CVCUS01Y`, `CUSTREC` (customer), `CVCRD01Y` (card work area) | Layout file VSAM |
| Record giao dịch | `CVTRA01Y` (TCATBAL), `CVTRA02Y` (DISCGRP), `CVTRA03Y` (TRANTYPE), `CVTRA04Y` (TRANCATG), `CVTRA05Y` (TRANSACT), `CVTRA06Y` (DALYTRAN), `CVTRA07Y` (report layout) | Layout file giao dịch |
| Sao kê | `COSTM01` | Layout statement |

### 4.5 JCL / PROC / CTL — 25 JCL

| JCL | Công việc | Nhóm |
|---|---|---|
| `DEFGDGB` | Định nghĩa GDG base (backup, systran, report, daily) | Setup |
| `CBADMCDJ` | Cài CSD vào CICS (DFHCSDUP) | Setup |
| `DUSRSECJ` | Tạo và nạp USRSEC VSAM. Trong bản Lite đây là cách tạo user (thay cho `COUSR01C`) | Setup / nạp dữ liệu |
| `ACCTFILE`, `CARDFILE`, `CUSTFILE`, `XREFFILE` | Định nghĩa và nạp master KSDS (+AIX, PATH cho card/xref) | Nạp dữ liệu |
| `TRANFILE` | Định nghĩa TRANSACT KSDS + AIX | Nạp dữ liệu |
| `TRANCATG`, `TRANTYPE`, `DISCGRP`, `TCATBALF` | Nạp các bảng tham chiếu / số dư theo category | Nạp dữ liệu |
| `DALYREJS` | Định nghĩa GDG file reject | Setup |
| `REPTFILE` | Định nghĩa GDG file report | Setup |
| `ESDSRRDS` | Tạo VSAM ESDS và RRDS (minh họa loại VSAM khác KSDS) | Kỹ thuật |
| `CLOSEFIL` / `OPENFIL` | Đóng/mở file VSAM trong CICS trước/sau batch (SDSF) | Chu trình batch |
| `POSTTRAN` | Chạy `CBTRN02C` | Chu trình batch |
| `INTCALC` | Chạy `CBACT04C` | Chu trình batch |
| `TRANBKP` | Backup TRANSACT ra GDG, định nghĩa lại cluster (dùng PROC `REPROC`) | Chu trình batch |
| `COMBTRAN` | SORT/gộp giao dịch hằng ngày + giao dịch hệ thống, nạp lại TRANSACT | Chu trình batch |
| `TRANIDX` | Tạo lại AIX cho TRANSACT | Chu trình batch |
| `CREASTMT` | SORT + chạy `CBSTM03A` | Chu trình batch |
| `TRANREPT` | Backup + SORT + chạy `CBTRN03C` (cũng được submit từ `CORPT00C`) | Báo cáo |
| `READACCT` | Chạy `CBACT01C` | Kỹ thuật |
| `proc/REPROC.prc`, `proc/TRANREPT.prc`, `ctl/REPROCT.ctl` | PROC và control card dùng chung | Hạ tầng JCL |

### 4.6 Dữ liệu, CSD, script, tài liệu

- `app/data/ASCII/*` và `app/data/EBCDIC/*`, trừ `EXPORT.DATA.PS` và `ACCDATA.PS` (xem 5.6).
- `app/csd/CARDDEMO.CSD` (đã chỉnh, xem 7.3), `app/catlg/LISTCAT.txt`.
- `scripts/*` (đã chỉnh `run_full_batch.sh`).
- `diagrams/`: giữ `Signon-Screen.png`, `Main-Menu.png`, `Admin-Menu.png`, `Application-Flow-*.png`, `CARDDEMO-DataModel.drawio`. Các ảnh menu/flow cần vẽ lại sau khi rút gọn.
- `docs/business/*` (cần rà lại các phần mô tả màn hình đã loại).

---

## 5. Module loại bỏ

### 5.1 Chương trình online

| Chương trình | TransID / Mapset | Công việc | Mức | Lý do loại | Chức năng được bao phủ bởi |
|---|---|---|---|---|---|
| `COCRDSLC` | CCDL / COCRDSL | Xem chi tiết một thẻ (chỉ đọc). | Cơ bản | Trùng phần đọc + hiển thị của `COCRDUPC`. Giống `COACTVWC` 67%. | `COCRDUPC` |
| `COUSR01C` | CU01 / COUSR01 | Thêm user mới. | Cơ bản | Cùng khuôn với `COUSR02C/03C` (55–61%); `WRITE` đã có ở `COTRN02C`, `COBIL00C`. | `DUSRSECJ` (nạp user ban đầu) |
| `COACTVWC` | CAVW / COACTVW | Xem tài khoản + khách hàng (chỉ đọc): nhập Account ID, tra xref qua AIX, đọc account và customer. | Mức 1 | `COACTUPC` có cùng ô nhập Account ID, cùng 3 lệnh đọc (CXACAIX, ACCTDAT, CUSTDAT) và hiển thị đủ thông tin trước khi sửa. `HANDLE ABEND` đã có ở `COACTUPC`, `COCRDUPC`. | `COACTUPC` |
| `COTRN00C` | CT00 / COTRN00 | Danh sách giao dịch, phân trang, chọn `S` để xem chi tiết. | Mức 2 | Cùng khuôn với `COUSR00C` (64%) và `COCRDLIC`. Browse 2 chiều, lưới nhiều dòng, chọn dòng đều có ở `COCRDLIC`. | Xem từng giao dịch: `COTRN01C` (nhập Tran ID). Xem danh sách: report `TRANREPT` (`CORPT00C` → `CBTRN03C`) |
| `COUSR00C` | CU00 / COUSR00 | Danh sách user, phân trang, chọn `U` (sửa) / `D` (xóa). | Mức 2 | Cùng khuôn với `COTRN00C` (64%). Kỹ thuật được bao phủ bởi `COCRDLIC`. | `COUSR02C`, `COUSR03C` mở thẳng từ menu admin bằng User ID |

**Chức năng nghiệp vụ mất đi (chấp nhận):**
- Thêm user online.
- Duyệt danh sách giao dịch trên màn hình (vẫn có qua report).
- Duyệt danh sách user trên màn hình (admin phải biết User ID).

### 5.2 Chương trình batch

| Chương trình | JCL | Công việc | Lý do loại | Bao phủ bởi |
|---|---|---|---|---|
| `CBACT02C` | READCARD | Đọc CARDDATA tuần tự và DISPLAY từng record. | Cùng một khuôn đọc-in như `CBACT03C`, `CBCUS01C` (67–73%), chỉ khác file. | `CBACT01C` (cùng mẫu đọc KSDS tuần tự, nhiều kỹ thuật hơn) |
| `CBACT03C` | READXREF | Đọc CARDXREF và DISPLAY. | Như trên. | `CBACT01C` |
| `CBCUS01C` | READCUST | Đọc CUSTDATA và DISPLAY. | Như trên. | `CBACT01C` |
| `CBTRN01C` | — | Phiên bản sơ khai của posting: đọc DALYTRAN, tra xref/account rồi DISPLAY, không cập nhật. | Bị `CBTRN02C` bao trọn. | `CBTRN02C` |
| `CBEXPORT` | CBEXPORT | Export toàn bộ dữ liệu (customer, account, xref, tran, card) ra một file đa loại record. | Chức năng di trú dữ liệu bổ sung, không thuộc nghiệp vụ lõi. | — (có thể dùng IDCAMS REPRO nếu cần) |
| `CBIMPORT` | CBIMPORT | Import file export, tách ra từng file + file lỗi. | Như trên. | — |
| `COBSWAIT` | WAITSTEP | Chờ N giây bằng cách gọi ASM `MVSWAIT`. | Tiện ích; kỹ thuật COBOL→ASM đã có ở `CBACT01C`→`COBDATFT`. | `CBACT01C` |

### 5.3 Assembler / macro

| Thành phần | Lý do |
|---|---|
| `asm/MVSWAIT.asm`, `maclib/ASMWAIT.mac` | Chỉ phục vụ `COBSWAIT` |

### 5.4 JCL (13 file)

| JCL | Công việc | Lý do loại |
|---|---|---|
| `READCARD`, `READCUST`, `READXREF` | Chạy các chương trình đọc-in | Chương trình đã bị loại |
| `CBEXPORT`, `CBIMPORT` | Export/import | Chương trình đã bị loại |
| `WAITSTEP` | Chờ | Chương trình đã bị loại |
| `PRTCATBL` | SORT và in TCATBAL | Kỹ thuật SORT + PROC đã có ở `TRANREPT`, `COMBTRAN` |
| `TXT2PDF1` | Chuyển sao kê text sang PDF (TSO/REXX) | Tiện ích ngoài COBOL |
| `FTPJCL` | Truyền file qua FTP | Tiện ích hạ tầng |
| `INTRDRJ1`, `INTRDRJ2` | Minh họa submit job qua internal reader bằng JCL | Kỹ thuật này đã có ở `CORPT00C` (TDQ JOBS) |
| `DEFGDGD` | GDG + backup cho bảng tham chiếu, phục vụ module DB2 | Module DB2 bị loại |
| `DEFCUST` | Định nghĩa customer cluster với HLQ cũ (`AWS.CUSTDATA`) | Trùng `CUSTFILE` và không còn được dùng |

### 5.5 Module tùy chọn (loại toàn bộ thư mục)

| Thư mục | Nội dung | Lý do |
|---|---|---|
| `app/app-authorization-ims-db2-mq/` | Pending authorization: IMS DB, DB2, MQ, 8 chương trình (`COPAUA0C`, `COPAUS0C/1C/2C`, `CBPAUP0C`, `DBUNLDGS`, `PAUDBLOD`, `PAUDBUNL`) | Ngoài phạm vi CICS + VSAM |
| `app/app-transaction-type-db2/` | Quản lý transaction type trên DB2 (`COTRTLIC`, `COTRTUPC`, `COBTUPDT`) | Ngoài phạm vi; bảng TRANTYPE vẫn có dạng VSAM |
| `app/app-vsam-mq/` | Truy vấn account/date qua MQ (`COACCT01`, `CODATE01`) | Ngoài phạm vi |

> **Lưu ý:** nếu sau này cần minh họa **Embedded SQL (cursor, CRUD DB2)**, nên khôi phục riêng `app-transaction-type-db2` vì module này nhỏ (3 chương trình) và độc lập.

### 5.6 Thư mục và file khác

| Thành phần | Lý do |
|---|---|
| `app/scheduler/` (CA7, Control-M) | Định nghĩa lịch chạy, không phải logic; chuỗi batch được ghi ở mục 6 và trong `run_full_batch.sh` |
| `samples/` | Mẫu triển khai, không thuộc ứng dụng |
| `diagrams/auth_*.png`, `db2_model.png`, `ims_model.png` | Thuộc module tùy chọn |
| `cpy/CVEXPORT.cpy` | Chỉ dùng cho export/import |
| `cpy/UNUSED1Y.cpy` | Không chương trình nào dùng |
| `bms/` + `cpy-bms/` của `COCRDSL`, `COUSR01`, `COACTVW`, `COTRN00`, `COUSR00` | Mapset của chương trình đã loại |
| `data/EBCDIC/AWS.M2.CARDDEMO.EXPORT.DATA.PS` | Dữ liệu export |
| `data/EBCDIC/AWS.M2.CARDDEMO.ACCDATA.PS` | Bản trùng kích thước với `ACCTDATA.PS`, không JCL nào tham chiếu. **Cần đối chiếu nội dung trước khi xóa.** |

---

## 6. Chu trình batch của bản Lite

```
 Setup (chạy 1 lần):  DEFGDGB → DALYREJS → REPTFILE → CBADMCDJ → DUSRSECJ → ESDSRRDS

 Full batch:
  1. CLOSEFIL   đóng file trong CICS
  2. ACCTFILE   CARDFILE   XREFFILE   CUSTFILE   TRANFILE
     TRANCATG   TRANTYPE   DISCGRP    TCATBALF          (nạp master + tham chiếu)
  3. POSTTRAN   CBTRN02C   posting DALYTRAN → TRANSACT / TCATBAL / ACCOUNT / DALYREJS
  4. INTCALC    CBACT04C   tính lãi → SYSTRAN
  5. TRANBKP    backup TRANSACT
  6. COMBTRAN   SORT gộp DALY + SYSTRAN → TRANSACT
  7. TRANIDX    tạo lại AIX TRANSACT
  8. CREASTMT   CBSTM03A/B sao kê text + HTML
  9. OPENFIL    mở lại file cho CICS

 Theo yêu cầu:  TRANREPT (CBTRN03C) — submit từ màn hình CORPT00C hoặc chạy tay
                READACCT (CBACT01C) — chạy tay
```

---

## 7. Thay đổi bắt buộc khi tạo bản Lite

### 7.1 Bảng menu

**`app/cpy/COMEN02Y.cpy`** (menu user: 11 → 7 option)

| # mới | Option | Chương trình | Ghi chú |
|---|---|---|---|
| 1 | Account Update | `COACTUPC` | Đổi nhãn thành "Account View/Update" (tùy chọn) |
| 2 | Credit Card List | `COCRDLIC` | |
| 3 | Credit Card Update | `COCRDUPC` | Đổi nhãn thành "Credit Card View/Update" (tùy chọn) |
| 4 | Transaction View | `COTRN01C` | |
| 5 | Transaction Add | `COTRN02C` | |
| 6 | Transaction Reports | `CORPT00C` | |
| 7 | Bill Payment | `COBIL00C` | |

- Xóa: `COACTVWC` (Account View), `COCRDSLC` (Credit Card View), `COTRN00C` (Transaction List), `COPAUS0C` (Pending Authorization View).
- Đổi `CDEMO-MENU-OPT-COUNT` từ `11` thành `7`.

**`app/cpy/COADM02Y.cpy`** (menu admin: 6 → 2 option)

| # mới | Option | Chương trình |
|---|---|---|
| 1 | User Update (Security) | `COUSR02C` |
| 2 | User Delete (Security) | `COUSR03C` |

- Xóa: `COUSR00C` (User List), `COUSR01C` (User Add), `COTRTLIC`, `COTRTUPC`.
- Đổi `CDEMO-ADMIN-OPT-COUNT` từ `6` thành `2`.

**Lưu ý kích thước bảng:** hai bảng dùng `REDEFINES` với `OCCURS 12 TIMES` (user) và `OCCURS 9 TIMES` (admin) phủ lên vùng dữ liệu FILLER. Sau khi xóa option, vùng FILLER ngắn hơn vùng REDEFINES. Cần một trong hai cách:
- Giảm `OCCURS` cho khớp (7 và 2).
- Hoặc thêm `FILLER PIC X(46)` / `X(45)` đệm cho đủ kích thước.

Phải kiểm tra lại vòng lặp hiển thị trong `COMEN01C` / `COADM01C` (lặp theo `*-OPT-COUNT`).

### 7.2 COBOL (chỉ đổi hằng số, không đổi logic)

| File | Thay đổi | Lý do |
|---|---|---|
| `COCRDLIC.cbl` | Đổi `LIT-CARDDTLPGM` từ `'COCRDSLC'` sang `'COCRDUPC'`, và `LIT-CARDDTLMAPSET` / `LIT-CARDDTLMAP` từ `COCRDSL` / `CCRDSLA` sang `COCRDUP` / `CCRDUPA`. Có thể đổi luôn `LIT-CARDDTLTRANID` từ `CCDL` sang `CCUP` cho nhất quán. | Lựa chọn `S` trên danh sách thẻ sẽ mở màn hình xem/cập nhật thẻ |
| `COTRN01C.cbl:126` | PF5 đang `MOVE 'COTRN00C' TO CDEMO-TO-PROGRAM`, đổi thành `'COMEN01C'` (hoặc bỏ nhánh `WHEN DFHPF5`, để rơi vào thông báo phím không hợp lệ). | `COTRN00C` đã bị loại |
| `COACTUPC.cbl`, `COCRDUPC.cbl` | Có khai báo `LIT-CARDDTLPGM = 'COCRDSLC'` nhưng không có lệnh nào dùng (đã kiểm tra). Không bắt buộc sửa, có thể đổi để nhất quán. | — |

Không cần sửa `COUSR02C` / `COUSR03C`: khi mở từ menu, `CDEMO-CU0x-USR-SELECTED` để trống nên màn hình chờ nhập User ID, và PF3/PF12 quay về `COADM01C`.

### 7.3 CSD (`app/csd/CARDDEMO.CSD`)

| Xóa | PROGRAM | TRANSACTION | MAPSET |
|---|---|---|---|
| Xem thẻ | `COCRDSLC` | `CCDL` | `COCRDSL` |
| Thêm user | `COUSR01C` | `CU01` | `COUSR01` |
| Xem tài khoản | `COACTVWC` | `CAVW` | `COACTVW` |
| Danh sách giao dịch | `COTRN00C` | `CT00` | `COTRN00` |
| Danh sách user | `COUSR00C` | `CU00` | `COUSR00` |
| Định nghĩa mồ côi (không có source) | `COCRDSEC` | `CDV1` | — |

Giữ `TDQUEUE(JOBS)`, các `FILE(...)` và `LIBRARY(...)`. `FILE(CARDAIX)` không còn chương trình online nào dùng, nhưng vẫn giữ vì AIX/PATH của CARDDAT vẫn được định nghĩa trong `CARDFILE`.

### 7.4 Script và tài liệu

- `scripts/run_full_batch.sh`: bỏ `WAITSTEP`, `TRANEXTR`, `CBPAUP0J` và các bước của module tùy chọn.
- `README.md`: cập nhật danh sách chương trình, màn hình, JCL, và xóa phần "Optional Modules".
- `diagrams/Main-Menu.png`, `Admin-Menu.png`, `Application-Flow-*.png`: vẽ lại theo menu mới.
- `docs/business/*`: rà lại các phần nhắc tới màn hình đã loại.

---

## 8. Tiêu chí nghiệm thu

1. **Biên dịch:** toàn bộ 19 chương trình COBOL, 1 ASM và 12 BMS compile không lỗi. Không còn `COPY` nào trỏ tới copybook không tồn tại.
2. **Tham chiếu:** grep không còn tên chương trình đã loại trong `cbl`, `cpy`, `csd`, `jcl`, `scripts` (ngoại trừ comment và các hằng không dùng nêu ở 7.2). Danh sách tên: `COCRDSLC`, `COUSR01C`, `COACTVWC`, `COTRN00C`, `COUSR00C`, `CBACT02C`, `CBACT03C`, `CBCUS01C`, `CBTRN01C`, `CBEXPORT`, `CBIMPORT`, `COBSWAIT`, `MVSWAIT`, `COPAUS0C`, `COTRTLIC`, `COTRTUPC`.
3. **Online – điều hướng:**
   - Đăng nhập được bằng user thường và admin.
   - Menu user hiện đúng 7 option, menu admin hiện đúng 2 option, mọi option mở đúng màn hình.
   - Chọn `S` và `U` trên danh sách thẻ đều mở `COCRDUPC` với đúng thẻ đã chọn.
   - PF3 trên mọi màn hình quay về đúng menu.
4. **Online – nghiệp vụ:**
   - Xem và sửa account + customer thành công. Mô phỏng thay đổi đồng thời thì nhận đúng thông báo "data was changed".
   - Xem giao dịch theo Tran ID.
   - Thêm giao dịch sinh ID tăng dần.
   - Thanh toán đưa số dư về 0 và sinh giao dịch.
   - Sửa user, xóa user thành công.
5. **Online → batch:** gửi yêu cầu report từ `CORPT00C` thì job `TRANREPT` được submit và tạo report.
6. **Batch:** chạy hết chu trình ở mục 6 với RC ≤ 4 (`POSTTRAN` trả RC=4 khi có reject là hợp lệ). Sao kê tạo được cả file text và HTML.
7. **Độ phủ kỹ thuật:** mọi dòng trong ma trận 3.3 (trừ dòng DB2/IMS/MQ) đều chỉ ra được chương trình hoặc JCL tồn tại trong bản Lite.
