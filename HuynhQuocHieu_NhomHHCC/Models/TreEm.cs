using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace HuynhQuocHieu_NhomHHCC.Models
{
    // Bảng lưu trong Database
    public class TreEm
    {
        [Key]
        public int Id { get; set; }

        [Required(ErrorMessage = "Họ tên bé không được để trống")]
        [MaxLength(100)]
        public string HoTen { get; set; } = string.Empty;

        public DateTime NgaySinh { get; set; }

        public string GioiTinh { get; set; } = "Nam"; // Nam / Nữ

        public string NhomMau { get; set; } = "O"; // A, B, AB, O

        public string DiUng { get; set; } = "Không có"; // Dị ứng hải sản, thuốc,...

        public string SdtKhanCap { get; set; } = string.Empty; // SĐT bố mẹ khi khẩn cấp

        public string LopHoc { get; set; } = "Lớp Mầm 1"; // Lớp của bé

        public string? HinhAnh { get; set; } // Ảnh avatar của bé

        public string? PhuHuynhId { get; set; }
        [ForeignKey("PhuHuynhId")]
        public User? PhuHuynh { get; set; }

        public DateTime NgayTao { get; set; } = DateTime.UtcNow;
    }

    // Khuôn mẫu nhập trên Swagger & App (CHỈ HIỆN ĐÚNG CÁC TRƯỜNG CẦN NHẬP)
    public class ThemTreEmModel
    {
        [Required(ErrorMessage = "Họ tên không được để trống")]
        public string HoTen { get; set; } = string.Empty;

        public DateTime NgaySinh { get; set; } = DateTime.UtcNow;

        public string GioiTinh { get; set; } = "Nam";

        public string NhomMau { get; set; } = "O";

        public string DiUng { get; set; } = "Không có";

        public string SdtKhanCap { get; set; } = string.Empty;

        public string LopHoc { get; set; } = "Lớp Mầm 1";

        public string? HinhAnh { get; set; }

        public string? PhuHuynhId { get; set; }
    }
}