using System;
using System.Collections.Generic;

namespace AmbulanceAPI.Models;

public partial class User
{
    public int Id { get; set; }

    public string? Username { get; set; }

    public string? PasswordHash { get; set; }

    public string? DeviceId { get; set; }

    public string UserType { get; set; } = null!;

    public string? AccountStatus { get; set; }

    public string? FcmToken { get; set; }

    public decimal? Latitude { get; set; }

    public decimal? Longitude { get; set; }

    public DateTime? LastLocationUpdate { get; set; }

    public DateTime? CreatedAt { get; set; }
}
