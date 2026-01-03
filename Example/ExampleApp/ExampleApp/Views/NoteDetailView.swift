//
//  NoteDetailView.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 28/12/2024.
//

import SwiftUI

struct NoteDetailView: View {
    // MARK: Private Properties

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    @State private var color: NoteColor
    @State private var isPinned: Bool

    private let note: Note
    private let onSave: (Note) async -> Void

    // MARK: Initialization

    init(note: Note, onSave: @escaping (Note) async -> Void) {
        self.note = note
        self.onSave = onSave
        _title = State(initialValue: note.title)
        _content = State(initialValue: note.content)
        _color = State(initialValue: note.color)
        _isPinned = State(initialValue: note.isPinned)
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

                    Toggle("Pinned", isOn: $isPinned)
                }

                Section("Info") {
                    LabeledContent("Created") {
                        Text(note.createdAt, style: .date)
                    }

                    LabeledContent("Last Modified") {
                        Text(note.updatedAt, style: .relative)
                    }
                }
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveNote()
                        }
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Private Functions

extension NoteDetailView {
    fileprivate func saveNote() async {
        let updated = Note(
            id: note.id,
            title: title,
            content: content,
            createdAt: note.createdAt,
            updatedAt: Date(),
            isPinned: isPinned,
            color: color
        )

        await onSave(updated)
        dismiss()
    }

    fileprivate func colorFor(_ noteColor: NoteColor) -> Color {
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
    NoteDetailView(note: Note.samples[0]) { _ in }
}
