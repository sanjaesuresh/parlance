import SwiftUI

/// A password field that shows gold-colored dots (matching the Parlance logo period) when hidden.
/// Toggles between secure entry and plain text via an eye button.
struct GoldSecureTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var isRevealed: Bool
    var textContentType: UITextContentType? = .password

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.isSecureTextEntry = !isRevealed
        field.textColor = UIColor(isRevealed ? AppColors.text : AppColors.gold)
        field.tintColor = UIColor(AppColors.gold)
        field.font = UIFont(name: "Inter-Regular", size: 15) ?? .systemFont(ofSize: 15)
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.textContentType = textContentType
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor(AppColors.dim)]
        )
        field.addTarget(context.coordinator, action: #selector(Coordinator.textChanged(_:)), for: .editingChanged)
        field.delegate = context.coordinator
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Preserve text when toggling isSecureTextEntry (iOS clears it otherwise)
        if uiView.isSecureTextEntry != !isRevealed {
            let saved = text
            uiView.isSecureTextEntry = !isRevealed
            uiView.text = saved
        }
        if uiView.text != text {
            uiView.text = text
        }
        uiView.textColor = UIColor(isRevealed ? AppColors.text : AppColors.gold)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String

        init(text: Binding<String>) { _text = text }

        @objc func textChanged(_ field: UITextField) {
            text = field.text ?? ""
        }
    }
}
