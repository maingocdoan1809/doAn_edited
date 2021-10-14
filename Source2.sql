----------------------------------------Cài đặt database đồ án của nhóm 9--------------------
-- - Hệ thống tính toán các dữ liệu chính như: Phí shippers, phí cửa hàng, tổng doanh thu xoay quanh theo tháng và hóa đơn.
--   các tháng được cập nhật tự động từ built-in function là: GETDATE() và MONTH()
--   Các thủ tục, truy vấn đều được chuyển sang dưới dạng PROCEDURES và FUNCTIONS ( RETURN TYPE: TABLE )
--   Đề xuất thay đổi database: Thêm cột NAM INT YEAR(GETDATE()) vào bảng PhiShippers và CuaHang
--   Đã thay đổi: Cột DANH_GIA từ bảng Shippers từ kiểu TINYINT sang DECIMAL(2,1)
--   Xem thêm file: Interface.sql
--                : Source.sql
-- I, Các lệnh cập nhật, thêm mới.
--     1, CuaHang:
        /*Cập nhật ID của CuaHang mới trong hệ thống vào bảng PhiCuaHang: */
    CREATE OR ALTER PROCEDURE ADD_CuaHang AS
        INSERT INTO 
            PhiCuaHang(P_ID)
            SELECT P_ID from CuaHang 
                        WHERE   MONTH(GETDATE()) > ALL (
                                    SELECT THANG FROM PhiCuaHang --- Trường hợp sang tháng mới
                                )  OR YEAR(GETDATE()) > ALL (
                                    SELECT NAM FROM PhiCuaHang --- Trường hợp sang năm mới
                                )  OR P_ID != ALL (
                                    SELECT P_ID from PhiCuaHang  --- Trường hợp có thêm CuaHang mới
                                )
        -------------------------------------------------------------------------------------
    -- -- SELECT * from PhiCuaHang
    -- 2, Shippers
    --     /*Cập nhật ID của Shipper mới trong hệ thống vào bảng PhiShippers */

    --CREATE OR ALTER PROCEDURE ADD_Shipper AS

        INSERT INTO 
            PhiShippers(S_ID)
            SELECT S_ID from Shippers 
                            WHERE MONTH(GETDATE()) > ALL (
                                SELECT THANG FROM PhiShippers
                            ) OR YEAR(GETDATE()) > ALL (
                                SELECT NAM FROM PhiShippers
                            ) OR S_ID != ALL (
                                SELECT S_ID from PhiShippers
                            )
                
        -- SELECT * from PhiShippers


-----------------------------------------------------------------------------------------------------------------------------------------------------



        /*Tính phí phải trả của Shipper mỗi cuối tháng và cập nhật vào trong bảng PhiShippers */
    -- CREATE or ALTER PROCEDURE Update_ShipperFee AS
        UPDATE PhiShippers
            SET PhiShippers.SO_TIEN_KIEM_DUOC_TRONG_THANG = sSum.TONG_TIEN_SHIP ,
                PhiShippers.TIEN_PHI_THANG = sSum.PHI_PHAI_TRA
            FROM
                PhiShippers as s
                INNER JOIN
                (
                SELECT  HoaDon.S_ID,
                        SUM(HoaDon.PHI_SHIP_VND) as TONG_TIEN_SHIP,
                        SUM(HoaDon.PHI_SHIP_VND)*0.3 as PHI_PHAI_TRA,
                        -- Hệ số tính: Lấy 30% tổng số tiền phí ship mà shipper nhận được trong mỗi đơn hàng
                        MONTH(GETDATE()) as Thang ,
                        YEAR(GETDATE()) as NAM
                    from HoaDon
                WHERE HoaDon.TRANG_THAI = N'Đã giao' 
                        AND  
                        MONTH(HoaDon.THOI_GIAN_NHAN_HANG) = MONTH(GETDATE())
                        AND 
                        YEAR(HoaDon.THOI_GIAN_NHAN_HANG) = YEAR(GETDATE())

                /*
                *chỉ những đơn hàng "Đã giao" thì hệ thống mới thực sự tính phí cho shipper, nếu đơn hàng ở trạng thái đang giao thì vẫn chưa coi
                 là một đơn hàng thành công -> shipper vẫn chưa nhận được tiền phí ship.
                * Điều kiện WHERE nhấn mạnh rằng tiền phí tháng/ năm nào thì phải tính cho shipper ở tháng/ năm đấy
                 */
                GROUP BY S_ID
                ) as sSum
                ON s.S_ID = sSum.S_ID and sSum.Thang = s.THANG and sSum.NAM = s.NAM



