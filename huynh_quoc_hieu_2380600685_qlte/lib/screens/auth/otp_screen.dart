import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../admin/admin_screen.dart';
import '../staff/staff_screen.dart';
import '../parent/parent_screen.dart';

class OtpScreen extends StatefulWidget {
  final String username;
  final String email;

  const OtpScreen({
    super.key,
    required this.username,
    required this.email,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  // Ô nhập luôn luôn để trống, người dùng phải xem mã trong Gmail và tự gõ vào
  final _otpController = TextEditingController();
  bool _isLoading = false;

  void _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đủ 6 chữ số mã OTP từ Gmail!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final res = await ApiService.verifyOtp(widget.username, otp);

    setState(() => _isLoading = false);

    if (res['statusCode'] == 200 && res['data']?['status'] == true) {
      // Đọc cả vaiTro và role để luôn chuẩn xác 100%
      final role = (res['data']?['vaiTro'] ?? res['data']?['role'] ?? '').toString();

      if (!mounted) return;

      // ==================== PHÂN QUYỀN 3 VAI TRÒ (Mục 3) ====================
      if (role.toLowerCase() == 'admin') {
        // 1. Quản trị viên
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AdminScreen()),
              (route) => false,
        );
      } else if (role.toLowerCase() == 'nhanvien') {
        // 2. Giáo viên / Nhân viên (hieuhq1 sẽ vào đây)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const StaffScreen()),
              (route) => false,
        );
      } else {
        // 3. Phụ huynh (hieuhq sẽ vào đây)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ParentScreen()),
              (route) => false,
        );
      }
    } else {
      if (!mounted) return;
      final msg = res['data']?['message'] ?? res['message'] ?? 'Mã OTP không chính xác hoặc đã hết hạn!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Xác thực OTP (2FA)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            child: Column(
              children: [
                // Icon hộp thư Squircle cao cấp
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.mark_email_read_rounded,
                      size: 42,
                      color: Color(0xFF059669),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Kiểm Tra Hộp Thư Email',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Mã xác thực bảo mật 6 số đã được gửi đến email:',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    widget.email.isNotEmpty ? widget.email : widget.username,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1D4ED8),
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Card nhập OTP
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x080F172A),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(26.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Nhập Mã OTP 6 Số',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Ô nhập 6 số OTP (Trống trơn)
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 12,
                          color: Color(0xFF1D4ED8),
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '••••••',
                          hintStyle: const TextStyle(letterSpacing: 10, color: Color(0xFFCBD5E1)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer_outlined, size: 14, color: Color(0xFF94A3B8)),
                          SizedBox(width: 4),
                          Text(
                            'Mã có hiệu lực trong vòng 5 phút',
                            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Nút Xác nhận Gradient
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleVerifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Xác Nhận & Vào Ứng Dụng',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}