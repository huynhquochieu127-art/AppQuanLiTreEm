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

        // 1. GET: /api/TreEm - Lấy danh sách toàn bộ trẻ em
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
                    t.NgaySinh,
                    t.GioiTinh,
                    t.NhomMau,
                    t.DiUng,
                    t.SdtKhanCap,
                    t.LopHoc,
                    t.HinhAnh,
                    t.PhuHuynhId,
                    TenPhuHuynh = t.PhuHuynh != null ? t.PhuHuynh.HoTen : "Chưa liên kết",
                    t.NgayTao
                })
                .ToListAsync();

            return Ok(new { status = true, data = danhSach });
        }

        // 2. GET: /api/TreEm/{id} - Lấy chi tiết 1 bé
        [HttpGet("{id}")]
        public async Task<IActionResult> LayTheoId(int id)
        {
            var be = await _context.TreEms
                .Include(t => t.PhuHuynh)
                .FirstOrDefaultAsync(t => t.Id == id);

            if (be == null)
                return NotFound(new { status = false, message = "Không tìm thấy hồ sơ của bé!" });

            return Ok(new
            {
                status = true,
                data = new
                {
                    be.Id,
                    be.HoTen,
                    be.NgaySinh,
                    be.GioiTinh,
                    be.NhomMau,
                    be.DiUng,
                    be.SdtKhanCap,
                    be.LopHoc,
                    be.HinhAnh,
                    be.PhuHuynhId,
                    TenPhuHuynh = be.PhuHuynh != null ? be.PhuHuynh.HoTen : "Chưa liên kết"
                }
            });
        }

        // 3. POST: /api/TreEm - Thêm mới bé (DÙNG MODEL GỌN GÀNG)
        [HttpPost]
        public async Task<IActionResult> ThemTreEm([FromBody] ThemTreEmModel model)
        {
            if (!ModelState.IsValid) return BadRequest(ModelState);

            var treEm = new TreEm
            {
                HoTen = model.HoTen,
                NgaySinh = model.NgaySinh,
                GioiTinh = model.GioiTinh,
                NhomMau = model.NhomMau,
                DiUng = model.DiUng,
                SdtKhanCap = model.SdtKhanCap,
                LopHoc = model.LopHoc,
                HinhAnh = model.HinhAnh,
                PhuHuynhId = model.PhuHuynhId,
                NgayTao = DateTime.UtcNow
            };

            _context.TreEms.Add(treEm);
            await _context.SaveChangesAsync();

            return CreatedAtAction(nameof(LayTheoId), new { id = treEm.Id }, new
            {
                status = true,
                message = "Thêm mới hồ sơ bé thành công!",
                data = treEm
            });
        }

        // 4. PUT: /api/TreEm/{id} - Sửa thông tin bé (CHỈ CẦN GỬI TRƯỜNG MUỐN SỬA)
        [HttpPut("{id}")]
        public async Task<IActionResult> CapNhatTreEm(int id, [FromBody] ThemTreEmModel model)
        {
            var beCu = await _context.TreEms.FindAsync(id);
            if (beCu == null)
                return NotFound(new { status = false, message = "Không tìm thấy hồ sơ bé cần cập nhật!" });

            // Chỉ cập nhật nếu người dùng có nhập và không phải chữ mặc định "string"
            if (!string.IsNullOrWhiteSpace(model.HoTen) && model.HoTen != "string") beCu.HoTen = model.HoTen;
            if (model.NgaySinh != default && model.NgaySinh != DateTime.MinValue) beCu.NgaySinh = model.NgaySinh;
            if (!string.IsNullOrWhiteSpace(model.GioiTinh) && model.GioiTinh != "string") beCu.GioiTinh = model.GioiTinh;
            if (!string.IsNullOrWhiteSpace(model.NhomMau) && model.NhomMau != "string") beCu.NhomMau = model.NhomMau;
            if (!string.IsNullOrWhiteSpace(model.DiUng) && model.DiUng != "string") beCu.DiUng = model.DiUng;
            if (!string.IsNullOrWhiteSpace(model.SdtKhanCap) && model.SdtKhanCap != "string") beCu.SdtKhanCap = model.SdtKhanCap;
            if (!string.IsNullOrWhiteSpace(model.LopHoc) && model.LopHoc != "string") beCu.LopHoc = model.LopHoc;
            if (!string.IsNullOrWhiteSpace(model.HinhAnh) && model.HinhAnh != "string") beCu.HinhAnh = model.HinhAnh;

            // Nếu có truyền ID phụ huynh thật thì mới cập nhật
            if (!string.IsNullOrWhiteSpace(model.PhuHuynhId) && model.PhuHuynhId != "string")
            {
                beCu.PhuHuynhId = model.PhuHuynhId;
            }

            await _context.SaveChangesAsync();

            return Ok(new
            {
                status = true,
                message = "Cập nhật hồ sơ bé thành công!",
                data = beCu
            });
        }

        // 5. DELETE: /api/TreEm/{id} - Xóa hồ sơ bé
        [HttpDelete("{id}")]
        public async Task<IActionResult> XoaTreEm(int id)
        {
            var be = await _context.TreEms.FindAsync(id);
            if (be == null)
                return NotFound(new { status = false, message = "Không tìm thấy hồ sơ bé cần xóa!" });

            _context.TreEms.Remove(be);
            await _context.SaveChangesAsync();

            return Ok(new { status = true, message = "Đã xóa hồ sơ bé thành công!" });
        }
    }
}