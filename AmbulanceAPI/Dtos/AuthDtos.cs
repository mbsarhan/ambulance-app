namespace AmbulanceAPI.Dtos
{
    // For Regular Users (Anonymous)
    public class RegisterGuestDto
    {
        public string DeviceId { get; set; } = string.Empty;
        public string? FcmToken { get; set; }
    }

    // For Ambulance Drivers (Login)
    public class LoginDriverDto
    {
        public string Username { get; set; } = string.Empty;
        public string Password { get; set; } = string.Empty;
        public string? FcmToken { get; set; }
    }

    // Response sent back to Flutter
    public class AuthResponseDto
    {
        public string Token { get; set; } = string.Empty; // The JWT
        public string UserType { get; set; } = string.Empty; // "Regular" or "Ambulance"
        public string Status { get; set; } = string.Empty;
    }
}