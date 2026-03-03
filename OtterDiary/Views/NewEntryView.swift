import SwiftUI
import PhotosUI

struct NewEntryView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""
    @State private var date = Date()
    @State private var mood: Mood? = nil
    @State private var selectedEmoji: String? = nil
    @State private var imageAssetPaths: [String] = []
    @State private var pickedPhotoItem: PhotosPickerItem?

    @State private var tags: [String] = ["日常", "旅行"]
    @State private var newTagText = ""
    @State private var showDraftDialog = false

    @AppStorage("draft_title") private var draftTitle: String = ""
    @AppStorage("draft_content") private var draftContent: String = ""
    @AppStorage("draft_timestamp") private var draftTimestamp: Double = 0

    let onSave: (_ title: String, _ content: String, _ date: Date, _ mood: Mood?, _ emoji: String?, _ imageAssetPaths: [String]) -> Void

    private let emojiOptions = ["😀","😌","🥳","😴","😢","🤩","🔥","🌧️","📚","☕️"]

    private var hasUnsavedChanges: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !imageAssetPaths.isEmpty
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !imageAssetPaths.isEmpty
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
        .onChange(of: pickedPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let path = try? savePickedImageData(data) {
                    await MainActor.run { imageAssetPaths.append(path) }
                }
                await MainActor.run { pickedPhotoItem = nil }
            }
        }
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
            Color.clear.frame(width: 44, height: 44)
        }
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(date, format: .dateTime.locale(Locale(identifier: "zh_CN")).year().month(.wide).day()).font(.title3.weight(.bold))
                Text(date, format: .dateTime.locale(Locale(identifier: "zh_CN")).weekday(.wide).hour().minute()).font(.subheadline).foregroundStyle(.secondary)
            }

            if let selectedEmoji {
                Text("心情表情：\(selectedEmoji)")
                    .font(.subheadline.weight(.semibold))
            }

            if !imageAssetPaths.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(imageAssetPaths, id: \.self) { path in
                            if let uiImage = UIImage(contentsOfFile: localImageURL(for: path).path) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                .frame(height: 84)
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
        let isDisabled = !canSave
        return HStack(spacing: 12) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $pickedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    toolbarCircleIcon(systemName: "photo")
                }
                Menu {
                    Button("清除表情") { selectedEmoji = nil }
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Button(emoji) { selectedEmoji = emoji }
                    }
                } label: {
                    toolbarCircleIcon(systemName: "face.smiling")
                }
            }
            Spacer()
            Button {
                onSave(title, content, date, mood, selectedEmoji, imageAssetPaths)
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

    private func toolbarCircleIcon(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: DiaryStyle.TopBar.iconSize, height: DiaryStyle.TopBar.iconSize)
            .background(DiaryColor.surfacePrimary)
            .clipShape(Circle())
            .overlay(Circle().stroke(DiaryColor.strokeStrong, lineWidth: 1))
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
    private func savePickedImageData(_ data: Data) throws -> String {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        let dir = docs.appendingPathComponent("entry-images", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let name = "\(UUID().uuidString).jpg"
        try data.write(to: dir.appendingPathComponent(name), options: .atomic)
        return "entry-images/\(name)"
    }

    private func localImageURL(for relativePath: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return docs.appendingPathComponent(relativePath)
    }

}
