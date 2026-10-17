# 00. Lộ trình học SQL

> **Tóm tắt:** Trang này là roadmap 30 ngày học SQL, tóm tắt từng ngày bạn sẽ học gì – từ các truy vấn cơ bản (SELECT, WHERE, JOIN) đến các chủ đề nâng cao (Transactions, Index, Optimization, Security, Big Data, NoSQL). Đây là entry point để AI Agents và người đọc hiểu nhanh cấu trúc lộ trình trước khi đi vào từng bài chi tiết.

Dưới đây là **lộ trình học SQL trong 30 ngày** với các mục tiêu hàng ngày để giúp bạn từng bước nắm vững SQL, từ cơ bản đến nâng cao.  

---

### **📅 Tuần 1: Cơ bản về SQL & Truy vấn đơn giản**  
📌 **Ngày 1:** [Giới thiệu SQL, RDBMS (MySQL, PostgreSQL, SQL Server, SQLite)](01-intro-to-sql-and-dbms.md)
- Hiểu SQL là gì?  
- Cách hoạt động của hệ quản trị cơ sở dữ liệu quan hệ (RDBMS).  
- Cài đặt MySQL/PostgreSQL/SQLite.  
- Thực hành: Tạo database đơn giản.  

📌 **Ngày 2:** [Kiến trúc bảng & Kiểu dữ liệu](02-table-structure-and-data-types.md)
- Hiểu về bảng, cột, hàng (rows, columns).  
- Các kiểu dữ liệu: `INT`, `VARCHAR`, `TEXT`, `DATE`, `BOOLEAN`, `FLOAT`, v.v.  
- Thực hành: Tạo bảng với các kiểu dữ liệu khác nhau.  

📌 **Ngày 3:** [Câu lệnh SELECT & WHERE](03-select-where.md)
- Cách sử dụng `SELECT` để truy vấn dữ liệu.  
- Bộ lọc `WHERE`, toán tử `=`, `!=`, `>`, `<`, `LIKE`, `BETWEEN`, `IN`.  
- Thực hành: Lọc dữ liệu từ một bảng có sẵn.  

📌 **Ngày 4:** [Sắp xếp & Giới hạn dữ liệu](04-order-by-limit.md)
- `ORDER BY` (sắp xếp tăng/giảm dần).  
- `LIMIT` (lấy số dòng giới hạn).  
- Thực hành: Lấy 5 sản phẩm đắt nhất, 10 khách hàng mới nhất.  

📌 **Ngày 5:** [Toán tử & Biểu thức trong SQL](05-operators-expressions.md)
- Toán tử số học (`+`, `-`, `*`, `/`).  
- Toán tử logic (`AND`, `OR`, `NOT`).  
- Thực hành: Viết truy vấn sử dụng toán tử logic.  

📌 **Ngày 6:** [Chỉnh sửa dữ liệu với `INSERT`, `UPDATE`, `DELETE`](06-insert-update-delete.md)
- Chèn dữ liệu với `INSERT INTO`.  
- Cập nhật dữ liệu bằng `UPDATE`.  
- Xóa dữ liệu với `DELETE`.  
- Thực hành: Thêm, cập nhật, xóa dữ liệu trong bảng.  

📌 **Ngày 7:** [Kiểm tra kiến thức - Bài tập tổng hợp tuần 1](07-review-1.md)
- Xây dựng database đơn giản cho hệ thống quản lý sinh viên hoặc cửa hàng.  
- Viết các truy vấn thực tế với `SELECT`, `INSERT`, `UPDATE`, `DELETE`.  

---

### **📅 Tuần 2: Các hàm & Truy vấn nâng cao**  
📌 **Ngày 8:** [Hàm trong SQL - Aggregate Functions](08-aggregate-functions.md)
- `COUNT()`, `SUM()`, `AVG()`, `MIN()`, `MAX()`.  
- Thực hành: Tính tổng doanh thu, số lượng đơn hàng, giá trung bình.  

📌 **Ngày 9:** [GROUP BY & HAVING](09-group-by-having.md)
- `GROUP BY` để nhóm dữ liệu.  
- `HAVING` để lọc dữ liệu sau khi nhóm.  
- Thực hành: Đếm số đơn hàng theo khách hàng, tổng doanh thu theo tháng.  

📌 **Ngày 10:** [Truy vấn nhiều bảng - JOIN](10-join.md)
- `INNER JOIN`, `LEFT JOIN`, `RIGHT JOIN`, `FULL JOIN`.  
- Thực hành: Lấy danh sách đơn hàng kèm thông tin khách hàng.  

📌 **Ngày 11:** [Truy vấn con (Subquery)](11-subquery.md)
- Subquery trong `SELECT`, `WHERE`, `FROM`.  
- Thực hành: Tìm sản phẩm có giá cao hơn giá trung bình.  

📌 **Ngày 12:** [UNION & INTERSECT](12-union-intersect.md)
- `UNION` để hợp dữ liệu từ nhiều bảng.  
- `INTERSECT` để lấy dữ liệu chung.  
- Thực hành: Kết hợp danh sách khách hàng từ hai bảng khác nhau.  

📌 **Ngày 13:** [CASE WHEN (Điều kiện trong SQL)](13-case-when.md)
- Cách sử dụng `CASE WHEN` để xử lý điều kiện.  
- Thực hành: Phân loại sản phẩm theo giá rẻ/trung bình/đắt.  

