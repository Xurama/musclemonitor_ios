//
//  DaySessionsSheet.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 26/09/2025.
//

import SwiftUI
import PhotosUI
import UIKit

struct DaySessionsSheet: View {
    let date: Date

    @EnvironmentObject var vm: CalendarViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editingSession: WorkoutSession? = nil
    @State private var toConfirmDelete: WorkoutSession? = nil

    @State private var shareBackgroundImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem? = nil

    // MARK: - Computed (allège le body)
    private var sessions: [WorkoutSession] {
        vm.sessions(on: date).sorted { $0.endedAt > $1.endedAt }
    }
    private var sessionCount: Int {
        vm.sessions(on: date).count
    }

    // Présentation édition (navigationDestination)
    private var editPresented: Binding<Bool> {
        Binding(
            get: { editingSession != nil },
            set: { if !$0 { editingSession = nil } }
        )
    }

    // Présentation alerte suppression
    private var deletePresented: Binding<Bool> {
        Binding(
            get: { toConfirmDelete != nil },
            set: { if !$0 { toConfirmDelete = nil } }
        )
    }

    private var deleteMessage: Text {
        if let s = toConfirmDelete {
            let f = DateFormatter()
            f.locale = .current
            f.dateStyle = .medium
            f.timeStyle = .short
            return Text("\(s.title) – \(f.string(from: s.endedAt))")
        }
        return Text("")
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { s in
                    NavigationLink {
                        SessionDetailCompactView(session: s, tags: ["Tricep","Core","Shoulders","Chest"])
                    } label: {
                        SessionRow(session: s)
                    }
                    .onLongPressGesture { editingSession = s }
                    .contextMenu {
                        Button("edit", systemImage: "pencil") { editingSession = s }
                        Button("delete", systemImage: "trash", role: .destructive) { toConfirmDelete = s }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { toConfirmDelete = s } label: {
                            Label("delete", systemImage: "trash")
                        }
                        Button { editingSession = s } label: {
                            Label("edit", systemImage: "pencil")
                        }
                    }
                }
            }
            .navigationTitle(dateTitle(date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                PhotosPicker(selection: $photoItem, matching: .images) {
                                    Image(systemName: "photo").imageScale(.medium)
                                }
                            }
                            ToolbarItem(placement: .topBarTrailing) {
                                Button(action: handleShare) { // Appel de la fonction extraite
                                    Image(systemName: "square.and.arrow.up")
                                }
                            }
                ToolbarItem(placement: .topBarTrailing) { Button("close") { dismiss() } }
            }
            // ✅ Navigation édition (binding extrait)
            .navigationDestination(isPresented: editPresented) {
                if let s = editingSession {
                    EditSessionView(
                        original: s,
                        onCancel: { editingSession = nil },
                        onSave: { updated in
                            vm.applyEdit(updated)
                            editingSession = nil
                        }
                    )
                }
            }
            // ✅ Alerte suppression (binding + message extraits)
            .alert("delete_session",
                   isPresented: deletePresented) {
                Button("cancel", role: .cancel) { toConfirmDelete = nil }
                Button("delete", role: .destructive) {
                    if let s = toConfirmDelete {
                        vm.requestDelete(s)
                        vm.confirmDelete()
                    }
                    toConfirmDelete = nil
                }
            } message: {
                deleteMessage
            }
            // ✅ Fermer la sheet si plus de séance ce jour
            .onChange(of: sessionCount) { count in
                if count == 0 { dismiss() }
            }
            .onChange(of: photoItem) { newItem in
                Task { @MainActor in
                    guard let item = newItem else { return }
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        self.shareBackgroundImage = normalized(img)
                    }
                }
            }
        }
    }

    @MainActor
        private func handleShare() {
            let currentSessions = vm.sessions(on: date)
            guard !currentSessions.isEmpty else { return }

            let shareTitle = currentSessions.count == 1 ? (currentSessions.first?.title ?? "Séance") : "Séances du jour"

            let durationTotal = currentSessions.reduce(0) { acc, s in
                max(acc, Int(s.endedAt.timeIntervalSince(s.startedAt)))
            }
            let totalExos = currentSessions.reduce(0) { $0 + $1.exercises.count }

            let card = WorkoutShareCardView(
                title: shareTitle,
                durationText: timeString(durationTotal),
                totalExercises: totalExos,
                currentDate: date,
                background: shareBackgroundImage,
                bestRM: 0.0,
                totalVolume: 0.0,
                starExerciseName: nil
            )

            let renderer = ImageRenderer(content: card)
            renderer.scale = 3.0
            
            guard let ui = renderer.uiImage else { return }

            let scheme = URL(string: "instagram-stories://share")!
            if UIApplication.shared.canOpenURL(scheme) {
                InstagramStorySharing.share(
                    sticker: UIImage(),
                    backgroundColor: nil,
                    backgroundImage: ui,
                    attributionURL: URL(string: "https://musclemonitor.app")
                )
            } else {
                let av = UIActivityViewController(activityItems: [ui], applicationActivities: nil)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(av, animated: true)
                }
            }
        }

        private func dateTitle(_ d: Date) -> String {
            let f = DateFormatter()
            f.locale = .current
            f.dateStyle = .full
            return f.string(from: d)
        }
        
        private func timeString(_ s: Int) -> String {
            let h = s / 3600
            let m = (s % 3600) / 60
            let r = s % 60
            if h > 0 { return String(format: "%d:%02d:%02d", h, m, r) }
            return String(format: "%02d:%02d", m, r)
        }
        
        private func normalized(_ image: UIImage) -> UIImage {
            if image.imageOrientation == .up { return image }
            UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
            image.draw(in: CGRect(origin: .zero, size: image.size))
            let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return normalizedImage ?? image
        }
    }

private struct SessionRow: View {
    let session: WorkoutSession
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title).font(.headline)
                Text(timeRange(session))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(session.exercises.count) exercices – \(durationMinutes(session)) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func timeRange(_ s: WorkoutSession) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.timeStyle = .short
        return "\(f.string(from: s.startedAt)) – \(f.string(from: s.endedAt))"
    }

    private func durationMinutes(_ s: WorkoutSession) -> Int {
        let sec = max(0, Int(s.endedAt.timeIntervalSince(s.startedAt)))
        return max(1, sec / 60)
    }
}

