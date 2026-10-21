using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace HuynhQuocHieu_NhomHHCC.Models
{
    // Bảng lưu trong Database - Quản lý thiết bị & bé
    public class TreEm
    {
        [Key]
        public int Id { get; set; }

        [Required(ErrorMessage = "Họ tên bé không được để trống")]
        [MaxLength(100)]
        public string HoTen { get; set; } = string.Empty; // Tên bé (Bé Tuấn, Bé An...)

        public string TenThietBi { get; set; } = "Samsung Galaxy A15"; // Tên máy của bé

        public string HeDieuHanh { get; set; } = "Android"; // Android / iOS

        public int GioiHanPhut { get; set; } = 120; // Giới hạn dùng máy mỗi ngày (phút)

        public bool DangKhoa { get; set; } = false; // Khóa máy từ xa (true = Đang khóa)

        public string SdtKhanCap { get; set; } = string.Empty; // Số SOS khẩn cấp

        public string MaKetNoi { get; set; } = "DEV-8899"; // Mã ghép nối thiết bị / QR

        public string? HinhAnh { get; set; } // Ảnh đại diện bé / thiết bị

        public string? PhuHuynhId { get; set; }
        [ForeignKey("PhuHuynhId")]
        public User? PhuHuynh { get; set; }

        public DateTime NgayTao { get; set; } = DateTime.UtcNow;
    }

    // Khuôn mẫu nhập trên Swagger & App Mobile
    public class ThemTreEmModel
    {
        [Required(ErrorMessage = "Họ tên bé không được để trống")]
        public string HoTen { get; set; } = string.Empty;

        public string TenThietBi { get; set; } = "Samsung Galaxy A15";

        public string HeDieuHanh { get; set; } = "Android";

        public int GioiHanPhut { get; set; } = 120;

        public bool DangKhoa { get; set; } = false;

        public string SdtKhanCap { get; set; } = string.Empty;

        public string MaKetNoi { get; set; } = "DEV-8899";

        public string? HinhAnh { get; set; }

        public string? PhuHuynhId { get; set; }
    }
}