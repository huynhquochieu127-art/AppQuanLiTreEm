using HuynhQuocHieu_NhomHHCC.Models;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// 1. Cấu hình DbContext kết nối SQL Server HuynhQuocHieu_API
builder.Services.AddDbContext<ApplicationDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// 2. Cấu hình Identity
builder.Services.AddIdentity<User, IdentityRole>(options =>
{
    options.Password.RequireDigit = false;
    options.Password.RequireLowercase = false;
    options.Password.RequireUppercase = false;
    options.Password.RequireNonAlphanumeric = false;
    options.Password.RequiredLength = 4;
})
.AddEntityFrameworkStores<ApplicationDbContext>()
.AddDefaultTokenProviders();

// 3. Cấu hình JWT Token
var jwtSettings = builder.Configuration.GetSection("JWTKey");
var key = Encoding.UTF8.GetBytes(jwtSettings["Secret"] ?? "ChuoiKhoaMacDinhBaoMat12345678901234567890!");

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtSettings["ValidIssuer"],
        ValidAudience = jwtSettings["ValidAudience"],
        IssuerSigningKey = new SymmetricSecurityKey(key)
    };
});

builder.Services.AddAuthorization();

// 4. Cấu hình CORS
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

// 5. Cấu hình Swagger
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "App Quản Lý Trẻ Em API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "Nhập: Bearer {token}",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

var app = builder.Build();

// 6. Tự động tạo Role & 3 Tài khoản mẫu (Admin, NhanVien, PhuHuynh)
using (var scope = app.Services.CreateScope())
{
    var services = scope.ServiceProvider;
    try
    {
        var roleManager = services.GetRequiredService<RoleManager<IdentityRole>>();
        var userManager = services.GetRequiredService<UserManager<User>>();

        string[] roles = { "Admin", "NhanVien", "PhuHuynh" };
        foreach (var role in roles)
        {
            if (!await roleManager.RoleExistsAsync(role))
            {
                await roleManager.CreateAsync(new IdentityRole(role));
            }
        }

        // Tạo tài khoản Admin
        if (await userManager.FindByNameAsync("admin") == null)
        {
            var adminUser = new User
            {
                UserName = "admin",
                Email = "admin@childcare.com",
                HoTen = "Quản Trị Viên Hệ Thống",
                VaiTro = "Admin"
            };
            await userManager.CreateAsync(adminUser, "Admin@123");
            await userManager.AddToRoleAsync(adminUser, "Admin");
        }

        // Tạo tài khoản Nhân viên (Bảo mẫu/Giáo viên)
        if (await userManager.FindByNameAsync("nhanvien") == null)
        {
            var staffUser = new User
            {
                UserName = "nhanvien",
                Email = "nhanvien@childcare.com",
                HoTen = "Cô Giáo Mai Lan",
                VaiTro = "NhanVien"
            };
            await userManager.CreateAsync(staffUser, "NhanVien@123");
            await userManager.AddToRoleAsync(staffUser, "NhanVien");
        }

        // Tạo tài khoản Phụ huynh
        if (await userManager.FindByNameAsync("phuhuynh") == null)
        {
            var parentUser = new User
            {
                UserName = "phuhuynh",
                Email = "phuhuynh@gmail.com",
                HoTen = "Nguyễn Văn Hùng (Bố bé)",
                VaiTro = "PhuHuynh"
            };
            await userManager.CreateAsync(parentUser, "PhuHuynh@123");
            await userManager.AddToRoleAsync(parentUser, "PhuHuynh");
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine("Lỗi Seed Data: " + ex.Message);
    }
}

// 7. Pipeline HTTP
app.UseSwagger();
app.UseSwaggerUI();

app.UseHttpsRedirection();

app.UseCors("AllowAll");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();