-----------------------------------------------------------------------------------------------------------------------------------------------------




    -- 3, Cập nhật:
    -- Ghi các mặt hàng có trong hóa đơn vào bảng MatHang_HD
    -- CREATE OR ALTER PROCEDURE Cap_nhat_mat_hang_trong_hoa_don @B_ID SMALLINT, @H_ID SMALLINT,@amount TINYINT AS
    --- @param:* @B_ID
            --*  @H_ID
            --*  @amount
        DECLARE @soluonghangconlai TINYINT;
        DECLARE @trangthai NVARCHAR(15);
        DECLARE @OK NVARCHAR(20);
        DECLARE @NotOk NVARCHAR(100);
        SET @OK = N'Thành công.';
        SET @NotOk = N'Thất bại, số lượng hàng trong kho không đủ hoặc đơn hàng đang(đã) giao! Xin vui lòng thử lại';
        SET @soluonghangconlai = (
            SELECT CON_LAI FROM MatHang
            WHERE MatHang.H_ID = @H_ID
        ); -- get số lượng còn lại của mặt hàng có mã @H_ID trong kho
        SET @trangthai = (
            select TRANG_THAI from HoaDon
            WHERE HoaDon.B_ID = @B_ID
        ) -- get trạng thái của đơn hàng có mã @B_ID
        IF  @soluonghangconlai >= @amount and @trangthai = N'Chờ xác nhận'  
                -- Kiểm tra trong kho hàng có đủ lượng @amount khách hàng yêu cầu hay không.
            BEGIN
                INSERT INTO MatHang_HD(H_ID, B_ID,SO_LUONG) 
                    VALUES(
                        @H_ID, -- H_ID; ID mặt hàng mua
                        @B_ID,-- B_ID; ID hóa đơn mua
                        @amount -- SO_LUONG 
                    )
                -- sau khi (thêm) bán thì phải trừ đi số lượng đã bán
                UPDATE MatHang
                    SET MatHang.CON_LAI = (MatHang.CON_LAI - @amount)
                    WHERE MatHang.H_ID = @H_ID
                SELECT @OK AS THANH_CONG
            END
        ELSE  -- Nếu kho không đủ thì không thực hiện cập nhật
            BEGIN
            (SELECT @NotOk AS THAT_BAI)
            END
        

        



    -- Update tổng tiền hàng cho tất cả các bills mới được thêm mới.
    -- CREATE or ALTER PROCEDURE Update_Bills AS

    UPDATE HoaDon
        SET HoaDon.TONG_TIEN = bSum.SUM + HoaDon.PHI_SHIP_VND , 
            HoaDon.KHUYEN_MAI_VND = bSum.DISCOUNT
        FROM
             (
            HoaDon AS h
            INNER JOIN
                (
                SELECT B_ID, SUM( SO_LUONG* (GIA - KHUYEN_MAI)  )  as [SUM], -- Chưa cộng phí ship
                    SUM(SO_LUONG*KHUYEN_MAI)                   as DISCOUNT
                FROM VIEWALL
                GROUP BY B_ID
                )  AS bSum
                ON h.B_ID = bSum.B_ID
            )
            INNER JOIN 
                HoaDon
            ON h.B_ID = HoaDon.B_ID
        WHERE HoaDon.TONG_TIEN IS NULL AND HoaDon.TRANG_THAI = N'Chờ xác nhận'  --- Hóa đơn mới tạo mới cần cập nhật tổng tiền
    





-----------------------------------------------------------------------------------------------------------------------------------------------------




