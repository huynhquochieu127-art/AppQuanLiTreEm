import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';

class StaffScreen extends StatefulWidget {
  final bool isAdmin;
  const StaffScreen({super.key, this.isAdmin = false});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  List<dynamic> _danhSachThietBi = [];
  bool _isLoading = true;
  String _filter = 'ALL'; // ALL, ACTIVE, LOCKED
  String _gvUsername = 'hieuhq1';
  String _gvHoTen = 'Huỳnh Quốc Huy';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final uname = await ApiService.getUsername();
    final users = await ApiService.getDanhSachUsers();
    final data = await ApiService.getDanhSachTreEm();

    String foundHoTen = 'Huỳnh Quốc Huy';
    final effectiveUname = (uname != null && uname.isNotEmpty && uname.toLowerCase() != 'admin')
        ? uname
        : 'hieuhq1';

    for (var u in users) {
      if ((u['userName'] ?? '').toString().toLowerCase() == effectiveUname.toLowerCase()) {
        foundHoTen = (u['hoTen'] ?? effectiveUname).toString();
        break;
      }
    }

    if (!mounted) return;
    setState(() {
      _gvUsername = effectiveUname;
      _gvHoTen = foundHoTen;
      _danhSachThietBi = data;
      _isLoading = false;
    });
  }

  // Hộp thoại Bước Kết Nối Máy Học Sinh Bằng Mã Ghép Nối (PAIR-xxxx / QR)
  void _showKetNoiThietBiDialog() {
    final maPairController = TextEditingController();
    final dsChuaKetNoi = _danhSachThietBi
        .where((b) => !ApiService.daKetNoiGiaoVien(b, gvUsername: _gvUsername))
        .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.qr_code_scanner_rounded, color: Colors.teal.shade700, size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Kết Nối Máy Học Sinh',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Thiết bị của bé khi tạo chỉ kết nối với Phụ huynh. Giáo viên cần nhập Mã Ghép Nối (PAIR-xxxx) do Phụ huynh cung cấp để liên kết giám sát trong giờ học.',
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: maPairController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'Nhập Mã Ghép Nối Thiết Bị (VD: PAIR-8518) *',
                    hintText: 'PAIR-xxxx',
                    prefixIcon: Icon(Icons.vpn_key_rounded, color: Colors.teal.shade700),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '📋 Mã thiết bị từ Phụ huynh đang chờ kết nối (${dsChuaKetNoi.length} máy):',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                if (dsChuaKetNoi.isEmpty)
                  Text(
                    'Tất cả thiết bị học sinh trên hệ thống đều đã được kết nối giám sát!',
                    style: TextStyle(fontSize: 12, color: Colors.teal.shade700, fontStyle: FontStyle.italic),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: dsChuaKetNoi.map((be) {
                      final String tenBe = be['hoTen'] ?? 'Bé';
                      final String tenMay = be['tenThietBi'] ?? 'Điện thoại';
                      final String maPair = be['maKetNoi'] ?? 'PAIR';
                      final String tenPh = be['tenPhuHuynh'] ?? 'Phụ huynh';
                      final bool daKetNoiGvKhac = ApiService.daKetNoiGiaoVien(be);
                      final String gvKhacText = daKetNoiGvKhac ? ' (Đang GV: ${ApiService.layTenGiaoVienKetNoi(be)})' : '';
                      return ActionChip(
                        avatar: Icon(Icons.add_link_rounded, size: 15, color: Colors.teal.shade700),
                        backgroundColor: Colors.teal.shade50,
                        label: Text(
                          '$tenBe ($tenMay • $maPair)$gvKhacText - PH: $tenPh',
                          style: TextStyle(fontSize: 11.5, color: Colors.teal.shade900, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          setDialogState(() {
                            maPairController.text = maPair;
                          });
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final code = maPairController.text.trim().toUpperCase();
                if (code.isEmpty) return;

                Map<String, dynamic>? foundBe;
                for (var b in _danhSachThietBi) {
                  if ((b['maKetNoi'] ?? '').toString().trim().toUpperCase() == code) {
                    foundBe = b as Map<String, dynamic>;
                    break;
                  }
                }

                if (foundBe == null) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Không tìm thấy thiết bị nào có mã ghép nối "$code"!'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);
                setState(() => _isLoading = true);

                final ok = await ApiService.capNhatKetNoiGiaoVien(
                  be: foundBe,
                  ketNoi: true,
                  gvUsername: _gvUsername,
                  gvHoTen: _gvHoTen,
                );
                await _loadData();

                if (!mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '🔗 Đã kết nối thiết bị của ${foundBe['hoTen']} ($code) vào danh sách giám sát của Giáo viên $_gvHoTen!'),
                      backgroundColor: Colors.teal.shade700,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Kết Nối Giám Sát'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Ngắt kết nối thiết bị học sinh khỏi danh sách giám sát của Giáo viên
  Future<void> _confirmNgatKetNoi(Map<String, dynamic> be) async {
    final String tenBe = be['hoTen'] ?? 'Học sinh';
    final String maPair = be['maKetNoi'] ?? 'PAIR';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Ngắt kết nối giám sát?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text(
          'Bạn có muốn ngắt kết nối giám sát thiết bị của "$tenBe" (Mã: $maPair) khỏi danh sách lớp của Giáo viên không?\n\n(Khi cần kết nối lại, chỉ cần nhập lại mã $maPair).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Ngắt Kết Nối'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await ApiService.capNhatKetNoiGiaoVien(
        be: be,
        ketNoi: false,
        gvUsername: _gvUsername,
        gvHoTen: _gvHoTen,
      );
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã ngắt kết nối giám sát thiết bị của $tenBe ($maPair).'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }
  }

  // Form dành riêng cho Giáo viên: Gửi yêu cầu nhắc nhở về chuông thông báo của Phụ huynh
  void _showGuiNhacNhoDialog(Map<String, dynamic> be) {
    final int treEmId = be['id'] ?? 0;
    final String tenBe = be['hoTen'] ?? 'Học sinh';
    final String tenThietBi = be['tenThietBi'] ?? 'Điện thoại';
    final String phuHuynh = be['tenPhuHuynh'] ?? 'Phụ huynh';

    String loaiViPham = '📵 Sử dụng điện thoại trong giờ học';
    final noiDungController = TextEditingController(
      text: 'Phát hiện bé mở điện thoại trong giờ học, nhờ Phụ huynh khóa máy từ xa giúp giáo viên ạ!',
    );
    final giaoVienController = TextEditingController(text: '$_gvHoTen - GV Giám sát');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.campaign_rounded, color: Colors.teal.shade700, size: 28),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Gửi Nhắc Nhở Phụ Huynh',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('👦 Học sinh: $tenBe ($tenThietBi)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text('👨‍👩‍👧 Gửi đến PH: $phuHuynh',
                          style: TextStyle(fontSize: 12, color: Colors.teal.shade900, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text('🕒 Giờ gửi: ${DateFormat('HH:mm - dd/MM/yyyy').format(DateTime.now())} (Thời gian thực)',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: loaiViPham,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Lý do nhắc nhở *',
                    prefixIcon: Icon(Icons.report_problem_outlined, color: Colors.orange),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: '📵 Sử dụng điện thoại trong giờ học',
                      child: Text('📵 Sử dụng điện thoại trong giờ học', style: TextStyle(fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: '🎮 Chơi game / Mạng xã hội trong lớp',
                      child: Text('🎮 Chơi game / Mạng xã hội trong lớp', style: TextStyle(fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: '🔒 Yêu cầu Phụ huynh khóa máy từ xa',
                      child: Text('🔒 Yêu cầu Phụ huynh khóa máy từ xa', style: TextStyle(fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: '⚠️ Mất tập trung vì thông báo điện thoại',
                      child: Text('⚠️ Mất tập trung vì thông báo điện thoại', style: TextStyle(fontSize: 13)),
                    ),
                    DropdownMenuItem(
                      value: '🌟 Khen ngợi: Chấp hành tốt nội quy thiết bị',
                      child: Text('🌟 Khen ngợi: Chấp hành tốt nội quy thiết bị', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        loaiViPham = val;
                        if (val.contains('Chơi game')) {
                          noiDungController.text =
                              'Giáo viên phát hiện bé đang mở game trong tiết học. Đề nghị phụ huynh kiểm tra và khóa máy!';
                        } else if (val.contains('Khen ngợi')) {
                          noiDungController.text =
                              'Hôm nay bé chấp hành rất tốt quy định không dùng điện thoại trong lớp học!';
                        } else {
                          noiDungController.text =
                              'Phát hiện bé mở điện thoại trong giờ học, nhờ Phụ huynh khóa máy từ xa giúp giáo viên ạ!';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noiDungController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Lời nhắn gửi đến Phụ huynh *',
                    prefixIcon: Icon(Icons.message_outlined, color: Colors.teal),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Mẫu câu nhắc nhanh:',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final mau in [
                      'Nhờ PH khóa máy ngay giúp GV ạ!',
                      'Bé đang mở máy trong tiết Toán',
                      'Bé dùng điện thoại giờ ra chơi quá lâu',
                    ])
                      ActionChip(
                        label: Text(mau, style: const TextStyle(fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Colors.orange.shade50,
                        onPressed: () {
                          setDialogState(() {
                            noiDungController.text = mau;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: giaoVienController,
                  decoration: const InputDecoration(
                    labelText: 'Tên Giáo viên gửi',
                    prefixIcon: Icon(Icons.badge_outlined, color: Colors.blueGrey),
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
            ElevatedButton.icon(
              onPressed: () async {
                final loiNhan = noiDungController.text.trim();
                final gv = giaoVienController.text.trim().isEmpty ? _gvHoTen : giaoVienController.text.trim();
                if (loiNhan.isEmpty) return;

                final success = await ApiService.themNhatKy({
                  'treEmId': treEmId,
                  'ungDung': '[GV] $loaiViPham',
                  'thoiGianSuDung': 0,
                  'khungGio': DateTime.now().toIso8601String(),
                  'viDo': 10.762622,
                  'kinhDo': 106.660172,
                  'mucPin': 100,
                  'viTriHienTai': loiNhan,
                  'canhBao': loaiViPham,
                  'nhanVienGhi': 'GV: $gv',
                });

                if (!mounted) return;
                if (ctx.mounted) Navigator.pop(ctx);
                if (success) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('🔔 Đã gửi thông báo nhắc nhở đến phụ huynh của $tenBe!'),
                      backgroundColor: Colors.teal.shade700,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.send_rounded, size: 16),
              label: const Text('Gửi Về Phụ Huynh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nếu là Giáo viên: Chỉ hiển thị các máy đã kết nối qua mã PAIR
    // Nếu là Admin: Hiển thị toàn bộ máy trên hệ thống
    final List<dynamic> baseList = widget.isAdmin
        ? _danhSachThietBi
        : _danhSachThietBi.where((b) => ApiService.daKetNoiGiaoVien(b, gvUsername: _gvUsername)).toList();

    final int soMayChoKetNoi = widget.isAdmin
        ? _danhSachThietBi.where((b) => !ApiService.daKetNoiGiaoVien(b)).length
        : _danhSachThietBi.where((b) => !ApiService.daKetNoiGiaoVien(b, gvUsername: _gvUsername)).length;

    final tongSo = baseList.length;
    final dangKhoaCount = baseList.where((b) => b['dangKhoa'] == true).length;
    final dangMoCount = tongSo - dangKhoaCount;

    final filteredList = baseList.where((b) {
      if (_filter == 'LOCKED') return b['dangKhoa'] == true;
      if (_filter == 'ACTIVE') return b['dangKhoa'] != true;
      return true;
    }).toList();

    final themeColor = widget.isAdmin ? const Color(0xFF1E1B4B) : const Color(0xFF0F766E);
    final gradientColors = widget.isAdmin
        ? [const Color(0xFF1E1B4B), const Color(0xFF312E81), const Color(0xFF4338CA)]
        : [const Color(0xFF042F2E), const Color(0xFF0F766E), const Color(0xFF14B8A6)];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isAdmin ? 'Giám Sát Thiết Bị Toàn Hệ Thống' : 'Khu Vực Giám Sát Lớp Học',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              widget.isAdmin
                  ? 'Quyền Quản Trị Viên (Admin) • Toàn bộ thiết bị'
                  : 'Giáo viên: $_gvHoTen (@$_gvUsername)',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF99F6E4), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
            tooltip: 'Kết nối máy học sinh bằng mã PAIR',
            onPressed: _showKetNoiThietBiDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
          if (!widget.isAdmin)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Banner tổng quan giám sát sang trọng
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: (widget.isAdmin ? const Color(0xFF312E81) : const Color(0xFF0F766E)).withOpacity(0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat(widget.isAdmin ? 'Tổng máy' : 'Đã kết nối', '$tongSo', Icons.devices_rounded),
                        Container(width: 1, height: 35, color: Colors.white24),
                        _buildStat('Đang mở máy', '$dangMoCount', Icons.check_circle_outline_rounded),
                        Container(width: 1, height: 35, color: Colors.white24),
                        _buildStat('Đã khóa từ xa', '$dangKhoaCount', Icons.lock_outline_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // NÚT BƯỚC KẾT NỐI MÁY HỌC SINH QUA MÃ PAIR / QR
                  InkWell(
                    onTap: _showKetNoiThietBiDialog,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFF99F6E4), width: 1.2),
                        boxShadow: const [
                          BoxShadow(color: Color(0x060F172A), blurRadius: 12, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCCFBF1),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF0F766E), size: 24),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '🔗 Kết Nối Thiết Bị Học Sinh (Mã PAIR)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  soMayChoKetNoi > 0
                                      ? 'Nhập mã PAIR từ Phụ huynh ($soMayChoKetNoi máy chờ kết nối)'
                                      : 'Nhập mã PAIR do Phụ huynh cấp để liên kết giám sát',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F766E).withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              '+ Kết Nối',
                              style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bộ lọc trạng thái kiểu Pill hiện đại
                  Row(
                    children: [
                      _buildFilterChip('Tất cả ($tongSo)', 'ALL'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Đang mở ($dangMoCount)', 'ACTIVE'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Đã khóa ($dangKhoaCount)', 'LOCKED'),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (filteredList.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.link_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.isAdmin
                                ? 'Không có thiết bị nào trong danh sách'
                                : 'Giáo viên chưa liên kết với thiết bị học sinh nào.\nBấm "+ Kết Nối" ở trên và nhập mã PAIR do Phụ huynh cung cấp!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    )
                  else
                    ...filteredList.map((be) {
                      final ten = be['hoTen'] ?? 'Bé';
                      final thietBi = be['tenThietBi'] ?? 'Samsung Galaxy';
                      final heDieuHanh = be['heDieuHanh'] ?? 'Android';
                      final gioiHanPhut = be['gioiHanPhut'] ?? 120;
                      final dangKhoa = be['dangKhoa'] == true;
                      final phuHuynh = be['tenPhuHuynh'] ?? 'Chưa liên kết';
                      final maKetNoi = be['maKetNoi'] ?? 'PAIR';
                      final daKetNoiGv = widget.isAdmin
                          ? ApiService.daKetNoiGiaoVien(be)
                          : ApiService.daKetNoiGiaoVien(be, gvUsername: _gvUsername);
                      final tenGvKetNoi = ApiService.layTenGiaoVienKetNoi(be);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          boxShadow: const [
                            BoxShadow(color: Color(0x060F172A), blurRadius: 14, offset: Offset(0, 4)),
                          ],
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _showGuiNhacNhoDialog(be),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: dangKhoa ? const Color(0xFFFEF2F2) : const Color(0xFFCCFBF1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: dangKhoa ? const Color(0xFFFECACA) : const Color(0xFF99F6E4),
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          dangKhoa ? Icons.lock_rounded : Icons.phone_android_rounded,
                                          color: dangKhoa ? const Color(0xFFDC2626) : const Color(0xFF0F766E),
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(ten, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0F172A))),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$thietBi ($heDieuHanh) • PH: $phuHuynh',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: dangKhoa ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: dangKhoa ? const Color(0xFFFECACA) : const Color(0xFFA7F3D0),
                                                  ),
                                                ),
                                                child: Text(
                                                  dangKhoa ? 'ĐÃ KHÓA MÁY' : 'ĐANG MỞ MÁY',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: dangKhoa ? const Color(0xFFDC2626) : const Color(0xFF047857),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text('Giới hạn: ${gioiHanPhut}p',
                                                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: () => _showGuiNhacNhoDialog(be),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFEA580C), Color(0xFFC2410C)],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFEA580C).withOpacity(0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.notifications_active_rounded, size: 14, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text(
                                              'Nhắc PH',
                                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      daKetNoiGv ? Icons.verified_rounded : Icons.link_off_rounded,
                                      size: 15,
                                      color: daKetNoiGv ? const Color(0xFF0F766E) : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        widget.isAdmin
                                            ? 'Mã: $maKetNoi • GV: $tenGvKetNoi'
                                            : 'Đã kết nối giám sát qua mã: $maKetNoi',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: daKetNoiGv ? const Color(0xFF0F766E) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    if (daKetNoiGv)
                                      InkWell(
                                        onTap: () => _confirmNgatKetNoi(be),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          child: Row(
                                            children: [
                                              Icon(Icons.link_off_rounded, size: 13, color: Color(0xFFDC2626)),
                                              SizedBox(width: 3),
                                              Text(
                                                'Ngắt kết nối',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFFDC2626),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    else if (widget.isAdmin)
                                      InkWell(
                                        onTap: () async {
                                          setState(() => _isLoading = true);
                                          await ApiService.capNhatKetNoiGiaoVien(
                                            be: be,
                                            ketNoi: true,
                                            gvUsername: _gvUsername,
                                            gvHoTen: _gvHoTen,
                                          );
                                          await _loadData();
                                        },
                                        child: const Text(
                                          '+ Kết nối GV',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF2563EB),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    final activeColor = widget.isAdmin ? Colors.indigo.shade700 : Colors.teal.shade700;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? activeColor : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, String count, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 4),
        Text(count, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}