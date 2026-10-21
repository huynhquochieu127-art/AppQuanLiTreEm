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

        // 1. GET: /api/NhatKy/tre-em/{id} - Lấy lịch sử hoạt động điện thoại CỦA BÉ
        [HttpGet("tre-em/{id}")]
        public async Task<IActionResult> LayTheoTreEm(int id)
        {
            var danhSach = await _context.NhatKySinhHoats
                .Include(n => n.TreEm)
                .Where(n => n.TreEmId == id)
                .OrderByDescending(n => n.NgayGhi)
                .Select(n => new
                {
                    maNhatKy = n.Id,
                    id = n.TreEmId,
                    tenBe = n.TreEm != null ? n.TreEm.HoTen : "Không xác định",
                    tenThietBi = n.TreEm != null ? n.TreEm.TenThietBi : "",
                    ngayGhi = n.NgayGhi,
                    thoiGianDungPhut = n.ThoiGianDungPhut,
                    ungDung = n.UngDung,
                    mucPin = n.MucPin,
                    viTriHienTai = n.ViTriHienTai,
                    canhBao = n.CanhBao,
                    nhanVienGhi = n.NhanVienGhi
                })
                .ToListAsync();

            return Ok(new { status = true, data = danhSach });
        }

        // 2. GET: /api/NhatKy/{maNhatKy} - Xem chi tiết 1 lượt hoạt động
        [HttpGet("{maNhatKy}")]
        public async Task<IActionResult> LayTheoId(int maNhatKy)
        {
            var log = await _context.NhatKySinhHoats
                .Include(n => n.TreEm)
                .Where(n => n.Id == maNhatKy)
                .Select(n => new
                {
                    maNhatKy = n.Id,
                    id = n.TreEmId,
                    tenBe = n.TreEm != null ? n.TreEm.HoTen : "Không xác định",
                    tenThietBi = n.TreEm != null ? n.TreEm.TenThietBi : "",
                    ngayGhi = n.NgayGhi,
                    thoiGianDungPhut = n.ThoiGianDungPhut,
                    ungDung = n.UngDung,
                    mucPin = n.MucPin,
                    viTriHienTai = n.ViTriHienTai,
                    canhBao = n.CanhBao,
                    nhanVienGhi = n.NhanVienGhi
                })
                .FirstOrDefaultAsync();

            if (log == null)
                return NotFound(new { status = false, message = "Không tìm thấy nhật ký hoạt động này!" });

            return Ok(new { status = true, data = log });
        }

        // 3. POST: /api/NhatKy - Thêm nhật ký hoạt động mới
        [HttpPost]
        public async Task<IActionResult> ThemNhatKy([FromBody] ThemNhatKyModel model)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var be = await _context.TreEms.FindAsync(model.TreEmId);
            if (be == null)
                return BadRequest(new { status = false, message = "Không tìm thấy thiết bị/bé với Id này!" });

            var nhatKy = new NhatKySinhHoat
            {
                TreEmId = model.TreEmId,
                NgayGhi = model.NgayGhi ?? DateTime.Now,
                ThoiGianDungPhut = model.ThoiGianDungPhut,
                UngDung = string.IsNullOrWhiteSpace(model.UngDung) ? "YouTube Kids" : model.UngDung,
                MucPin = model.MucPin,
                ViTriHienTai = string.IsNullOrWhiteSpace(model.ViTriHienTai) ? "10.762622, 106.660172" : model.ViTriHienTai,
                CanhBao = string.IsNullOrWhiteSpace(model.CanhBao) ? "Bình thường" : model.CanhBao,
                NhanVienGhi = model.NhanVienGhi
            };

            _context.NhatKySinhHoats.Add(nhatKy);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(LayTheoId), new { maNhatKy = nhatKy.Id }, new
            {
                status = true,
                message = "Đã lưu nhật ký hoạt động điện thoại thành công!",
                data = new
                {
                    maNhatKy = nhatKy.Id,
                    id = nhatKy.TreEmId,
                    tenBe = be.HoTen,
                    tenThietBi = be.TenThietBi,
                    nhatKy.NgayGhi,
                    nhatKy.ThoiGianDungPhut,
                    nhatKy.UngDung,
                    nhatKy.MucPin,
                    nhatKy.ViTriHienTai,
                    nhatKy.CanhBao,
                    nhatKy.NhanVienGhi
                }
            });
        }

        // 4. PUT: /api/NhatKy/{maNhatKy} - Sửa nhật ký hoạt động
        [HttpPut("{maNhatKy}")]
        public async Task<IActionResult> CapNhatNhatKy(int maNhatKy, [FromBody] ThemNhatKyModel model)
        {
            var nhatKyCu = await _context.NhatKySinhHoats
                .Include(n => n.TreEm)
                .FirstOrDefaultAsync(n => n.Id == maNhatKy);

            if (nhatKyCu == null)
                return NotFound(new { status = false, message = "Không tìm thấy nhật ký cần cập nhật!" });

            if (model.TreEmId > 0) nhatKyCu.TreEmId = model.TreEmId;
            if (model.ThoiGianDungPhut > 0) nhatKyCu.ThoiGianDungPhut = model.ThoiGianDungPhut;
            if (!string.IsNullOrWhiteSpace(model.UngDung) && model.UngDung != "string") nhatKyCu.UngDung = model.UngDung;
            if (model.MucPin >= 0) nhatKyCu.MucPin = model.MucPin;
            if (!string.IsNullOrWhiteSpace(model.ViTriHienTai) && model.ViTriHienTai != "string") nhatKyCu.ViTriHienTai = model.ViTriHienTai;
            if (!string.IsNullOrWhiteSpace(model.CanhBao) && model.CanhBao != "string") nhatKyCu.CanhBao = model.CanhBao;
            if (!string.IsNullOrWhiteSpace(model.NhanVienGhi) && model.NhanVienGhi != "string") nhatKyCu.NhanVienGhi = model.NhanVienGhi;

            await _context.SaveChangesAsync();

            return Ok(new
            {
                status = true,
                message = "Cập nhật nhật ký hoạt động thành công!",
                data = new
                {
                    maNhatKy = nhatKyCu.Id,
                    id = nhatKyCu.TreEmId,
                    tenBe = nhatKyCu.TreEm != null ? nhatKyCu.TreEm.HoTen : "Không xác định",
                    tenThietBi = nhatKyCu.TreEm != null ? nhatKyCu.TreEm.TenThietBi : "",
                    nhatKyCu.NgayGhi,
                    nhatKyCu.ThoiGianDungPhut,
                    nhatKyCu.UngDung,
                    nhatKyCu.MucPin,
                    nhatKyCu.ViTriHienTai,
                    nhatKyCu.CanhBao,
                    nhatKyCu.NhanVienGhi
                }
            });
        }

        // 5. DELETE: /api/NhatKy/{maNhatKy} - Xóa nhật ký hoạt động
        [HttpDelete("{maNhatKy}")]
        public async Task<IActionResult> XoaNhatKy(int maNhatKy)
        {
            var nhatKy = await _context.NhatKySinhHoats.FindAsync(maNhatKy);
            if (nhatKy == null)
                return NotFound(new { status = false, message = "Không tìm thấy nhật ký cần xóa!" });

            _context.NhatKySinhHoats.Remove(nhatKy);
            await _context.SaveChangesAsync();

            return Ok(new { status = true, message = "Đã xóa nhật ký hoạt động thành công!" });
        }
    }
}