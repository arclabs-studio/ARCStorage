//
//  AuthView.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 05/01/2026.
//

import SwiftUI

/// View demonstrating secure Keychain storage with KeychainAccessibility.
struct AuthView: View {
    // MARK: Properties

    @Bindable var viewModel: AuthViewModel

    // MARK: Body

    var body: some View {
        NavigationStack {
            List {
                securitySection
                tokenSection
                actionsSection
            }
            .navigationTitle("Secure Storage")
            .task {
                await viewModel.loadToken()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.ultraThinMaterial)
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    // Error is cleared on next action
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: Sections

    private var securitySection: some View {
        Section {
            LabeledContent("Security Level") {
                Text(viewModel.securityLevelDescription)
                    .foregroundStyle(.secondary)
            }

            LabeledContent("Storage") {
                Text("iOS Keychain")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Security")
        } footer: {
            Text("Keychain items are encrypted and protected by the device's Secure Enclave.")
        }
    }

    private var tokenSection: some View {
        Section {
            if let token = viewModel.token {
                LabeledContent("User") {
                    Text(token.userEmail)
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Token") {
                    Text(token.token.prefix(16) + "...")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Status") {
                    HStack {
                        Image(systemName: token.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(token.isValid ? .green : .red)
                        Text(token.isValid ? "Valid" : "Expired")
                    }
                }

                if token.isValid {
                    LabeledContent("Expires In") {
                        Text(formatTimeRemaining(token.timeRemaining))
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Issued At") {
                    Text(token.issuedAt, style: .relative)
                        .foregroundStyle(.secondary)
                }
            } else {
                ContentUnavailableView(
                    "Not Authenticated",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Generate a demo token to test secure storage.")
                )
            }
        } header: {
            Text("Authentication Token")
        }
    }

    private var actionsSection: some View {
        Section {
            if viewModel.token == nil {
                Button {
                    Task {
                        await viewModel.generateDemoToken()
                    }
                } label: {
                    Label("Generate Demo Token", systemImage: "key.fill")
                }
            } else {
                Button {
                    Task {
                        await viewModel.refreshToken()
                    }
                } label: {
                    Label("Refresh Token", systemImage: "arrow.clockwise")
                }

                Button(role: .destructive) {
                    Task {
                        await viewModel.deleteToken()
                    }
                } label: {
                    Label("Delete Token (Logout)", systemImage: "trash")
                }
            }
        } header: {
            Text("Actions")
        } footer: {
            Text("In a real app, tokens would be obtained from your authentication server.")
        }
    }

    // MARK: Helpers

    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? "Unknown"
    }
}

// MARK: - Preview

#Preview("With Token") {
    AuthView(
        viewModel: AuthViewModel(securityLevel: .whenUnlockedThisDeviceOnly)
    )
}

#Preview("No Token") {
    AuthView(
        viewModel: AuthViewModel(securityLevel: .whenPasscodeSetThisDeviceOnly)
    )
}
