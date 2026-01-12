//
//  TimeFormatter.swift
//  EFB Agent
//
//  Separate formatters for past and future times
//

import Foundation

struct TimeFormatter {
    // Format past dates: "10m ago", "Just now"
    static func relativePast(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        // "Just now" for ≤1 second
        if interval <= 1.0 {
            return "Just now"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Format future dates: "in 29s", "in 5m", or "Ready" if very soon
    static func relativeFuture(_ date: Date) -> String {
        let interval = date.timeIntervalSince(Date())
        
        // Handle past dates (shouldn't happen but guard against it)
        if interval < 0 {
            return "Ready"
        }
        
        // "Ready" for very near future (≤30s) - upload can happen immediately
        if interval <= 30.0 {
            return "Ready"
        }
        
        // Manual formatting for future dates to ensure "in X" prefix
        if interval < 60 {
            let seconds = Int(interval)
            return "in \(seconds)s"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "in \(minutes)m"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "in \(hours)h"
        } else {
            let days = Int(interval / 86400)
            return "in \(days)d"
        }
    }
}

