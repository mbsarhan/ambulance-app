using System;
using System.Collections.Generic;
using AmbulanceAPI.Models;
using Microsoft.EntityFrameworkCore;
using Pomelo.EntityFrameworkCore.MySql.Scaffolding.Internal;

namespace AmbulanceAPI.Data;

public partial class AppDbContext : DbContext
{
    public AppDbContext()
    {
    }

    public AppDbContext(DbContextOptions<AppDbContext> options)
        : base(options)
    {
    }

    public virtual DbSet<Appsetting> Appsettings { get; set; }

    public virtual DbSet<User> Users { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder
            .UseCollation("utf8mb4_general_ci")
            .HasCharSet("utf8mb4");

        modelBuilder.Entity<Appsetting>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PRIMARY");

            entity.ToTable("appsettings");

            entity.Property(e => e.Id).HasColumnType("int(11)");
            entity.Property(e => e.AlertRadiusMeters)
                .HasDefaultValueSql("'1000'")
                .HasColumnType("int(11)");
            entity.Property(e => e.LastUpdated)
                .HasDefaultValueSql("current_timestamp()")
                .HasColumnType("datetime");
        });

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PRIMARY");

            entity.ToTable("users");

            entity.HasIndex(e => e.DeviceId, "DeviceId").IsUnique();

            entity.HasIndex(e => e.Username, "Username").IsUnique();

            entity.HasIndex(e => e.AccountStatus, "idx_status");

            entity.HasIndex(e => e.UserType, "idx_user_type");

            entity.Property(e => e.Id).HasColumnType("int(11)");
            entity.Property(e => e.AccountStatus)
                .HasDefaultValueSql("'Active'")
                .HasColumnType("enum('Pending','Active','Rejected')");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("current_timestamp()")
                .HasColumnType("datetime");
            entity.Property(e => e.DeviceId).HasMaxLength(100);
            entity.Property(e => e.FcmToken).HasMaxLength(255);
            entity.Property(e => e.LastLocationUpdate).HasColumnType("datetime");
            entity.Property(e => e.Latitude).HasPrecision(10, 8);
            entity.Property(e => e.Longitude).HasPrecision(11, 8);
            entity.Property(e => e.PasswordHash).HasMaxLength(255);
            entity.Property(e => e.UserType).HasColumnType("enum('Regular','Ambulance')");
            entity.Property(e => e.Username).HasMaxLength(50);
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
