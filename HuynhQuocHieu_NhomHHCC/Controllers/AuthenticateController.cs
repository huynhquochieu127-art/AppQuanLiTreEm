using HuynhQuocHieu_NhomHHCC.Models;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Mail;
using System.Security.Claims;
using System.Text;

namespace HuynhQuocHieu_NhomHHCC.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthenticateController : ControllerBase
    {
        private readonly UserManager<User> _userManager;
        private readonly RoleManager<IdentityRole> _roleManager;
        private readonly IConfiguration _configuration;

        public AuthenticateController(
            UserManager<User> userManager,
            RoleManager<IdentityRole> roleManager,
            IConfiguration configuration)
        {
            _userManager = userManager;
            _roleManager = roleManager;
            _configuration = configuration;
        }

        // 1. ĐĂNG KÝ TÀI KHOẢN QUA EMAIL (Yêu cầu 1)
        [HttpPost("register")]
        public async Task<IActionResult> DangKy([FromBody] DangKyModel model)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var userExists = await _userManager.FindByNameAsync(model.TenDangNhap);
            if (userExists != null)
                return BadRequest(new { status = false, message = "Tên đăng nhập đã tồn tại!" });

            var emailExists = await _userManager.FindByEmailAsync(model.Email);
            if (emailExists != null)
                return BadRequest(new { status = false, message = "Email này đã được sử dụng!" });

            var user = new User
            {
                UserName = model.TenDangNhap,
                Email = model.Email,
                HoTen = string.IsNullOrWhiteSpace(model.HoTen) ? model.TenDangNhap : model.HoTen,
                VaiTro = string.IsNullOrWhiteSpace(model.VaiTro) ? "PhuHuynh" : model.VaiTro
            };

            var result = await _userManager.CreateAsync(user, model.MatKhau);
            if (!result.Succeeded)
            {
                var errors = string.Join("; ", result.Errors.Select(e => e.Description));
                return StatusCode(StatusCodes.Status500InternalServerError, new { status = false, message = "Lỗi: " + errors });
            }

            if (!await _roleManager.RoleExistsAsync(user.VaiTro))
            {
                await _roleManager.CreateAsync(new IdentityRole(user.VaiTro));
            }
            await _userManager.AddToRoleAsync(user, user.VaiTro);

            return Ok(new { status = true, message = "Đăng ký tài khoản thành công!", vaiTro = user.VaiTro });
        }

        // 2. BƯỚC 1 ĐĂNG NHẬP: KIỂM TRA MẬT KHẨU -> SINH MÃ OTP & GỬI VỀ GMAIL (Yêu cầu 2)
        [HttpPost("login")]
        public async Task<IActionResult> DangNhap([FromBody] DangNhapModel model)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var user = await _userManager.FindByNameAsync(model.TenDangNhap);
            if (user == null || !await _userManager.CheckPasswordAsync(user, model.MatKhau))
                return Unauthorized(new { status = false, message = "Tên đăng nhập hoặc mật khẩu không chính xác!" });

            // ==================== TÀI KHOẢN ADMIN: ĐƯỢC DUYỆT VÀO THẲNG, BỎ QUA OTP ====================
            if (user.UserName.ToLower() == "admin")
            {
                var authClaims = new List<Claim>
                {
                    new Claim(ClaimTypes.NameIdentifier, user.Id),
                    new Claim(ClaimTypes.Name, user.UserName ?? ""),
                    new Claim(ClaimTypes.Role, "Admin")
                };

                return Ok(new
                {
                    status = true,
                    requiresOtp = false, // Không cần OTP
                    message = "Đăng nhập Admin thành công!",
                    token = GenerateToken(authClaims),
                    vaiTro = "Admin",
                    role = "Admin",
                    username = user.UserName
                });
            }

            // Sinh mã OTP 6 số ngẫu nhiên cho Giáo viên & Phụ huynh
            string otpCode = Random.Shared.Next(100000, 999999).ToString();
            user.MaOtp = otpCode;
            user.HanOtp = DateTime.UtcNow.AddMinutes(5); // Hạn 5 phút
            await _userManager.UpdateAsync(user);

            // GỬI EMAIL THẬT VÀO HÒM THƯ GMAIL CỦA NGƯỜI DÙNG:
            if (!string.IsNullOrEmpty(user.Email))
            {
                await GuiEmailOtpAsync(user.Email, otpCode);
            }

            return Ok(new
            {
                status = true,
                requiresOtp = true,
                message = "Đăng nhập bước 1 thành công! Mã OTP đã được gửi về hộp thư Gmail của bạn.",
                otpDemo = otpCode,
                email = user.Email
            });
        }

        // 3. BƯỚC 2 XÁC THỰC MÃ OTP -> CẤP TOKEN (Yêu cầu 2 & 3)
        [HttpPost("verify-otp")]
        public async Task<IActionResult> XacThucOtp([FromBody] XacThucOtpModel model)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var user = await _userManager.FindByNameAsync(model.TenDangNhap);
            if (user == null)
                return NotFound(new { status = false, message = "Không tìm thấy tài khoản!" });

            if (string.IsNullOrEmpty(user.MaOtp) || user.MaOtp != model.MaOtp)
                return BadRequest(new { status = false, message = "Mã OTP không chính xác!" });

            if (user.HanOtp == null || user.HanOtp < DateTime.UtcNow)
                return BadRequest(new { status = false, message = "Mã OTP đã hết hạn! Vui lòng đăng nhập lại." });

            user.MaOtp = null;
            user.HanOtp = null;
            await _userManager.UpdateAsync(user);

            var userRoles = await _userManager.GetRolesAsync(user);
            var roleName = userRoles.FirstOrDefault() ?? user.VaiTro;

            var authClaims = new List<Claim>
            {
                new Claim(ClaimTypes.NameIdentifier, user.Id),
                new Claim(ClaimTypes.Name, user.UserName ?? ""),
                new Claim(ClaimTypes.Email, user.Email ?? ""),
                new Claim("HoTen", user.HoTen),
                new Claim(ClaimTypes.Role, roleName),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };

            var token = GenerateToken(authClaims);

            return Ok(new
            {
                status = true,
                message = "Xác thực OTP thành công! Đăng nhập hoàn tất.",
                token = token,
                vaiTro = roleName,
                role = roleName, // Trả về cả role để Flutter phân quyền chính xác 100%
                hoTen = user.HoTen,
                userId = user.Id
            });
        }

        // HÀM GỬI EMAIL THẬT QUA GMAIL SMTP
        private async Task GuiEmailOtpAsync(string emailNhan, string otpCode)
        {
            try
            {
                var emailSettings = _configuration.GetSection("EmailSettings");
                var fromEmail = emailSettings["FromEmail"];
                var appPassword = emailSettings["AppPassword"];

                var smtpClient = new SmtpClient("smtp.gmail.com")
                {
                    Port = 587,
                    Credentials = new NetworkCredential(fromEmail, appPassword),
                    EnableSsl = true,
                };

                var mailMessage = new MailMessage
                {
                    From = new MailAddress(fromEmail!, "KidSafe - Quản Lý Trẻ Em"),
                    Subject = "[KidSafe] Mã xác thực OTP đăng nhập",
                    Body = $@"
                        <div style='font-family: Arial, sans-serif; padding: 20px; background-color: #f4f6f8;'>
                            <div style='max-width: 500px; margin: auto; background: white; padding: 25px; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);'>
                                <h2 style='color: #1976D2; text-align: center;'>Hệ Thống KidSafe</h2>
                                <p>Xin chào,</p>
                                <p>Mã xác thực OTP đăng nhập vào ứng dụng của bạn là:</p>
                                <div style='text-align: center; margin: 25px 0;'>
                                    <span style='font-size: 32px; font-weight: bold; letter-spacing: 6px; color: #D32F2F; background: #FFEBEE; padding: 10px 20px; border-radius: 8px;'>{otpCode}</span>
                                </div>
                                <p style='color: #666; font-size: 13px;'>Mã này có hiệu lực trong vòng <b>5 phút</b>. Vui lòng không chia sẻ mã này cho bất kỳ ai.</p>
                            </div>
                        </div>",
                    IsBodyHtml = true,
                };

                mailMessage.To.Add(emailNhan);
                await smtpClient.SendMailAsync(mailMessage);
            }
            catch (Exception ex)
            {
                Console.WriteLine("Lỗi gửi email: " + ex.Message);
            }
        }

        private string GenerateToken(IEnumerable<Claim> claims)
        {
            var jwtSettings = _configuration.GetSection("JWTKey");
            var authSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSettings["Secret"]!));

            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(claims),
                Expires = DateTime.UtcNow.AddHours(Convert.ToDouble(jwtSettings["TokenExpiryTimeInHour"] ?? "24")),
                Issuer = jwtSettings["ValidIssuer"],
                Audience = jwtSettings["ValidAudience"],
                SigningCredentials = new SigningCredentials(authSigningKey, SecurityAlgorithms.HmacSha256)
            };

            var tokenHandler = new JwtSecurityTokenHandler();
            var token = tokenHandler.CreateToken(tokenDescriptor);
            return tokenHandler.WriteToken(token);
        }
        // 4. LẤY DANH SÁCH TẤT CẢ TÀI KHOẢN (Cho Admin xem)
        [HttpGet("users")]
        public IActionResult GetDanhSachUser()
        {
            var users = _userManager.Users.Select(u => new
            {
                u.Id,
                u.UserName,
                u.HoTen,
                u.Email,
                u.VaiTro
            }).ToList();

            return Ok(users);
        }

        // 5. XÓA TÀI KHOẢN (Cho Admin xóa user)
        [HttpDelete("users/{username}")]
        public async Task<IActionResult> XoaUser(string username)
        {
            if (username.ToLower() == "admin")
                return BadRequest(new { status = false, message = "Không được xóa tài khoản Admin tối cao của hệ thống!" });

            var user = await _userManager.FindByNameAsync(username);
            if (user == null)
                return NotFound(new { status = false, message = "Không tìm thấy tài khoản người dùng!" });

            // Xóa liên kết vai trò trước
            var roles = await _userManager.GetRolesAsync(user);
            await _userManager.RemoveFromRolesAsync(user, roles);

            // Xóa người dùng
            var result = await _userManager.DeleteAsync(user);
            if (!result.Succeeded)
                return StatusCode(StatusCodes.Status500InternalServerError, new { status = false, message = "Lỗi khi xóa tài khoản!" });

            return Ok(new { status = true, message = $"Đã xóa tài khoản '{username}' thành công!" });
        }

        // 6. CẬP NHẬT THÔNG TIN TÀI KHOẢN (Cho Admin sửa user - PUT)
        [HttpPut("users/{username}")]
        public async Task<IActionResult> CapNhatUser(string username, [FromBody] CapNhatUserModel model)
        {
            var user = await _userManager.FindByNameAsync(username);
            if (user == null)
                return NotFound(new { status = false, message = "Không tìm thấy tài khoản người dùng!" });

            if (!string.IsNullOrWhiteSpace(model.HoTen) && model.HoTen != "string")
                user.HoTen = model.HoTen;

            if (!string.IsNullOrWhiteSpace(model.Email) && model.Email != "string")
            {
                user.Email = model.Email;
                user.NormalizedEmail = model.Email.ToUpperInvariant();
            }

            if (!string.IsNullOrWhiteSpace(model.VaiTro) && model.VaiTro != "string" && user.UserName?.ToLower() != "admin")
            {
                var oldRoles = await _userManager.GetRolesAsync(user);
                if (oldRoles.Any())
                    await _userManager.RemoveFromRolesAsync(user, oldRoles);

                if (!await _roleManager.RoleExistsAsync(model.VaiTro))
                    await _roleManager.CreateAsync(new IdentityRole(model.VaiTro));

                await _userManager.AddToRoleAsync(user, model.VaiTro);
                user.VaiTro = model.VaiTro;
            }

            var result = await _userManager.UpdateAsync(user);
            if (!result.Succeeded)
                return StatusCode(StatusCodes.Status500InternalServerError, new { status = false, message = "Lỗi khi cập nhật tài khoản!" });

            return Ok(new
            {
                status = true,
                message = $"Đã cập nhật tài khoản '{username}' thành công!",
                data = new { user.Id, user.UserName, user.HoTen, user.Email, user.VaiTro }
            });
        }
    }

    public class CapNhatUserModel
    {
        public string? HoTen { get; set; }
        public string? Email { get; set; }
        public string? VaiTro { get; set; }
    }
}