//
//  NoteListView.swift
//  ARCStorageDemoApp
//
//  Created by ARC Labs Studio on 28/12/2024.
//

import ARCStorage
import SwiftUI

struct NoteListView: View {
    // MARK: Private Properties

    @Bindable private var viewModel: NotesViewModel
    @State private var showAddNote = false
    @State private var selectedNote: Note?

    // MARK: Initialization

    init(viewModel: NotesViewModel) {
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
            .navigationTitle("Notes")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showAddNote) {
                AddNoteView { note in
                    await viewModel.addNote(note)
                }
            }
            .sheet(item: $selectedNote) { note in
                NoteDetailView(note: note) { updated in
                    await viewModel.updateNote(updated)
                }
            }
            .task {
                await viewModel.loadNotes()
            }
            .refreshable {
                await viewModel.refreshNotes()
            }
        }
    }
}

// MARK: - Subviews

extension NoteListView {
    fileprivate var notesList: some View {
        List {
            ForEach(viewModel.notes) { note in
                NoteRowView(note: note)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedNote = note
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            Task {
                                await viewModel.togglePin(note)
                            }
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
                            Task {
                                await viewModel.deleteNote(id: note.id)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
    }

    fileprivate var emptyView: some View {
        ContentUnavailableView {
            Label("No Notes", systemImage: "note.text")
        } description: {
            Text("Tap the + button to create your first note.")
        } actions: {
            Button("Load Sample Data") {
                Task {
                    await viewModel.loadSampleData()
                }
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
                Task {
                    await viewModel.loadNotes()
                }
            }
            .buttonStyle(.borderedProminent)
        }
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
                    Task {
                        await viewModel.loadSampleData()
                    }
                }

                Button("Clear All", role: .destructive) {
                    Task {
                        await viewModel.clearAllNotes()
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }
}

// MARK: - NoteRowView

private struct NoteRowView: View {
    let note: Note

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
        switch note.color {
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
    let viewModel = NotesViewModel(repository: InMemoryRepository<Note>())

    return NoteListView(viewModel: viewModel)
        .task {
            await viewModel.loadSampleData()
        }
}

#Preview("Empty State") {
    NoteListView(viewModel: NotesViewModel(repository: InMemoryRepository<Note>()))
}
