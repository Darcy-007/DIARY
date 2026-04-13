import SwiftUI
import Photos

struct DiaryDetailView: View {

    // MARK: - Dependencies

    let entry: DiaryEntry
    let storageManager: StorageManaging
    var onDelete: (() -> Void)?

    // MARK: - State

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation: Bool = false
    @State private var isEditing: Bool = false
    @State private var editedText: String = ""

    // MARK: - Body

    var body: some View {
        if isEditing {
            // Edit mode — full screen text editor
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.date.formatted(date: .long, time: .omitted))
                    .font(.title2.weight(.bold))
                    .padding(.horizontal)
                    .padding(.top, 8)

                TextEditor(text: $editedText)
                    .font(.body)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
            }
            .navigationTitle("Entry")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        entry.text = editedText
                        try? storageManager.save(entry)
                        isEditing = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isEditing = false
                    }
                }
            }
        } else {
            // Read mode — scrollable content
            readView
        }
    }

    private var readView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.date.formatted(date: .long, time: .omitted))
                        .font(.title2.weight(.bold))
                    if entry.isSupplemental {
                        Text("Supplemental Entry")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Text("Created \(entry.createdAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text(entry.text)
                    .font(.body)

                if !entry.photoReferences.isEmpty {
                    photosSection
                }

                if let health = entry.healthSummary {
                    healthSection(health)
                }
            }
            .padding()
        }
        .navigationTitle("Entry")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    editedText = entry.text
                    isEditing = true
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        .alert("Delete Entry?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteEntry()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This diary entry will be permanently deleted.")
        }
    }

    // MARK: - Sections

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Photos", systemImage: "photo.on.rectangle")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(entry.photoReferences, id: \.assetIdentifier) { ref in
                        PhotoThumbnailView(assetIdentifier: ref.assetIdentifier)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }

    private func healthSection(_ health: HealthSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Health", systemImage: "heart.fill")
                .font(.headline)

            HStack(spacing: 16) {
                healthMetric(
                    icon: "figure.walk",
                    value: "\(health.stepCount)",
                    label: "Steps"
                )
                healthMetric(
                    icon: "map",
                    value: String(format: "%.1f km", health.walkingRunningDistanceMeters / 1000),
                    label: "Distance"
                )
                healthMetric(
                    icon: "flame",
                    value: String(format: "%.0f kcal", health.activeEnergyBurnedKcal),
                    label: "Energy"
                )
            }
        }
    }

    private func healthMetric(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.pink)
            Text(value)
                .font(.subheadline.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 70)
    }

    // MARK: - Actions

    private func deleteEntry() {
        do {
            try storageManager.delete(entry)
            onDelete?()
            dismiss()
        } catch {
            // Deletion failed — in a production app we'd show an error
        }
    }
}

// MARK: - Photo Thumbnail

#if canImport(UIKit)
import UIKit

private struct PhotoThumbnailView: View {
    let assetIdentifier: String
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetIdentifier],
            options: nil
        )
        guard let asset = result.firstObject else { return }

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .opportunistic

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 160, height: 160),
            contentMode: .aspectFill,
            options: options
        ) { result, _ in
            if let result {
                self.image = result
            }
        }
    }
}
#else
private struct PhotoThumbnailView: View {
    let assetIdentifier: String

    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
    }
}
#endif
