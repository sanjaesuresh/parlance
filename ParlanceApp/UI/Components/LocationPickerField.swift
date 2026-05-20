import SwiftUI

struct LocationPickerField: View {
    @Binding var location: String?

    var label: String = "Location"
    var hint: String? = "Optional"
    var placeholder: String = "Search for your city"

    @StateObject private var search = CitySearchService()
    @StateObject private var network = NetworkMonitor()

    @State private var query: String = ""
    @State private var isResolving = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(AppFonts.bodyBold(10))
                .foregroundStyle(AppColors.dim)
                .kerning(1)

            VStack(spacing: 0) {
                fieldRow
                if isFocused && !network.isConnected {
                    offlineHint
                } else if isFocused && !search.suggestions.isEmpty {
                    Divider().background(AppColors.border)
                    suggestionsList
                }
            }
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? AppColors.gold.opacity(0.6) : AppColors.border, lineWidth: 1)
            )

            if let hint, !isFocused {
                Text(hint)
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                search.clear()
            }
        }
    }

    private var fieldRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 15))
                .foregroundStyle(AppColors.sub)

            if let location, !isFocused {
                Text(location)
                    .font(AppFonts.body(16))
                    .foregroundStyle(AppColors.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("locationSelectedDisplay")
                    .onTapGesture {
                        query = ""
                        isFocused = true
                    }

                Button {
                    self.location = nil
                    query = ""
                    search.clear()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppColors.dim)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("locationClearButton")
            } else {
                TextField(placeholder, text: $query)
                    .font(AppFonts.body(16))
                    .foregroundStyle(AppColors.text)
                    .focused($isFocused)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("locationSearchField")
                    .onChange(of: query) { _, newValue in
                        if network.isConnected {
                            search.search(newValue)
                        }
                    }

                if isResolving {
                    ProgressView().scaleEffect(0.7)
                } else if !query.isEmpty {
                    Button {
                        query = ""
                        search.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(AppColors.dim)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
    }

    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(search.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    Task { await select(suggestion) }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.sub)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(AppFonts.body(15))
                                .foregroundStyle(AppColors.text)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(AppFonts.body(12))
                                    .foregroundStyle(AppColors.sub)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("locationSuggestion_\(index)")
                if suggestion.id != search.suggestions.last?.id {
                    Divider().background(AppColors.border).padding(.leading, 40)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var offlineHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.dim)
            Text("Connect to the internet to search cities")
                .font(AppFonts.body(12))
                .foregroundStyle(AppColors.sub)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func select(_ suggestion: CitySuggestion) async {
        isResolving = true
        defer { isResolving = false }
        if let result = await search.resolve(suggestion) {
            location = result.formatted
            query = ""
            search.clear()
            isFocused = false
        }
    }
}
