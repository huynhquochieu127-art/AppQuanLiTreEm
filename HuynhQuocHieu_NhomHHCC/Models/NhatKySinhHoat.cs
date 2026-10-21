using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace HuynhQuocHieu_NhomHHCC.Models
{
    // Bảng lưu trong Database - Nhật ký hoạt động điện thoại của bé
    public class NhatKySinhHoat
    {
        [Key]
        public int Id { get; set; }

        [Required]
        public int TreEmId { get; set; }
        [ForeignKey("TreEmId")]
        public TreEm? TreEm { get; set; }

        public DateTime NgayGhi { get; set; } = DateTime.UtcNow;

        public int ThoiGianDungPhut { get; set; } = 45; // Thời gian sử dụng trong phiên (phút)

        public string UngDung { get; set; } = "YouTube Kids"; // Ứng dụng mở nhiều (YouTube Kids, Roblox, TikTok, ...)

        public int MucPin { get; set; } = 85; // Phần trăm pin (%)

        public string ViTriHienTai { get; set; } = "10.762622, 106.660172"; // Tọa độ GPS / Địa chỉ hiện tại

        public string CanhBao { get; set; } = "Bình thường"; // Bình thường, Quá giờ quy định, Pin yếu (<15%), Vượt vùng an toàn

        public string? NhanVienGhi { get; set; } = "Hệ thống giám sát"; // Người phụ trách / Phụ huynh
    }

    // Khuôn mẫu nhập trên Swagger & App Mobile
    public class ThemNhatKyModel
    {
        [Required(ErrorMessage = "Vui lòng chọn Id của bé/thiết bị")]
        public int TreEmId { get; set; }

        public DateTime? NgayGhi { get; set; }

        public int ThoiGianDungPhut { get; set; } = 45;

        public string UngDung { get; set; } = "YouTube Kids";

        public int MucPin { get; set; } = 85;

        public string ViTriHienTai { get; set; } = "10.762622, 106.660172";

        public string CanhBao { get; set; } = "Bình thường";

        public string? NhanVienGhi { get; set; } = "Hệ thống giám sát";
    }
}