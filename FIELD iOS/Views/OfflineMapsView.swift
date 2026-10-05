import SwiftUI
import UniformTypeIdentifiers

struct OfflineMapsView: View {
    @EnvironmentObject private var state: AppState
    @State private var importingMap = false
    @State private var importingPOI = false
    @State private var importingTrails = false
    @State private var errorText: String?
    @State private var layerEdits: [UUID: String] = [:]

    var body: some View {
        List {
            Section("Offline map packs") {
                Button("Import PMTiles File") { importingMap = true }
                if state.mapPacks.isEmpty {
                    Text("No native map packs imported yet.").foregroundStyle(.secondary)
                }
                ForEach(state.mapPacks) { pack in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(pack.originalName)
                            Text("\(pack.sizeLabel) // imported \(pack.importedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if pack.active { StatusPill(text: "MAPLIBRE / LOCAL") }
                    }
                    if pack.active {
                        TextField("Additional vector source-layer IDs (comma separated)",
                                  text: Binding(get: { layerEdits[pack.id] ?? (pack.sourceLayers ?? []).joined(separator: ", ") },
                                                set: { layerEdits[pack.id] = $0 }))
                            .font(.caption).textInputAutocapitalization(.never)
                        Button("Apply layer names") { saveLayers(pack) }
                    }
                    Button(pack.active ? "Deselect local map" : "Use as offline basemap") { setActive(pack) }
                    .buttonStyle(.bordered)
                    .swipeActions { Button("Delete", role: .destructive) { remove(pack) } }
                }
                Text("MapLibre renders the selected PMTiles file from device storage. Raster archives display directly. Vector layers vary by publisher; add source-layer IDs if imported tiles use unusual names. Device rendering must still be tested on iPhone before relying on it in the field.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Offline trail network") {
                Button("Import Trail GeoJSON") { importingTrails = true }
                if let network = state.trailNetwork {
                    LabeledContent("Source", value: network.sourceName)
                    LabeledContent("Trail nodes", value: "\(network.nodes.count)")
                    LabeledContent("Trail segments", value: "\(network.edges.count)")
                    Button("Clear Trail Network", role: .destructive) { state.trailNetwork = nil; state.persist() }
                } else {
                    Text("Import GeoJSON LineString or MultiLineString trails to enable fully offline trail snapping and A* routing.").font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("Offline place index") {
                Button("Import JSON / GeoJSON POIs") { importingPOI = true }
                LabeledContent("Local points", value: "\(state.offlinePOIs.count)")
                Button("Clear Imported POIs", role: .destructive) { state.offlinePOIs = []; state.persist() }
                    .disabled(state.offlinePOIs.isEmpty)
                Text("Imported POIs are searchable from the Map tab without a network connection. Up to 5,000 points are retained per import.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(FieldTheme.background.ignoresSafeArea())
        .tint(FieldTheme.accent)
        .environment(\.defaultMinListRowHeight, 46)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Offline Maps")
        .fileImporter(isPresented: $importingMap,
                      allowedContentTypes: [UTType(filenameExtension: "pmtiles") ?? .data],
                      allowsMultipleSelection: false) { result in importMap(result) }
        .fileImporter(isPresented: $importingPOI,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in importPOI(result) }
        .fileImporter(isPresented: $importingTrails,
                      allowedContentTypes: [.json],
                      allowsMultipleSelection: false) { result in importTrails(result) }
        .alert("Import error", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
            Button("OK", role: .cancel) { errorText = nil }
        } message: { Text(errorText ?? "Unknown error") }
    }

    private func importMap(_ result: Result<[URL], Error>) {
        Task {
            do {
                guard let url = try result.get().first else { return }
                let pack = try await MapPackService.shared.importPack(from: url)
                await MainActor.run {
                    var imported = pack
                    imported.active = state.mapPacks.isEmpty
                    state.mapPacks.append(imported)
                    // Import alone cannot certify offline map rendering.
                    state.readiness.offlineMapChecked = false
                    state.persist()
                }
            } catch { await MainActor.run { errorText = error.localizedDescription } }
        }
    }

    private func importPOI(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let imported = try POIImportService.parse(data: data, sourceName: url.lastPathComponent)
            state.offlinePOIs = imported
            state.persist()
        } catch { errorText = error.localizedDescription }
    }

    private func saveLayers(_ pack: MapPack) {
        let text = layerEdits[pack.id] ?? (pack.sourceLayers ?? []).joined(separator: ",")
        let names = Array(Set(text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.count < 120 })).sorted()
        if let i = state.mapPacks.firstIndex(where: { $0.id == pack.id }) {
            state.mapPacks[i].sourceLayers = names
            // Recreate local style on next pack activation; existing view must be reloaded manually.
            state.persist()
        }
    }

    private func setActive(_ pack: MapPack) {
        state.mapPacks = state.mapPacks.map { current in
            var copy = current
            copy.active = current.id == pack.id ? !pack.active : false
            return copy
        }
        state.persist()
    }

    private func remove(_ pack: MapPack) {
        Task {
            try? await MapPackService.shared.remove(pack)
            await MainActor.run {
                state.mapPacks.removeAll { $0.id == pack.id }
                state.readiness.offlineMapChecked = false
                state.persist()
            }
        }
    }

    private func importTrails(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            state.trailNetwork = try TrailNetworkService.parseGeoJSON(data: data, sourceName: url.lastPathComponent)
            state.persist()
        } catch { errorText = error.localizedDescription }
    }

}
