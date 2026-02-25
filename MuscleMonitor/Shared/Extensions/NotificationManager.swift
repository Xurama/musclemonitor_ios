//
//  NotificationManager.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 13/01/2026.
//


import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Permission accordée")
                self.scheduleMealReminders()
            }
        }
    }
    
    func scheduleMealReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        let reminders = [
            (id: "breakfast", hour: 8, min: 0, title: "breakfast_notif_title", body: "breakfast_notif_body"),
            (id: "lunch", hour: 12, min: 30, title: "lunch_notif_title", body: "lunch_notif_body"),
            (id: "dinner", hour: 19, min: 30, title: "dinner_notif_title", body: "dinner_notif_body")
        ]
        
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = NSLocalizedString(reminder.title, comment: "")
            content.body = NSLocalizedString(reminder.body, comment: "")
            content.sound = .default
            
            var dateComponents = DateComponents()
            dateComponents.hour = reminder.hour
            dateComponents.minute = reminder.min
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
    }
}