--    Shipper xác nhận đơn:
    -- CREATE OR ALTER PROCEDURE Shipper_Confirm_Bill @Who SMALLINT, @WhichBill SMALLINT AS
    /* 
      *@param: @Who - Mã id shipper
               @WhichBll - Mã id đơn hàng
    */
        UPDATE HoaDon
            SET S_ID = @Who , TRANG_THAI = N'Đang giao', THOI_GIAN_SHIPPER_XAC_NHAN = GETDATE()
        WHERE B_ID = @WhichBill AND TRANG_THAI = N'Chờ xác nhận'  -- chỉ những hóa đơn đang ở trạng thái "Chờ xác nhận" 
                                                                   --thì shipper mới có quyền nhận đơn



-----------------------------------------------------------------------------------------------------------------------------------------------------





    -- Khách hàng nhận hàng:
    -- CREATE OR ALTER PROCEDURE Customer_Received @WhichBill SMALLINT, @TinhTrang NVARCHAR(50), @danhgia TINYINT AS
    /* 
      *@param:  @WhichBill- Mã id đơn hàng
                @TinhTrang - Cho biết tình trạng, đánh giá tổng quan đơn hàng
                @danhgia - Đánh giá cho shipper
    */
        UPDATE HoaDon
        SET TRANG_THAI = N'Đã giao', THOI_GIAN_NHAN_HANG = GETDATE(), TINH_TRANG_DON_HANG = @TinhTrang, DANH_GIA_DON_HANG = @danhgia
           WHERE B_ID = @WhichBill AND TRANG_THAI = N'Đang giao'

    
    --CREATE OR ALTER PROCEDURE Customer_Cancel @WhichBill SMALLINT AS
            DECLARE @TrangThai NVARCHAR(20) = (
                SELECT TRANG_THAI from HoaDon
            )
        IF @TrangThai = N'Chờ xác nhận'  
            BEGIN
                -- Chuyển hóa đơn về trạng thái hủy
                UPDATE HoaDon
                    SET @TrangThai = N'Đã hủy'
                WHERE B_ID = @WhichBill
                -- Trả lại hàng cho quán
                UPDATE MatHang
                    SET MatHang.CON_LAI = MatHang.CON_LAI + VIEWALL.SO_LUONG
                FROM  VIEWALL 
                WHERE VIEWALL.B_ID = @WhichBill
            END
        ELSE
            SELECT N'Không thể hoàn tất,đơn hàng đang được giao. Hãy liên lạc với nhân viên để được biết thêm chi tiết.' AS THAT_BAI
            ---------------------------------------------------------------------------------------------------------------------------------------------------


    -- 4, Cập nhật điểm tích lũy cho khách hàng, số sao cho Shipper:
    -- CREATE or ALTER PROCEDURE UpdateKhachHangAndShipper AS
        -- Khách hàng mua một đơn hàng thành công sẽ +1 điểm tích lũy
        -- KhachHang
        UPDATE KhachHang
            SET KhachHang.DIEM_TICH_LUY = TinhDiem.DIEMTICHLUY
            from
                (SELECT C_ID, COUNT(C_ID) as DIEMTICHLUY from HoaDon
                WHERE TRANG_THAI = N'Đã giao'
                GROUP BY C_ID) AS TinhDiem
            WHERE TinhDiem.C_ID = KhachHang.C_ID
        
        -- Shippers
        -- Shipper giao hàng và được đánh giá sẽ được tính số đánh giá trung bình:
        UPDATE Shippers
            SET Shippers.DANH_GIA = DanhGia.DANH_GIA
        FROM 
        (SELECT S_ID, AVG( DANH_GIA_DON_HANG ) as DANH_GIA 
        from HoaDon
        GROUP BY S_ID ) as DanhGia
        WHERE Shippers.S_ID = DanhGia.S_ID
        
        -- Cập nhật số sao đánh giá, số điểm tích lũy liên tục
        ---



