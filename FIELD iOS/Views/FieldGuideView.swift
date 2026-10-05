import SwiftUI

struct FieldGuideView: View {
    private let articles: [(String, String, String)] = [
        ("Ten Essentials", "backpack", "Navigation, light, sun protection, first aid, knife/repair, fire, shelter, extra food, extra water, and extra clothing."),
        ("Lost / Disoriented", "questionmark.diamond", "Stop moving long enough to think. Confirm your last known position, protect yourself from exposure, and use your route/track before committing to unfamiliar terrain."),
        ("Shelter / Exposure", "tent", "Prioritize insulation from wind, rain, snow, and the ground. Replace wet layers when possible and use your emergency shelter early rather than after you become cold."),
        ("Water Treatment", "drop", "Use a proven filter, purifier, or chemical treatment according to its instructions. Do not assume clear mountain water is safe to drink."),
        ("Hypothermia", "thermometer.snowflake", "Move the person out of cold/wet conditions, insulate them, handle them gently, and seek emergency help for confusion, severe shivering changes, drowsiness, or worsening symptoms."),
        ("Bleeding / Shock", "cross.case", "Use firm direct pressure for serious bleeding and get emergency help. Follow your first-aid training and the instructions of emergency dispatchers."),
        ("Lightning", "bolt", "Leave exposed ridges, peaks, isolated trees, water, and metal structures. Seek a substantial building or hard-topped vehicle when available."),
        ("Signaling", "wave.3.right", "Use multiple methods: phone/satellite/mesh when available, whistle, visible signals, and a clear position report with coordinates and landmarks.")
    ]

    var body: some View {
        List(articles, id: \.0) { article in
            NavigationLink {
                ScrollView {
                    Text(article.2)
                        .font(.body)
                        .foregroundStyle(FieldTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .background(FieldTheme.background)
                .navigationTitle(article.0)
            } label: {
                Label(article.0, systemImage: article.1)
            }
        }
        .scrollContentBackground(.hidden)
        .background(FieldTheme.background)
        .navigationTitle("FIELD GUIDE")
    }
}
