class ApiConfig {
  // Link Conveyor Internet toàn cầu của bạn (Bật 4G hay Wifi ở đâu cũng chạy được)
  static const String baseUrl = "https://representation-partners-receives-abilities.trycloudflare.com";

  // API Xác thực & Tài khoản
  static const String loginUrl = "$baseUrl/api/Authenticate/login";
  static const String verifyOtpUrl = "$baseUrl/api/Authenticate/verify-otp";
  static const String registerUrl = "$baseUrl/api/Authenticate/register";
  static const String usersUrl = "$baseUrl/api/Authenticate/users";
  // API Nghiệp vụ Trẻ Em & Nhật Ký
  static const String treEmUrl = "$baseUrl/api/TreEm";
  static const String nhatKyUrl = "$baseUrl/api/NhatKy";
}