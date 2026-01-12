//
//  DiagnosticsReportCard.swift
//  EFB Agent
//
//  Diagnostics report display card
//

import SwiftUI

struct DiagnosticsReportCard: View {
    let report: DiagnosticsReport
    @State private var copied = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Diagnostics Report")
                    .font(.headline)
                Spacer()
                HStack(spacing: 8) {
                    Button(action: saveReport) {
                        HStack {
                            Image(systemName: "square.and.arrow.down")
                            Text("Save")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }
                    
                    Button(action: shareReport) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                    
                    Button(action: copyReport) {
                        HStack {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            Text(copied ? "Copied" : "Copy")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                DiagnosticsShareSheet(activityItems: shareItems)
            }
            
            Divider()
            
            // Summary
            VStack(alignment: .leading, spacing: 8) {
                Text("Summary")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                DiagnosticsRow(label: "Elapsed Time", value: String(format: "%.2fs", report.elapsedTime))
                DiagnosticsRow(label: "Events Generated", value: "\(report.eventsGenerated)")
                DiagnosticsRow(label: "Rules Passed", value: "\(report.rulesTriggered.filter { $0.passed }.count)/\(report.rulesTriggered.count)")
            }
            
            // Collector Checks
            VStack(alignment: .leading, spacing: 8) {
                Text("Collector Checks")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                DiagnosticsRow(label: "MetricKit", value: report.metricKitAvailable ? "Available" : "Simulated", success: nil)
                DiagnosticsRow(label: "MetricKit Events", value: "\(report.metricKitPayloadCount)")
                DiagnosticsRow(label: "Network Updates", value: "\(report.networkUpdatesCount)")
                DiagnosticsRow(label: "URLSession Metrics", value: "\(report.urlSessionMetricsCount) (simulated)")
            }
            
            // Verification Checks
            VStack(alignment: .leading, spacing: 8) {
                Text("Verification Checks")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                DiagnosticsRow(label: "Store Write", value: report.storeWriteSuccess ? "✓" : "✗", success: report.storeWriteSuccess)
                DiagnosticsRow(label: "Store Read", value: report.storeReadSuccess ? "✓" : "✗", success: report.storeReadSuccess)
                DiagnosticsRow(label: "Encryption", value: report.encryptionSuccess ? "✓" : "✗", success: report.encryptionSuccess)
                DiagnosticsRow(label: "Pending Before", value: "\(report.pendingBeforeUpload)")
                DiagnosticsRow(label: "Pending After", value: "\(report.pendingAfterUpload)")
            }
            
            // Reporting Verification
            VStack(alignment: .leading, spacing: 8) {
                Text("Reporting Verification")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                DiagnosticsRow(label: "Upload Success", value: report.uploadSuccess ? "✓" : "✗", success: report.uploadSuccess)
                if let statusCode = report.uploadStatusCode {
                    DiagnosticsRow(label: "Status Code", value: "\(statusCode)")
                }
                if report.uploadRetries > 0 {
                    DiagnosticsRow(label: "Upload Retries", value: "\(report.uploadRetries)")
                } else if report.uploadSuccess {
                    DiagnosticsRow(label: "Upload Retries", value: "—")
                }
                if let errorMsg = report.uploadErrorMessage, !report.uploadSuccess {
                    DiagnosticsRow(label: "Upload Error", value: errorMsg, success: false)
                }
            }
            
            // Rules
            VStack(alignment: .leading, spacing: 8) {
                Text("Rules")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ForEach(report.rulesTriggered, id: \.ruleId) { rule in
                    VStack(alignment: .leading, spacing: 4) {
                        RuleResultRow(result: rule)
                        if !rule.triggeredEventIds.isEmpty {
                            Text("Event IDs: \(rule.triggeredEventIds.joined(separator: ", "))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                        }
                        if rule.rateLimitChecked || rule.cooldownChecked {
                            HStack(spacing: 8) {
                                if rule.rateLimitChecked {
                                    Text("Rate Limit ✓")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                                if rule.cooldownChecked {
                                    Text("Cooldown ✓")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.leading, 8)
                        }
                    }
                }
            }
            
            // Errors
            if !report.errors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Errors")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                    
                    ForEach(report.errors, id: \.self) { error in
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func copyReport() {
        if let jsonData = try? report.exportJSON(),
           let string = String(data: jsonData, encoding: .utf8) {
            UIPasteboard.general.string = string
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                copied = false
            }
        }
    }
    
    private func saveReport() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: report.timestamp)
        let filename = "efb_agent_diagnostics_\(report.runId)_\(timestamp)"
        
        // Save both JSON and text versions
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Save JSON
        if let jsonData = try? report.exportJSON() {
            let jsonURL = documentsPath.appendingPathComponent("\(filename).json")
            try? jsonData.write(to: jsonURL)
        }
        
        // Save text
        let textContent = report.exportText()
        let textURL = documentsPath.appendingPathComponent("\(filename).txt")
        try? textContent.write(to: textURL, atomically: true, encoding: .utf8)
    }
    
    private func shareReport() {
        var items: [Any] = []
        
        // Add JSON
        if let jsonData = try? report.exportJSON() {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HHmmss"
            let timestamp = formatter.string(from: report.timestamp)
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("efb_diagnostics_\(report.runId)_\(timestamp).json")
            try? jsonData.write(to: tempURL)
            items.append(tempURL)
        }
        
        // Add text
        let textContent = report.exportText()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = formatter.string(from: report.timestamp)
        let textURL = FileManager.default.temporaryDirectory.appendingPathComponent("efb_diagnostics_\(report.runId)_\(timestamp).txt")
        try? textContent.write(to: textURL, atomically: true, encoding: .utf8)
        items.append(textURL)
        
        shareItems = items
        showingShareSheet = true
    }
}

struct DiagnosticsShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DiagnosticsRow: View {
    let label: String
    let value: String
    var success: Bool? = nil
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(success == true ? .green : (success == false ? .red : .primary))
        }
    }
}

struct RuleResultRow: View {
    let result: DiagnosticsReport.RuleTestResult
    
    var body: some View {
        HStack {
            Text(result.ruleName)
                .font(.caption)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.passed ? .green : .red)
                Text(result.passed ? "Pass" : "Fail")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(result.passed ? .green : .red)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(result.passed ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(6)
    }
}

