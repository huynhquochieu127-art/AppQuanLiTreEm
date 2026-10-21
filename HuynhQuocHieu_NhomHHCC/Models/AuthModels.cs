using System.ComponentModel.DataAnnotations;

namespace HuynhQuocHieu_NhomHHCC.Models
{
    // Form dữ liệu khi Đăng ký tài khoản mới
    public class DangKyModel
    {
        [Required(ErrorMessage = "Tên đăng nhập không được để trống")]
        public string TenDangNhap { get; set; } = string.Empty;

        [Required(ErrorMessage = "Email không được để trống")]
        [EmailAddress(ErrorMessage = "Email không đúng định dạng")]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Mật khẩu không được để trống")]
        public string MatKhau { get; set; } = string.Empty;

        public string HoTen { get; set; } = string.Empty;

        public string VaiTro { get; set; } = "PhuHuynh"; // Admin, NhanVien, PhuHuynh
    }

    // Form dữ liệu khi Đăng nhập bước 1
    public class DangNhapModel
    {
        [Required(ErrorMessage = "Tên đăng nhập không được để trống")]
        public string TenDangNhap { get; set; } = string.Empty;

        [Required(ErrorMessage = "Mật khẩu không được để trống")]
        public string MatKhau { get; set; } = string.Empty;
    }

    // Form dữ liệu khi Nhập mã OTP bước 2
    public class XacThucOtpModel
    {
        [Required(ErrorMessage = "Tên đăng nhập không được để trống")]
        public string TenDangNhap { get; set; } = string.Empty;

        [Required(ErrorMessage = "Mã OTP không được để trống")]
        public string MaOtp { get; set; } = string.Empty;
    }
}