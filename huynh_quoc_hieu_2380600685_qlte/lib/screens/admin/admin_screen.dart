import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import '../staff/staff_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<dynamic> _users = [];
  List<dynamic> _danhSachThietBi = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Tải danh sách tất cả tài khoản + danh sách thiết bị từ API
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      ApiService.getDanhSachUsers(),
      ApiService.getDanhSachTreEm(),
    ]);
    if (!mounted) return;
    setState(() {
      _users = results[0];
      _danhSachThietBi = results[1];
      _isLoading = false;
    });
  }

  // Lấy danh sách các thiết bị mà User này đang quản lý / giám sát
  List<dynamic> _getThietBiCuaUser(Map<String, dynamic> user) {
    final String userId = (user['id'] ?? '').toString();
    final String username = (user['userName'] ?? '').toString();
    final String hoTen = (user['hoTen'] ?? '').toString();
    final String vaiTro = (user['vaiTro'] ?? 'PhuHuynh').toString();

    if (vaiTro == 'PhuHuynh') {
      return _danhSachThietBi.where((b) {
        final String phId = (b['phuHuynhId'] ?? '').toString();
        final String tenPh = (b['tenPhuHuynh'] ?? '').toString();
        return (userId.isNotEmpty && phId == userId) ||
            (hoTen.isNotEmpty && tenPh.toLowerCase() == hoTen.toLowerCase());
      }).toList();
    } else if (vaiTro == 'NhanVien') {
      return _danhSachThietBi
          .where((b) => ApiService.daKetNoiGiaoVien(b, gvUsername: username))
          .toList();
    } else {
      return _danhSachThietBi;
    }
  }

  // Hộp thoại Sửa thông tin tài khoản (PUT) & Phân quyền thiết bị giám sát
  void _showEditUserDialog(Map<String, dynamic> user) {
    final String username = (user['userName'] ?? '').toString();
    final String userId = (user['id'] ?? '').toString();
    final bool isRootAdmin = username.toLowerCase() == 'admin';

    final hoTenController = TextEditingController(text: (user['hoTen'] ?? username).toString());
    final emailController = TextEditingController(text: (user['email'] ?? '').toString());
    String selectedVaiTro = (user['vaiTro'] ?? 'PhuHuynh').toString();
    if (!['Admin', 'NhanVien', 'PhuHuynh'].contains(selectedVaiTro)) {
      selectedVaiTro = 'PhuHuynh';
    }

    // Tập hợp ID các máy đang gắn với tài khoản này
    final Set<int> selectedDeviceIds = _getThietBiCuaUser(user)
        .map<int>((b) => (b['id'] ?? 0) as int)
        .toSet();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.edit_note_rounded, color: Colors.indigo, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sửa Tài Khoản (PUT)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    Text(
                      'Tài khoản: @$username',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: hoTenController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên *',
                    prefixIcon: Icon(Icons.badge_outlined, color: Colors.indigo),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ Email *',
                    prefixIcon: Icon(Icons.email_outlined, color: Colors.indigo),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedVaiTro,
                  decoration: const InputDecoration(
                    labelText: 'Vai trò phân quyền',
                    prefixIcon: Icon(Icons.security_rounded, color: Colors.indigo),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'PhuHuynh', child: Text('👨‍👩‍👧 Phụ Huynh')),
                    DropdownMenuItem(value: 'NhanVien', child: Text('🎓 Giám Sát Viên (Giáo Viên)')),
                    DropdownMenuItem(value: 'Admin', child: Text('🛡️ Quản Trị Viên (Admin)')),
                  ],
                  onChanged: isRootAdmin
                      ? null
                      : (val) {
                          if (val != null) {
                            setDialogState(() => selectedVaiTro = val);
                          }
                        },
                ),
                if (!isRootAdmin && _danhSachThietBi.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        selectedVaiTro == 'NhanVien' ? Icons.link_rounded : Icons.devices_rounded,
                        size: 18,
                        color: selectedVaiTro == 'NhanVien' ? Colors.teal : Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          selectedVaiTro == 'NhanVien'
                              ? 'Kết nối máy học sinh cho Giáo viên giám sát:'
                              : 'Thiết bị con em thuộc Phụ huynh quản lý:',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ..._danhSachThietBi.map((be) {
                    final int id = be['id'] ?? 0;
                    final String tenBe = be['hoTen'] ?? 'Bé';
                    final String tenMay = be['tenThietBi'] ?? 'Điện thoại';
                    final String maPair = be['maKetNoi'] ?? 'PAIR';
                    final bool isChecked = selectedDeviceIds.contains(id);

                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: selectedVaiTro == 'NhanVien' ? Colors.teal : Colors.indigo,
                      value: isChecked,
                      title: Text(
                        '$tenBe ($tenMay)',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Text(
                        'Mã kết nối: $maPair',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      onChanged: (bool? checked) {
                        setDialogState(() {
                          if (checked == true) {
                            selectedDeviceIds.add(id);
                          } else {
                            selectedDeviceIds.remove(id);
                          }
                        });
                      },
                    );
                  }),
                ],
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
                final String newHoTen = hoTenController.text.trim();
                final String newEmail = emailController.text.trim();
                if (newHoTen.isEmpty) return;

                Navigator.pop(ctx);
                setState(() => _isLoading = true);

                // 1. Gọi PUT cập nhật thông tin User
                await ApiService.capNhatUser(username, {
                  'hoTen': newHoTen,
                  'email': newEmail,
                  'vaiTro': selectedVaiTro,
                });

                // 2. Nếu là Giáo viên: cập nhật danh sách máy kết nối giám sát vào SQL Server
                if (selectedVaiTro == 'NhanVien') {
                  for (var be in _danhSachThietBi) {
                    final int id = be['id'] ?? 0;
                    final bool shouldConnect = selectedDeviceIds.contains(id);
                    final bool currentlyConnected =
                        ApiService.daKetNoiGiaoVien(be, gvUsername: username);
                    if (shouldConnect && !currentlyConnected) {
                      await ApiService.capNhatKetNoiGiaoVien(
                        be: be,
                        ketNoi: true,
                        gvUsername: username,
                        gvHoTen: newHoTen,
                      );
                    } else if (!shouldConnect && currentlyConnected) {
                      await ApiService.capNhatKetNoiGiaoVien(
                        be: be,
                        ketNoi: false,
                        gvUsername: username,
                        gvHoTen: newHoTen,
                      );
                    } else if (shouldConnect && currentlyConnected) {
                      // Cập nhật lại tên GV nếu đổi họ tên
                      await ApiService.capNhatKetNoiGiaoVien(
                        be: be,
                        ketNoi: true,
                        gvUsername: username,
                        gvHoTen: newHoTen,
                      );
                    }
                  }
                } else if (selectedVaiTro == 'PhuHuynh' && userId.isNotEmpty) {
                  for (var be in _danhSachThietBi) {
                    final int id = be['id'] ?? 0;
                    if (selectedDeviceIds.contains(id) && be['phuHuynhId'] != userId) {
                      await ApiService.capNhatTreEm(id, {
                        'hoTen': be['hoTen'],
                        'tenThietBi': be['tenThietBi'],
                        'heDieuHanh': be['heDieuHanh'],
                        'gioiHanPhut': be['gioiHanPhut'],
                        'dangKhoa': be['dangKhoa'],
                        'sdtKhanCap': be['sdtKhanCap'],
                        'maKetNoi': be['maKetNoi'],
                        'hinhAnh': be['hinhAnh'],
                        'phuHuynhId': userId,
                      });
                    }
                  }
                }

                await _loadData();
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('✅ Đã cập nhật (PUT) tài khoản @$username thành công!'),
                    backgroundColor: Colors.indigo,
                  ),
                );
              },
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Lưu Cập Nhật (PUT)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Hộp thoại xác nhận xóa tài khoản
  void _confirmDelete(String username, String hoTen) {
    if (username.toLowerCase() == 'admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể xóa tài khoản Admin tối cao của hệ thống!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xác nhận xóa tài khoản', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc chắn muốn xóa tài khoản "$hoTen" (@$username) khỏi hệ thống không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ApiService.xoaUser(username);
              if (success) {
                _loadData();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đã xóa thành công tài khoản @$username!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Xóa Tài Khoản'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final soGiaoVien = _users.where((u) => (u['vaiTro'] ?? '') == 'NhanVien').length;
    final soPhuHuynh = _users.where((u) => (u['vaiTro'] ?? '') == 'PhuHuynh').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Quản Trị Hệ Thống (Admin)',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white, letterSpacing: -0.3),
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Làm mới',
            onPressed: _loadData,
          ),
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
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // THỐNG KÊ NHANH HỆ THỐNG
                    Row(
                      children: [
                        _buildStatCard('Tổng User', '${_users.length}', Icons.people_alt_rounded, const Color(0xFF4338CA), const Color(0xFFEEF2FF)),
                        const SizedBox(width: 10),
                        _buildStatCard('Giám Sát', '$soGiaoVien', Icons.school_rounded, const Color(0xFF0F766E), const Color(0xFFCCFBF1)),
                        const SizedBox(width: 10),
                        _buildStatCard('Phụ Huynh', '$soPhuHuynh', Icons.family_restroom_rounded, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // PHÍM TẮT ĐIỀU HÀNH GIÁM SÁT TOÀN HỆ THỐNG
                    InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const StaffScreen(isAdmin: true)),
                        );
                        _loadData();
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFC7D2FE), width: 1.2),
                          boxShadow: const [
                            BoxShadow(color: Color(0x060F172A), blurRadius: 14, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Center(
                                child: Icon(Icons.phonelink_setup_rounded, color: Color(0xFF4338CA), size: 24),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Giám Sát Thiết Bị Hệ Thống (${_danhSachThietBi.length} máy)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: Color(0xFF1E1B4B),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Xem trạng thái khóa, kết nối GV & PH của toàn bộ các máy',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Row(
                      children: [
                        Icon(Icons.manage_accounts_rounded, size: 20, color: Color(0xFF1E1B4B)),
                        SizedBox(width: 8),
                        Text(
                          'Danh Sách Tài Khoản & Phân Quyền',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bấm biểu tượng ✏️ để cập nhật (PUT) thông tin hoặc gán máy giám sát',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 12),

                    // DANH SÁCH TÀI KHOẢN KÈM THIẾT BỊ GIÁM SÁT
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index] as Map<String, dynamic>;
                        final username = (user['userName'] ?? '').toString();
                        final hoTen = (user['hoTen'] ?? username).toString();
                        final email = (user['email'] ?? '').toString();
                        final vaiTro = (user['vaiTro'] ?? 'PhuHuynh').toString();
                        final isAdmin = username.toLowerCase() == 'admin';

                        final List<dynamic> mayCuaUser = _getThietBiCuaUser(user);

                        final Color roleColor = isAdmin
                            ? Colors.indigo
                            : vaiTro == 'NhanVien'
                                ? Colors.teal
                                : Colors.blueAccent;

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
                            onTap: () => _showEditUserDialog(user),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Hàng 1: Avatar + Thông tin User + Nút Sửa (PUT) & Xóa (DELETE)
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: roleColor.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            isAdmin
                                                ? Icons.shield_rounded
                                                : vaiTro == 'NhanVien'
                                                    ? Icons.school_rounded
                                                    : Icons.family_restroom_rounded,
                                            color: roleColor,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              hoTen,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15.5,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '@$username • $email',
                                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: roleColor.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                vaiTro == 'Admin'
                                                    ? '🛡️ Quản Trị Viên'
                                                    : vaiTro == 'NhanVien'
                                                        ? '🎓 Giám Sát Viên (Giáo Viên)'
                                                        : '👨‍👩‍👧 Phụ Huynh',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: roleColor,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Nút Sửa (PUT)
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 20),
                                        tooltip: 'Sửa tài khoản & gán thiết bị (PUT)',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _showEditUserDialog(user),
                                      ),
                                      if (isAdmin)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text('Root', style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                          tooltip: 'Xóa tài khoản',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () => _confirmDelete(username, hoTen),
                                        ),
                                    ],
                                  ),

                                  // Hàng 2: Hiển thị danh sách máy mà Phụ huynh hoặc Giáo viên đang giám sát
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isAdmin
                                          ? Colors.indigo.shade50.withOpacity(0.5)
                                          : vaiTro == 'NhanVien'
                                              ? Colors.teal.shade50.withOpacity(0.6)
                                              : Colors.blue.shade50.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isAdmin
                                            ? Colors.indigo.shade100
                                            : vaiTro == 'NhanVien'
                                                ? Colors.teal.shade200
                                                : Colors.blue.shade200,
                                      ),
                                    ),
                                    child: isAdmin
                                        ? Row(
                                            children: [
                                              const Icon(Icons.verified_user_rounded,
                                                  size: 16, color: Colors.indigo),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Toàn quyền điều hành tất cả ${_danhSachThietBi.length} thiết bị trên hệ thống',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.indigo.shade800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    vaiTro == 'NhanVien'
                                                        ? Icons.phonelink_ring_rounded
                                                        : Icons.devices_other_rounded,
                                                    size: 15,
                                                    color: roleColor,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      vaiTro == 'NhanVien'
                                                          ? 'Thiết bị học sinh đang giám sát (${mayCuaUser.length} máy):'
                                                          : 'Thiết bị con đang giám sát (${mayCuaUser.length} máy):',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                        color: roleColor,
                                                      ),
                                                    ),
                                                  ),
                                                  InkWell(
                                                    onTap: () => _showEditUserDialog(user),
                                                    child: Text(
                                                      vaiTro == 'NhanVien'
                                                          ? '+ Kết nối / Đổi máy'
                                                          : 'Chi tiết',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: roleColor,
                                                        decoration: TextDecoration.underline,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              if (mayCuaUser.isEmpty)
                                                Text(
                                                  vaiTro == 'NhanVien'
                                                      ? 'Chưa kết nối máy học sinh nào (Cần nhập mã PAIR hoặc bấm "+ Kết nối / Đổi máy")'
                                                      : 'Chưa thêm thiết bị nào',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                )
                                              else
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: mayCuaUser.map((be) {
                                                    final String tenBe = be['hoTen'] ?? 'Bé';
                                                    final String tenMay =
                                                        be['tenThietBi'] ?? 'Máy';
                                                    final String maPair =
                                                        be['maKetNoi'] ?? 'PAIR';
                                                    final bool dangKhoa =
                                                        be['dangKhoa'] == true;
                                                    return Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: dangKhoa
                                                              ? Colors.red.shade200
                                                              : roleColor.withOpacity(0.35),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            dangKhoa
                                                                ? Icons.lock_rounded
                                                                : Icons.smartphone_rounded,
                                                            size: 13,
                                                            color: dangKhoa
                                                                ? Colors.red
                                                                : roleColor,
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            '$tenBe ($tenMay • $maPair)',
                                                            style: const TextStyle(
                                                              fontSize: 11.5,
                                                              fontWeight: FontWeight.w600,
                                                              color: Color(0xFF1E293B),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // Widget thẻ thống kê nhỏ squircle cao cấp
  Widget _buildStatCard(String title, String count, IconData icon, Color color, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: const [
            BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(icon, color: color, size: 20),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}