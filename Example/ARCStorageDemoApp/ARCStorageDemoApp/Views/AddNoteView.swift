//
//  AddNoteView.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 28/12/2024.
//

import SwiftUI

struct AddNoteView: View {
    // MARK: Private Properties

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var color: NoteColor = .yellow
    @State private var isPinned = false

    private let onSave: (Note) async -> Void

    // MARK: Initialization

    init(onSave: @escaping (Note) async -> Void) {
        self.onSave = onSave
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("Note title", text: $title)
                }

                Section("Content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                }

                Section("Options") {
                    Picker("Color", selection: $color) {
                        ForEach(NoteColor.allCases, id: \.self) { noteColor in
                            Label(noteColor.displayName, systemImage: "circle.fill")
                                .tint(colorFor(noteColor))
                                .tag(noteColor)
                        }
                    }

                    Toggle("Pin this note", isOn: $isPinned)
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await addNote()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Private Functions

extension AddNoteView {
    private func addNote() async {
        let note = Note(
            title: title,
            content: content,
            isPinned: isPinned,
            color: color
        )

        await onSave(note)
        dismiss()
    }

    private func colorFor(_ noteColor: NoteColor) -> Color {
        switch noteColor {
        case .yellow: .yellow
        case .blue: .blue
        case .green: .green
        case .pink: .pink
        case .purple: .purple
        }
    }
}

// MARK: - Preview

#Preview {
    AddNoteView { _ in }
}
