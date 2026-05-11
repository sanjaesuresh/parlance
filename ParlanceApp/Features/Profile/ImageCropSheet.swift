import SwiftUI
import UIKit

struct ImageCropSheet: View {
    let image: UIImage
    let onSave: (Data) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let cropDiameter: CGFloat = 300
    private let outputSize: CGFloat = 512

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.bg.ignoresSafeArea()

                VStack(spacing: 28) {
                    Spacer(minLength: 8)

                    cropFrame

                    VStack(spacing: 4) {
                        Text("Pinch to zoom")
                            .font(AppFonts.bodyMedium(13))
                            .foregroundStyle(AppColors.text)
                        Text("Drag to position")
                            .font(AppFonts.body(12))
                            .foregroundStyle(AppColors.sub)
                    }

                    Spacer()

                    Button(action: saveCropped) {
                        Text("Use this photo")
                            .font(AppFonts.bodyBold(15))
                            .foregroundStyle(AppColors.onGold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(AppColors.gold)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Crop avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundStyle(AppColors.sub)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                    .foregroundStyle(AppColors.sub)
                }
            }
        }
    }

    private var cropFrame: some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: cropDiameter, height: cropDiameter)
                .scaleEffect(scale)
                .offset(offset)
                .clipShape(Circle())

            Circle()
                .stroke(AppColors.gold.opacity(0.7), lineWidth: 2)
                .frame(width: cropDiameter, height: cropDiameter)
        }
        .frame(width: cropDiameter, height: cropDiameter)
        .contentShape(Circle())
        .gesture(combinedGesture)
    }

    private var combinedGesture: some Gesture {
        SimultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    scale = max(1.0, min(5.0, lastScale * value.magnification))
                }
                .onEnded { _ in
                    lastScale = scale
                    lastOffset = offset
                },
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in
                    lastOffset = offset
                }
        )
    }

    private func saveCropped() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSize, height: outputSize))
        let outputImage = renderer.image { context in
            let ratio = outputSize / cropDiameter

            context.cgContext.translateBy(x: outputSize / 2, y: outputSize / 2)
            context.cgContext.translateBy(x: offset.width * ratio, y: offset.height * ratio)
            context.cgContext.scaleBy(x: scale, y: scale)

            // scaledToFill into the output square
            let imageAspect = image.size.width / max(image.size.height, 1)
            var drawSize: CGSize
            if imageAspect > 1 {
                drawSize = CGSize(width: outputSize * imageAspect, height: outputSize)
            } else {
                drawSize = CGSize(width: outputSize, height: outputSize / max(imageAspect, 0.01))
            }

            image.draw(in: CGRect(
                x: -drawSize.width / 2,
                y: -drawSize.height / 2,
                width: drawSize.width,
                height: drawSize.height
            ))
        }

        if let data = outputImage.jpegData(compressionQuality: 0.85) {
            onSave(data)
        }
    }
}
