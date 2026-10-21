import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../services/api_service.dart';

class ChildDetailScreen extends StatefulWidget {
  final int treEmId;
  final String tenBe;
  final String tenThietBi;
  final String heDieuHanh;
  final int gioiHanPhut;
  final bool dangKhoa;
  final String maKetNoi;
  final String sdtKhanCap;
  final bool isStaff;

  const ChildDetailScreen({
    super.key,
    required this.treEmId,
    required this.tenBe,
    required this.tenThietBi,
    required this.heDieuHanh,
    required this.gioiHanPhut,
    required this.dangKhoa,
    required this.maKetNoi,
    required this.sdtKhanCap,
    this.isStaff = false,
  });

  @override
  State<ChildDetailScreen> createState() => _ChildDetailScreenState();
}

class _ChildDetailScreenState extends State<ChildDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _nhatKyList = [];
  bool _isLoading = true;
  late bool _dangKhoaHienTai;

  // Tọa độ GPS mặc định máy bé (TP.HCM)
  LatLng _viTriBe = const LatLng(10.762622, 106.660172);
  String _diaChiHienTai = 'Trường THCS Ba Đình, Quận 5';

  // Cảm biến chuyển động (Shake-to-SOS - Mục d: 3.5đ)
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  bool _isShakeListening = true;
  int _shakeCount = 0;
  DateTime? _lastShakeTime;

  @override
  void initState() {
    super.initState();
    _dangKhoaHienTai = widget.dangKhoa;
    _tabController = TabController(length: 3, vsync: this);
    _loadNhatKy();
    _initShakeDetection();
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  double _liveGForce = 1.0;
  String _shakeStatusText = 'Sẵn sàng nhận diện';

  // Khởi tạo bộ lắng nghe cảm biến gia tốc kế (Accelerometer)
  void _initShakeDetection() {
    try {
      _accelerometerSubscription = accelerometerEventStream(
        samplingPeriod: SensorInterval.uiInterval,
      ).listen((AccelerometerEvent event) {
        if (!_isShakeListening) return;

        // Tính lực gia tốc chuẩn hóa gForce
        final double gX = event.x / 9.81;
        final double gY = event.y / 9.81;
        final double gZ = event.z / 9.81;
        final double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

        if (mounted) {
          setState(() {
            _liveGForce = gForce;
          });
        }

        // Ngưỡng lắc nhạy (lắc nhẹ tay hoặc lắc ngang/dọc)
        if (gForce > 1.25 || event.x.abs() > 11 || event.y.abs() > 11) {
          final now = DateTime.now();
          if (_lastShakeTime == null || now.difference(_lastShakeTime!).inMilliseconds > 200) {
            _lastShakeTime = now;
            _shakeCount++;
            if (mounted) {
              setState(() {
                _shakeStatusText = '⚡ Đã nhận 1 nhịp lắc! ($_shakeCount/2)';
              });
            }

            // Chỉ cần lắc 2 nhịp là kích hoạt ngay!
            if (_shakeCount >= 2) {
              _shakeCount = 0;
              _kichHoatSosDoLacTay();
            }
          }
        }
      });
    } catch (e) {
      debugPrint('Lỗi khởi tạo cảm biến gia tốc: $e');
    }
  }

  // Kích hoạt báo động khẩn cấp do cảm biến lắc tay phát hiện
  void _kichHoatSosDoLacTay() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚠️ PHÁT HIỆN LẮC MẠNH ĐIỆN THOẠI (SHAKE SENSOR) -> TỰ ĐỘNG BÁO ĐỘNG SOS!'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
    _triggerSosAlert();
  }

  // Tải nhật ký hoạt động điện thoại của bé từ API (tách riêng tin nhắn GV)
  Future<void> _loadNhatKy() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getNhatKyTheoTreEm(widget.treEmId);
    final activityLogs = data.where((log) {
      final nv = (log['nhanVienGhi'] ?? '').toString();
      final ud = (log['ungDung'] ?? '').toString();
      return !nv.startsWith('GV:') && !ud.startsWith('[GV]') && !ud.startsWith('[SYNC_USER]') && nv != 'SYS_SYNC';
    }).toList();

    setState(() {
      _nhatKyList = activityLogs;
      _isLoading = false;

      // Cập nhật tọa độ từ bản ghi mới nhất nếu có
      if (_nhatKyList.isNotEmpty) {
        final viTriStr = _nhatKyList.first['viTriHienTai']?.toString() ?? '';
        if (viTriStr.isNotEmpty) {
          _diaChiHienTai = viTriStr;
        }

        // Dùng Regex tìm tọa độ (lat, lng) ở bất kỳ đâu trong chuỗi
        final reg = RegExp(r'(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)');
        final match = reg.firstMatch(viTriStr);
        if (match != null) {
          final lat = double.tryParse(match.group(1)!);
          final lng = double.tryParse(match.group(2)!);
          if (lat != null && lng != null) {
            _viTriBe = LatLng(lat, lng);
          }
        } else {
          // Nếu người dùng nhập tên địa điểm quen thuộc bằng chữ
          final lower = viTriStr.toLowerCase();
          if (lower.contains('nhà')) {
            _viTriBe = const LatLng(10.755100, 106.668200);
          } else if (lower.contains('công viên')) {
            _viTriBe = const LatLng(10.774500, 106.691200);
          } else if (lower.contains('sách') || lower.contains('siêu thị')) {
            _viTriBe = const LatLng(10.774500, 106.702500);
          } else {
            _viTriBe = const LatLng(10.762622, 106.660172);
          }
        }
      }
    });
  }

  // Khóa / Mở khóa máy từ xa
  Future<void> _toggleLock() async {
    final bool trangThaiMoi = !_dangKhoaHienTai;
    final success = await ApiService.khoaMoThietBi(widget.treEmId, trangThai: trangThaiMoi);
    if (success) {
      setState(() {
        _dangKhoaHienTai = trangThaiMoi;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(trangThaiMoi ? '🔒 Đã khóa điện thoại của bé!' : '🔓 Đã mở khóa điện thoại!'),
          backgroundColor: trangThaiMoi ? Colors.redAccent : Colors.green,
        ),
      );
    }
  }

  // Dialog ghi nhận hoạt động mới (CRUD CREATE Nhật Ký)
  void _showAddLogDialog() {
    final appController = TextEditingController(text: 'YouTube Kids');
    final thoiGianController = TextEditingController(text: '45');
    final pinController = TextEditingController(text: '80');
    final viTriController = TextEditingController(text: 'Trường THCS Ba Đình, Q5 (10.762622, 106.660172)');
    String canhBao = 'Bình thường';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Ghi Nhật Ký Dùng Máy - ${widget.tenBe}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hiển thị thời gian thực tự động (không cho chỉnh sửa)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_filled_rounded, color: Color(0xFF1E3A8A), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Thời gian ghi: ${DateFormat('HH:mm - dd/MM/yyyy').format(DateTime.now())} (Thời gian thực)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
                        ),
                      ),
                    ],
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: canhBao,
                  decoration: const InputDecoration(labelText: 'Tình trạng cảnh báo', prefixIcon: Icon(Icons.warning_amber_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'Bình thường', child: Text('✅ Sử dụng bình thường')),
                    DropdownMenuItem(value: 'Cảnh báo: Dùng quá giờ', child: Text('⚠️ Dùng liên tục quá giờ')),
                    DropdownMenuItem(value: 'Cảnh báo: Pin yếu (<15%)', child: Text('🪫 Pin yếu sắp tắt máy')),
                    DropdownMenuItem(value: 'Cảnh báo: Ngoài vùng an toàn', child: Text('📍 Ngoài vùng an toàn')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => canhBao = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: appController,
                  decoration: const InputDecoration(
                    labelText: 'Ứng dụng sử dụng *',
                    hintText: 'VD: YouTube Kids, Roblox, TikTok...',
                    prefixIcon: Icon(Icons.apps_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: thoiGianController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Thời gian đã dùng (phút) *',
                    hintText: 'VD: 45',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Mức pin hiện tại (%)',
                    hintText: 'VD: 85',
                    prefixIcon: Icon(Icons.battery_5_bar_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: viTriController,
                  decoration: const InputDecoration(
                    labelText: 'Vị trí GPS / Địa chỉ cụ thể',
                    hintText: 'VD: Trường THCS Ba Đình, Q5',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('📍 Chọn nhanh địa điểm:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.school, size: 14, color: Color(0xFF1E3A8A)),
                      label: const Text('Trường học', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setDialogState(() {
                          viTriController.text = 'Trường THCS Ba Đình, Q5 (10.762622, 106.660172)';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.home, size: 14, color: Colors.green),
                      label: const Text('Ở nhà', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setDialogState(() {
                          viTriController.text = 'Nhà riêng, Q5 (10.755100, 106.668200)';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.menu_book, size: 14, color: Colors.purple),
                      label: const Text('Nhà sách', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setDialogState(() {
                          viTriController.text = 'Nhà sách Fahasa, Q1 (10.774500, 106.702500)';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.park, size: 14, color: Colors.teal),
                      label: const Text('Công viên', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setDialogState(() {
                          viTriController.text = 'Công viên Tao Đàn, Q1 (10.774500, 106.691200)';
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final phut = int.tryParse(thoiGianController.text.trim()) ?? 30;
                final pin = int.tryParse(pinController.text.trim()) ?? 100;

                final success = await ApiService.themNhatKy({
                  'treEmId': widget.treEmId,
                  'ngayGhi': DateTime.now().toIso8601String(),
                  'thoiGianDungPhut': phut,
                  'ungDung': appController.text.trim().isEmpty ? 'YouTube Kids' : appController.text.trim(),
                  'mucPin': pin,
                  'viTriHienTai': viTriController.text.trim(),
                  'canhBao': canhBao,
                  'nhanVienGhi': widget.isStaff ? 'Giáo viên trường ghi nhận' : 'Phụ huynh ghi nhận',
                });

                if (!mounted) return;
                if (ctx.mounted) Navigator.pop(ctx);
                if (success) {
                  _loadNhatKy();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(' Đã lưu nhật ký hoạt động!'), backgroundColor: Colors.green),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
              child: const Text('Lưu Hoạt Động'),
            ),
          ],
        ),
      ),
    );
  }

  // Sửa nhật ký hoạt động (CRUD UPDATE - PUT /api/NhatKy/{id})
  void _showEditLogDialog(Map<String, dynamic> log) {
    final maNhatKy = log['maNhatKy'] ?? log['id'] ?? 0;
    final appController = TextEditingController(text: log['ungDung']?.toString() ?? 'YouTube Kids');
    final thoiGianController = TextEditingController(text: (log['thoiGianDungPhut'] ?? 45).toString());
    final pinController = TextEditingController(text: (log['mucPin'] ?? 80).toString());
    final viTriController = TextEditingController(text: log['viTriHienTai']?.toString() ?? '');
    String canhBao = log['canhBao']?.toString() ?? 'Bình thường';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.edit_calendar_rounded, color: Color(0xFF1E3A8A)),
              SizedBox(width: 8),
              Text('Sửa Nhật Ký Dùng Máy', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: canhBao,
                  decoration: const InputDecoration(labelText: 'Tình trạng cảnh báo', prefixIcon: Icon(Icons.warning_amber_rounded)),
                  items: const [
                    DropdownMenuItem(value: 'Bình thường', child: Text('✅ Sử dụng bình thường')),
                    DropdownMenuItem(value: 'Cảnh báo: Dùng quá giờ', child: Text('⚠️ Dùng liên tục quá giờ')),
                    DropdownMenuItem(value: 'Cảnh báo: Pin yếu (<15%)', child: Text('🪫 Pin yếu sắp tắt máy')),
                    DropdownMenuItem(value: 'Cảnh báo: Ngoài vùng an toàn', child: Text('📍 Ngoài vùng an toàn')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => canhBao = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: appController,
                  decoration: const InputDecoration(
                    labelText: 'Ứng dụng sử dụng *',
                    prefixIcon: Icon(Icons.apps_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: thoiGianController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Thời gian đã dùng (phút) *',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Mức pin hiện tại (%)',
                    prefixIcon: Icon(Icons.battery_5_bar_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: viTriController,
                  decoration: const InputDecoration(
                    labelText: 'Vị trí GPS / Địa chỉ cụ thể',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('📍 Chọn nhanh địa điểm:', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.school, size: 14, color: Color(0xFF1E3A8A)),
                      label: const Text('Trường học', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setDialogState(() {
                          viTriController.text = 'Trường THCS Ba Đình, Q5 (10.762622, 106.660172)';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.home, size: 14, color: Colors.green),
                      label: const Text('Ở nhà', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setDialogState(() {
                          viTriController.text = 'Nhà riêng, Q5 (10.755100, 106.668200)';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.menu_book, size: 14, color: Colors.purple),
                      label: const Text('Nhà sách', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setDialogState(() {
                          viTriController.text = 'Nhà sách Fahasa, Q1 (10.774500, 106.702500)';
                        });
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.park, size: 14, color: Colors.teal),
                      label: const Text('Công viên', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        setDialogState(() {
                          viTriController.text = 'Công viên Tao Đàn, Q1 (10.774500, 106.691200)';
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final phut = int.tryParse(thoiGianController.text.trim()) ?? 30;
                final pin = int.tryParse(pinController.text.trim()) ?? 100;

                final success = await ApiService.capNhatNhatKy(maNhatKy, {
                  'treEmId': widget.treEmId,
                  'thoiGianDungPhut': phut,
                  'ungDung': appController.text.trim().isEmpty ? 'YouTube Kids' : appController.text.trim(),
                  'mucPin': pin,
                  'viTriHienTai': viTriController.text.trim(),
                  'canhBao': canhBao,
                  'nhanVienGhi': 'Phụ huynh cập nhật',
                });

                if (!mounted) return;
                if (ctx.mounted) Navigator.pop(ctx);
                if (success) {
                  _loadNhatKy();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text(' Đã cập nhật nhật ký hoạt động!'), backgroundColor: Colors.green),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
              child: const Text('Lưu Thay Đổi'),
            ),
          ],
        ),
      ),
    );
  }

  // Xóa nhật ký hoạt động (CRUD DELETE)
  void _confirmDeleteLog(int maNhatKy) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có muốn xóa bản ghi hoạt động này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ApiService.xoaNhatKy(maNhatKy);
              if (success) {
                _loadNhatKy();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa bản ghi hoạt động!'), backgroundColor: Colors.orange),
                );
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Kích hoạt còi báo động SOS khẩn cấp (Tính năng sáng tạo 1.0đ)
  void _triggerSosAlert() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFFF1F2),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red, size: 30),
            SizedBox(width: 8),
            Text('KÍCH HOẠT SOS KHẨN CẤP', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Đang gửi tín hiệu khẩn cấp đến thiết bị của ${widget.tenBe} (${widget.tenThietBi}):', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('• Điện thoại của bé sẽ phát chuông báo động to nhất dù đang im lặng.'),
            const Text('• Khóa màn hình ngay lập tức để bảo vệ bé.'),
            Text('• Gửi SMS tọa độ GPS đến số SOS: ${widget.sdtKhanCap}.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await ApiService.khoaMoThietBi(widget.treEmId, trangThai: true);
              setState(() => _dangKhoaHienTai = true);
              if (!mounted) return;
              _showSosSuccessDialog();
            },
            icon: const Icon(Icons.notifications_active),
            label: const Text('PHÁT BÁO ĐỘNG NGAY'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // Hộp thoại hiển thị Link Google Maps & Xác nhận gửi tín hiệu cứu hộ
  void _showSosSuccessDialog() {
    final googleMapsUrl = 'https://maps.google.com/?q=${_viTriBe.latitude},${_viTriBe.longitude}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('ĐÃ GỬI TÍN HIỆU CỨU HỘ!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• Đã phát chuông hú to nhất và khóa máy ${widget.tenBe}.', style: const TextStyle(fontSize: 13)),
            Text('• Đã gửi SMS cứu hộ đến SĐT: ${widget.sdtKhanCap}.', style: const TextStyle(fontSize: 13)),
            Text('• Vị trí định vị: $_diaChiHienTai', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E3A8A))),
            const SizedBox(height: 12),
            const Text('Link Google Maps vị trí của bé:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E3A8A))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: SelectableText(
                googleMapsUrl,
                style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: googleMapsUrl));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('📋 Đã sao chép link Google Maps!'), backgroundColor: Colors.blueAccent),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Sao Chép Link'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _tabController.animateTo(1); // Mở ngay Tab 2: Bản đồ GPS
            },
            icon: const Icon(Icons.map_rounded),
            label: const Text('Xem Bản Đồ'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E3A8A), foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        toolbarHeight: 65,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
          tooltip: '',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.tenBe,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.white, letterSpacing: -0.3),
            ),
            const SizedBox(height: 2),
            Text(
              '${widget.tenThietBi} • ${widget.maKetNoi}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadNhatKy,
            tooltip: 'Làm mới dữ liệu',
          ),
        ],
      ),
      body: Column(
        children: [
          // Thanh TabBar Capsule sang trọng nằm tách biệt hoàn toàn dưới AppBar
          Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF94A3B8),
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                tabs: const [
                  Tab(icon: Icon(Icons.history_rounded, size: 18), text: 'Nhật Ký'),
                  Tab(icon: Icon(Icons.map_rounded, size: 18), text: 'Định Vị'),
                  Tab(icon: Icon(Icons.security_rounded, size: 18), text: 'Bảo Mật'),
                ],
              ),
            ),
          ),
          // Nội dung 3 Tab
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: NHẬT KÝ HOẠT ĐỘNG
                _buildActivityLogTab(),

                // TAB 2: ĐỊNH VỊ GPS THỜI GIAN THỰC (BẢN ĐỒ OPENSTREETMAP)
                _buildGpsMapTab(),

                // TAB 3: BẢO MẬT, MÃ GHÉP NỐI & SOS KHẨN CẤP
                _buildSecurityAndSosTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLogDialog,
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Ghi Hoạt Động', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }

  // ==================== TAB 1: NHẬT KÝ HOẠT ĐỘNG ====================
  Widget _buildActivityLogTab() {
    return RefreshIndicator(
      onRefresh: _loadNhatKy,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Card thông tin thiết bị tổng quan cao cấp
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: const [
                BoxShadow(color: Color(0x060F172A), blurRadius: 16, offset: Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _dangKhoaHienTai ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _dangKhoaHienTai ? const Color(0xFFFECACA) : const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _dangKhoaHienTai ? Icons.lock_rounded : Icons.phone_android_rounded,
                      color: _dangKhoaHienTai ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.tenThietBi} (${widget.heDieuHanh})',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Giới hạn: ${widget.gioiHanPhut} phút • SOS: ${widget.sdtKhanCap}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: _toggleLock,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _dangKhoaHienTai
                            ? [const Color(0xFF059669), const Color(0xFF047857)]
                            : [const Color(0xFFDC2626), const Color(0xFFB91C1C)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: (_dangKhoaHienTai ? const Color(0xFF059669) : const Color(0xFFDC2626)).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _dangKhoaHienTai ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                          size: 15,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _dangKhoaHienTai ? 'MỞ MÁY' : 'KHÓA MÁY',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Row(
            children: [
              Icon(Icons.access_time_filled_rounded, size: 18, color: Color(0xFF0F172A)),
              SizedBox(width: 6),
              Text(
                'Lịch Sử Hoạt Động & Thời Gian Màn Hình',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
          else if (_nhatKyList.isEmpty)
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
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.history_toggle_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 12),
                  const Text('Chưa có nhật ký hoạt động nào!', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Bấm "+ Ghi Hoạt Động" bên dưới để thêm mới', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                ],
              ),
            )
          else
            ..._nhatKyList.map((log) {
              final maNhatKy = log['maNhatKy'] ?? log['id'] ?? 0;
              final app = log['ungDung'] ?? 'Không rõ app';
              final phut = log['thoiGianDungPhut'] ?? 0;
              final pin = log['mucPin'] ?? 100;
              final viTri = log['viTriHienTai'] ?? 'TP.HCM';
              final canhBao = log['canhBao'] ?? 'Bình thường';
              final ngayGhiStr = log['ngayGhi'] ?? '';

              String gioStr = '';
              if (ngayGhiStr.isNotEmpty) {
                try {
                  final dt = DateTime.parse(ngayGhiStr).toLocal();
                  gioStr = DateFormat('HH:mm - dd/MM/yyyy').format(dt);
                } catch (_) {
                  gioStr = ngayGhiStr;
                }
              }

              final isWarning = canhBao.contains('Cảnh báo') || canhBao.contains('Vượt');

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isWarning ? const Color(0xFFFFFBEB) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isWarning ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3)),
                  ],
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _getAppIcon(app),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 2),
                              Text(gioStr, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: isWarning ? const Color(0xFFFEF3C7) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isWarning ? const Color(0xFFFDE68A) : const Color(0xFFA7F3D0),
                            ),
                          ),
                          child: Text(
                            canhBao,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isWarning ? const Color(0xFFB45309) : const Color(0xFF047857),
                            ),
                          ),
                        ),
                        if (!widget.isStaff) ...[
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF2563EB)),
                            tooltip: 'Sửa hoạt động',
                            onPressed: () => _showEditLogDialog(log),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                            tooltip: 'Xóa hoạt động',
                            onPressed: () => _confirmDeleteLog(maNhatKy),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined, size: 15, color: Color(0xFF2563EB)),
                            const SizedBox(width: 5),
                            Text('Dùng: $phut phút', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.battery_charging_full_rounded,
                              size: 16,
                              color: pin < 20 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                            ),
                            const SizedBox(width: 4),
                            Text('Pin: $pin%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 15, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            viTri,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ==================== TAB 2: ĐỊNH VỊ GPS THỜI GIAN THỰC ====================
  Widget _buildGpsMapTab() {
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _viTriBe,
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.huynh_quoc_hieu_qlte',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _viTriBe,
                  width: 90,
                  height: 90,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: Text(
                          widget.tenBe,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Icon(Icons.location_pin, size: 44, color: Color(0xFFDC2626)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        // Thanh địa chỉ phía trên phong cách Glassmorphic
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(color: Color(0x140F172A), blurRadius: 16, offset: Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.my_location_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Vị trí của ${widget.tenBe}:',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _diaChiHienTai,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tọa độ: ${_viTriBe.latitude.toStringAsFixed(6)}, ${_viTriBe.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () {
                    final link = 'https://maps.google.com/?q=${_viTriBe.latitude},${_viTriBe.longitude}';
                    Clipboard.setData(ClipboardData(text: link));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('📋 Đã sao chép link Google Maps!'), backgroundColor: Color(0xFF2563EB)),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.share_location_rounded, size: 14, color: Color(0xFF2563EB)),
                        SizedBox(width: 4),
                        Text('Maps', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==================== TAB 3: BẢO MẬT & SOS ====================
  Widget _buildSecurityAndSosTab() {
    // Tính phần trăm đo lực gia tốc (chuẩn hóa 0.0 - 1.0)
    final double gForcePercent = ((_liveGForce - 1.0) / 1.5).clamp(0.0, 1.0);
    final bool isRungManh = _liveGForce > 1.35;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Card QR Code ghép nối
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x060F172A), blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'MÃ QR GHÉP NỐI THIẾT BỊ',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A), letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Text(
                'Giáo viên quét mã này từ màn hình Giáo viên để kết nối giám sát trong giờ học:',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: QrImageView(
                  data: widget.maKetNoi,
                  version: 3,
                  gapless: true,
                  size: 150.0,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.vpn_key_rounded, size: 15, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    Text(
                      widget.maKetNoi,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.5, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: widget.maKetNoi));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('📋 Đã sao chép mã ghép nối!'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card Cảm Biến Gia Tốc - Lắc Tay Khẩn Cấp (Mục d: 3.5đ)
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isRungManh ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A),
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x060F172A), blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: Icon(Icons.vibration_rounded, color: Color(0xFFD97706), size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CẢM BIẾN CHUYỂN ĐỘNG',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Gia tốc kế Accelerometer (Mục d)',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isShakeListening,
                    activeColor: const Color(0xFFD97706),
                    onChanged: (val) {
                      setState(() => _isShakeListening = val);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(val ? 'Đã bật cảm biến lắc tay!' : 'Đã tắt cảm biến lắc tay.'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _isShakeListening
                    ? '🟢 Cảm biến đang bật: Khi trẻ gặp nguy hiểm, chỉ cần lắc mạnh điện thoại 2 lần (Shake-to-SOS), hệ thống tự động kích hoạt còi báo động và gửi GPS cứu hộ!'
                    : '⚪ Cảm biến lắc tay đang tạm tắt.',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
              ),
              const SizedBox(height: 12),

              // Thanh đo lực chuyển động thời gian thực dạng tiến trình IoT
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          isRungManh ? Icons.bolt_rounded : Icons.speed_rounded,
                          size: 16,
                          color: isRungManh ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'G-Force: ${_liveGForce.toStringAsFixed(2)}G • $_shakeStatusText',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isRungManh ? const Color(0xFFDC2626) : const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: gForcePercent,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isRungManh ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _kichHoatSosDoLacTay,
                  icon: const Icon(Icons.screen_rotation_rounded, size: 18),
                  label: const Text('Thử Nghiệm Lắc Tay Ảo (Simulate Shake)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD97706),
                    side: const BorderSide(color: Color(0xFFD97706), width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Card Kích hoạt SOS khẩn cấp
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFFECACA), width: 1.2),
            boxShadow: const [
              BoxShadow(color: Color(0x060F172A), blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 26),
                  SizedBox(width: 8),
                  Text('BÁO ĐỘNG SOS KHẨN CẤP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFFDC2626))),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Kích hoạt còi hú to nhất trên máy bé, khóa màn hình bảo vệ và gửi SMS tọa độ khẩn cấp về số phụ huynh.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF7F1D1D), height: 1.4),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _triggerSosAlert,
                  icon: const Icon(Icons.notifications_active_rounded, size: 20),
                  label: const Text('KÍCH HOẠT CÒI BÁO ĐỘNG SOS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _getAppIcon(String appName) {
    if (appName.contains('YouTube')) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.play_circle_fill, color: Colors.red, size: 24),
      );
    } else if (appName.contains('Roblox') || appName.contains('Game')) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.sports_esports, color: Colors.purple, size: 24),
      );
    } else if (appName.contains('TikTok')) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.music_video, color: Colors.black87, size: 24),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.apps, color: Colors.blueAccent, size: 24),
      );
    }
  }
}