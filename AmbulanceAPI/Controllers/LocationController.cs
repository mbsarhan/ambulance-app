using AmbulanceAPI.Data;
using AmbulanceAPI.Dtos;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace AmbulanceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    [Authorize] // 🔒 Requires JWT Token
    public class LocationController : ControllerBase
    {
        private readonly AppDbContext _context;

        public LocationController(AppDbContext context)
        {
            _context = context;
        }

        [HttpPost("update")]
        public async Task<IActionResult> UpdateLocation([FromBody] LocationUpdateDto data)
        {
            var userIdStr = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdStr == null) return Unauthorized();

            var userId = int.Parse(userIdStr);
            var user = await _context.Users.FindAsync(userId);
            if (user == null) return NotFound();

            // 1. Update Location
            user.Latitude = (decimal)data.Latitude;
            user.Longitude = (decimal)data.Longitude;
            user.LastLocationUpdate = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            // 2. Get Alert Radius
            var settings = await _context.Appsettings.FirstOrDefaultAsync();
            double radiusMeters = settings?.AlertRadiusMeters ?? 1000;

            // ============================================================
            // SCENARIO A: I am an AMBULANCE
            // ============================================================
            if (user.UserType == "Ambulance")
            {
                // Find Regular Users nearby to count them
                var nearbyUsers = await CheckForProximity((double)user.Latitude.Value, (double)user.Longitude.Value, radiusMeters);
                return Ok(new { message = "Location updated", nearbyUsersCount = nearbyUsers.Count });
            }

            // ============================================================
            // SCENARIO B: I am a REGULAR USER (New Logic!)
            // ============================================================
            else
            {
                // Check if any AMBULANCE is near me
                bool isAmbulanceNear = await CheckForAmbulancesNearMe((double)user.Latitude.Value, (double)user.Longitude.Value, radiusMeters);

                return Ok(new
                {
                    message = "Location updated",
                    alert = isAmbulanceNear, // <--- Crucial Flag
                    alertMessage = isAmbulanceNear ? "AMBULANCE APPROACHING!" : ""
                });
            }
        }

        // Helper 1: Find Users (Existing)
        private async Task<List<string>> CheckForProximity(double lat, double lon, double radius)
        {
            var activeUsers = await _context.Users
                .Where(u => u.UserType == "Regular" && u.Latitude != null && u.Longitude != null)
                .ToListAsync();

            var list = new List<string>();
            foreach (var u in activeUsers)
            {
                if (GetDistance(lat, lon, (double)u.Latitude!, (double)u.Longitude!) <= radius)
                    list.Add(u.Id.ToString());
            }
            return list;
        }

        // Helper 2: Find Ambulances (New)
        private async Task<bool> CheckForAmbulancesNearMe(double myLat, double myLon, double radius)
        {
            // Only look for ambulances active in the last 5 minutes
            var activeAmbulances = await _context.Users
                .Where(u => u.UserType == "Ambulance"
                            && u.Latitude != null
                            && u.Longitude != null
                            && u.LastLocationUpdate > DateTime.UtcNow.AddMinutes(-5))
                .ToListAsync();

            foreach (var amb in activeAmbulances)
            {
                double distance = GetDistance(myLat, myLon, (double)amb.Latitude!, (double)amb.Longitude!);
                if (distance <= radius)
                {
                    return true; // Found one!
                }
            }
            return false;
        }

        // Keep your GetDistance method...

        // Haversine Formula to calculate distance in Meters
        private double GetDistance(double lat1, double lon1, double lat2, double lon2)
        {
            var R = 6371e3; // Earth radius in meters
            var φ1 = lat1 * Math.PI / 180;
            var φ2 = lat2 * Math.PI / 180;
            var Δφ = (lat2 - lat1) * Math.PI / 180;
            var Δλ = (lon2 - lon1) * Math.PI / 180;

            var a = Math.Sin(Δφ / 2) * Math.Sin(Δφ / 2) +
                    Math.Cos(φ1) * Math.Cos(φ2) *
                    Math.Sin(Δλ / 2) * Math.Sin(Δλ / 2);
            var c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));

            return R * c; // Distance in meters
        }
    }
}