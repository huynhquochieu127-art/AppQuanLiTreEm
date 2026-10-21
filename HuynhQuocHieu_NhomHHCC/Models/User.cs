using Microsoft.AspNetCore.Identity;

namespace HuynhQuocHieu_NhomHHCC.Models
{
    public class User : IdentityUser
    {
        public string HoTen { get; set; } = string.Empty;
        public string VaiTro { get; set; } = "PhuHuynh"; // Admin, NhanVien, PhuHuynh
        public string? MaOtp { get; set; } // Mã OTP 6 số
        public DateTime? HanOtp { get; set; } // Hạn dùng OTP
    }
}