-----------------------------------------------------------------------------------------------------------------------------------------------------





        ------------------------
    -- 5, Tính doanh thu mỗi(cuối) tháng:
    -- Nộp tiền:

    --CREATE OR ALTER PROCEDURE NopPhi @ID_Phi TINYINT,@Who CHAR ,@month TINYINT,@year SMALLINT AS
    /*
      * @param: @ID_Phi : ID nộp phí trong bảng nộp phí, Shipper = FS_ID; CuaHang = FP_ID
                @Who    : Chỉ định đối tượng nộp phí: 'S' or 's'-> Shipper; 'P' or 'p' -> CuaHang 
                @month  : Chỉ định tháng mà đối tượng nộp phí
                @year   : Chỉ định năm đối tượng đóng: // cần thiết cho năm vì trường hợp sang năm mới thì mới nộp cho tháng 12 năm trước
    */ 
        DECLARE @check NVARCHAR(10) = ( SELECT TRANG_THAI 
                                    from PhiShippers 
                                    WHERE FS_ID = @ID_Phi and THANG = @month
                                          and NAM = @year and TIEN_PHI_THANG IS NOT NULL)
            -- Nếu @check = '' thì có nghĩa là FS_ID không tồn tại trong hệ thống
        DECLARE @check1 NVARCHAR(10) = ( SELECT TRANG_THAI 
                                        from PhiCuaHang 
                                        WHERE FP_ID = @ID_Phi and THANG = @month
                                              and NAM = @year and TIEN_PHI_THANG IS NOT NULL)
            -- Nếu @check1 = '' thì có nghĩa là FP_ID không tồn tại trong hệ thống hoặc tháng không hợp lệ
        -- THƯỜNG xảy ra 3 trường hợp:
        --                    1: Không tồn tại @thang, @ID_Phi trong database
        --                    2: @ID_Phi trong @thang đã nộp tiền phí 
        --                    3: @ID_Phi trong @thang chưa nộp tiền phí 

        IF ( LOWER(@who) = 's' ) and @check != ''                                  
            BEGIN
                IF @check = N'Chưa nộp'
                    BEGIN
                        UPDATE PhiShippers
                            SET TRANG_THAI = N'Đã nộp', THOI_GIAN_NOP = GETDATE()
                        WHERE FS_ID = @ID_Phi and THANG = @month and NAM = @year
                        SELECT N'Đã nộp thành công.' AS SUCCESS
                    END
                ELSE
                    SELECT N'Bạn đã nộp rồi!' AS SHIPPER_DA_NOP
            END
        IF (LOWER(@who) = 'p') and @check1 != ''   
            BEGIN
                IF @check1 = N'Chưa nộp'
                    BEGIN
                        UPDATE PhiCuaHang
                            SET TRANG_THAI = N'Đã nộp',THOI_GIAN_NOP = GETDATE()
                        WHERE FP_ID = @ID_Phi and THANG = @month and NAM = @year 
                        SELECT N'Đã nộp thành công.' AS SUCCESS
                    END
                ELSE
                    SELECT N'Bạn đã nộp rồi!' AS CUA_HANG_DA_NOP
            END
        ELSE
            SELECT N'Có lỗi xảy ra, xin vui lòng thử lại.' AS ERORR

    --CREATE or ALTER PROCEDURE Monthly_Revenue @thang int AS

        SELECT SUM(TONG.TONG) AS TONG_DOANH_THU FROM
            (SELECT SUM(TIEN_PHI_THANG) AS TONG FROM PhiShippers
                WHERE THANG = @thang AND TRANG_THAI = N'Đã nộp' and NAM = YEAR(GETDATE())
            UNION
            SELECT SUM(TIEN_PHI_THANG) AS TONG FROM PhiCuaHang
                WHERE THANG = @thang AND TRANG_THAI = N'Đã nộp' and NAM = YEAR(GETDATE())
            ) AS TONG



-----------------------------------------------------------------------------------------------------------------------------------------------------




-- II, Các lệnh truy xuất
    -- 1, Đưa ra danh sách khách hàng có điểm tích lũy đạt các mốc: 50,100,200,500
    --CREATE OR ALTER  FUNCTION KH_DiemTichLuy(@diem INT)
         RETURNS TABLE AS RETURN(
            SELECT * FROM dbo.KhachHang
            WHERE DIEM_TICH_LUY = @diem  -- Số điểm mốc cần truy cứu
         )




