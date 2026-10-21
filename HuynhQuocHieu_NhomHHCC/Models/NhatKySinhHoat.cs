using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace HuynhQuocHieu_NhomHHCC.Models
{
    // Bảng lưu trong Database
    public class NhatKySinhHoat
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int TreEmId { get; set; }
        [ForeignKey("TreEmId")]
        public TreEm? TreEm { get; set; }

        public DateTime NgayGhi { get; set; } = DateTime.UtcNow;

        public string BuaAn { get; set; } = "Ăn hết suất"; // Ăn tốt, ăn ít, bỏ bữa

        public string GiacNgu { get; set; } = "Ngủ ngon 2 tiếng"; // Ngủ sâu, quấy khóc

        public double ThanNhiet { get; set; } = 36.5; // Thân nhiệt bé (°C)

        public string GhiChuSucKhoe { get; set; } = "Bình thường"; // Ho, sổ mũi, vui vẻ

        public string? NhanVienGhi { get; set; } // Tên cô giáo / bảo mẫu ghi nhận
    }

    // Khuôn mẫu nhập trên Swagger & App (CHỈ HIỆN 6 DÒNG GỌN GÀNG)
    public class ThemNhatKyModel
    {
        [Required(ErrorMessage = "Vui lòng chọn Id của bé")]
        public int TreEmId { get; set; }

        public string BuaAn { get; set; } = "Ăn hết suất";

        public string GiacNgu { get; set; } = "Ngủ ngon 2 tiếng";

        public double ThanNhiet { get; set; } = 36.5;

        public string GhiChuSucKhoe { get; set; } = "Bình thường";

        public string? NhanVienGhi { get; set; } = "Cô Mai Lan";
    }
}