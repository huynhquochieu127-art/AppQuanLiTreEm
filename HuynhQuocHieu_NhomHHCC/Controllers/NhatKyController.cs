using HuynhQuocHieu_NhomHHCC.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace HuynhQuocHieu_NhomHHCC.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class NhatKyController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public NhatKyController(ApplicationDbContext context)
        {
            _context = context;
        }

        // 1. GET: /api/NhatKy/tre-em/{id} - Lấy tất cả nhật ký CỦA BÉ (tham số 'id' là mã bé)
        [HttpGet("tre-em/{id}")]
        public async Task<IActionResult> LayTheoTreEm(int id)
        {
            var danhSach = await _context.NhatKySinhHoats
                .Include(n => n.TreEm)
                .Where(n => n.TreEmId == id)
                .OrderByDescending(n => n.NgayGhi)
                .Select(n => new
                {
                    maNhatKy = n.Id,                                               // Mã tờ nhật ký
                    id = n.TreEmId,                                                // Mã bé (khớp chữ id bên Trẻ Em)
                    tenBe = n.TreEm != null ? n.TreEm.HoTen : "Không xác định",     // Tên bé
                    n.NgayGhi,
                    n.BuaAn,
                    n.GiacNgu,
                    n.ThanNhiet,
                    n.GhiChuSucKhoe,
                    n.NhanVienGhi
                })
                .ToListAsync();

            return Ok(new { status = true, data = danhSach });
        }

        // 2. GET: /api/NhatKy/{maNhatKy} - Xem chi tiết ĐÚNG 1 TỜ NHẬT KÝ (tham số là 'maNhatKy')
        [HttpGet("{maNhatKy}")]
        public async Task<IActionResult> LayTheoId(int maNhatKy)
        {
            var log = await _context.NhatKySinhHoats
                .Include(n => n.TreEm)
                .Where(n => n.Id == maNhatKy)
                .Select(n => new
                {
                    maNhatKy = n.Id,                                               // Mã tờ nhật ký
                    id = n.TreEmId,                                                // Mã bé
                    tenBe = n.TreEm != null ? n.TreEm.HoTen : "Không xác định",     // Tên bé
                    n.NgayGhi,
                    n.BuaAn,
                    n.GiacNgu,
                    n.ThanNhiet,
                    n.GhiChuSucKhoe,
                    n.NhanVienGhi
                })
                .FirstOrDefaultAsync();

            if (log == null)
                return NotFound(new { status = false, message = "Không tìm thấy tờ nhật ký này!" });

            return Ok(new { status = true, data = log });
        }

        // 3. POST: /api/NhatKy - Thêm nhật ký mới
        [HttpPost]
        public async Task<IActionResult> ThemNhatKy([FromBody] ThemNhatKyModel model)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var be = await _context.TreEms.FindAsync(model.TreEmId);
            if (be == null)
                return BadRequest(new { status = false, message = "Không tìm thấy bé với Id này!" });

            var nhatKy = new NhatKySinhHoat
            {
                TreEmId = model.TreEmId,
                NgayGhi = DateTime.UtcNow,
                BuaAn = model.BuaAn,
                GiacNgu = model.GiacNgu,
                ThanNhiet = model.ThanNhiet,
                GhiChuSucKhoe = model.GhiChuSucKhoe,
                NhanVienGhi = model.NhanVienGhi
            };

            _context.NhatKySinhHoats.Add(nhatKy);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(LayTheoId), new { maNhatKy = nhatKy.Id }, new
            {
                status = true,
                message = "Đã lưu nhật ký sinh hoạt của bé thành công!",
                data = new
                {
                    maNhatKy = nhatKy.Id,
                    id = nhatKy.TreEmId,
                    tenBe = be.HoTen,
                    nhatKy.NgayGhi,
                    nhatKy.BuaAn,
                    nhatKy.GiacNgu,
                    nhatKy.ThanNhiet,
                    nhatKy.GhiChuSucKhoe,
                    nhatKy.NhanVienGhi
                }
            });
        }

        // 4. PUT: /api/NhatKy/{maNhatKy} - Sửa nhật ký theo 'maNhatKy'
        [HttpPut("{maNhatKy}")]
        public async Task<IActionResult> CapNhatNhatKy(int maNhatKy, [FromBody] ThemNhatKyModel model)
        {
            var nhatKyCu = await _context.NhatKySinhHoats
                .Include(n => n.TreEm)
                .FirstOrDefaultAsync(n => n.Id == maNhatKy);

            if (nhatKyCu == null)
                return NotFound(new { status = false, message = "Không tìm thấy tờ nhật ký cần cập nhật!" });

            // Chỉ cập nhật những ô có thay đổi
            if (model.TreEmId > 0) nhatKyCu.TreEmId = model.TreEmId;
            if (!string.IsNullOrWhiteSpace(model.BuaAn) && model.BuaAn != "string") nhatKyCu.BuaAn = model.BuaAn;
            if (!string.IsNullOrWhiteSpace(model.GiacNgu) && model.GiacNgu != "string") nhatKyCu.GiacNgu = model.GiacNgu;
            if (model.ThanNhiet > 0) nhatKyCu.ThanNhiet = model.ThanNhiet;
            if (!string.IsNullOrWhiteSpace(model.GhiChuSucKhoe) && model.GhiChuSucKhoe != "string") nhatKyCu.GhiChuSucKhoe = model.GhiChuSucKhoe;
            if (!string.IsNullOrWhiteSpace(model.NhanVienGhi) && model.NhanVienGhi != "string") nhatKyCu.NhanVienGhi = model.NhanVienGhi;

            await _context.SaveChangesAsync();

            return Ok(new
            {
                status = true,
                message = "Cập nhật nhật ký thành công!",
                data = new
                {
                    maNhatKy = nhatKyCu.Id,
                    id = nhatKyCu.TreEmId,
                    tenBe = nhatKyCu.TreEm != null ? nhatKyCu.TreEm.HoTen : "Không xác định",
                    nhatKyCu.NgayGhi,
                    nhatKyCu.BuaAn,
                    nhatKyCu.GiacNgu,
                    nhatKyCu.ThanNhiet,
                    nhatKyCu.GhiChuSucKhoe,
                    nhatKyCu.NhanVienGhi
                }
            });
        }

        // 5. DELETE: /api/NhatKy/{maNhatKy} - Xóa tờ nhật ký theo 'maNhatKy'
        [HttpDelete("{maNhatKy}")]
        public async Task<IActionResult> XoaNhatKy(int maNhatKy)
        {
            var nhatKy = await _context.NhatKySinhHoats.FindAsync(maNhatKy);
            if (nhatKy == null)
                return NotFound(new { status = false, message = "Không tìm thấy tờ nhật ký cần xóa!" });

            _context.NhatKySinhHoats.Remove(nhatKy);
            await _context.SaveChangesAsync();

            return Ok(new { status = true, message = "Đã xóa tờ nhật ký thành công!" });
        }
    }
}