📌 **Ngày 14:** [Ôn tập và bài tập tổng hợp tuần 2](14-review-2.md)
- Viết truy vấn phức tạp kết hợp `JOIN`, `GROUP BY`, `HAVING`, `CASE WHEN`.  

---

### **📅 Tuần 3: SQL nâng cao & Tối ưu hóa**  
📌 **Ngày 15:** [Chỉ mục (Indexes)](15-index.md)
- Cách hoạt động của chỉ mục (`INDEX`).  
- Khi nào nên dùng?  
- Thực hành: Tạo index trên bảng lớn.  

📌 **Ngày 16:** [Transactions & ACID](16-transactions-acid.md)
- Hiểu về Transactions (`BEGIN`, `COMMIT`, `ROLLBACK`).  
- Đảm bảo tính nhất quán dữ liệu với ACID.  
- Thực hành: Mô phỏng giao dịch ngân hàng.  

📌 **Ngày 17:** [Stored Procedures & Functions](17-stored-procedures-functions.md)
- Viết `Stored Procedure` để tự động hóa truy vấn.  
- Viết `User Defined Functions (UDF)`.  
- Thực hành: Tạo một hàm trả về tổng doanh thu tháng.  

📌 **Ngày 18:** [Triggers (Tự động hóa trong SQL)](18-triggers.md)
- Tạo Trigger để kiểm soát dữ liệu trước/sau thay đổi.  
- Thực hành: Tự động cập nhật tồn kho khi có đơn hàng mới.  

📌 **Ngày 19:** [Views (Bảng ảo)](19-views.md)
- Cách tạo và sử dụng `VIEW`.  
- Thực hành: Tạo View giúp đơn giản hóa truy vấn phức tạp.  

📌 **Ngày 20:** [Phân tích hiệu suất truy vấn](20-query-performance.md)
- `EXPLAIN ANALYZE` để kiểm tra hiệu suất truy vấn.  
- Thực hành: So sánh hiệu suất với và không có index.  

📌 **Ngày 21:** [Ôn tập và bài tập tổng hợp tuần 3](21-review-3.md)
- Viết truy vấn tối ưu với `Stored Procedures`, `Functions`, `Views`, `Triggers`, `Indexes`, `Transactions`, v.v.

---

### **📅 Tuần 4: Thực hành với Dữ liệu thực tế & NoSQL**  
📌 **Ngày 22:** [Làm việc với dữ liệu JSON trong SQL](22-sql-json-practice.md)
- Cách lưu trữ và truy vấn JSON trong SQL.  
- Thực hành: Xử lý JSON trong PostgreSQL/MySQL.  

📌 **Ngày 23:** [Kết nối SQL với ứng dụng](23-sql-connect-apps.md)
- Cách kết nối SQL với Python, Node.js, C#, v.v.  
- Thực hành: Viết API CRUD đơn giản.  

📌 **Ngày 24:** [Nhập & Xuất dữ liệu CSV, Excel](24-import-export-data.md)
- `LOAD DATA INFILE`, `COPY`, `IMPORT/EXPORT`.  
- Thực hành: Nhập dữ liệu từ file CSV vào bảng SQL.  

📌 **Ngày 25:** [Làm việc với dữ liệu lớn (Big Data)](25-big-data.md)
- Phân vùng bảng (`Partitioning`).  
- Thực hành: Tạo bảng phân vùng theo tháng.  

📌 **Ngày 26:** [So sánh SQL & NoSQL](26-sql-nosql.md)
- Hiểu sự khác nhau giữa SQL & NoSQL (MongoDB, Firebase).  

📌 **Ngày 27:** [Thiết kế CSDL & Best Practices](27-database-design-best-practices.md)
- Nguyên tắc chuẩn hóa (1NF, 2NF, 3NF, BCNF).  
- Khi nào nên **denormalize** để tối ưu hiệu suất?  
- Cách thiết kế cơ sở dữ liệu **có thể mở rộng** cho hệ thống lớn.  

📌 **Ngày 28:** [Tối ưu hóa truy vấn & Debug SQL nâng cao](28-sql-query-optimization.md)
- **EXPLAIN ANALYZE** để kiểm tra hiệu suất truy vấn.  
- Tránh các lỗi phổ biến khi viết truy vấn SQL.  
- So sánh cách viết truy vấn tối ưu với `JOIN`, `INDEX`, `PARTITION`.  

📌 **Ngày 29:** [Recursive Queries & Window Functions](29-recursive-queries-window-functions.md)
- Cách viết **Recursive Queries** (`WITH RECURSIVE`).  
- **Window Functions** (`RANK()`, `DENSE_RANK()`, `ROW_NUMBER()`).  
- Ứng dụng trong báo cáo và phân tích dữ liệu.  

📌 **Ngày 30:** [Quản trị & Bảo mật Database](30-database-security.md)
- Quản lý **Users, Roles, Permissions** (`GRANT`, `REVOKE`).  
- Phát hiện & ngăn chặn **SQL Injection**.  
- Sao lưu & phục hồi dữ liệu (**Backup & Restore**).

📌 **END:** [Tổng kết khóa học](99-summary.md)
- Review lại kiến thức đã học.
- Lập kế hoạch học tập tiếp theo.

---

[📚 Mục lục](../README.md) | [01. Giới thiệu SQL & DBMS ➡️](01-intro-to-sql-and-dbms.md)
