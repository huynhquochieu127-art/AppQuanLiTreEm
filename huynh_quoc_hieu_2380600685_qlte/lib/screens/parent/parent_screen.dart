import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'child_detail_screen.dart';

class ParentScreen extends StatefulWidget {
  const ParentScreen({super.key});

  @override
  State<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends State<ParentScreen> {
  List<dynamic> _danhSachThietBi = [];
  List<Map<String, dynamic>> _thongBaoGiaoVien = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDanhSachThietBi();
  }

  // Tải danh sách thiết bị bé & thông báo từ giáo viên
  Future<void> _loadDanhSachThietBi() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getDanhSachTreEm();

    // Tải tất cả thông báo nhắc nhở do Giáo viên gửi về
    final List<Map<String, dynamic>> dsThongBao = [];
    for (final be in data) {
      final int id = be['id'] ?? 0;
      final String tenBe = be['hoTen'] ?? 'Bé';
      final String tenThietBi = be['tenThietBi'] ?? '';
      final bool dangKhoa = be['dangKhoa'] == true;
      final logs = await ApiService.getNhatKyTheoTreEm(id);
      for (final log in logs) {
        final String nv = (log['nhanVienGhi'] ?? '').toString();
        final String ud = (log['ungDung'] ?? '').toString();
        if (nv.startsWith('GV:') || nv.contains('Giáo viên') || ud.startsWith('[GV]')) {
          dsThongBao.add({
            ...Map<String, dynamic>.from(log),
            'tenBe': tenBe,
            'tenThietBi': tenThietBi,
            'treEmId': id,
            'dangKhoa': dangKhoa,
          });
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _danhSachThietBi = data;
      _thongBaoGiaoVien = dsThongBao;
      _isLoading = false;
    });
  }

