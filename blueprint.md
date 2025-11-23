# Blueprint: SSH Tunneling App

## Overview

A Flutter application with a native Android component to provide a secure and obfuscated internet connection. The connection sequence is: **Android VpnService -> HTTP Proxy (with custom Payload & SNI) -> SSH Server -> Internet**.

## Architecture

1.  **Flutter UI (Dart):** The user-facing interface, built with Material 3. It is responsible for:
    *   Displaying connection status.
    *   Managing configurations for the Proxy, SSH server, **custom Payload, and SNI**.
    *   Sending start/stop commands to the native service via a `MethodChannel`.

2.  **MethodChannel Bridge:** Communication layer between Flutter UI and the native Android service.

3.  **Native Android `VpnService` (Kotlin/Java):** This is the core engine of the application. It runs as a background service and performs a sophisticated connection sequence for each outgoing request:
    *   Captures all device network traffic using a virtual TUN interface.
    *   Constructs a custom **HTTP `CONNECT`** request to the specified **Proxy Server**.
    *   **Injects the user-defined `Payload`** into this HTTP request to mimic legitimate traffic.
    *   When establishing the connection to the proxy, it **sets the `SNI` (Server Name Indication)** in the TLS handshake to a user-defined value to further disguise the traffic destination.
    *   Once the proxy establishes the tunnel to the **SSH Server**, the service negotiates the SSH connection.
    *   All subsequent application traffic is forwarded through this secure, multi-layered tunnel.

## Features & Design

*   **Modern & Intuitive UI:**
    *   **Dashboard:** Main screen with a prominent connect/disconnect button and clear status indicators.
    *   **Settings Screen:** Well-organized forms for:
        *   Proxy Server (Host, Port)
        *   SSH Server (Host, Port, User, Password/Key)
        *   **Payload** (Text input for the HTTP payload)
        *   **SNI** (Text input for the Server Name Indication)
    *   Ability to save and manage multiple connection profiles.
    *   **Logs Screen:** For detailed debugging information.
*   **Theming:** Light/dark mode support.
*   **State Management:** `provider` package for UI state.

## Current Plan

1.  **Setup Project Dependencies:**
    *   Add `provider` for state management.
    *   Add `google_fonts` for enhanced typography.
2.  **Build Foundational UI:**
    *   Modify `main.dart` to use `provider` for theme and connection state management.
    *   Create `HomePage`, `SettingsPage`, `ThemeProvider`, and `ConnectionProvider` classes.
3.  **Establish MethodChannel Bridge:**
    *   Define the communication methods (e.g., `startVpn`, `stopVpn`, `getStatus`).