-----------------------------------------------------------------------------------------------------------------------------------------------------




    -- 2, Đưa ra danh sách các khách hàng, shipper, chưa nộp phí dịch vụ trong tháng
    --- Gồm các shipper + Cửa hàng chưa nộp phí trong những tháng < @thang
    --CREATE OR ALTER FUNCTION TON_NO(@thang INT,@year SMALLINT)
    RETURNS TABLE 
    AS  
        RETURN
            SELECT PHI_ID,bang1.ID,TEN,THANG
            from
                (
                Select FS_ID AS PHI_ID,S_ID AS ID,THANG,NAM,TRANG_THAI from PhiShippers
                UNION
                SELECt FP_ID AS PHI_ID, P_ID AS ID,THANG,NAM,TRANG_THAI FROM PhiCuaHang
                )
                AS bang1
                INNER JOIN
                (
                SELECT S_ID AS ID, HO_VA_TEN  AS TEN FROM Shippers
                UNION
                SELECT P_ID,TEN_CUA_HANG from CuaHang
                ) AS bang2
                ON bang1.ID = bang2.ID
            WHERE TRANG_THAI = N'Chưa nộp' AND THANG < @thang and NAM <= @year



-----------------------------------------------------------------------------------------------------------------------------------------------------



    -- 3, Tìm TOP3 mặt hàng được mua nhiều nhất trong tháng:
        -- Khai thác từ bảng VIEWALL
    --CREATE PROCEDURE Best_Selling @thang INT AS
        SELECT TOP 3 H_ID,TEN_MAT_HANG, SUM(SO_LUONG) AS SO_LUONG_MUA
        FROM VIEWALL
        WHERE THANG = @thang AND NAM = YEAR(GETDATE())
        GROUP BY H_ID,TEN_MAT_HANG
        ORDER BY SO_LUONG_MUA DESC
        ----
        ----
        -- Hoặc khai thác từ các bảng có sẵn
        
        -- FROM VIEWALL = FROM (
        --         MatHang
        --         INNER join
        --         MatHang_HD
        --         ON MatHang_HD.H_ID = MatHang.H_ID
        --     ) 

    ------- EXCECUTE


-----------------------------------------------------------------------------------------------------------------------------------------------------




    -- 4, Tìm số lượng hàng còn lại trong kho, và check xem những mặt hàng nào đang trong thời gian khuyến mại
    --CREATE OR ALTER FUNCTION Check_If_Available(@name NVARCHAR(10),@min INT)
       RETURNS TABLE AS
           RETURN
                SELECT * from MatHang
                WHERE   MatHang.CON_LAI >= @min AND MatHang.TEN_MAT_HANG LIKE @name


    --CREATE OR ALTER PROCEDURE Check_Discount AS
                SELECT * from MatHang
                WHERE   KHUYEN_MAI > 0

    -- 5 Tìm khách hàng có ngày sinh là ngày hôm nay:
    --Create or ALTER PROCEDURE Sinh_Nhat AS
        SELECT * from KhachHang
        WHERE DAY(NGAY_SINH) = DAY(Getdate()) and MONTH(NGAY_SINH) = MONTH(GETDATE())
-----------------------------------------------------------------------------------------------------------------------------------------------------

-------------Phần phụ-------
--     -- Tạo một bảng theo dõi tổng thể tiện cho việc tính toán
    --- Bảng VIEWALL được Join từ nhiều bảng với mục đính tính tiền cho hóa đơn :

    --CREATE or ALTER VIEW VIEWALL AS 
                SELECT 
                    h.B_ID,
                    m.H_ID,
                    mh.TEN_MAT_HANG,
                    h.C_ID,
                    m.SO_LUONG,
                    mh.CON_LAI,
                    mh.GIA,
                    mh.KHUYEN_MAI,
                    h.PHI_SHIP_VND,
                    h.TONG_TIEN,
                    h.TRANG_THAI,
                    h.DANH_GIA_DON_HANG,
                    Month(h.THOI_GIAN_NHAN_HANG) AS THANG,
                    YEAR(h.THOI_GIAN_NHAN_HANG) AS NAM
                from ( 
                        HoaDon              AS h 
                        INNER JOIN 
                            MatHang_HD      AS m 
                        on m.B_ID = h.B_ID
                            INNER JOIN
                                MatHang     AS mh 
                            on mh.H_ID = m.H_ID
                )





SELECT * FROM MatHang_HD
SELECT * FROM MatHang
SELECT * FROM VIEWALL



--                                                                                                                          Mai Ngọc Đoàn