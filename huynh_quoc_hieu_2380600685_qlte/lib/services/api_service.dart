import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  // Lấy token đã lưu
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // Lấy vai trò đã lưu (Admin / NhanVien / PhuHuynh)
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  // Lấy username hiện tại
  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('username');
  }

  // Đăng xuất
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_role');
    await prefs.remove('username');
  }

  // ==================== 1. XÁC THỰC & ĐĂNG NHẬP 2FA ====================

  // Đăng nhập bước 1: Kiểm tra mật khẩu (Admin vào thẳng, người khác nhận OTP)
  static Future<Map<String, dynamic>> login(String username, String matKhau) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tenDangNhap': username, // Khớp đúng với C# Backend
          'matKhau': matKhau,
        }),
      );

      final data = jsonDecode(response.body);

      // Nếu là Admin đăng nhập thẳng (không cần OTP), tự lưu Token luôn
      if (response.statusCode == 200 && data['requiresOtp'] == false) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['token'] ?? '');
        await prefs.setString('user_role', data['vaiTro'] ?? data['role'] ?? 'Admin');
        await prefs.setString('username', data['username'] ?? username);
      }

      return {
        'statusCode': response.statusCode,
        'data': data,
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'message': 'Lỗi kết nối máy chủ: $e',
      };
    }
  }

  // Đăng nhập bước 2: Xác thực OTP và lưu Token + Role
  static Future<Map<String, dynamic>> verifyOtp(String username, String otpCode) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.verifyOtpUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tenDangNhap': username, // Khớp đúng với C# Backend
          'maOtp': otpCode,        // Khớp đúng với C# Backend
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['status'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', data['token'] ?? '');
        await prefs.setString('user_role', data['vaiTro'] ?? data['role'] ?? '');
        await prefs.setString('username', data['username'] ?? username);
      }

      return {
        'statusCode': response.statusCode,
        'data': data,
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'message': 'Lỗi xác thực OTP: $e',
      };
    }
  }

  // Đăng ký tài khoản qua Email
  static Future<Map<String, dynamic>> register({
    required String hoTen,
    required String username,
    required String email,
    required String matKhau,
    required String vaiTro,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.registerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'hoTen': hoTen,
          'tenDangNhap': username,
          'email': email,
          'matKhau': matKhau,
          'vaiTro': vaiTro,
        }),
      );

      return {
        'statusCode': response.statusCode,
        'data': jsonDecode(response.body),
      };
    } catch (e) {
      return {
        'statusCode': 500,
        'message': 'Lỗi đăng ký: $e',
      };
    }
  }

  // ==================== 2. QUẢN LÝ THIẾT BỊ TRẺ EM (CRUD 4.5đ) ====================

  // Lấy danh sách thiết bị bé
  static Future<List<dynamic>> getDanhSachTreEm() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.treEmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('data')) {
          return decoded['data'] as List<dynamic>;
        } else if (decoded is List) {
          return decoded;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Thêm thiết bị / bé mới
  static Future<bool> themTreEm(Map<String, dynamic> data) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.treEmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // Cập nhật thông tin thiết bị / bé
  static Future<bool> capNhatTreEm(int id, Map<String, dynamic> data) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse("${ApiConfig.treEmUrl}/$id"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Khóa / Mở khóa thiết bị từ xa (Chức năng sáng tạo 1.0đ)
  static Future<bool> khoaMoThietBi(int id, {bool? trangThai}) async {
    try {
      final token = await getToken();
      String url = "${ApiConfig.treEmUrl}/$id/khoa-thiet-bi";
      if (trangThai != null) {
        url += "?trangThai=$trangThai";
      }
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Xóa hồ sơ thiết bị bé
  static Future<bool> xoaTreEm(int id) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse("${ApiConfig.treEmUrl}/$id"),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==================== 3. QUẢN LÝ NHẬT KÝ HOẠT ĐỘNG (CRUD 4.5đ) ====================

  // Lấy nhật ký hoạt động theo mã bé
  static Future<List<dynamic>> getNhatKyTheoTreEm(int treEmId) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse("${ApiConfig.nhatKyUrl}/tre-em/$treEmId"),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded.containsKey('data')) {
          return decoded['data'] as List<dynamic>;
        } else if (decoded is List) {
          return decoded;
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Thêm nhật ký hoạt động mới
  static Future<bool> themNhatKy(Map<String, dynamic> data) async {
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.nhatKyUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // Cập nhật / Sửa nhật ký hoạt động (PUT /api/NhatKy/{id})
  static Future<bool> capNhatNhatKy(int maNhatKy, Map<String, dynamic> data) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse("${ApiConfig.nhatKyUrl}/$maNhatKy"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Xóa nhật ký hoạt động
  static Future<bool> xoaNhatKy(int maNhatKy) async {
    try {
      final token = await getToken();
      final response = await http.delete(
        Uri.parse("${ApiConfig.nhatKyUrl}/$maNhatKy"),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==================== 4. DÀNH CHO ADMIN (QUẢN LÝ TÀI KHOẢN) ====================

  // Lấy danh sách tài khoản trực tiếp từ SQL Server (100% đồng bộ 2 chiều với Swagger)
  static Future<List<dynamic>> getDanhSachUsers() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.usersUrl));
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
        for (var u in list) {
          if (u is Map) {
            final uname = (u['userName'] ?? '').toString().toLowerCase();
            bool needHeal = false;
            if ((u['email'] ?? '') == 'string' || (u['email'] ?? '').toString().isEmpty) {
              u['email'] = uname == 'hieuhq1'
                  ? 'hieu2380600685@gmail.com'
                  : uname == 'hieuhq'
                      ? 'quochieu4622@gmail.com'
                      : '$uname@gmail.com';
              needHeal = true;
            }
            if ((u['vaiTro'] ?? '') == 'string' || (u['vaiTro'] ?? '').toString().isEmpty) {
              u['vaiTro'] = uname == 'admin'
                  ? 'Admin'
                  : uname == 'hieuhq1'
                      ? 'NhanVien'
                      : 'PhuHuynh';
              needHeal = true;
            }
            if (needHeal) {
              http.put(
                Uri.parse("${ApiConfig.usersUrl}/${u['userName']}"),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'hoTen': u['hoTen'],
                  'email': u['email'],
                  'vaiTro': u['vaiTro'],
                }),
              );
            }
          }
        }
        return list;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Admin sửa thông tin tài khoản (PUT /api/Authenticate/users/{username})
  static Future<bool> capNhatUser(String username, Map<String, dynamic> data) async {
    try {
      final token = await getToken();
      final response = await http.put(
        Uri.parse("${ApiConfig.usersUrl}/$username"),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Admin xóa tài khoản
  static Future<bool> xoaUser(String username) async {
    try {
      final response = await http.delete(
        Uri.parse("${ApiConfig.usersUrl}/$username"),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // ==================== 5. LIÊN KẾT GIÁO VIÊN <-> THIẾT BỊ BÉ QUA MÃ PAIR ====================

  // Kiểm tra thiết bị bé đã kết nối với Giáo viên chưa (Hỗ trợ nhiều Giáo viên cùng kết nối 1 máy)
  static bool daKetNoiGiaoVien(Map<String, dynamic> be, {String? gvUsername}) {
    final raw = (be['hinhAnh'] ?? '').toString();
    if (!raw.startsWith('GV:')) return false;
    final afterPrefix = raw.substring(3);
    final entries = afterPrefix.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (entries.isEmpty) return false;
    if (gvUsername == null || gvUsername.isEmpty) return true;

    for (var entry in entries) {
      final parts = entry.split('|');
      if (parts.first.toLowerCase() == gvUsername.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  // Lấy danh sách tên Giáo viên đang kết nối với máy của bé
  static String layTenGiaoVienKetNoi(Map<String, dynamic> be) {
    final raw = (be['hinhAnh'] ?? '').toString();
    if (!raw.startsWith('GV:')) return 'Chưa kết nối Giáo viên';
    final afterPrefix = raw.substring(3);
    final entries = afterPrefix.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (entries.isEmpty) return 'Chưa kết nối Giáo viên';

    final names = <String>[];
    for (var entry in entries) {
      final parts = entry.split('|');
      if (parts.length > 1 && parts[1].trim().isNotEmpty) {
        names.add('${parts[1]} (@${parts[0]})');
      } else {
        names.add(parts[0]);
      }
    }
    return names.join(', ');
  }

  // Kết nối hoặc Ngắt kết nối Giáo viên với máy của bé (Hỗ trợ nhiều Giáo viên kết nối cùng 1 máy)
  static Future<bool> capNhatKetNoiGiaoVien({
    required Map<String, dynamic> be,
    required bool ketNoi,
    String gvUsername = 'hieuhq1',
    String gvHoTen = 'Huỳnh Quốc Huy',
  }) async {
    final int id = be['id'] ?? 0;
    final raw = (be['hinhAnh'] ?? '').toString();

    final List<Map<String, String>> gvList = [];
    if (raw.startsWith('GV:')) {
      final afterPrefix = raw.substring(3);
      final entries = afterPrefix.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty);
      for (var entry in entries) {
        final parts = entry.split('|');
        if (parts.isNotEmpty && parts[0].isNotEmpty) {
          gvList.add({
            'username': parts[0],
            'hoten': parts.length > 1 ? parts[1] : parts[0],
          });
        }
      }
    }

    if (ketNoi) {
      final exists = gvList.any((g) => g['username']!.toLowerCase() == gvUsername.toLowerCase());
      if (!exists) {
        gvList.add({'username': gvUsername, 'hoten': gvHoTen});
      }
    } else {
      gvList.removeWhere((g) => g['username']!.toLowerCase() == gvUsername.toLowerCase());
    }

    final String hinhAnhMoi = gvList.isEmpty
        ? 'CHUA_KET_NOI'
        : 'GV:${gvList.map((g) => '${g['username']}|${g['hoten']}').join(';')}';

    return await capNhatTreEm(id, {
      'hoTen': be['hoTen'] ?? 'Bé',
      'tenThietBi': be['tenThietBi'] ?? 'Samsung Galaxy',
      'heDieuHanh': be['heDieuHanh'] ?? 'Android',
      'gioiHanPhut': be['gioiHanPhut'] ?? 120,
      'dangKhoa': be['dangKhoa'] ?? false,
      'sdtKhanCap': be['sdtKhanCap'] ?? '0909123456',
      'maKetNoi': be['maKetNoi'] ?? 'PAIR-1001',
      'hinhAnh': hinhAnhMoi,
      'phuHuynhId': be['phuHuynhId'] ?? 'c43c2bee-fdeb-4c14-9033-14d8ebb3b634',
    });
  }
}