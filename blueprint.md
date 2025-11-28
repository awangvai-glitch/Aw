# VPN App Blueprint

## Overview

This document outlines the architecture, features, and development plan for the Flutter VPN application. The app connects to VPN servers managed via a Supabase backend.

## Implemented Features & Design

*   **UI Framework:** Flutter
*   **State Management:** `provider` package (`ChangeNotifierProvider`)
*   **Backend:** Supabase for storing and retrieving VPN server list.
    *   **Table:** `servers`
*   **VPN Protocol:** OpenVPN, managed via the `openvpn_flutter` package.
*   **Core UI (`lib/main.dart`):**
    *   A main screen (`VpnHomePage`) displays the app's core functionality.
    *   A loading indicator (`CircularProgressIndicator`) is shown while fetching data.
    *   A dropdown menu (`DropdownButton`) lists available VPN servers.
    *   "CONNECT" and "DISCONNECT" buttons control the VPN state.
*   **State & Logic (`lib/vpn_provider.dart`):**
    *   `VpnProvider` class manages all application state.
    *   `fetchVpnServers()`: Asynchronously fetches server data from the `servers` table in Supabase.
    *   Handles loading, connection, and status states.
*   **Data Model (`lib/vpn_server.dart`):**
    *   `VpnServer` class represents a single VPN server.
    *   **Enhanced `fromJson` factory method:**
        *   **Robust Parsing:** Implemented safe type casting (`as String?`) and null-coalescing operators (`??`) to prevent crashes from unexpected `null` or incorrect data types from Supabase.
        *   **Detailed Logging:** Added `dart:developer` logging to output the raw JSON being parsed, making future data-related bugs much easier to diagnose.
        *   **Error Handling:** Wrapped the parsing logic in a `try-catch` block to gracefully handle malformed data and throw a more informative `FormatException`.
*   **Android Configuration (`android/app/src/main/AndroidManifest.xml`):**
    *   Includes necessary permissions for `INTERNET` and VPN services.
*   **Supabase Security:**
    *   A Row Level Security (RLS) policy (`Allow public read access`) is in place on the `servers` table to allow clients to fetch the server list.

## Current Goal: Final Validation and Connection Test

The app was previously failing due to a combination of an incorrect table name and fragile data parsing. Both issues have been addressed.

**Plan:**

1.  **DONE:** Corrected the table name from `vpn_servers` to `servers` in `lib/vpn_provider.dart`.
2.  **DONE:** Created and instructed the user to apply the correct RLS policy to the `servers` table in Supabase.
3.  **DONE:** Fortified the `VpnServer.fromJson` method to handle potential data inconsistencies gracefully.
4.  **PENDING:** Run the application to confirm that the server list is now correctly fetched and displayed in the UI.
5.  **PENDING:** Perform a full connection test by selecting a server and tapping the "CONNECT" button.

