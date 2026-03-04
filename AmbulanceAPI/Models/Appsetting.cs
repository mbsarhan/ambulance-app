using System;
using System.Collections.Generic;

namespace AmbulanceAPI.Models;

public partial class Appsetting
{
    public int Id { get; set; }

    public int AlertRadiusMeters { get; set; }

    public DateTime? LastUpdated { get; set; }
}
