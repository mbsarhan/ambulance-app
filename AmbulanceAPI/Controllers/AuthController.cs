using AmbulanceAPI.Data;
using AmbulanceAPI.Dtos;
using AmbulanceAPI.Models; // Use your Scaffolded Model namespace
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using BCrypt.Net;

namespace AmbulanceAPI.Controllers
{
    [Route("api/[controller]")]
    [ApiController]
    public class AuthController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly IConfiguration _configuration;

        public AuthController(AppDbContext context, IConfiguration configuration)
        {
            _context = context;
            _configuration = configuration;
        }

        // 1. Regular User "Login/Register"
        [HttpPost("guest-login")]
        public async Task<IActionResult> GuestLogin([FromBody] RegisterGuestDto request)
        {
            // Check if device already exists
            var user = await _context.Users.FirstOrDefaultAsync(u => u.DeviceId == request.DeviceId);

            if (user == null)
            {
                // Create new Regular User
                user = new User
                {
                    DeviceId = request.DeviceId,
                    UserType = "Regular",
                    AccountStatus = "Active",
                    FcmToken = request.FcmToken,
                    CreatedAt = DateTime.UtcNow
                };
                _context.Users.Add(user);
            }
            else
            {
                // Update existing user's token
                user.FcmToken = request.FcmToken;
                user.LastLocationUpdate = DateTime.UtcNow; // Mark as active
            }

            await _context.SaveChangesAsync();

            var token = GenerateJwtToken(user);
            return Ok(new AuthResponseDto { Token = token, UserType = "Regular", Status = "Active" });
        }

        // 2. Ambulance Driver Login
        [HttpPost("driver-login")]
        public async Task<IActionResult> DriverLogin([FromBody] LoginDriverDto request)
        {
            var user = await _context.Users.FirstOrDefaultAsync(u => u.Username == request.Username);

            // Check if user exists and password is correct
            // Note: We use BCrypt.Verify to check the password against the hash
            if (user == null || user.UserType != "Ambulance" || !BCrypt.Net.BCrypt.Verify(request.Password, user.PasswordHash))
            {
                return Unauthorized("Invalid username or password.");
            }

            if (user.AccountStatus != "Active")
            {
                return Unauthorized($"Your account is currently {user.AccountStatus}. Please contact Admin.");
            }

            // Update FCM Token
            user.FcmToken = request.FcmToken;
            await _context.SaveChangesAsync();

            var token = GenerateJwtToken(user);
            return Ok(new AuthResponseDto { Token = token, UserType = "Ambulance", Status = "Active" });
        }

        [HttpPost("register-driver")]
        public async Task<IActionResult> RegisterDriver([FromBody] LoginDriverDto request)
        {
            // 1. Check if username already exists
            if (await _context.Users.AnyAsync(u => u.Username == request.Username))
            {
                return BadRequest(new { message = "اسم المستخدم موجود مسبقاً" }); // Username already exists
            }

            // 2. Hash the password securely
            string passwordHash = BCrypt.Net.BCrypt.HashPassword(request.Password);

            // 3. Create the user with "Pending" status
            var user = new User
            {
                Username = request.Username,
                PasswordHash = passwordHash,
                UserType = "Ambulance",
                AccountStatus = "Pending", // <--- CRITICAL: Requires Admin Approval
                CreatedAt = DateTime.UtcNow
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            return Ok(new { message = "تم التسجيل بنجاح. يرجى انتظار موافقة الإدارة." }); // Registration successful. Wait for admin.
        }

        // Helper: Generate JWT
        private string GenerateJwtToken(User user)
        {
            var jwtKey = _configuration["JwtSettings:Key"];
            var key = Encoding.ASCII.GetBytes(jwtKey!);

            var tokenHandler = new JwtSecurityTokenHandler();
            var tokenDescriptor = new SecurityTokenDescriptor
            {
                Subject = new ClaimsIdentity(new[]
                {
                    new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
                    new Claim(ClaimTypes.Role, user.UserType)
                }),
                Expires = DateTime.UtcNow.AddDays(7), // Token valid for 7 days
                SigningCredentials = new SigningCredentials(new SymmetricSecurityKey(key), SecurityAlgorithms.HmacSha256Signature)
            };

            var token = tokenHandler.CreateToken(tokenDescriptor);
            return tokenHandler.WriteToken(token);
        }
    }
}