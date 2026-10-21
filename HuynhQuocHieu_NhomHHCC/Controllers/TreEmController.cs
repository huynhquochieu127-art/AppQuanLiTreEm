using HuynhQuocHieu_NhomHHCC.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HuynhQuocHieu_NhomHHCC.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class TreEmController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public TreEmController(ApplicationDbContext context)
        {
            _context = context;
        }

        // 1. GET: /api/TreEm - Lấy danh sách toàn bộ thiết bị trẻ em
        [HttpGet]
        public async Task<IActionResult> LayTatCa()
        {
            var danhSach = await _context.TreEms
                .Include(t => t.PhuHuynh)
                .OrderByDescending(t => t.NgayTao)
                .Select(t => new
                {
                    t.Id,
                    t.HoTen,
                    t.TenThietBi,
                    t.HeDieuHanh,
                    t.GioiHanPhut,
                    t.DangKhoa,
                    t.SdtKhanCap,
                    t.MaKetNoi,
                    t.HinhAnh,
                    t.PhuHuynhId,
                    TenPhuHuynh = t.PhuHuynh != null ? t.PhuHuynh.HoTen : "Chưa liên kết",
                    t.NgayTao
                })
                .ToListAsync();

            return Ok(new { status = true, data = danhSach });
        }

        // 2. GET: /api/TreEm/{id} - Lấy chi tiết 1 thiết bị của bé
        [HttpGet("{id}")]
        public async Task<IActionResult> LayTheoId(int id)
        {
            var be = await _context.TreEms
                .Include(t => t.PhuHuynh)
                .FirstOrDefaultAsync(t => t.Id == id);

            if (be == null)
                return NotFound(new { status = false, message = "Không tìm thấy hồ sơ thiết bị của bé!" });

            return Ok(new
            {
                status = true,
                data = new
                {
                    be.Id,
                    be.HoTen,
                    be.TenThietBi,
                    be.HeDieuHanh,
                    be.GioiHanPhut,
                    be.DangKhoa,
                    be.SdtKhanCap,
                    be.MaKetNoi,
                    be.HinhAnh,
                    be.PhuHuynhId,
                    TenPhuHuynh = be.PhuHuynh != null ? be.PhuHuynh.HoTen : "Chưa liên kết",
                    be.NgayTao
                }
            });
        }

        // 3. POST: /api/TreEm - Thêm mới thiết bị bé
        [HttpPost]
        public async Task<IActionResult> ThemTreEm([FromBody] ThemTreEmModel model)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            string? phuHuynhId = model.PhuHuynhId;
            if (string.IsNullOrWhiteSpace(phuHuynhId))
            {
                var ph = await _context.Users.FirstOrDefaultAsync(u => u.VaiTro == "PhuHuynh");
                if (ph != null) phuHuynhId = ph.Id;
            }

            var treEm = new TreEm
            {
                HoTen = model.HoTen,
                TenThietBi = string.IsNullOrWhiteSpace(model.TenThietBi) ? "Samsung Galaxy A15" : model.TenThietBi,
                HeDieuHanh = string.IsNullOrWhiteSpace(model.HeDieuHanh) ? "Android" : model.HeDieuHanh,
                GioiHanPhut = model.GioiHanPhut > 0 ? model.GioiHanPhut : 120,
                DangKhoa = model.DangKhoa,
                SdtKhanCap = model.SdtKhanCap ?? string.Empty,
                MaKetNoi = string.IsNullOrWhiteSpace(model.MaKetNoi) ? $"DEV-{new Random().Next(1000, 9999)}" : model.MaKetNoi,
                HinhAnh = model.HinhAnh,
                PhuHuynhId = phuHuynhId,
                NgayTao = DateTime.UtcNow
            };

            _context.TreEms.Add(treEm);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(LayTheoId), new { id = treEm.Id }, new
            {
                status = true,
                message = "Thêm thiết bị của bé thành công!",
                data = treEm
            });
        }

        // 4. PUT: /api/TreEm/{id} - Sửa thông tin thiết bị
        [HttpPut("{id}")]
        public async Task<IActionResult> CapNhatTreEm(int id, [FromBody] ThemTreEmModel model)
        {
            var beCu = await _context.TreEms.FindAsync(id);
            if (beCu == null)
                return NotFound(new { status = false, message = "Không tìm thấy thiết bị của bé cần cập nhật!" });

            if (!string.IsNullOrWhiteSpace(model.HoTen) && model.HoTen != "string") beCu.HoTen = model.HoTen;
            if (!string.IsNullOrWhiteSpace(model.TenThietBi) && model.TenThietBi != "string") beCu.TenThietBi = model.TenThietBi;
            if (!string.IsNullOrWhiteSpace(model.HeDieuHanh) && model.HeDieuHanh != "string") beCu.HeDieuHanh = model.HeDieuHanh;
            if (model.GioiHanPhut > 0) beCu.GioiHanPhut = model.GioiHanPhut;
            beCu.DangKhoa = model.DangKhoa;
            if (!string.IsNullOrWhiteSpace(model.SdtKhanCap) && model.SdtKhanCap != "string") beCu.SdtKhanCap = model.SdtKhanCap;
            if (!string.IsNullOrWhiteSpace(model.MaKetNoi) && model.MaKetNoi != "string") beCu.MaKetNoi = model.MaKetNoi;
            if (!string.IsNullOrWhiteSpace(model.HinhAnh) && model.HinhAnh != "string") beCu.HinhAnh = model.HinhAnh;

            if (!string.IsNullOrWhiteSpace(model.PhuHuynhId) && model.PhuHuynhId != "string")
            {
                beCu.PhuHuynhId = model.PhuHuynhId;
            }

            await _context.SaveChangesAsync();

            return Ok(new
            {
                status = true,
                message = "Cập nhật thiết bị của bé thành công!",
                data = beCu
            });
        }

        // 5. PUT: /api/TreEm/{id}/khoa-thiet-bi - Khóa / Mở khóa thiết bị từ xa (Chức năng sáng tạo)
        [HttpPut("{id}/khoa-thiet-bi")]
        public async Task<IActionResult> KhoaMoThietBi(int id, [FromQuery] bool? trangThai)
        {
            var be = await _context.TreEms.FindAsync(id);
            if (be == null)
                return NotFound(new { status = false, message = "Không tìm thấy thiết bị của bé!" });

            if (trangThai.HasValue)
                be.DangKhoa = trangThai.Value;
            else
                be.DangKhoa = !be.DangKhoa;

            await _context.SaveChangesAsync();

            string thongBao = be.DangKhoa ? "Đã khóa máy của bé từ xa thành công!" : "Đã mở khóa máy của bé thành công!";
            return Ok(new
            {
                status = true,
                message = thongBao,
                dangKhoa = be.DangKhoa
            });
        }

        // 6. DELETE: /api/TreEm/{id} - Xóa thiết bị của bé
        [HttpDelete("{id}")]
        public async Task<IActionResult> XoaTreEm(int id)
        {
            var be = await _context.TreEms.FindAsync(id);
            if (be == null)
                return NotFound(new { status = false, message = "Không tìm thấy thiết bị cần xóa!" });

            _context.TreEms.Remove(be);
            await _context.SaveChangesAsync();

            return Ok(new { status = true, message = "Đã xóa thiết bị thành công!" });
        }
    }
}