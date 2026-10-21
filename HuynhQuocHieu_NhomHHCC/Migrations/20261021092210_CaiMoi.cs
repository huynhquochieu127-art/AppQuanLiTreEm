using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace HuynhQuocHieu_NhomHHCC.Migrations
{
    /// <inheritdoc />
    public partial class CaiMoi : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DailyLogs");

            migrationBuilder.DropTable(
                name: "Children");

            migrationBuilder.RenameColumn(
                name: "Role",
                table: "AspNetUsers",
                newName: "VaiTro");

            migrationBuilder.RenameColumn(
                name: "OtpExpiryTime",
                table: "AspNetUsers",
                newName: "HanOtp");

            migrationBuilder.RenameColumn(
                name: "OtpCode",
                table: "AspNetUsers",
                newName: "MaOtp");

            migrationBuilder.RenameColumn(
                name: "FullName",
                table: "AspNetUsers",
                newName: "HoTen");

            migrationBuilder.CreateTable(
                name: "TreEms",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    HoTen = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    NgaySinh = table.Column<DateTime>(type: "datetime2", nullable: false),
                    GioiTinh = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    NhomMau = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    DiUng = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    SdtKhanCap = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    LopHoc = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    HinhAnh = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    PhuHuynhId = table.Column<string>(type: "nvarchar(450)", nullable: true),
                    NgayTao = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TreEms", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TreEms_AspNetUsers_PhuHuynhId",
                        column: x => x.PhuHuynhId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "NhatKySinhHoats",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    TreEmId = table.Column<int>(type: "int", nullable: false),
                    NgayGhi = table.Column<DateTime>(type: "datetime2", nullable: false),
                    BuaAn = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    GiacNgu = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    ThanNhiet = table.Column<double>(type: "float", nullable: false),
                    GhiChuSucKhoe = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    NhanVienGhi = table.Column<string>(type: "nvarchar(max)", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_NhatKySinhHoats", x => x.Id);
                    table.ForeignKey(
                        name: "FK_NhatKySinhHoats_TreEms_TreEmId",
                        column: x => x.TreEmId,
                        principalTable: "TreEms",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_NhatKySinhHoats_TreEmId",
                table: "NhatKySinhHoats",
                column: "TreEmId");

            migrationBuilder.CreateIndex(
                name: "IX_TreEms_PhuHuynhId",
                table: "TreEms",
                column: "PhuHuynhId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "NhatKySinhHoats");

            migrationBuilder.DropTable(
                name: "TreEms");

            migrationBuilder.RenameColumn(
                name: "VaiTro",
                table: "AspNetUsers",
                newName: "Role");

            migrationBuilder.RenameColumn(
                name: "MaOtp",
                table: "AspNetUsers",
                newName: "OtpCode");

            migrationBuilder.RenameColumn(
                name: "HoTen",
                table: "AspNetUsers",
                newName: "FullName");

            migrationBuilder.RenameColumn(
                name: "HanOtp",
                table: "AspNetUsers",
                newName: "OtpExpiryTime");

            migrationBuilder.CreateTable(
                name: "Children",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ParentId = table.Column<string>(type: "nvarchar(450)", nullable: true),
                    Allergies = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    AvatarUrl = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    BloodType = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    ClassRoom = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    DateOfBirth = table.Column<DateTime>(type: "datetime2", nullable: false),
                    EmergencyContact = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    FullName = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Gender = table.Column<string>(type: "nvarchar(max)", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Children", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Children_AspNetUsers_ParentId",
                        column: x => x.ParentId,
                        principalTable: "AspNetUsers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "DailyLogs",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ChildId = table.Column<int>(type: "int", nullable: false),
                    HealthNotes = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    LogDate = table.Column<DateTime>(type: "datetime2", nullable: false),
                    MealStatus = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    SleepStatus = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    StaffId = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    Temperature = table.Column<double>(type: "float", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DailyLogs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DailyLogs_Children_ChildId",
                        column: x => x.ChildId,
                        principalTable: "Children",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Children_ParentId",
                table: "Children",
                column: "ParentId");

            migrationBuilder.CreateIndex(
                name: "IX_DailyLogs_ChildId",
                table: "DailyLogs",
                column: "ChildId");
        }
    }
}
