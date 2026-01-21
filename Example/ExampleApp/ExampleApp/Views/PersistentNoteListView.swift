//
//  PersistentNoteListView.swift
//  ExampleApp
//
//  Created by ARC Labs Studio on 21/01/2026.
//

import ARCStorage
import SwiftData
import SwiftUI

struct PersistentNoteListView: View {
    // MARK: Private Properties

    @Bindable private var viewModel: PersistentNotesViewModel
    @State private var showAddNote = false
    @State private var selectedNote: PersistentNote?
    @State private var newNoteTitle = ""
    @State private var newNoteContent = ""
    @State private var newNoteColor: NoteColor = .yellow

    // MARK: Initialization

    init(viewModel: PersistentNotesViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading notes...")
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if viewModel.notes.isEmpty {
                    emptyView
                } else {
                    notesList
                }
            }
            .navigationTitle("Persistent Notes")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showAddNote) {
                addNoteSheet
            }
            .sheet(item: $selectedNote) { note in
                editNoteSheet(note)
            }
            .onAppear {
                viewModel.loadNotes()
            }
        }
    }
}

// MARK: - Subviews

extension PersistentNoteListView {
    fileprivate var notesList: some View {
        List {
            Section {
                ForEach(viewModel.notes) { note in
                    PersistentNoteRowView(note: note)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedNote = note
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                viewModel.togglePin(note)
                            } label: {
                                Label(
                                    note.isPinned ? "Unpin" : "Pin",
                                    systemImage: note.isPinned ? "pin.slash" : "pin"
                                )
                            }
                            .tint(.orange)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.deleteNote(id: note.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } header: {
                Label("SwiftData Storage", systemImage: "externaldrive.fill")
            } footer: {
                Text("Notes are persisted using SwiftData with Swift 6 strict concurrency support.")
            }
        }
    }

    fileprivate var emptyView: some View {
        ContentUnavailableView {
            Label("No Persistent Notes", systemImage: "externaldrive")
        } description: {
            Text("Tap the + button to create your first persistent note.")
        } actions: {
            Button("Load Sample Data") {
                viewModel.loadSampleData()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    fileprivate func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Retry") {
                viewModel.loadNotes()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    fileprivate var addNoteSheet: some View {
        NavigationStack {
            Form {
                Section("Note Details") {
                    TextField("Title", text: $newNoteTitle)
                    TextField("Content", text: $newNoteContent, axis: .vertical)
                        .lineLimit(3 ... 6)
                }

                Section("Color") {
                    Picker("Color", selection: $newNoteColor) {
                        ForEach(NoteColor.allCases, id: \.self) { color in
                            Text(color.displayName).tag(color)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetNewNoteForm()
                        showAddNote = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let note = PersistentNote(
                            title: newNoteTitle,
                            content: newNoteContent,
                            colorName: newNoteColor.rawValue
                        )
                        viewModel.addNote(note)
                        resetNewNoteForm()
                        showAddNote = false
                    }
                    .disabled(newNoteTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    fileprivate func editNoteSheet(_ note: PersistentNote) -> some View {
        NavigationStack {
            Form {
                Section("Note Details") {
                    TextField("Title", text: Binding(
                        get: { note.title },
                        set: { note.title = $0 }
                    ))
                    TextField("Content", text: Binding(
                        get: { note.content },
                        set: { note.content = $0 }
                    ), axis: .vertical)
                        .lineLimit(3 ... 6)
                }

                Section("Color") {
                    Picker("Color", selection: Binding(
                        get: { note.noteColor },
                        set: { note.noteColor = $0 }
                    )) {
                        ForEach(NoteColor.allCases, id: \.self) { color in
                            Text(color.displayName).tag(color)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        viewModel.updateNote(note)
                        selectedNote = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ToolbarContentBuilder fileprivate var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showAddNote = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add Note")
        }

        ToolbarItem(placement: .secondaryAction) {
            Menu {
                Button("Load Sample Data") {
                    viewModel.loadSampleData()
                }

                Button("Clear All", role: .destructive) {
                    viewModel.clearAllNotes()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func resetNewNoteForm() {
        newNoteTitle = ""
        newNoteContent = ""
        newNoteColor = .yellow
    }
}

// MARK: - PersistentNoteRowView

private struct PersistentNoteRowView: View {
    let note: PersistentNote

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(colorForNote)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.title)
                        .font(.headline)
                        .lineLimit(1)

                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(note.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }

    private var colorForNote: Color {
        switch note.noteColor {
        case .yellow: .yellow
        case .blue: .blue
        case .green: .green
        case .pink: .pink
        case .purple: .purple
        }
    }
}

// MARK: - Preview

#Preview("With Notes") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PersistentNote.self, configurations: config)
    let storage = SwiftDataStorage<PersistentNote>(modelContainer: container)
    let repository = SwiftDataRepository(storage: storage)
    let viewModel = PersistentNotesViewModel(repository: repository)

    return PersistentNoteListView(viewModel: viewModel)
        .onAppear {
            viewModel.loadSampleData()
        }
}

#Preview("Empty State") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PersistentNote.self, configurations: config)
    let storage = SwiftDataStorage<PersistentNote>(modelContainer: container)
    let repository = SwiftDataRepository(storage: storage)
    let viewModel = PersistentNotesViewModel(repository: repository)

    return PersistentNoteListView(viewModel: viewModel)
}