  // Khóa / Mở khóa máy từ xa (Tính năng sáng tạo 1.0đ)
  Future<void> _toggleKhoaMay(int id, bool hienTai, String tenBe) async {
    final bool trangThaiMoi = !hienTai;
    final success = await ApiService.khoaMoThietBi(id, trangThai: trangThaiMoi);
    if (success) {
      _loadDanhSachThietBi();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trangThaiMoi
                ? ' Đã khóa điện thoại của $tenBe từ xa!'
                : ' Đã mở khóa điện thoại của $tenBe!',
          ),
          backgroundColor: trangThaiMoi ? Colors.redAccent : Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lỗi khi gửi lệnh khóa thiết bị!'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Dialog hiển thị mã QR ghép nối thiết bị (Tính năng trình diễn 3.5đ)
  void _showQrPairingDialog(String tenBe, String maKetNoi, String thietBi) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.qr_code_2_rounded, color: Colors.blueAccent, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Mã Ghép Nối - $tenBe',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Quét mã này từ điện thoại của bé ($thietBi) để kích hoạt giám sát an toàn.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.shade100, width: 2),
                ),
                child: QrImageView(
                  data: maKetNoi.isNotEmpty ? maKetNoi : 'PAIR-DEFAULT',
                  version: QrVersions.auto,
                  size: 160.0,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'MÃ KẾT NỐI: $maKetNoi',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.blueAccent,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  // Dialog Thêm thiết bị bé mới (CREATE)
  void _showAddDeviceDialog() {
    final tenController = TextEditingController();
    final thietBiController = TextEditingController(text: 'Samsung Galaxy A15');
    final phutController = TextEditingController(text: '120');
    final sdtController = TextEditingController(text: '0901234567');
    String heDieuHanh = 'Android';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.phone_android_rounded, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text('Thêm Thiết Bị Của Bé', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tenController,
                  decoration: const InputDecoration(
                    labelText: 'Tên của bé *',
                    hintText: 'VD: Bé Quốc Bảo',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: thietBiController,
                  decoration: const InputDecoration(
                    labelText: 'Dòng máy điện thoại *',
                    hintText: 'VD: Samsung A15, iPhone 11...',
                    prefixIcon: Icon(Icons.smartphone),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: heDieuHanh,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Hệ điều hành',
                    prefixIcon: Icon(Icons.devices_other),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Android', child: Text('🤖 Android (Samsung, Xiaomi...)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'iOS', child: Text('🍎 iOS (iPhone, iPad)', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => heDieuHanh = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phutController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giới hạn dùng/ngày (phút) *',
                    hintText: '120 (tương đương 2 tiếng)',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sdtController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'SĐT khẩn cấp (SOS bố mẹ)',
                    hintText: '0901234567',
                    prefixIcon: Icon(Icons.emergency_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (tenController.text.trim().isEmpty) return;
                final phut = int.tryParse(phutController.text.trim()) ?? 120;

                final success = await ApiService.themTreEm({
                  'hoTen': tenController.text.trim(),
                  'tenThietBi': thietBiController.text.trim().isEmpty ? 'Samsung Galaxy' : thietBiController.text.trim(),
                  'heDieuHanh': heDieuHanh,
                  'gioiHanPhut': phut,
                  'dangKhoa': false,
                  'sdtKhanCap': sdtController.text.trim(),
                  'maKetNoi': 'PAIR-${DateTime.now().millisecondsSinceEpoch % 10000}',
                  'phuHuynhId': 'c43c2bee-fdeb-4c14-9033-14d8ebb3b634',
                });

                if (!mounted) return;
                if (ctx.mounted) Navigator.pop(ctx);
                if (success) {
                  _loadDanhSachThietBi();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(' Thêm thiết bị bé thành công!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Thêm Thiết Bị'),
            ),
          ],
        ),
      ),
    );
  }

  // Sửa thông tin thiết bị bé (CRUD UPDATE - PUT /api/TreEm/{id})
  void _showEditDeviceDialog(Map<String, dynamic> be) {
    final int id = be['id'] ?? 0;
    final tenController = TextEditingController(text: be['hoTen']?.toString() ?? '');
    final thietBiController = TextEditingController(text: be['tenThietBi']?.toString() ?? '');
    final phutController = TextEditingController(text: (be['gioiHanPhut'] ?? 120).toString());
    final sdtController = TextEditingController(text: be['sdtKhanCap']?.toString() ?? '');
    String heDieuHanh = (be['heDieuHanh']?.toString() == 'iOS') ? 'iOS' : 'Android';
    bool choPhepGvKetNoi = ApiService.daKetNoiGiaoVien(be);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: Color(0xFF1E3A8A)),
              SizedBox(width: 8),
              Text('Sửa Thông Tin Thiết Bị', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tenController,
                  decoration: const InputDecoration(
                    labelText: 'Tên của bé *',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: thietBiController,
                  decoration: const InputDecoration(
                    labelText: 'Dòng máy điện thoại *',
                    prefixIcon: Icon(Icons.smartphone),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: heDieuHanh,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Hệ điều hành',
                    prefixIcon: Icon(Icons.devices_other),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Android', child: Text('🤖 Android (Samsung, Xiaomi...)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'iOS', child: Text('🍎 iOS (iPhone, iPad)', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => heDieuHanh = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phutController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Giới hạn dùng/ngày (phút) *',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: sdtController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'SĐT khẩn cấp (SOS bố mẹ)',
                    prefixIcon: Icon(Icons.emergency_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: SwitchListTile(
                    dense: true,
                    activeColor: Colors.teal.shade700,
                    title: const Text(
                      '🎓 Kết nối Giáo viên giám sát tại trường',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    subtitle: Text(
                      'Mã cấp cho Giáo viên: ${be['maKetNoi'] ?? 'PAIR'}',
                      style: TextStyle(fontSize: 11, color: Colors.teal.shade900),
                    ),
                    value: choPhepGvKetNoi,
                    onChanged: (val) {
                      setDialogState(() => choPhepGvKetNoi = val);
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (tenController.text.trim().isEmpty) return;
                final phut = int.tryParse(phutController.text.trim()) ?? 120;
                final String currentHinhAnh = (be['hinhAnh'] ?? '').toString();
                final String newHinhAnh = choPhepGvKetNoi
                    ? (currentHinhAnh.startsWith('GV:') ? currentHinhAnh : 'GV:hieuhq1|Huỳnh Quốc Huy')
                    : 'CHUA_KET_NOI';

                final success = await ApiService.capNhatTreEm(id, {
                  'hoTen': tenController.text.trim(),
                  'tenThietBi': thietBiController.text.trim().isEmpty ? 'Samsung Galaxy' : thietBiController.text.trim(),
                  'heDieuHanh': heDieuHanh,
                  'gioiHanPhut': phut,
                  'dangKhoa': be['dangKhoa'] == true,
                  'sdtKhanCap': sdtController.text.trim(),
                  'maKetNoi': be['maKetNoi'] ?? 'PAIR-0000',
                  'hinhAnh': newHinhAnh,
                  'phuHuynhId': be['phuHuynhId'] ?? 'c43c2bee-fdeb-4c14-9033-14d8ebb3b634',
                });

                if (!mounted) return;
                if (ctx.mounted) Navigator.pop(ctx);
                if (success) {
                  _loadDanhSachThietBi();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(' Đã cập nhật thông tin thiết bị!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Lưu Thay Đổi'),
            ),
          ],
        ),
      ),
    );
  }

  // Xóa thiết bị bé (DELETE)
  void _confirmDelete(int id, String ten) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn gỡ thiết bị của bé "$ten"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ApiService.xoaTreEm(id);
              if (success) {
                _loadDanhSachThietBi();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã gỡ thiết bị của bé!'), backgroundColor: Colors.orange),
                );
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Hộp thư Chuông Thông Báo nhận tin nhắn nhắc nhở từ Giáo viên
  void _showThongBaoGiaoVienDialog() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Thông Báo Giáo Viên (${_thongBaoGiaoVien.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 340,
            child: _thongBaoGiaoVien.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        Text(
                          'Chưa có tin nhắn nhắc nhở nào từ Giáo viên.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _thongBaoGiaoVien.length,
                      itemBuilder: (context, index) {
                        final tb = _thongBaoGiaoVien[index];
                        final int maNhatKy = tb['maNhatKy'] ?? tb['id'] ?? 0;
                        final int treEmId = tb['treEmId'] ?? 0;
                        final String tenBe = tb['tenBe'] ?? 'Bé';
                        final String tenThietBi = tb['tenThietBi'] ?? '';
                        final String canhBao = tb['canhBao'] ?? 'Nhắc nhở từ Giáo viên';
                        final String rawNoiDung = (tb['ungDung'] ?? '').toString();
                        final String noiDung = rawNoiDung.replaceFirst('[GV] ', '');
                        final String nguoiGui = tb['nhanVienGhi'] ?? 'GV nhà trường';
                        final String ngayGhiStr = (tb['ngayGhi'] ?? '').toString();

                        String gioStr = '';
                        if (ngayGhiStr.isNotEmpty) {
                          try {
                            final dt = DateTime.parse(ngayGhiStr).toLocal();
                            gioStr = DateFormat('HH:mm - dd/MM/yyyy').format(dt);
                          } catch (_) {
                            gioStr = ngayGhiStr;
                          }
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '👦 $tenBe ($tenThietBi)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E3A8A)),
                                    ),
                                  ),
                                  Text(
                                    gioStr,
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  canhBao,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '💬 "$noiDung"',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '👩‍🏫 Người gửi: $nguoiGui',
                                style: TextStyle(fontSize: 11, color: Colors.teal.shade800, fontWeight: FontWeight.w600),
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () async {
                                      final ok = await ApiService.xoaNhatKy(maNhatKy);
                                      if (ok) {
                                        setDialogState(() {
                                          _thongBaoGiaoVien.removeAt(index);
                                        });
                                        _loadDanhSachThietBi();
                                      }
                                    },
                                    icon: const Icon(Icons.done_all, size: 16, color: Colors.grey),
                                    label: const Text('Đã xem / Xóa', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ),
                                  const SizedBox(width: 6),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await _toggleKhoaMay(treEmId, false, tenBe);
                                    },
                                    icon: const Icon(Icons.lock, size: 14),
                                    label: const Text('Khóa Máy Ngay', style: TextStyle(fontSize: 11)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
              child: const Text('Đóng'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Đếm thống kê
    final tongSo = _danhSachThietBi.length;
    final dangKhoaCount = _danhSachThietBi.where((b) => b['dangKhoa'] == true).length;
    final dangMoCount = tongSo - dangKhoaCount;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quản Lý Điện Thoại Trẻ Em',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3),
            ),
            Text(
              'Family Link & Parental Control • KidSafe',
              style: TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Chuông thông báo nhận tin nhắc nhở từ Giáo viên
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_active_rounded, size: 22),
                  tooltip: 'Thông báo từ Giáo viên',
                  onPressed: _showThongBaoGiaoVienDialog,
                ),
                if (_thongBaoGiaoVien.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '${_thongBaoGiaoVien.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _loadDanhSachThietBi,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await ApiService.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDanhSachThietBi,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Banner tổng quan thống kê cao cấp
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF312E81)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E293B).withOpacity(0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Tổng máy', '$tongSo', Icons.devices_rounded, Colors.white),
                        Container(width: 1, height: 42, color: Colors.white12),
                        _buildStatItem('Đang mở máy', '$dangMoCount', Icons.check_circle_rounded, const Color(0xFF34D399)),
                        Container(width: 1, height: 42, color: Colors.white12),
                        _buildStatItem('Đang khóa', '$dangKhoaCount', Icons.lock_rounded, const Color(0xFFF87171)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.phonelink_lock_rounded, color: Color(0xFF4F46E5), size: 18),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Danh Sách Thiết Bị Của Bé',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          '${_danhSachThietBi.length} thiết bị',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (_danhSachThietBi.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.phonelink_erase_rounded, size: 70, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text('Chưa liên kết thiết bị bé nào!', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _showAddDeviceDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm thiết bị ngay'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._danhSachThietBi.map((be) {
                      final id = be['id'] ?? 0;
                      final ten = be['hoTen'] ?? 'Bé';
                      final thietBi = be['tenThietBi'] ?? 'Samsung Galaxy';
                      final heDieuHanh = be['heDieuHanh'] ?? 'Android';
                      final gioiHanPhut = be['gioiHanPhut'] ?? 120;
                      final dangKhoa = be['dangKhoa'] == true;
                      final maKetNoi = be['maKetNoi'] ?? 'PAIR-0000';
                      final sdtKhanCap = be['sdtKhanCap'] ?? 'Chưa cài';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: dangKhoa ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. VÙNG BẤM VÀO ĐỂ XEM CHI TIẾT
                            InkWell(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChildDetailScreen(
                                      treEmId: id,
                                      tenBe: ten,
                                      tenThietBi: thietBi,
                                      heDieuHanh: heDieuHanh,
                                      gioiHanPhut: gioiHanPhut,
                                      dangKhoa: dangKhoa,
                                      maKetNoi: maKetNoi,
                                      sdtKhanCap: sdtKhanCap,
                                    ),
                                  ),
                                ).then((_) => _loadDanhSachThietBi());
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Icon máy với nền Squircle hiện đại
                                    Container(
                                      padding: const EdgeInsets.all(13),
                                      decoration: BoxDecoration(
                                        color: dangKhoa ? const Color(0xFFFEE2E2) : const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: dangKhoa ? const Color(0xFFFCA5A5) : const Color(0xFFC7D2FE),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Icon(
                                        dangKhoa ? Icons.lock_rounded : (heDieuHanh == 'iOS' ? Icons.apple : Icons.phone_android),
                                        size: 28,
                                        color: dangKhoa ? const Color(0xFFDC2626) : const Color(0xFF4F46E5),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    // Tên bé & Tên máy
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ten,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF0F172A),
                                              letterSpacing: -0.2,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '$thietBi • $heDieuHanh',
                                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                          ),
                                          const SizedBox(height: 7),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 5,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEEF2FF),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFFC7D2FE), width: 0.6),
                                                ),
                                                child: Text(
                                                  '⏱ $gioiHanPhut phút/ngày',
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF4338CA), fontWeight: FontWeight.w700),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                                decoration: BoxDecoration(
                                                  color: dangKhoa ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: dangKhoa ? const Color(0xFFFCA5A5) : const Color(0xFFA7F3D0),
                                                    width: 0.6,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: dangKhoa ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      dangKhoa ? 'ĐÃ KHÓA' : 'ĐANG MỞ',
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        color: dangKhoa ? const Color(0xFF991B1B) : const Color(0xFF065F46),
                                                        fontWeight: FontWeight.w800,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                                decoration: BoxDecoration(
                                                  color: ApiService.daKetNoiGiaoVien(be)
                                                      ? const Color(0xFFF0FDFA)
                                                      : const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: ApiService.daKetNoiGiaoVien(be)
                                                        ? const Color(0xFF99F6E4)
                                                        : const Color(0xFFE2E8F0),
                                                    width: 0.6,
                                                  ),
                                                ),
                                                child: Text(
                                                  ApiService.daKetNoiGiaoVien(be)
                                                      ? '🎓 GV: ${ApiService.layTenGiaoVienKetNoi(be)}'
                                                      : '🎓 Chưa kết nối GV',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: ApiService.daKetNoiGiaoVien(be)
                                                        ? const Color(0xFF0F766E)
                                                        : const Color(0xFF64748B),
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Nút gạt Khóa / Mở Khóa máy từ xa
                                    Column(
                                      children: [
                                        Transform.scale(
                                          scale: 0.9,
                                          child: Switch(
                                            value: !dangKhoa, // Bật là Mở, Tắt là Khóa
                                            activeColor: const Color(0xFF10B981),
                                            inactiveThumbColor: const Color(0xFFEF4444),
                                            inactiveTrackColor: const Color(0xFFFEE2E2),
                                            onChanged: (val) => _toggleKhoaMay(id, dangKhoa, ten),
                                          ),
                                        ),
                                        Text(
                                          dangKhoa ? 'Khóa máy' : 'Đang mở',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: dangKhoa ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                            // 2. VÙNG ĐỘC LẬP CHO MÃ GHÉP NỐI QR & NÚT XÓA
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _showQrPairingDialog(ten, maKetNoi, thietBi),
                                    icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                                    label: Text('Mã QR: $maKetNoi', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.blueAccent,
                                      side: BorderSide(color: Colors.blue.shade300),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF1E3A8A)),
                                        tooltip: 'Sửa thông tin thiết bị',
                                        onPressed: () => _showEditDeviceDialog(be),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                        tooltip: 'Gỡ thiết bị',
                                        onPressed: () => _confirmDelete(id, ten),
                                      ),
                                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDeviceDialog,
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Thêm Điện Thoại Bé', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}