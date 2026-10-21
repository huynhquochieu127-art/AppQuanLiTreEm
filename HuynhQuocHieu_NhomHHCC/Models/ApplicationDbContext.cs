using HuynhQuocHieu_NhomHHCC.Models;
using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace HuynhQuocHieu_NhomHHCC.Models
{
    public class ApplicationDbContext : IdentityDbContext<User>
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options)
        {
        }

        public DbSet<TreEm> TreEms { get; set; }
        public DbSet<NhatKySinhHoat> NhatKySinhHoats { get; set; }

        protected override void OnModelCreating(ModelBuilder builder)
        {
            base.OnModelCreating(builder);

            builder.Entity<TreEm>()
                .HasOne(t => t.PhuHuynh)
                .WithMany()
                .HasForeignKey(t => t.PhuHuynhId)
                .OnDelete(DeleteBehavior.SetNull);

            builder.Entity<NhatKySinhHoat>()
                .HasOne(n => n.TreEm)
                .WithMany()
                .HasForeignKey(n => n.TreEmId)
                .OnDelete(DeleteBehavior.Cascade);
        }
    }
}