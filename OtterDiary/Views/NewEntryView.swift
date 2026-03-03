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
    @State private var showDraftDialog = false

    @AppStorage("draft_title") private var draftTitle: String = ""
    @AppStorage("draft_content") private var draftContent: String = ""
    @AppStorage("draft_timestamp") private var draftTimestamp: Double = 0

    let onSave: (_ title: String, _ content: String, _ date: Date, _ mood: Mood?) -> Void

    private var hasUnsavedChanges: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            DiaryColor.pageBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)
                    .padding(.top, 10)
                    .padding(.bottom, DiaryStyle.TopBar.bottomPadding)

                ScrollView {
                    contentCard
                        .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)
                        .padding(.top, DiaryStyle.Spacing.contentTop)
                        .padding(.bottom, DiaryStyle.Spacing.bottomSafe)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .onAppear(perform: restoreDraftIfNeeded)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .interactiveDismissDisabled(hasUnsavedChanges)
        .safeAreaInset(edge: .bottom) {
            bottomToolbar
                .padding(.horizontal, DiaryStyle.Spacing.pageHorizontal)
                .padding(.top, 10)
                .padding(.bottom, DiaryStyle.BottomNav.bottomPadding)
                .frame(minHeight: 74)
                .background(.ultraThinMaterial)
        }
        .alert("功能开发中", isPresented: $showPlaceholderHint) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("图片/语音/表情入口已预留，后续会接入完整能力。")
        }
        .confirmationDialog("保存草稿？", isPresented: $showDraftDialog, titleVisibility: .visible) {
            Button("保存草稿") {
                saveDraft()
                dismiss()
            }
            Button("放弃", role: .destructive) {
                clearDraft()
                dismiss()
            }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("你有未保存内容，是否保存为草稿？")
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                if hasUnsavedChanges {
                    showDraftDialog = true
                } else {
                    dismiss()
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: DiaryStyle.TopBar.iconSize, height: DiaryStyle.TopBar.iconSize)
                    .background(DiaryColor.surfacePrimary)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(DiaryColor.stroke, lineWidth: 1))
            }
            .buttonStyle(DiaryPressButtonStyle(minimumSize: 44, cornerRadius: 22))

            Spacer()
            Text("新建日记").font(.title2.weight(.heavy))
            Spacer()

            Button { showPlaceholderHint = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: DiaryStyle.TopBar.iconSize, height: DiaryStyle.TopBar.iconSize)
                    .background(DiaryColor.surfacePrimary)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(DiaryColor.stroke, lineWidth: 1))
            }
            .buttonStyle(DiaryPressButtonStyle(minimumSize: 44, cornerRadius: 22))
        }
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(date, format: .dateTime.locale(Locale(identifier: "zh_CN")).year().month(.wide).day()).font(.title3.weight(.bold))
                Text(date, format: .dateTime.locale(Locale(identifier: "zh_CN")).weekday(.wide).hour().minute()).font(.subheadline).foregroundStyle(.secondary)
            }

            TextField("标题（可选）", text: $title)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DiaryColor.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            ZStack(alignment: .topLeading) {
                TextEditor(text: $content)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 240)
                    .background(DiaryColor.controlBackground)
                    .clipShape(RoundedRectangle(cornerRadius: DiaryStyle.Radius.control, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DiaryStyle.Radius.control, style: .continuous).stroke(DiaryColor.strokeStrong, lineWidth: 1))
                if content.isEmpty {
                    Text("记录此刻的想法、见闻和心情…")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in tagChip(tag) }
                }
            }
            .scrollIndicators(.hidden)

            TextField("添加标签（如 #学习）", text: $newTagText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit(addTagFromInput)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DiaryColor.controlBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DiaryColor.strokeStrong, lineWidth: 1))
        }
        .padding(16)
        .cardStyle()
    }

    private var bottomToolbar: some View {
        let isDisabled = content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return HStack(spacing: 12) {
            HStack(spacing: 10) {
                toolbarCircleButton(systemName: "camera")
                toolbarCircleButton(systemName: "mic")
                toolbarCircleButton(systemName: "face.smiling")
            }
            Spacer()
            Button {
                onSave(title, content, date, mood)
                clearDraft()
                dismiss()
            } label: {
                Text("完成")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .frame(height: 50)
                    .background(DiaryColor.tintStrong)
                    .clipShape(Capsule())
            }
            .buttonStyle(DiaryPressButtonStyle(minimumSize: 50, cornerRadius: 25, pressedScale: 0.97))
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.52 : 1)
        }
    }

    private func toolbarCircleButton(systemName: String) -> some View {
        Button { showPlaceholderHint = true } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: DiaryStyle.TopBar.iconSize, height: DiaryStyle.TopBar.iconSize)
                .background(DiaryColor.surfacePrimary)
                .clipShape(Circle())
                .overlay(Circle().stroke(DiaryColor.strokeStrong, lineWidth: 1))
        }
        .buttonStyle(DiaryPressButtonStyle(minimumSize: 44, cornerRadius: 22))
    }

    private func tagChip(_ tag: String) -> some View {
        Button { tags.removeAll { $0 == tag } } label: {
            HStack(spacing: 6) {
                Text("#\(tag)").font(.footnote.weight(.semibold))
                Image(systemName: "xmark").font(.caption2.weight(.bold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(DiaryColor.controlBackground)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(DiaryColor.stroke, lineWidth: 1))
        }
        .buttonStyle(DiaryPressButtonStyle(cornerRadius: 16, pressedScale: 0.97))
    }

    private func addTagFromInput() {
        let cleaned = newTagText.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard !cleaned.isEmpty else { return }
        guard !tags.contains(cleaned) else { newTagText = ""; return }
        tags.append(cleaned)
        newTagText = ""
    }

    private func saveDraft() {
        draftTitle = title
        draftContent = content
        draftTimestamp = Date().timeIntervalSince1970
    }

    private func clearDraft() {
        draftTitle = ""
        draftContent = ""
        draftTimestamp = 0
    }

    private func restoreDraftIfNeeded() {
        guard !draftContent.isEmpty || !draftTitle.isEmpty else { return }
        if title.isEmpty && content.isEmpty {
            title = draftTitle
            content = draftContent
        }
    }
}
