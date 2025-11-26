
# Project Blueprint: SSH Tunneling App

## Overview

This document outlines the plan for creating a simple SSH tunneling application using Flutter. The app will provide a modern, intuitive interface for connecting and disconnecting from an SSH server.

## Features

*   **SSH Connection:** Users can connect to and disconnect from an SSH server using username/password or a private key.
*   **Modern UI:** A beautiful and intuitive user interface that follows modern design guidelines, including a theme toggle for light/dark mode.
*   **Connection Status:** Clear visual indicators for connection status (disconnected, connecting, connected, error) and connection duration.
*   **Cross-Platform:** The app will be built with Flutter, allowing it to run on both Android and iOS.

## Plan

### Phase 1: UI & VPN (Completed & Deprecated)

*   Initial setup with `flutter_vpn`.
*   UI redesign with provider and modern components.

### Phase 2: Pivot to SSH (Current)

1.  **Update Dependencies**: Remove `flutter_vpn` and add the `dartssh2` package for handling SSH connections.
2.  **Refactor State Management**: Create a new `SshStateProvider` to manage the logic and state of the SSH connection.
3.  **Implement SSH Logic**: Use `dartssh2` to establish and terminate SSH connections. The logic will handle authentication via password or private key (placeholders will be provided).
4.  **Adapt UI**: The existing modern UI will be adapted to work with the new `SshStateProvider`. The connection button and status indicators will now reflect the SSH connection state.
5.  **Error Handling**: Implement robust error handling for common SSH connection issues (e.g., authentication failed, host not found).
