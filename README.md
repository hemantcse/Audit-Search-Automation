# Microsoft 365 Audit Search Automation

PowerShell automation to search the Microsoft 365 Unified Audit Log for a selected date range and export the results to a CSV file.

## 📋 Overview

This script automates Microsoft 365 audit log searches using PowerShell.

The user can:

- Select an output folder
- Enter a Start Date
- Enter an End Date
- Optionally filter by specific operations
- Search all Record Types
- Export audit results to CSV


---

## 🔄 Automation Flow

```text
┌─────────────────────────────┐
│      Start PowerShell       │
└──────────────┬──────────────┘
               ↓
┌─────────────────────────────┐
│    Enter Output Folder      │
└──────────────┬──────────────┘
               ↓
┌─────────────────────────────┐
│ Enter Start & End Date      │
│      DD-MM-YYYY Format      │
└──────────────┬──────────────┘
               ↓
┌─────────────────────────────┐
│   Select Operation Filter   │
│   or Press Enter for All    │
└──────────────┬──────────────┘
               ↓
┌─────────────────────────────┐
│ Connect to Microsoft 365    │
│    Exchange Online Module   │
└──────────────┬──────────────┘
               ↓
┌─────────────────────────────┐
│ Search Unified Audit Log    │
│ Search-UnifiedAuditLog      │
└──────────────┬──────────────┘
               ↓
┌─────────────────────────────┐
│ Retrieve Results in Pages   │
└──────────────┬──────────────┘
               ↓
┌─────────────────────────────┐
│     Parse Audit Details     │
└──────────────┬──────────────┘
               ↓
┌─────────────────────────────┐
│       Export to CSV         │
└──────────────┬──────────────┘
               ↓
┌─────────────────────────────┐
│   Microsoft 365 Audit CSV   │
│          Report             │
└─────────────────────────────┘
