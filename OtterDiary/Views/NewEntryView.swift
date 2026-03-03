import SwiftUI

struct NewEntryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""
    @State private var date = Date()
    @State private var mood: Mood? = nil

    @State private var tags: [String] = ["日常", "旅行"]
    @State private var newTagText = ""
    @State private var showPlaceholderHint = false

    let onSave: (_ title: String, _ content: String, _ date: Date, _ mood: Mood?) -> Void

    var body: some View {
        ZStack {
            Color(hex: 0xF3F4F6)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 18)
                    .padding(.top, 10)
                    .padding(.bottom, 10)

                ScrollView {
                    contentCard
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 120)
                }
                .scrollIndicators(.hidden)
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomToolbar
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .background(.ultraThinMaterial)
        }
        .alert("功能开发中", isPresented: $showPlaceholderHint) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("图片/语音/表情入口已预留，后续会接入完整能力。")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 1))
            }

            Spacer()

            Text("新建日记")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Spacer()

            Button {
                showPlaceholderHint = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.black.opacity(0.05), lineWidth: 1))
            }
            .accessibilityLabel("设置")
        }
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(date, format: .dateTime.locale(Locale(identifier: "zh_CN")).year().month(.wide).day())
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text(date, format: .dateTime.locale(Locale(identifier: "zh_CN")).weekday(.wide).hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("内容")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $content)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: 240)
                        .background(Color(hex: 0xF9FAFB))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )

                    if content.isEmpty {
                        Text("记录此刻的想法、见闻和心情…")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("图片")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Button {
                    showPlaceholderHint = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("添加图片")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 130)
                    .background(Color(hex: 0xFCFCFD))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                Color(hex: 0xD1D5DB),
                                style: StrokeStyle(lineWidth: 1.2, dash: [6, 6])
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("标签")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            tagChip(tag)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)

                TextField("添加标签（如 #学习）", text: $newTagText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(addTagFromInput)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(hex: 0xF9FAFB))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(Color.black.opacity(0.04), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.06), radius: 14, y: 8)
        )
    }

    private var bottomToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                toolbarCircleButton(systemName: "camera")
                toolbarCircleButton(systemName: "mic")
                toolbarCircleButton(systemName: "face.smiling")
            }

            Spacer()

            Button {
                onSave(title, content, date, mood)
                dismiss()
            } label: {
                Text("完成")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 48)
                    .background(Color.black)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
            }
            .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
    }

    private func toolbarCircleButton(systemName: String) -> some View {
        Button {
            showPlaceholderHint = true
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(.white)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.black.opacity(0.06), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func tagChip(_ tag: String) -> some View {
        Button {
            tags.removeAll { $0 == tag }
        } label: {
            HStack(spacing: 6) {
                Text("#\(tag)")
                    .font(.footnote.weight(.semibold))
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(hex: 0xF3F4F6))
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func addTagFromInput() {
        let cleaned = newTagText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        guard !cleaned.isEmpty else { return }
        guard !tags.contains(cleaned) else {
            newTagText = ""
            return
        }

        tags.append(cleaned)
        newTagText = ""
    }
}
