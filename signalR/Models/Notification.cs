﻿namespace signalR.Models
{
    public class Notification
    {
        public int notification_id { get; set; }
        public string? notification_send_push_login { get; set; }
        public string? notification_message { get; set; }
        public DateTime notification_register_date { get; set; }
        public string? notification_register_by { get; set; }       
    }
}
