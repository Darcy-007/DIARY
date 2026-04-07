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

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
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

                // Task 9.2 — Full diary text
                Text(entry.text)
                    .font(.body)

                // Task 9.2 — Associated photos
                if !entry.photoReferences.isEmpty {
                    photosSection
                }

                // Health summary
                if let health = entry.healthSummary {
                    healthSection(health)
                }

                // Transaction summary
                if !entry.transactionSummary.isEmpty {
                    transactionsSection
                }
            }
            .padding()
        }
        .navigationTitle("Entry")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            // Task 9.5 — Delete button
            ToolbarItem(placement: .destructiveAction) {
                Button("Delete", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
        }
        // Task 9.5 — Delete confirmation alert
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

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Transactions", systemImage: "creditcard")
                .font(.headline)

            ForEach(entry.transactionSummary, id: \.merchantName) { tx in
                HStack {
                    Text(tx.merchantName)
                        .font(.subheadline)
                    Spacer()
                    Text(tx.amount, format: .currency(code: "USD"))
                        .font(.subheadline.weight(.medium))
                }
            }
        }
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
