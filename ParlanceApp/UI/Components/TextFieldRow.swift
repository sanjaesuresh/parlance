import SwiftUI

struct TextFieldRow: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var hint: String? = nil
    var isError: Bool = false
    var errorText: String? = nil
    var isDisabled: Bool = false
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences
    var autocorrectionDisabled: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(AppFonts.bodyMedium(14))
                .foregroundStyle(AppColors.sub)

            field
                .padding(14)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(borderColor, lineWidth: isFocused || isError ? 1.5 : 1)
                )
                .disabled(isDisabled)

            if isError, let errorText {
                Text(errorText)
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.error)
            } else if let hint {
                Text(hint)
                    .font(AppFonts.body(11))
                    .foregroundStyle(AppColors.dim)
            }
        }
    }

    @ViewBuilder
    private var field: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(AppFonts.body(17))
        .foregroundStyle(isDisabled ? AppColors.disabled : AppColors.text)
        .keyboardType(keyboardType)
        .textInputAutocapitalization(autocapitalization)
        .autocorrectionDisabled(autocorrectionDisabled)
        .focused($isFocused)
    }

    private var borderColor: Color {
        if isError { return AppColors.error }
        if isFocused { return AppColors.focused }
        return AppColors.border
    }
}
